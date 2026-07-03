import pytest

from server import db, store


@pytest.fixture
def conn(tmp_path):
    c = db.connect(tmp_path / "test.db")
    yield c
    c.close()


def _make_doc(conn, title, ocr_text, tags=(), doc_type="invoice", embedding=None):
    doc_id = store.create_document(conn)
    store.add_page(conn, doc_id, 1, f"/tmp/{doc_id}.jpg")
    conn.execute(
        "UPDATE pages SET ocr_text=? WHERE document_id=?", (ocr_text, doc_id)
    )
    conn.execute(
        "UPDATE documents SET title=?, doc_type=?, status='done' WHERE id=?",
        (title, doc_type, doc_id),
    )
    conn.commit()
    store.set_tags(conn, doc_id, list(tags), source="model")
    store.index_document(conn, doc_id, embedding)
    return doc_id


def test_create_then_enqueue(conn):
    doc_id = store.create_document(conn)
    # no job until pages are safely on disk and enqueue() is called explicitly
    assert conn.execute("SELECT * FROM jobs WHERE document_id=?", (doc_id,)).fetchone() is None
    store.enqueue(conn, doc_id)
    job = conn.execute("SELECT * FROM jobs WHERE document_id=?", (doc_id,)).fetchone()
    assert job["state"] == "queued"


def test_keyword_search_finds_ocr_text(conn):
    a = _make_doc(conn, "Tandarts factuur", "behandeling kies vulling €120")
    _make_doc(conn, "Verzekering polis", "autoverzekering premie")
    hits = store.list_documents(conn, query="vulling")
    assert [h["id"] for h in hits] == [a]


def test_fts_query_escaping_no_injection(conn):
    _make_doc(conn, "x", "hello world")
    # FTS5 syntax characters must not crash or leak syntax
    for evil in ['"foo', "foo*", "a AND b", "col:foo", "(paren"]:
        store.list_documents(conn, query=evil)  # must not raise


def test_hybrid_rrf_prefers_docs_in_both_legs(conn):
    emb_a = [1.0] + [0.0] * 1023
    emb_b = [0.0, 1.0] + [0.0] * 1022
    a = _make_doc(conn, "auto verzekering", "rode auto polis", embedding=emb_a)
    b = _make_doc(conn, "tandarts", "kies vulling", embedding=emb_b)
    # query matches doc a in keyword leg; embedding identical to a's vector
    hits = store.list_documents(conn, query="auto", query_embedding=emb_a)
    assert hits and hits[0]["id"] == a
    ids = [h["id"] for h in hits]
    assert b not in ids or ids.index(b) > 0


def test_filters(conn):
    a = _make_doc(conn, "a", "text a", tags=["bill"], doc_type="invoice")
    b = _make_doc(conn, "b", "text b", tags=["insurance"], doc_type="insurance")
    assert [d["id"] for d in store.list_documents(conn, tag="bill")] == [a]
    assert [d["id"] for d in store.list_documents(conn, doc_type="insurance")] == [b]
    assert store.list_documents(conn, tag="bill", doc_type="insurance") == []


def test_correction_audited_and_verified(conn):
    a = _make_doc(conn, "wrong title", "text")
    conn.execute(
        "INSERT INTO extracted_fields (document_id, key, raw_value) VALUES (?,?,?)",
        (a, "amount_due", "1.00"),
    )
    conn.commit()
    store.apply_correction(conn, a, "amount_due", "2.00")
    doc = store.get_document(conn, a)
    assert doc["amount_due"] == "2.00"
    corr = conn.execute("SELECT * FROM corrections WHERE document_id=?", (a,)).fetchone()
    assert corr["field"] == "amount_due"
    field = conn.execute(
        "SELECT verified FROM extracted_fields WHERE document_id=? AND key='amount_due'", (a,)
    ).fetchone()
    assert field["verified"] == 1


def test_correction_rejects_unknown_field(conn):
    a = _make_doc(conn, "t", "x")
    with pytest.raises(ValueError):
        store.apply_correction(conn, a, "status; DROP TABLE documents", "x")


def test_vector_only_semantic_hit(conn):
    """A doc with no keyword overlap must still surface via its embedding."""
    emb = [0.5] * 1024
    a = _make_doc(conn, "brief", "polis wagen schade", embedding=emb)
    hits = store.list_documents(conn, query="zzzznomatch", query_embedding=emb)
    assert a in [h["id"] for h in hits]

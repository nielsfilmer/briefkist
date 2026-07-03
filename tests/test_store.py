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


def test_cascade_works_on_second_connection(tmp_path):
    """Round-2 residual: PRAGMA foreign_keys is per-connection; a connection
    that skips the DDL fast-path must still get working ON DELETE CASCADE."""
    first = db.connect(tmp_path / "c.db")  # creates schema
    doc_id = store.create_document(first)
    store.add_page(first, doc_id, 1, "/tmp/x.jpg")
    store.enqueue(first, doc_id)
    first.close()

    second = db.connect(tmp_path / "c.db")  # DDL fast-path connection
    store.delete_document(second, doc_id)
    assert second.execute("SELECT COUNT(*) AS n FROM pages").fetchone()["n"] == 0
    assert second.execute("SELECT COUNT(*) AS n FROM jobs").fetchone()["n"] == 0
    second.close()


def test_vector_only_semantic_hit(conn):
    """A doc with no keyword overlap must still surface via its embedding."""
    emb = [0.5] * 1024
    a = _make_doc(conn, "brief", "polis wagen schade", embedding=emb)
    hits = store.list_documents(conn, query="zzzznomatch", query_embedding=emb)
    assert a in [h["id"] for h in hits]


def _emb_at_distance(distance):
    """Unit vector at a chosen cosine distance from the all-[1,0,...] query."""
    import math

    cos = 1.0 - distance
    return [cos, math.sqrt(max(0.0, 1 - cos * cos))] + [0.0] * 1022


_QUERY_EMB = [1.0, 0.0] + [0.0] * 1022


def test_semantic_only_far_hit_rejected_when_better_hit_exists(conn):
    """The 'Inkomstenbelasting' case: a semantic-only doc at distance ~0.6 must
    not ride in behind a clearly better hit (>solo bar, outside the margin)."""
    good = _make_doc(conn, "tax letter", "aangifte inkomstenbelasting",
                     embedding=_emb_at_distance(0.45))
    far = _make_doc(conn, "invoice", "plumbing work", embedding=_emb_at_distance(0.60))
    hits = store.list_documents(conn, query="zzzznomatch", query_embedding=_QUERY_EMB)
    ids = [h["id"] for h in hits]
    assert good in ids
    assert far not in ids


def test_semantic_only_near_tie_admitted(conn):
    """Two semantic-only docs within the margin of each other both surface
    (relative rule), even above the solo absolute bar."""
    a = _make_doc(conn, "a", "xxa", embedding=_emb_at_distance(0.56))
    b = _make_doc(conn, "b", "xxb", embedding=_emb_at_distance(0.58))
    hits = store.list_documents(conn, query="zzzznomatch", query_embedding=_QUERY_EMB)
    ids = [h["id"] for h in hits]
    assert a in ids and b in ids


def test_keyword_confirmed_hit_keeps_lenient_cap(conn):
    """A doc the keyword leg confirms stays admitted at the sanity cap even
    when a semantically closer competitor exists."""
    close = _make_doc(conn, "other", "unrelated text", embedding=_emb_at_distance(0.45))
    confirmed = _make_doc(conn, "match", "findme please",
                          embedding=_emb_at_distance(0.60))
    hits = store.list_documents(conn, query="findme", query_embedding=_QUERY_EMB)
    ids = [h["id"] for h in hits]
    assert confirmed in ids
    assert ids[0] == confirmed  # in both legs -> ranked first by RRF
    assert close in ids  # semantic-only but under the solo absolute bar


def test_sanity_cap_still_applies(conn):
    """Nothing beyond the 0.65 cap surfaces, even as the best available hit."""
    a = _make_doc(conn, "a", "yya", embedding=_emb_at_distance(0.70))
    hits = store.list_documents(conn, query="zzzznomatch", query_embedding=_QUERY_EMB)
    assert a not in [h["id"] for h in hits]

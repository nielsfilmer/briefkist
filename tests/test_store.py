import pytest

from server import db, store


@pytest.fixture
def conn(tmp_path):
    c = db.connect(tmp_path / "test.db")
    yield c
    c.close()


def _make_doc(
    conn, title, ocr_text, category="commercial", keywords=(), summary=None, embedding=None
):
    import json

    doc_id = store.create_document(conn)
    store.add_page(conn, doc_id, 1, f"/tmp/{doc_id}.jpg")
    conn.execute(
        "UPDATE pages SET ocr_text=? WHERE document_id=?", (ocr_text, doc_id)
    )
    conn.execute(
        "UPDATE documents SET title=?, category=?, keywords=?, summary=?, status='done' "
        "WHERE id=?",
        (title, category, json.dumps(list(keywords)), summary, doc_id),
    )
    conn.commit()
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
    a = _make_doc(conn, "a", "text a", category="government")
    b = _make_doc(conn, "b", "text b", category="insurance")
    assert [d["id"] for d in store.list_documents(conn, category="government")] == [a]
    assert [d["id"] for d in store.list_documents(conn, category="insurance")] == [b]
    assert store.list_documents(conn, category="legal") == []


def test_keywords_and_summary_are_searchable(conn):
    """The archive pivot's whole point: curated keywords + summary feed FTS."""
    a = _make_doc(
        conn, "brief", "onleesbare scan",
        keywords=["dakkapel", "vergunning", "gemeente"],
        summary="Besluit over de aanvraag van een dakkapelvergunning.",
    )
    _make_doc(conn, "andere brief", "iets anders")
    assert [h["id"] for h in store.list_documents(conn, query="dakkapel")] == [a]
    assert [h["id"] for h in store.list_documents(conn, query="dakkapelvergunning")] == [a]


def test_keywords_correction_roundtrip(conn):
    a = _make_doc(conn, "brief", "tekst", keywords=["oud"])
    store.apply_correction(conn, a, "keywords", "nieuw, zonnepanelen , ")
    doc = store.get_document(conn, a)
    assert doc["keywords"] == ["nieuw", "zonnepanelen"]
    store.index_document(conn, a, None)
    assert [h["id"] for h in store.list_documents(conn, query="zonnepanelen")] == [a]


def test_correction_audited_and_verified(conn):
    a = _make_doc(conn, "wrong title", "text")
    conn.execute(
        "INSERT INTO extracted_fields (document_id, key, raw_value) VALUES (?,?,?)",
        (a, "document_date", "3 juli 2026"),
    )
    conn.commit()
    store.apply_correction(conn, a, "document_date", "2026-07-04")
    doc = store.get_document(conn, a)
    assert doc["document_date"] == "2026-07-04"
    corr = conn.execute("SELECT * FROM corrections WHERE document_id=?", (a,)).fetchone()
    assert corr["field"] == "document_date"
    field = conn.execute(
        "SELECT verified FROM extracted_fields WHERE document_id=? AND key='document_date'",
        (a,),
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


def test_confirmed_clause_boosts_vec_leg_ranking(conn):
    """Pins the `doc_id in confirmed` clause itself: doc C is keyword rank 1 and
    only outranks keyword rank 0 through its (confirmed-admitted) vec-leg RRF
    contribution — without the clause its 0.60 hit is rejected (a 0.45 anchor
    holds the margin window down) and C drops to last."""
    x = _make_doc(conn, "findme findme findme", "aaa")  # fts rank 0, no vector
    c = _make_doc(conn, "findme", "bbb", embedding=_emb_at_distance(0.60))
    _make_doc(conn, "unrelated", "ccc", embedding=_emb_at_distance(0.45))  # anchor
    hits = store.list_documents(conn, query="findme", query_embedding=_QUERY_EMB)
    ids = [h["id"] for h in hits]
    assert ids[0] == c
    assert x in ids


def test_solo_absolute_bar_boundary(conn):
    """0.49 passes the solo bar, 0.51 fails it (anchored well away so the
    margin rule can't mask the absolute check)."""
    anchor = _make_doc(conn, "anchor", "zz1", embedding=_emb_at_distance(0.30))
    just_under = _make_doc(conn, "under", "zz2", embedding=_emb_at_distance(0.49))
    just_over = _make_doc(conn, "over", "zz3", embedding=_emb_at_distance(0.51))
    ids = [h["id"] for h in store.list_documents(conn, query="zzzznomatch",
                                                 query_embedding=_QUERY_EMB)]
    assert anchor in ids and just_under in ids
    assert just_over not in ids


def test_margin_disabled_when_best_hit_is_keyword_confirmed(conn):
    """The production regression (issue #20, second data point): with the best
    semantic candidate already confirmed by the keyword leg, a semantic-only
    doc inside the margin window must NOT ride along — it needs the absolute
    bar. Distances mirror the real case (0.58 confirmed vs 0.60 solo)."""
    confirmed = _make_doc(conn, "aangifte findme", "inkomstenbelasting tekst",
                          embedding=_emb_at_distance(0.58))
    straggler = _make_doc(conn, "loodgieter", "iets anders",
                          embedding=_emb_at_distance(0.60))
    hits = store.list_documents(conn, query="findme", query_embedding=_QUERY_EMB)
    ids = [h["id"] for h in hits]
    assert confirmed in ids
    assert straggler not in ids


def test_solo_margin_boundary(conn):
    """Gap 0.035 from the best hit is inside the 0.04 margin, 0.045 is outside
    (both above the absolute bar so only the margin rule decides)."""
    best = _make_doc(conn, "best", "yy1", embedding=_emb_at_distance(0.52))
    inside = _make_doc(conn, "inside", "yy2", embedding=_emb_at_distance(0.555))
    outside = _make_doc(conn, "outside", "yy3", embedding=_emb_at_distance(0.565))
    ids = [h["id"] for h in store.list_documents(conn, query="zzzznomatch",
                                                 query_embedding=_QUERY_EMB)]
    assert best in ids and inside in ids
    assert outside not in ids


def test_sanity_cap_still_applies(conn):
    """Nothing beyond the 0.65 cap surfaces, even as the best available hit."""
    a = _make_doc(conn, "a", "yya", embedding=_emb_at_distance(0.70))
    hits = store.list_documents(conn, query="zzzznomatch", query_embedding=_QUERY_EMB)
    assert a not in [h["id"] for h in hits]


def _set_meta(conn, doc_id, correspondent=None, document_date=None):
    conn.execute(
        "UPDATE documents SET correspondent=?, document_date=? WHERE id=?",
        (correspondent, document_date, doc_id),
    )
    conn.commit()


def test_list_filters_correspondent_and_date_range(conn):
    a = _make_doc(conn, "polis", "verzekering")
    b = _make_doc(conn, "jaaropgave", "belasting")
    c = _make_doc(conn, "afspraak", "cardiologie")
    _set_meta(conn, a, "Zilveren Kruis", "2026-03-12")
    _set_meta(conn, b, "Belastingdienst", "2026-01-28")
    _set_meta(conn, c, "UMC Utrecht", None)  # NULL date: never matches a range

    hits = store.list_documents(conn, correspondent="Belastingdienst")
    assert [h["id"] for h in hits] == [b]

    hits = store.list_documents(conn, date_from="2026-02-01")
    assert [h["id"] for h in hits] == [a]

    hits = store.list_documents(conn, date_from="2026-01-01", date_to="2026-01-31")
    assert [h["id"] for h in hits] == [b]

    # range filters compose with a query (hybrid path)
    hits = store.list_documents(conn, query="belasting", date_to="2026-12-31")
    assert [h["id"] for h in hits] == [b]


def test_list_projection_includes_page_count(conn):
    a = _make_doc(conn, "twee paginas", "pagina een")
    store.add_page(conn, a, 2, f"/tmp/{a}_2.jpg")
    conn.commit()
    hits = store.list_documents(conn)
    assert hits[0]["page_count"] == 2


def test_list_correspondents_counts_and_order(conn):
    a = _make_doc(conn, "a", "x")
    b = _make_doc(conn, "b", "y")
    c = _make_doc(conn, "c", "z")
    _set_meta(conn, a, "Zilveren Kruis", None)
    _set_meta(conn, b, "Zilveren Kruis", None)
    _set_meta(conn, c, "Belastingdienst", None)
    got = store.list_correspondents(conn)
    assert got == [
        {"name": "Zilveren Kruis", "count": 2},
        {"name": "Belastingdienst", "count": 1},
    ]


def test_list_date_to_alone_no_query(conn):
    a = _make_doc(conn, "vroeg", "januari brief")
    b = _make_doc(conn, "laat", "december brief")
    _set_meta(conn, a, None, "2026-01-05")
    _set_meta(conn, b, None, "2026-11-30")
    hits = store.list_documents(conn, date_to="2026-06-30")
    assert [h["id"] for h in hits] == [a]


def test_list_correspondents_tiebreak_and_empty_excluded(conn):
    a = _make_doc(conn, "a", "x")
    b = _make_doc(conn, "b", "y")
    c = _make_doc(conn, "c", "z")
    _set_meta(conn, a, "Ziggo", None)
    _set_meta(conn, b, "Belastingdienst", None)
    _set_meta(conn, c, "", None)  # empty string excluded like NULL
    got = store.list_correspondents(conn)
    # equal counts -> alphabetical
    assert got == [
        {"name": "Belastingdienst", "count": 1},
        {"name": "Ziggo", "count": 1},
    ]

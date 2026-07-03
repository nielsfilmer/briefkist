"""v1 -> v2 migration tests against a FROZEN v1 schema fixture.

The DDL below is the v1 schema as shipped (PR #18), deliberately copied
verbatim rather than imported: the whole point is to migrate databases created
by old code, so the fixture must not drift with the current schema module.
"""

import sqlite3

import sqlite_vec

from server import db

_V1_DDL = """
PRAGMA journal_mode=WAL;
CREATE TABLE documents (
    id INTEGER PRIMARY KEY,
    title TEXT,
    correspondent TEXT,
    doc_type TEXT,
    document_date TEXT,
    due_date TEXT,
    amount_due TEXT,
    currency TEXT NOT NULL DEFAULT 'EUR',
    iban TEXT,
    reference TEXT,
    language TEXT,
    subject TEXT,
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued','processing','done','failed')),
    needs_review INTEGER NOT NULL DEFAULT 0,
    review_reasons TEXT,
    source TEXT NOT NULL DEFAULT 'photo',
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    processed_at TEXT,
    error TEXT
);
CREATE TABLE pages (
    id INTEGER PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    page_no INTEGER NOT NULL,
    original_path TEXT NOT NULL,
    cleaned_path TEXT, thumbnail_path TEXT, ocr_text TEXT,
    ocr_confidence REAL, ocr_engine TEXT,
    UNIQUE (document_id, page_no)
);
CREATE TABLE tags (
    id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE,
    kind TEXT NOT NULL DEFAULT 'controlled'
);
CREATE TABLE document_tags (
    document_id INTEGER NOT NULL, tag_id INTEGER NOT NULL,
    source TEXT NOT NULL DEFAULT 'model', UNIQUE (document_id, tag_id)
);
CREATE TABLE extracted_fields (
    id INTEGER PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    key TEXT NOT NULL, raw_value TEXT, normalized_value TEXT,
    valid INTEGER, verified INTEGER NOT NULL DEFAULT 0,
    UNIQUE (document_id, key)
);
CREATE TABLE corrections (
    id INTEGER PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    field TEXT NOT NULL, model_value TEXT, user_value TEXT,
    corrected_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE TABLE jobs (
    id INTEGER PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    state TEXT NOT NULL DEFAULT 'queued'
        CHECK (state IN ('queued','running','done','failed')),
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    started_at TEXT, finished_at TEXT, error TEXT
);
CREATE INDEX idx_jobs_state ON jobs(state, id);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_due ON documents(due_date);
CREATE VIRTUAL TABLE doc_fts USING fts5(
    title, correspondent, subject, reference, ocr_text,
    tokenize = 'unicode61 remove_diacritics 2'
);
PRAGMA user_version = 1;
"""


def _make_v1_db(path):
    conn = sqlite3.connect(path)
    conn.enable_load_extension(True)
    sqlite_vec.load(conn)
    conn.enable_load_extension(False)
    conn.executescript(_V1_DDL)
    conn.executescript(
        "CREATE VIRTUAL TABLE doc_vec USING vec0(embedding float[1024]);"
    )
    # one processed doc (old vocabulary, financial fields set), one failed doc
    conn.execute(
        "INSERT INTO documents (id, title, doc_type, iban, amount_due, due_date, "
        "needs_review, status) VALUES (1, 'Factuur X', 'invoice', "
        "'NL91ABNA0417164300', '12.34', '2026-08-01', 1, 'done')"
    )
    conn.execute(
        "INSERT INTO documents (id, title, doc_type, status, error) "
        "VALUES (2, 'kapot', 'government_tax', 'failed', 'boom')"
    )
    conn.execute("INSERT INTO pages (document_id, page_no, original_path, ocr_text) "
                 "VALUES (1, 1, '/tmp/x.jpg', 'factuur tekst')")
    conn.execute("INSERT INTO extracted_fields (document_id, key, raw_value) "
                 "VALUES (1, 'iban', 'NL91...')")
    conn.execute("INSERT INTO extracted_fields (document_id, key, raw_value) "
                 "VALUES (1, 'document_date', '1 juli 2026')")
    conn.execute("INSERT INTO jobs (document_id, state) VALUES (1, 'done')")
    conn.commit()
    conn.close()


def test_v1_to_v2_migration(tmp_path):
    path = tmp_path / "v1.db"
    _make_v1_db(path)

    conn = db.connect(path)  # triggers the migration
    assert conn.execute("PRAGMA user_version").fetchone()[0] == 2

    cols = {r[1] for r in conn.execute("PRAGMA table_info(documents)")}
    assert {"iban", "due_date", "amount_due", "currency", "needs_review",
            "review_reasons", "doc_type"}.isdisjoint(cols)
    assert {"category", "summary", "keywords", "correspondent_place"} <= cols

    # old vocabulary remapped
    assert conn.execute("SELECT category FROM documents WHERE id=1").fetchone()[0] \
        == "commercial"
    assert conn.execute("SELECT category FROM documents WHERE id=2").fetchone()[0] \
        == "government"

    # only the done+summaryless doc requeued; the failed one left alone
    assert conn.execute(
        "SELECT status FROM documents WHERE id=1").fetchone()[0] == "queued"
    assert conn.execute(
        "SELECT status FROM documents WHERE id=2").fetchone()[0] == "failed"
    assert conn.execute(
        "SELECT COUNT(*) FROM jobs WHERE state='queued' AND document_id=1"
    ).fetchone()[0] == 1

    # financial extracted_fields purged, date kept
    keys = {r[0] for r in conn.execute("SELECT key FROM extracted_fields")}
    assert keys == {"document_date"}

    # tags tables gone; new FTS has the v2 columns and works
    tables = {r[0] for r in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'")}
    assert "tags" not in tables and "document_tags" not in tables
    conn.execute(
        "INSERT INTO doc_fts (rowid, title, correspondent, subject, reference, "
        "keywords, summary, ocr_text) VALUES (1,'t','c','s','r','kw','sum','o')"
    )
    assert conn.execute(
        "SELECT rowid FROM doc_fts WHERE doc_fts MATCH 'kw'").fetchone()[0] == 1
    conn.close()

    # reconnect is a no-op (idempotency)
    again = db.connect(path)
    assert again.execute("PRAGMA user_version").fetchone()[0] == 2
    assert again.execute("SELECT COUNT(*) FROM documents").fetchone()[0] == 2
    again.close()


def test_migration_failure_leaves_v1_intact(tmp_path, monkeypatch):
    """Atomicity: if the migration script dies mid-way, the database must stay
    a fully valid v1 (version unbumped, no columns dropped) so the next
    connect() can retry cleanly instead of crashing forever."""
    path = tmp_path / "v1.db"
    _make_v1_db(path)

    broken = db._MIGRATE_V1_TO_V2.replace(
        "DELETE FROM extracted_fields", "DELETE FROM no_such_table"
    )
    monkeypatch.setattr(db, "_MIGRATE_V1_TO_V2", broken)
    try:
        db.connect(path)
        raise AssertionError("broken migration should raise")
    except sqlite3.OperationalError:
        pass

    monkeypatch.undo()
    conn = db.connect(path)  # retry with the real script succeeds
    assert conn.execute("PRAGMA user_version").fetchone()[0] == 2
    cols = {r[1] for r in conn.execute("PRAGMA table_info(documents)")}
    assert "category" in cols and "iban" not in cols
    conn.close()

"""SQLite schema + connections. One file holds everything: metadata, FTS5
keyword index, sqlite-vec vector index, and the job queue (plan.md §6.5).

sqlite-vec is pre-v1 (pinned in pyproject); its vec0 virtual table stores one
embedding per document keyed by rowid = documents.id.

Schema v2 (decision log v0.4): pure archive — no financial columns, no review
queue; summary + keywords are first-class, indexed metadata.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import sqlite_vec

from . import config

_SCHEMA_VERSION = 2

_SCHEMA = """
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY,
    title TEXT,
    correspondent TEXT,
    correspondent_place TEXT,
    category TEXT,
    document_date TEXT,
    reference TEXT,
    language TEXT,
    subject TEXT,
    summary TEXT,
    keywords TEXT,  -- JSON array of curated search terms
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued','processing','done','failed')),
    source TEXT NOT NULL DEFAULT 'photo',
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    processed_at TEXT,
    error TEXT
);

CREATE TABLE IF NOT EXISTS pages (
    id INTEGER PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    page_no INTEGER NOT NULL,
    original_path TEXT NOT NULL,
    cleaned_path TEXT,
    thumbnail_path TEXT,
    ocr_text TEXT,
    ocr_confidence REAL,
    ocr_engine TEXT,
    UNIQUE (document_id, page_no)
);

CREATE TABLE IF NOT EXISTS extracted_fields (
    id INTEGER PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    key TEXT NOT NULL,
    raw_value TEXT,
    normalized_value TEXT,
    valid INTEGER,
    verified INTEGER NOT NULL DEFAULT 0,
    UNIQUE (document_id, key)
);

CREATE TABLE IF NOT EXISTS corrections (
    id INTEGER PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    field TEXT NOT NULL,
    model_value TEXT,
    user_value TEXT,
    corrected_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS jobs (
    id INTEGER PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    state TEXT NOT NULL DEFAULT 'queued'
        CHECK (state IN ('queued','running','done','failed')),
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    started_at TEXT,
    finished_at TEXT,
    error TEXT
);

CREATE INDEX IF NOT EXISTS idx_jobs_state ON jobs(state, id);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_category ON documents(category);

"""

_FTS_SCHEMA = """
CREATE VIRTUAL TABLE IF NOT EXISTS doc_fts USING fts5(
    title, correspondent, subject, reference, keywords, summary, ocr_text,
    tokenize = 'unicode61 remove_diacritics 2'
);
"""

_VEC_SCHEMA = f"""
CREATE VIRTUAL TABLE IF NOT EXISTS doc_vec USING vec0(
    embedding float[{config.EMBED_DIM}] distance_metric=cosine
);
"""

# v1 -> v2: drop the financial + review columns, rename doc_type -> category,
# add archive metadata, rebuild the FTS table with the new column set, and
# requeue existing documents so the new pipeline fills summary/keywords.
# The whole script (including the FTS recreate appended in _migrate and the
# user_version bump) runs inside ONE transaction: sqlite3.executescript
# autocommits per statement otherwise, and a crash mid-migration would leave
# user_version=1 with columns already dropped — every later connect() would
# retry the migration and die on the missing columns, bricking the archive.
# SQLite DDL is transactional, so BEGIN/COMMIT makes this all-or-nothing.
_MIGRATE_V1_TO_V2 = """
BEGIN;
DROP INDEX IF EXISTS idx_documents_due;
ALTER TABLE documents DROP COLUMN iban;
ALTER TABLE documents DROP COLUMN due_date;
ALTER TABLE documents DROP COLUMN amount_due;
ALTER TABLE documents DROP COLUMN currency;
ALTER TABLE documents DROP COLUMN needs_review;
ALTER TABLE documents DROP COLUMN review_reasons;
ALTER TABLE documents RENAME COLUMN doc_type TO category;
ALTER TABLE documents ADD COLUMN correspondent_place TEXT;
ALTER TABLE documents ADD COLUMN summary TEXT;
ALTER TABLE documents ADD COLUMN keywords TEXT;

UPDATE documents SET category = CASE category
    WHEN 'invoice' THEN 'commercial'
    WHEN 'government_tax' THEN 'government'
    WHEN 'subscription' THEN 'telecom'
    ELSE category END;

DROP TABLE IF EXISTS document_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS doc_fts;

DELETE FROM extracted_fields WHERE key IN ('iban','amount_due','due_date');

CREATE INDEX IF NOT EXISTS idx_documents_category ON documents(category);

-- requeue processed documents so the new pipeline fills summary/keywords and
-- rebuilds their index rows (pages/images are still on disk)
INSERT INTO jobs (document_id)
    SELECT id FROM documents WHERE status = 'done' AND summary IS NULL;
UPDATE documents SET status = 'queued'
    WHERE status = 'done' AND summary IS NULL;
"""


def _migrate(conn: sqlite3.Connection, from_version: int) -> None:
    if from_version == 1:
        # one atomic script: migration body + FTS recreate + version bump
        # (vec table is shape-compatible and left in place)
        conn.executescript(
            _MIGRATE_V1_TO_V2
            + _FTS_SCHEMA
            + f"PRAGMA user_version = {_SCHEMA_VERSION};\nCOMMIT;\n"
        )


def connect(db_path: Path | None = None) -> sqlite3.Connection:
    """Open a connection with extensions loaded and schema ensured."""
    path = db_path or config.DB_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    # check_same_thread=False: FastAPI may run a sync dependency and its cleanup
    # on different threadpool threads. Each request gets its own connection and
    # never shares it concurrently, so this is safe (WAL mode handles the rest).
    conn = sqlite3.connect(path, timeout=30, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.enable_load_extension(True)
    sqlite_vec.load(conn)
    conn.enable_load_extension(False)
    # per-connection pragma (defaults OFF) — must run on EVERY connection, not
    # only the schema-creating one, or ON DELETE CASCADE silently dies
    conn.execute("PRAGMA foreign_keys=ON")
    # DDL/migrations run once per database file (user_version-guarded), not on
    # every per-request connection
    version = conn.execute("PRAGMA user_version").fetchone()[0]
    if version < _SCHEMA_VERSION:
        try:
            if version == 0:
                # fresh database: IF NOT EXISTS DDL is idempotent, crash-safe
                conn.executescript(_SCHEMA)
                conn.executescript(_FTS_SCHEMA)
                conn.executescript(_VEC_SCHEMA)
                conn.execute(f"PRAGMA user_version = {_SCHEMA_VERSION}")
                conn.commit()
            else:
                _migrate(conn, version)  # bumps user_version atomically itself
        except Exception:
            # never leak a connection holding a write transaction — the next
            # connect() must be able to retry against an intact database
            conn.rollback()
            conn.close()
            raise
    return conn

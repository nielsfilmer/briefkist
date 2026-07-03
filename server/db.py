"""SQLite schema + connections. One file holds everything: metadata, FTS5
keyword index, sqlite-vec vector index, and the job queue (plan.md §6.5).

sqlite-vec is pre-v1 (pinned in pyproject); its vec0 virtual table stores one
embedding per document keyed by rowid = documents.id.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import sqlite_vec

from . import config

_SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS documents (
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

CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    kind TEXT NOT NULL DEFAULT 'controlled' CHECK (kind IN ('controlled','free'))
);

CREATE TABLE IF NOT EXISTS document_tags (
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    source TEXT NOT NULL DEFAULT 'model' CHECK (source IN ('model','user')),
    UNIQUE (document_id, tag_id)
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
CREATE INDEX IF NOT EXISTS idx_documents_due ON documents(due_date);

CREATE VIRTUAL TABLE IF NOT EXISTS doc_fts USING fts5(
    title, correspondent, subject, reference, ocr_text,
    tokenize = 'unicode61 remove_diacritics 2'
);
"""

_VEC_SCHEMA = f"""
CREATE VIRTUAL TABLE IF NOT EXISTS doc_vec USING vec0(
    embedding float[{config.EMBED_DIM}]
);
"""


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
    conn.executescript(_SCHEMA)
    conn.executescript(_VEC_SCHEMA)
    return conn

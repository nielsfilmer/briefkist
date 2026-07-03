"""Document CRUD + hybrid search (FTS5 BM25 ⊕ sqlite-vec KNN via Reciprocal
Rank Fusion — plan.md §6.5)."""

from __future__ import annotations

import json
import sqlite3
import struct
from typing import Any

_RRF_K = 60  # standard RRF constant


def serialize_vector(vector: list[float]) -> bytes:
    return struct.pack(f"{len(vector)}f", *vector)


# ---------------------------------------------------------------- create / update


def create_document(conn: sqlite3.Connection, source: str = "photo") -> int:
    cur = conn.execute("INSERT INTO documents (status, source) VALUES ('queued', ?)", (source,))
    doc_id = cur.lastrowid
    conn.execute("INSERT INTO jobs (document_id) VALUES (?)", (doc_id,))
    conn.commit()
    return doc_id


def add_page(
    conn: sqlite3.Connection, doc_id: int, page_no: int, original_path: str
) -> int:
    cur = conn.execute(
        "INSERT INTO pages (document_id, page_no, original_path) VALUES (?,?,?)",
        (doc_id, page_no, original_path),
    )
    conn.commit()
    return cur.lastrowid


def set_tags(
    conn: sqlite3.Connection, doc_id: int, names: list[str], source: str, kind: str = "controlled"
) -> None:
    for name in names:
        conn.execute("INSERT OR IGNORE INTO tags (name, kind) VALUES (?,?)", (name, kind))
        conn.execute(
            "INSERT OR IGNORE INTO document_tags (document_id, tag_id, source) "
            "SELECT ?, id, ? FROM tags WHERE name = ?",
            (doc_id, source, name),
        )
    conn.commit()


def index_document(
    conn: sqlite3.Connection, doc_id: int, embedding: list[float] | None
) -> None:
    """(Re)build the FTS row and vector for a processed document."""
    row = conn.execute("SELECT * FROM documents WHERE id = ?", (doc_id,)).fetchone()
    ocr_text = "\n".join(
        r["ocr_text"] or ""
        for r in conn.execute(
            "SELECT ocr_text FROM pages WHERE document_id = ? ORDER BY page_no", (doc_id,)
        )
    )
    conn.execute("DELETE FROM doc_fts WHERE rowid = ?", (doc_id,))
    conn.execute(
        "INSERT INTO doc_fts (rowid, title, correspondent, subject, reference, ocr_text) "
        "VALUES (?,?,?,?,?,?)",
        (doc_id, row["title"], row["correspondent"], row["subject"], row["reference"], ocr_text),
    )
    if embedding is not None:
        conn.execute("DELETE FROM doc_vec WHERE rowid = ?", (doc_id,))
        conn.execute(
            "INSERT INTO doc_vec (rowid, embedding) VALUES (?,?)",
            (doc_id, serialize_vector(embedding)),
        )
    conn.commit()


def apply_correction(
    conn: sqlite3.Connection, doc_id: int, field: str, value: Any
) -> None:
    """User fixes a field: audit the model value, update, mark verified."""
    allowed = {
        "title", "correspondent", "doc_type", "document_date", "due_date",
        "amount_due", "iban", "reference", "language", "subject", "needs_review",
    }
    if field not in allowed:
        raise ValueError(f"field {field!r} is not correctable")
    old = conn.execute(
        f"SELECT {field} AS v FROM documents WHERE id = ?", (doc_id,)  # noqa: S608 — allowlisted
    ).fetchone()
    if old is None:
        raise KeyError(doc_id)
    conn.execute(
        "INSERT INTO corrections (document_id, field, model_value, user_value) VALUES (?,?,?,?)",
        (doc_id, field, json.dumps(old["v"]), json.dumps(value)),
    )
    conn.execute(f"UPDATE documents SET {field} = ? WHERE id = ?", (value, doc_id))  # noqa: S608
    conn.execute(
        "UPDATE extracted_fields SET verified = 1 WHERE document_id = ? AND key = ?",
        (doc_id, field),
    )
    conn.commit()


# ---------------------------------------------------------------- read / search


def get_document(conn: sqlite3.Connection, doc_id: int) -> dict | None:
    row = conn.execute("SELECT * FROM documents WHERE id = ?", (doc_id,)).fetchone()
    if row is None:
        return None
    doc = dict(row)
    doc["pages"] = [
        dict(r)
        for r in conn.execute(
            "SELECT id, page_no, ocr_confidence, ocr_engine, original_path, cleaned_path, "
            "thumbnail_path FROM pages WHERE document_id = ? ORDER BY page_no",
            (doc_id,),
        )
    ]
    doc["tags"] = [
        r["name"]
        for r in conn.execute(
            "SELECT t.name FROM tags t JOIN document_tags dt ON dt.tag_id = t.id "
            "WHERE dt.document_id = ? ORDER BY t.name",
            (doc_id,),
        )
    ]
    doc["fields"] = [
        dict(r)
        for r in conn.execute(
            "SELECT key, raw_value, normalized_value, valid, verified "
            "FROM extracted_fields WHERE document_id = ?",
            (doc_id,),
        )
    ]
    return doc


def _filtered_ids(
    conn: sqlite3.Connection,
    tag: str | None,
    doc_type: str | None,
    status: str | None,
    needs_review: bool | None,
) -> set[int] | None:
    """Pre-filter by structured criteria; None means 'no filter'."""
    clauses, params = [], []
    if doc_type:
        clauses.append("doc_type = ?")
        params.append(doc_type)
    if status:
        clauses.append("status = ?")
        params.append(status)
    if needs_review is not None:
        clauses.append("needs_review = ?")
        params.append(int(needs_review))
    sql = "SELECT id FROM documents"
    if clauses:
        sql += " WHERE " + " AND ".join(clauses)
    ids = {r["id"] for r in conn.execute(sql, params)}
    if tag:
        tag_ids = {
            r["document_id"]
            for r in conn.execute(
                "SELECT dt.document_id FROM document_tags dt "
                "JOIN tags t ON t.id = dt.tag_id WHERE t.name = ?",
                (tag,),
            )
        }
        ids &= tag_ids
    if not clauses and not tag:
        return None
    return ids


def list_documents(
    conn: sqlite3.Connection,
    query: str | None = None,
    query_embedding: list[float] | None = None,
    tag: str | None = None,
    doc_type: str | None = None,
    status: str | None = None,
    needs_review: bool | None = None,
    limit: int = 50,
) -> list[dict]:
    """No query: newest first. With query: hybrid FTS+vector RRF ranking."""
    allowed_ids = _filtered_ids(conn, tag, doc_type, status, needs_review)

    if not query:
        sql = "SELECT id FROM documents"
        params: list = []
        if allowed_ids is not None:
            if not allowed_ids:
                return []
            sql += f" WHERE id IN ({','.join('?' * len(allowed_ids))})"
            params = list(allowed_ids)
        sql += " ORDER BY created_at DESC, id DESC LIMIT ?"
        params.append(limit)
        ids = [r["id"] for r in conn.execute(sql, params)]
    else:
        # keyword leg
        fts_ranked: list[int] = [
            r["rowid"]
            for r in conn.execute(
                "SELECT rowid FROM doc_fts WHERE doc_fts MATCH ? ORDER BY bm25(doc_fts) LIMIT 100",
                (_fts_query(query),),
            )
        ]
        # semantic leg
        vec_ranked: list[int] = []
        if query_embedding is not None:
            vec_ranked = [
                r["rowid"]
                for r in conn.execute(
                    "SELECT rowid FROM doc_vec WHERE embedding MATCH ? AND k = 100 "
                    "ORDER BY distance",
                    (serialize_vector(query_embedding),),
                )
            ]
        scores: dict[int, float] = {}
        for rank, doc_id in enumerate(fts_ranked):
            scores[doc_id] = scores.get(doc_id, 0.0) + 1.0 / (_RRF_K + rank + 1)
        for rank, doc_id in enumerate(vec_ranked):
            scores[doc_id] = scores.get(doc_id, 0.0) + 1.0 / (_RRF_K + rank + 1)
        ids = [d for d, _ in sorted(scores.items(), key=lambda kv: -kv[1])]
        if allowed_ids is not None:
            ids = [d for d in ids if d in allowed_ids]
        ids = ids[:limit]

    docs = []
    for doc_id in ids:
        row = conn.execute(
            "SELECT id, title, correspondent, doc_type, document_date, due_date, amount_due, "
            "language, status, needs_review, created_at FROM documents WHERE id = ?",
            (doc_id,),
        ).fetchone()
        if row:
            d = dict(row)
            d["tags"] = [
                r["name"]
                for r in conn.execute(
                    "SELECT t.name FROM tags t JOIN document_tags dt ON dt.tag_id = t.id "
                    "WHERE dt.document_id = ?",
                    (doc_id,),
                )
            ]
            docs.append(d)
    return docs


def _fts_query(query: str) -> str:
    """Escape user input into FTS5 phrase-ish terms (no syntax injection)."""
    terms = [t for t in "".join(c if c.isalnum() else " " for c in query).split() if t]
    return " ".join(f'"{t}"' for t in terms) if terms else '""'

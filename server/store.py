"""Document CRUD + hybrid search (FTS5 BM25 ⊕ sqlite-vec KNN via Reciprocal
Rank Fusion — plan.md §6.5)."""

from __future__ import annotations

import datetime as _dt
import json
import sqlite3
import struct
from typing import Any

_RRF_K = 60  # standard RRF constant

# Semantic-leg admission (cosine distance; see db.py schema). Tuned on the
# first real letter + synthetic demo (measurements in issue #20): wrong-doc
# distances (0.50-0.61) overlap paraphrase-hit distances (0.53-0.55), so a
# single absolute bar cannot separate them — but the right doc was closer than
# the wrong doc for every measured query. Hence: keyword-confirmed hits get
# the lenient sanity cap; semantic-ONLY hits additionally need strong absolute
# evidence OR to sit within a small margin of the best semantic hit.
_VEC_MAX_DISTANCE = 0.65  # sanity cap for any semantic hit (nonsense filter)
_VEC_SOLO_MAX_DISTANCE = 0.50  # semantic-only: strong absolute evidence...
_VEC_SOLO_MARGIN = 0.04  # ...or within this of the best semantic distance


def serialize_vector(vector: list[float]) -> bytes:
    return struct.pack(f"{len(vector)}f", *vector)


# ---------------------------------------------------------------- create / update


def create_document(conn: sqlite3.Connection, source: str = "photo") -> int:
    """Creates the document row only — call enqueue() once all pages are safely
    on disk, so the worker never sees a half-uploaded document."""
    cur = conn.execute("INSERT INTO documents (status, source) VALUES ('queued', ?)", (source,))
    doc_id = cur.lastrowid
    conn.commit()
    return doc_id


def enqueue(conn: sqlite3.Connection, doc_id: int) -> None:
    conn.execute("INSERT INTO jobs (document_id) VALUES (?)", (doc_id,))
    conn.commit()


def delete_document(conn: sqlite3.Connection, doc_id: int) -> None:
    """Used to roll back a failed multi-file upload (cascades pages/jobs/tags)."""
    conn.execute("DELETE FROM doc_fts WHERE rowid = ?", (doc_id,))
    conn.execute("DELETE FROM doc_vec WHERE rowid = ?", (doc_id,))
    conn.execute("DELETE FROM documents WHERE id = ?", (doc_id,))
    conn.commit()


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


# correctable field -> value normalizer/validator (raises ValueError on junk)
def _opt_str(value: Any) -> str | None:
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError("expected string or null")
    return value.strip() or None


def _opt_iso_date(value: Any) -> str | None:
    text = _opt_str(value)
    if text is None:
        return None
    return _dt.date.fromisoformat(text).isoformat()  # ValueError on junk


def _opt_amount(value: Any) -> str | None:
    text = _opt_str(value)
    if text is None:
        return None
    return f"{float(text.replace(',', '.')):.2f}"  # ValueError on junk


def _bool_int(value: Any) -> int:
    if isinstance(value, bool | int) and value in (0, 1, True, False):
        return int(value)
    raise ValueError("expected boolean")


_CORRECTABLE: dict[str, Any] = {
    "title": _opt_str,
    "correspondent": _opt_str,
    "doc_type": _opt_str,
    "document_date": _opt_iso_date,
    "due_date": _opt_iso_date,
    "amount_due": _opt_amount,
    "iban": _opt_str,
    "reference": _opt_str,
    "language": _opt_str,
    "subject": _opt_str,
    "needs_review": _bool_int,
}


def apply_correction(
    conn: sqlite3.Connection, doc_id: int, field: str, value: Any
) -> None:
    """User fixes a field: validate the value, audit the model value, update,
    mark verified. Field names are allowlisted (never interpolate user input)."""
    normalizer = _CORRECTABLE.get(field)
    if normalizer is None:
        raise ValueError(f"field {field!r} is not correctable")
    try:
        value = normalizer(value)
    except (ValueError, TypeError) as exc:
        raise ValueError(f"invalid value for {field}: {exc}") from exc
    old = conn.execute(
        f"SELECT {field} AS v FROM documents WHERE id = ?", (doc_id,)  # allowlisted above
    ).fetchone()
    if old is None:
        raise KeyError(doc_id)
    conn.execute(
        "INSERT INTO corrections (document_id, field, model_value, user_value) VALUES (?,?,?,?)",
        (doc_id, field, json.dumps(old["v"]), json.dumps(value)),
    )
    conn.execute(f"UPDATE documents SET {field} = ? WHERE id = ?", (value, doc_id))  # allowlisted
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
    if not (doc_type or status or needs_review is not None or tag):
        return None  # no filters — skip the scan entirely
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
    limit = max(1, min(limit, 200))
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
        # semantic leg: hits the keyword leg already confirmed pass at the
        # sanity cap; semantic-only hits must clear the stricter solo rule
        # (constants + rationale at the top of this module, data in issue #20)
        vec_ranked: list[int] = []
        if query_embedding is not None:
            candidates = [
                (r["rowid"], r["distance"])
                for r in conn.execute(
                    "SELECT rowid, distance FROM doc_vec WHERE embedding MATCH ? "
                    "AND k = 100 ORDER BY distance",
                    (serialize_vector(query_embedding),),
                )
                if r["distance"] <= _VEC_MAX_DISTANCE
            ]
            if candidates:
                best_distance = candidates[0][1]  # ordered by distance
                confirmed = set(fts_ranked)
                vec_ranked = [
                    doc_id
                    for doc_id, distance in candidates
                    if doc_id in confirmed
                    or distance <= _VEC_SOLO_MAX_DISTANCE
                    or distance <= best_distance + _VEC_SOLO_MARGIN
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
            "currency, language, status, needs_review, created_at FROM documents WHERE id = ?",
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

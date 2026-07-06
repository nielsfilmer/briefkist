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


def keywords_list(raw: str | None) -> list[str]:
    """documents.keywords is stored as a JSON array; tolerate legacy nulls."""
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except ValueError:
        return []
    return [str(k) for k in parsed] if isinstance(parsed, list) else []


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
        "INSERT INTO doc_fts (rowid, title, correspondent, subject, reference, "
        "keywords, summary, ocr_text) VALUES (?,?,?,?,?,?,?,?)",
        (
            doc_id,
            row["title"],
            row["correspondent"],
            row["subject"],
            row["reference"],
            " ".join(keywords_list(row["keywords"])),
            row["summary"],
            ocr_text,
        ),
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


def _opt_keywords(value: Any) -> str:
    """UI sends keywords as a comma-separated string; store as a JSON array."""
    if value is None:
        return json.dumps([])
    if isinstance(value, list):
        items = [str(k).strip() for k in value]
    elif isinstance(value, str):
        items = [k.strip() for k in value.split(",")]
    else:
        raise ValueError("expected a comma-separated string or a list")
    return json.dumps([k for k in items if k], ensure_ascii=False)


def _opt_category(value: Any) -> str | None:
    text = _opt_str(value)
    if text is None:
        return None
    from spike.extract import CATEGORIES  # lazy: avoids import cycle at module load

    if text not in CATEGORIES:
        raise ValueError(f"must be one of: {', '.join(CATEGORIES)}")
    return text


_CORRECTABLE: dict[str, Any] = {
    "title": _opt_str,
    "correspondent": _opt_str,
    "correspondent_place": _opt_str,
    "category": _opt_category,
    "document_date": _opt_iso_date,
    "reference": _opt_str,
    "language": _opt_str,
    "subject": _opt_str,
    "summary": _opt_str,
    "keywords": _opt_keywords,
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
    doc["keywords"] = keywords_list(doc.get("keywords"))
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
    category: str | None,
    status: str | None,
    correspondent: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
) -> set[int] | None:
    """Pre-filter by structured criteria; None means 'no filter'."""
    if not (category or status or correspondent or date_from or date_to):
        return None  # no filters — skip the scan entirely
    clauses, params = [], []
    if category:
        clauses.append("category = ?")
        params.append(category)
    if status:
        clauses.append("status = ?")
        params.append(status)
    if correspondent:
        clauses.append("correspondent = ?")
        params.append(correspondent)
    # document_date is ISO (YYYY-MM-DD, deterministic validation §6.4), so
    # string comparison IS date comparison; NULL dates never match a range.
    if date_from:
        clauses.append("document_date >= ?")
        params.append(date_from)
    if date_to:
        clauses.append("document_date <= ?")
        params.append(date_to)
    sql = "SELECT id FROM documents WHERE " + " AND ".join(clauses)
    return {r["id"] for r in conn.execute(sql, params)}


def list_correspondents(conn: sqlite3.Connection) -> list[dict]:
    """Distinct correspondents with document counts, busiest first — feeds
    the desktop sidebar filter."""
    return [
        dict(r)
        for r in conn.execute(
            "SELECT correspondent AS name, COUNT(*) AS count FROM documents "
            "WHERE correspondent IS NOT NULL AND correspondent != '' "
            "GROUP BY correspondent ORDER BY count DESC, name"
        )
    ]


def list_documents(
    conn: sqlite3.Connection,
    query: str | None = None,
    query_embedding: list[float] | None = None,
    category: str | None = None,
    status: str | None = None,
    limit: int = 50,
    correspondent: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
) -> list[dict]:
    """No query: newest first. With query: hybrid FTS+vector RRF ranking."""
    limit = max(1, min(limit, 200))
    allowed_ids = _filtered_ids(conn, category, status, correspondent, date_from, date_to)

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
                best_doc, best_distance = candidates[0]  # ordered by distance
                confirmed = set(fts_ranked)
                # The margin rule exists for PURE-semantic queries, where
                # relative ranking is the only signal. When the best candidate
                # is itself keyword-confirmed, the query is keyword-shaped and
                # semantic-only stragglers near it are exactly the
                # false-positive class (measured twice on 'Inkomstenbelasting',
                # issue #20) — they must show strong absolute evidence instead.
                margin_applies = best_doc not in confirmed
                vec_ranked = [
                    doc_id
                    for doc_id, distance in candidates
                    if doc_id in confirmed
                    or distance <= _VEC_SOLO_MAX_DISTANCE
                    or (margin_applies and distance <= best_distance + _VEC_SOLO_MARGIN)
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
            "SELECT id, title, correspondent, correspondent_place, category, document_date, "
            "reference, language, summary, keywords, status, created_at, "
            "(SELECT COUNT(*) FROM pages WHERE document_id = documents.id) AS page_count "
            "FROM documents WHERE id = ?",
            (doc_id,),
        ).fetchone()
        if row:
            d = dict(row)
            d["keywords"] = keywords_list(d.get("keywords"))
            docs.append(d)
    return docs


def _fts_query(query: str) -> str:
    """Escape user input into FTS5 phrase-ish terms (no syntax injection)."""
    terms = [t for t in "".join(c if c.isalnum() else " " for c in query).split() if t]
    return " ".join(f'"{t}"' for t in terms) if terms else '""'

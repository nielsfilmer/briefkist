"""The per-document processing pipeline (plan.md §9), run by the worker.

Stages: preprocess → OCR → extract → validate/normalize → tag → embed → index.
Every stage's confidence feeds the review-queue decision — low confidence
routes to review instead of silently guessing (plan.md §9 step 8).
"""

from __future__ import annotations

import datetime as dt
import logging
import sqlite3
from pathlib import Path

import cv2

from . import config, store
from .embeddings import embed

log = logging.getLogger("flopy.pipeline")

# spike.* (the proven Phase 0 pipeline components) is imported lazily inside
# process_document: it pulls in pyobjc/OpenCV machinery the API surface doesn't
# need, and it keeps `server.app` importable in tests without the ML stack.
_ocr_engine = None


def _ocr():
    global _ocr_engine
    if _ocr_engine is None:
        from spike.ocr_engines import AppleVisionOCR

        _ocr_engine = AppleVisionOCR()
    return _ocr_engine


def _thumbnail(src: Path, dest: Path, max_side: int = 480) -> None:
    img = cv2.imread(str(src))
    if img is None:
        return
    h, w = img.shape[:2]
    scale = max_side / max(h, w)
    if scale < 1:
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    dest.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(dest), img, [cv2.IMWRITE_JPEG_QUALITY, 80])


def process_document(conn: sqlite3.Connection, doc_id: int) -> None:
    import json

    from spike.extract import extract
    from spike.preprocess import preprocess
    from spike.validate import curate_keywords, normalize_date, normalize_place

    pages = conn.execute(
        "SELECT id, page_no, original_path FROM pages WHERE document_id = ? ORDER BY page_no",
        (doc_id,),
    ).fetchall()
    if not pages:
        raise ValueError(f"document {doc_id} has no pages")

    ocr_texts: list[str] = []
    for page in pages:
        original = Path(page["original_path"])
        cleaned = config.CLEANED_DIR / f"{doc_id}_{page['page_no']}.png"
        thumb = config.THUMBS_DIR / f"{doc_id}_{page['page_no']}.jpg"
        preprocess(original, cleaned)
        _thumbnail(cleaned, thumb)

        ocr = _ocr().recognize(cleaned)
        ocr_texts.append(ocr.text)
        conn.execute(
            "UPDATE pages SET cleaned_path=?, thumbnail_path=?, ocr_text=?, "
            "ocr_confidence=?, ocr_engine=? WHERE id=?",
            (str(cleaned), str(thumb), ocr.text, ocr.mean_confidence, ocr.engine, page["id"]),
        )
    conn.commit()

    full_text = "\n\n".join(ocr_texts)
    # num_ctx is pinned at 4096 (plan decision log #8); ~11k chars ≈ 3k tokens
    # leaves room for prompt + schema output on huge multi-page documents
    extract_text = full_text[:11000]
    first_cleaned = config.CLEANED_DIR / f"{doc_id}_{pages[0]['page_no']}.png"
    extraction, _stats = extract(first_cleaned, extract_text, model=config.VLM_MODEL)

    # Deterministic layer (§6.4): dates are the remaining format-critical field
    date_norm = normalize_date(extraction.document_date)
    conn.execute(
        "INSERT INTO extracted_fields (document_id, key, raw_value, normalized_value, valid) "
        "VALUES (?,?,?,?,?) ON CONFLICT(document_id, key) DO UPDATE SET "
        "raw_value=excluded.raw_value, normalized_value=excluded.normalized_value, "
        "valid=excluded.valid",
        (
            doc_id,
            "document_date",
            extraction.document_date,
            date_norm,
            None if extraction.document_date is None else int(date_norm is not None),
        ),
    )

    title = extraction.subject or (
        f"{extraction.category} — {extraction.sender_name}" if extraction.sender_name else None
    )
    keywords = curate_keywords(extraction.keywords)
    conn.execute(
        "UPDATE documents SET title=?, correspondent=?, correspondent_place=?, category=?, "
        "document_date=?, reference=?, language=?, subject=?, summary=?, keywords=?, "
        "status='done', processed_at=?, error=NULL WHERE id=?",
        (
            title,
            extraction.sender_name,
            normalize_place(extraction.sender_place),
            extraction.category,
            date_norm,
            extraction.reference,
            extraction.language,
            extraction.subject,
            extraction.summary,
            json.dumps(keywords, ensure_ascii=False),
            dt.datetime.now(dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
            doc_id,
        ),
    )

    # summary + keywords lead the embedding text: they are the densest
    # semantic anchor for "find it again years later" queries
    try:
        vector = embed(
            (extraction.summary or "")
            + "\n" + " ".join(keywords)
            + "\n" + (title or "")
            + "\n" + full_text[:6000]
        )
    except Exception as exc:  # noqa: BLE001 — search degrades to keyword-only
        log.warning("embedding failed for doc %s: %s", doc_id, exc)
        vector = None
    store.index_document(conn, doc_id, vector)

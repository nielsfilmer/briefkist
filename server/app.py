"""FastAPI app: ingest, browse/search, correct, static web UI.

Run:  uv run python -m server.app
Bind/auth posture: see config.py and auth.py (plan.md §5.1).
"""

from __future__ import annotations

import contextlib
import datetime
import logging
from pathlib import Path
from typing import Annotated, Any

import uvicorn
from fastapi import Depends, FastAPI, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from . import auth, config, db, store
from .embeddings import embed
from .worker import Worker

log = logging.getLogger("flopy")

WEB_DIR = Path(__file__).resolve().parent.parent / "web"

worker = Worker()


@contextlib.asynccontextmanager
async def _lifespan(app: FastAPI):
    config.validate_bind_host()  # guards `uvicorn server.app:app` runs too
    config.ensure_dirs()
    worker.start()
    yield
    worker.stop()


app = FastAPI(title="my-flopy", lifespan=_lifespan)

Device = Annotated[str, Depends(auth.require_token)]


def _conn(request: Request):
    """One connection per request; SQLite in WAL mode handles concurrency."""
    conn = db.connect()
    try:
        yield conn
    finally:
        conn.close()


Conn = Annotated[Any, Depends(_conn)]


_ALLOWED_SUFFIXES = (".jpg", ".jpeg", ".png", ".heic", ".webp")


def _convert_heic(path: Path) -> Path:
    """OpenCV can't decode HEIC (default iPhone format); convert to JPEG at
    ingest so the pipeline never sees one. pillow-heif is registered lazily."""
    from pillow_heif import register_heif_opener

    register_heif_opener()
    from PIL import Image

    jpeg_path = path.with_suffix(".jpg")
    Image.open(path).convert("RGB").save(jpeg_path, "JPEG", quality=95)
    path.unlink()
    return jpeg_path


@app.post("/api/documents", status_code=202)
async def upload_document(device: Device, conn: Conn, files: list[UploadFile]) -> dict:
    if not files:
        raise HTTPException(400, "no files")
    # validate everything BEFORE creating any state: a bad page 2 must not
    # leave a partial document behind
    suffixes = []
    for page_no, file in enumerate(files, start=1):
        suffix = Path(file.filename or "page.jpg").suffix.lower() or ".jpg"
        if suffix not in _ALLOWED_SUFFIXES:
            raise HTTPException(415, f"unsupported image type {suffix}")
        if file.size is not None and file.size > config.MAX_UPLOAD_BYTES:
            raise HTTPException(413, f"page {page_no} exceeds size limit")
        suffixes.append(suffix)

    doc_id = store.create_document(conn)
    written: list[Path] = []
    try:
        for page_no, (file, suffix) in enumerate(zip(files, suffixes, strict=True), start=1):
            dest = config.ORIGINALS_DIR / f"{doc_id}_{page_no}{suffix}"
            total = 0
            # stream in chunks: never materialize a whole upload in RAM
            with dest.open("wb") as out:
                written.append(dest)
                while chunk := await file.read(1 << 20):
                    total += len(chunk)
                    if total > config.MAX_UPLOAD_BYTES:
                        raise HTTPException(413, f"page {page_no} exceeds size limit")
                    out.write(chunk)
            if total == 0:
                raise HTTPException(400, f"page {page_no} is empty")
            if suffix == ".heic":
                dest = _convert_heic(dest)
                written[-1] = dest
            store.add_page(conn, doc_id, page_no, str(dest))
    except Exception:
        for path in written:
            path.unlink(missing_ok=True)
        store.delete_document(conn, doc_id)
        raise
    store.enqueue(conn, doc_id)
    worker.nudge()
    log.info("device %s uploaded document %s (%d pages)", device, doc_id, len(files))
    return {"id": doc_id, "status": "queued"}


@app.get("/api/documents")
def list_documents(
    device: Device,
    conn: Conn,
    query: str | None = None,
    semantic: bool = True,
    category: str | None = None,
    status: str | None = None,
    limit: int = 50,
    correspondent: str | None = None,
    # datetime.date: FastAPI 422s malformed dates at the edge, so only true
    # ISO strings reach the store's string-compare range filter
    date_from: datetime.date | None = None,
    date_to: datetime.date | None = None,
) -> list[dict]:
    query_embedding = None
    if query and semantic:
        try:
            query_embedding = embed(query)
        except Exception:  # noqa: BLE001 — degrade to keyword-only search
            log.warning("query embedding unavailable; keyword-only")
    return store.list_documents(
        conn,
        query,
        query_embedding,
        category=category,
        status=status,
        limit=min(limit, 200),
        correspondent=correspondent,
        date_from=date_from.isoformat() if date_from else None,
        date_to=date_to.isoformat() if date_to else None,
    )


@app.get("/api/correspondents")
def list_correspondents(device: Device, conn: Conn) -> list[dict]:
    return store.list_correspondents(conn)


@app.get("/api/documents/{doc_id}")
def get_document(device: Device, conn: Conn, doc_id: int) -> dict:
    doc = store.get_document(conn, doc_id)
    if doc is None:
        raise HTTPException(404)
    return doc


@app.patch("/api/documents/{doc_id}")
def correct_document(device: Device, conn: Conn, doc_id: int, patch: dict) -> dict:
    for field, value in patch.items():
        try:
            store.apply_correction(conn, doc_id, field, value)
        except ValueError as exc:
            raise HTTPException(422, str(exc)) from exc
        except KeyError as exc:
            raise HTTPException(404) from exc
    doc = store.get_document(conn, doc_id)
    if doc is None:  # deleted concurrently between PATCH and re-read
        raise HTTPException(404)
    if patch:
        # corrected metadata must be findable — rebuild the FTS row, and
        # refresh the embedding opportunistically (keyword index is the
        # guarantee; the old vector stays if Ollama is down)
        embedding = None
        try:
            ocr_text = "\n".join(
                r["ocr_text"] or ""
                for r in conn.execute(
                    "SELECT ocr_text FROM pages WHERE document_id=? ORDER BY page_no",
                    (doc_id,),
                )
            )
            # same composition as the pipeline: summary + keywords lead
            embedding = embed(
                (doc.get("summary") or "")
                + "\n" + " ".join(doc.get("keywords") or [])
                + "\n" + (doc.get("title") or "")
                + "\n" + ocr_text[:6000]
            )
        except Exception:  # noqa: BLE001 — degrade: FTS reindex still happens
            log.warning("re-embed after correction failed for doc %s", doc_id)
        store.index_document(conn, doc_id, embedding)
    return doc


@app.get("/api/documents/{doc_id}/pages/{page_no}/image")
def page_image(
    device: Device, conn: Conn, doc_id: int, page_no: int, kind: str = "thumb"
) -> FileResponse:
    col = {"original": "original_path", "cleaned": "cleaned_path", "thumb": "thumbnail_path"}.get(
        kind
    )
    if col is None:
        raise HTTPException(422, "kind must be original|cleaned|thumb")
    row = conn.execute(
        f"SELECT {col} AS p FROM pages WHERE document_id=? AND page_no=?",  # col dict-gated above
        (doc_id, page_no),
    ).fetchone()
    if row is None or not row["p"] or not Path(row["p"]).exists():
        raise HTTPException(404)
    return FileResponse(row["p"])


@app.delete("/api/documents/{doc_id}", status_code=204)
def delete_failed_document(device: Device, conn: Conn, doc_id: int) -> None:
    """Cleanup for failed ingests only. Deleting archived documents is a
    retention/product decision (plan.md v2 scope) and deliberately not exposed."""
    row = conn.execute("SELECT status FROM documents WHERE id=?", (doc_id,)).fetchone()
    if row is None:
        raise HTTPException(404)
    if row["status"] != "failed":
        raise HTTPException(409, "only failed documents can be deleted")
    for page in conn.execute(
        "SELECT original_path, cleaned_path, thumbnail_path FROM pages WHERE document_id=?",
        (doc_id,),
    ):
        for key in ("original_path", "cleaned_path", "thumbnail_path"):
            if page[key]:
                Path(page[key]).unlink(missing_ok=True)
    store.delete_document(conn, doc_id)
    log.info("device %s deleted failed document %s", device, doc_id)


@app.get("/api/status")
def status(device: Device, conn: Conn) -> dict:
    queue = {
        r["state"]: r["n"]
        for r in conn.execute("SELECT state, COUNT(*) AS n FROM jobs GROUP BY state")
    }
    docs = {
        r["status"]: r["n"]
        for r in conn.execute("SELECT status, COUNT(*) AS n FROM documents GROUP BY status")
    }
    return {"jobs": queue, "documents": docs}


@app.exception_handler(413)
async def too_large(request: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse(status_code=413, content={"detail": exc.detail})


if WEB_DIR.exists():
    app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="web")


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")
    config.validate_bind_host()
    uvicorn.run(app, host=config.HOST, port=config.PORT, access_log=False)


if __name__ == "__main__":
    main()

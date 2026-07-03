"""FastAPI app: ingest, browse/search, correct, review queue, static web UI.

Run:  uv run python -m server.app
Bind/auth posture: see config.py and auth.py (plan.md §5.1).
"""

from __future__ import annotations

import contextlib
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


@app.post("/api/documents", status_code=202)
async def upload_document(device: Device, conn: Conn, files: list[UploadFile]) -> dict:
    if not files:
        raise HTTPException(400, "no files")
    doc_id = store.create_document(conn)
    for page_no, file in enumerate(files, start=1):
        blob = await file.read()
        if len(blob) > config.MAX_UPLOAD_BYTES:
            raise HTTPException(413, f"page {page_no} exceeds size limit")
        suffix = Path(file.filename or "page.jpg").suffix.lower() or ".jpg"
        if suffix not in (".jpg", ".jpeg", ".png", ".heic", ".webp"):
            raise HTTPException(415, f"unsupported image type {suffix}")
        dest = config.ORIGINALS_DIR / f"{doc_id}_{page_no}{suffix}"
        dest.write_bytes(blob)
        store.add_page(conn, doc_id, page_no, str(dest))
    worker.nudge()
    log.info("device %s uploaded document %s (%d pages)", device, doc_id, len(files))
    return {"id": doc_id, "status": "queued"}


@app.get("/api/documents")
def list_documents(
    device: Device,
    conn: Conn,
    query: str | None = None,
    semantic: bool = True,
    tag: str | None = None,
    doc_type: str | None = None,
    status: str | None = None,
    needs_review: bool | None = None,
    limit: int = 50,
) -> list[dict]:
    query_embedding = None
    if query and semantic:
        try:
            query_embedding = embed(query)
        except Exception:  # noqa: BLE001 — degrade to keyword-only search
            log.warning("query embedding unavailable; keyword-only")
    return store.list_documents(
        conn, query, query_embedding, tag, doc_type, status, needs_review, min(limit, 200)
    )


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
    assert doc is not None
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
        f"SELECT {col} AS p FROM pages WHERE document_id=? AND page_no=?",  # noqa: S608
        (doc_id, page_no),
    ).fetchone()
    if row is None or not row["p"] or not Path(row["p"]).exists():
        raise HTTPException(404)
    return FileResponse(row["p"])


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
    review = conn.execute(
        "SELECT COUNT(*) AS n FROM documents WHERE needs_review = 1"
    ).fetchone()["n"]
    return {"jobs": queue, "documents": docs, "needs_review": review}


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

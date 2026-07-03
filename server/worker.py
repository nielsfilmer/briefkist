"""SQLite-backed job worker: one background thread, strictly sequential
processing (one document at a time keeps peak RAM bounded on the 8 GB host —
plan.md §5.1 setup notes)."""

from __future__ import annotations

import logging
import threading

from . import db
from .pipeline_runner import process_document

log = logging.getLogger("flopy.worker")

_MAX_ATTEMPTS = 2


class Worker:
    def __init__(self, poll_seconds: float = 2.0) -> None:
        self._poll = poll_seconds
        self._stop = threading.Event()
        self._wake = threading.Event()
        self._thread = threading.Thread(target=self._run, name="flopy-worker", daemon=True)

    def start(self) -> None:
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        self._wake.set()
        self._thread.join(timeout=10)

    def nudge(self) -> None:
        """Called after an enqueue so uploads start processing immediately."""
        self._wake.set()

    def _run(self) -> None:
        conn = db.connect()  # thread-local connection, lives with the thread
        # crash recovery: jobs stuck 'running' from a previous process
        conn.execute(
            "UPDATE jobs SET state='queued' WHERE state='running' AND attempts < ?",
            (_MAX_ATTEMPTS,),
        )
        conn.commit()
        while not self._stop.is_set():
            job = conn.execute(
                "SELECT id, document_id, attempts FROM jobs WHERE state='queued' "
                "ORDER BY id LIMIT 1"
            ).fetchone()
            if job is None:
                self._wake.wait(self._poll)
                self._wake.clear()
                continue
            conn.execute(
                "UPDATE jobs SET state='running', attempts=attempts+1, "
                "started_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=?",
                (job["id"],),
            )
            conn.execute(
                "UPDATE documents SET status='processing' WHERE id=?", (job["document_id"],)
            )
            conn.commit()
            try:
                process_document(conn, job["document_id"])
                conn.execute(
                    "UPDATE jobs SET state='done', "
                    "finished_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=?",
                    (job["id"],),
                )
                conn.commit()
                log.info("document %s processed", job["document_id"])
            except Exception as exc:  # noqa: BLE001 — job isolation: one failure never kills the worker
                conn.rollback()
                retry = job["attempts"] + 1 < _MAX_ATTEMPTS
                conn.execute(
                    "UPDATE jobs SET state=?, error=?, "
                    "finished_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=?",
                    ("queued" if retry else "failed", str(exc)[:2000], job["id"]),
                )
                conn.execute(
                    "UPDATE documents SET status=?, error=? WHERE id=?",
                    (
                        "processing" if retry else "failed",
                        str(exc)[:2000],
                        job["document_id"],
                    ),
                )
                conn.commit()
                log.exception("job %s failed (retry=%s)", job["id"], retry)
        conn.close()

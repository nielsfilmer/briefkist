from server import db, store
from server.worker import _MAX_ATTEMPTS, Worker


def _stale_running_job(conn, attempts):
    doc_id = store.create_document(conn)
    store.enqueue(conn, doc_id)
    conn.execute(
        "UPDATE jobs SET state='running', attempts=? WHERE document_id=?",
        (attempts, doc_id),
    )
    conn.execute("UPDATE documents SET status='processing' WHERE id=?", (doc_id,))
    conn.commit()
    return doc_id


def test_recovery_requeues_job_with_attempts_left(tmp_path):
    conn = db.connect(tmp_path / "t.db")
    doc_id = _stale_running_job(conn, attempts=1)
    Worker.recover_stale_jobs(conn)
    job = conn.execute("SELECT state FROM jobs WHERE document_id=?", (doc_id,)).fetchone()
    assert job["state"] == "queued"


def test_recovery_fails_job_that_died_on_final_attempt(tmp_path):
    """A job left 'running' with no attempts remaining must surface as failed,
    not dangle forever (review round-1 blocker B2)."""
    conn = db.connect(tmp_path / "t.db")
    doc_id = _stale_running_job(conn, attempts=_MAX_ATTEMPTS)
    Worker.recover_stale_jobs(conn)
    job = conn.execute("SELECT state, error FROM jobs WHERE document_id=?", (doc_id,)).fetchone()
    doc = conn.execute("SELECT status, error FROM documents WHERE id=?", (doc_id,)).fetchone()
    assert job["state"] == "failed" and job["error"]
    assert doc["status"] == "failed" and doc["error"]

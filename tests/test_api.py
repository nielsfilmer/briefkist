"""API tests with the worker and Ollama mocked out — pipeline correctness is
covered by the spike benchmark; here we test HTTP surface, auth, and wiring."""

import io

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("FLOPY_DATA_DIR", str(tmp_path / "archive"))
    # config reads env at import; reload the module chain against the tmp dir
    import importlib

    from server import app as app_module
    from server import auth, config, db

    importlib.reload(config)
    importlib.reload(db)
    importlib.reload(auth)
    importlib.reload(app_module)
    # don't let the real worker/pipeline run in tests
    monkeypatch.setattr(app_module.worker, "start", lambda: None)
    monkeypatch.setattr(app_module.worker, "stop", lambda: None)
    monkeypatch.setattr(app_module.worker, "nudge", lambda: None)
    # TestClient's request host is "testclient" (not loopback), so the
    # no-tokens bootstrap exception doesn't apply — authenticate like a device
    token = auth.add_device("test-device")
    with TestClient(app_module.app) as c:
        c.headers.update({"Authorization": f"Bearer {token}"})
        yield c


def _jpg() -> tuple[str, io.BytesIO, str]:
    return ("page1.jpg", io.BytesIO(b"\xff\xd8\xff\xe0 fake jpeg"), "image/jpeg")


def test_upload_and_get(client):
    r = client.post("/api/documents", files=[("files", _jpg())])
    assert r.status_code == 202, r.text
    doc_id = r.json()["id"]
    r = client.get(f"/api/documents/{doc_id}")
    assert r.status_code == 200
    doc = r.json()
    assert doc["status"] == "queued"
    assert len(doc["pages"]) == 1


def test_upload_rejects_weird_extension(client):
    r = client.post(
        "/api/documents", files=[("files", ("evil.sh", io.BytesIO(b"#!/bin/sh"), "text/plain"))]
    )
    assert r.status_code == 415


def test_bad_second_page_leaves_no_partial_document(client):
    """Review round-1 blocker B4: a rejected page must roll the whole upload back."""
    r = client.post(
        "/api/documents",
        files=[("files", _jpg()), ("files", ("p2.exe", io.BytesIO(b"MZ"), "text/plain"))],
    )
    assert r.status_code == 415
    from server import db

    conn = db.connect()
    assert conn.execute("SELECT COUNT(*) AS n FROM documents").fetchone()["n"] == 0
    assert conn.execute("SELECT COUNT(*) AS n FROM jobs").fetchone()["n"] == 0
    conn.close()


def test_oversize_upload_rejected(client, monkeypatch):
    from server import config

    monkeypatch.setattr(config, "MAX_UPLOAD_BYTES", 1024)
    big = ("big.jpg", io.BytesIO(b"\xff\xd8" + b"x" * 4096), "image/jpeg")
    r = client.post("/api/documents", files=[("files", big)])
    assert r.status_code == 413
    from server import db

    conn = db.connect()
    assert conn.execute("SELECT COUNT(*) AS n FROM documents").fetchone()["n"] == 0
    conn.close()


def test_page_image_kind_gate(client):
    doc_id = client.post("/api/documents", files=[("files", _jpg())]).json()["id"]
    assert client.get(f"/api/documents/{doc_id}/pages/1/image?kind=../etc").status_code == 422
    # valid kind but file not yet produced by the (mocked-out) worker
    assert client.get(f"/api/documents/{doc_id}/pages/1/image?kind=cleaned").status_code == 404
    assert client.get(f"/api/documents/{doc_id}/pages/9/image?kind=thumb").status_code == 404


def test_patch_validates_values(client):
    doc_id = client.post("/api/documents", files=[("files", _jpg())]).json()["id"]
    assert client.patch(
        f"/api/documents/{doc_id}", json={"needs_review": "banana"}
    ).status_code == 422
    assert client.patch(
        f"/api/documents/{doc_id}", json={"document_date": "not-a-date"}
    ).status_code == 422
    assert client.patch(
        f"/api/documents/{doc_id}", json={"amount_due": "12,34"}
    ).json()["amount_due"] == "12.34"
    assert client.patch(
        f"/api/documents/{doc_id}", json={"needs_review": True}
    ).json()["needs_review"] == 1


def test_status_endpoint(client):
    client.post("/api/documents", files=[("files", _jpg())])
    r = client.get("/api/status")
    assert r.status_code == 200
    body = r.json()
    assert body["jobs"].get("queued", 0) >= 1


def test_patch_correction(client):
    doc_id = client.post("/api/documents", files=[("files", _jpg())]).json()["id"]
    r = client.patch(f"/api/documents/{doc_id}", json={"title": "Fixed title"})
    assert r.status_code == 200
    assert r.json()["title"] == "Fixed title"
    r = client.patch(f"/api/documents/{doc_id}", json={"nonsense_field": 1})
    assert r.status_code == 422


def test_auth_enforced(client):
    from server import auth as auth_module

    # wrong / missing token → 401 (a token exists, so no bootstrap exception)
    bad = client.get("/api/documents", headers={"Authorization": "Bearer wrong"})
    assert bad.status_code == 401
    assert client.get("/api/documents", headers={"Authorization": ""}).status_code == 401
    # a second device can be added and revoked
    token2 = auth_module.add_device("second-phone")
    ok = client.get("/api/documents", headers={"Authorization": f"Bearer {token2}"})
    assert ok.status_code == 200
    assert auth_module.revoke_device("second-phone")
    gone = client.get("/api/documents", headers={"Authorization": f"Bearer {token2}"})
    assert gone.status_code == 401


def test_search_keyword_only_without_ollama(client, monkeypatch):
    """If the embedding service is down, search degrades instead of failing."""
    from server import app as app_module

    def boom(_q):
        raise RuntimeError("ollama down")

    monkeypatch.setattr(app_module, "embed", boom)
    r = client.get("/api/documents", params={"query": "anything"})
    assert r.status_code == 200

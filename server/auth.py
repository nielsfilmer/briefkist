"""Per-device bearer tokens (plan.md §5.1: app auth on top of network identity).

Tokens live in data/archive/tokens.json — outside the repo, inside the (later
encrypted) data dir. Manage with:

    uv run python -m server.tokens_cli add "niels-iphone"
    uv run python -m server.tokens_cli revoke "niels-iphone"
    uv run python -m server.tokens_cli list
"""

from __future__ import annotations

import hmac
import json
import logging
import secrets
import threading

from fastapi import HTTPException, Request

from . import config

# tokens.json is read-modify-written by both the API (threadpool) and the
# CLI; the lock serializes API-side writers (review #40 nit 3). Cross-process
# CLI races remain last-writer-wins — acceptable at household scale.
_write_lock = threading.Lock()


def _load() -> dict[str, dict]:
    """device name -> {"token": ..., "created": ISO-date-or-None}.

    Backwards compatible: pre-pairing files stored a bare token string per
    device; those load as entries with created=None and are rewritten in the
    new shape on the next save."""
    if not config.TOKENS_PATH.exists():
        return {}
    raw = json.loads(config.TOKENS_PATH.read_text(encoding="utf-8"))
    return {
        name: (value if isinstance(value, dict) else {"token": value, "created": None})
        for name, value in raw.items()
    }


def _save(tokens: dict[str, dict]) -> None:
    import os

    config.TOKENS_PATH.parent.mkdir(parents=True, exist_ok=True)
    # Atomic replace: a concurrent _load must never see a half-written file
    # (review #40). 0600 from the first byte; os.replace also normalizes
    # perms on files created before this hardening.
    tmp = config.TOKENS_PATH.with_suffix(f".json.{os.getpid()}.tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(tokens, fh, indent=2)
    os.replace(tmp, config.TOKENS_PATH)


class DeviceExists(Exception):
    """A device with that name is already paired."""


class BadDeviceName(Exception):
    """Name fails the charset/shape rules (message says why)."""


def validate_name(name: object) -> str:
    """Charset allowlist (review #40): '/' would make the device
    irrevocable via DELETE /api/devices/{name}; control chars would allow
    log-line injection; a leading '_' collides with the '_bootstrap_loopback'
    sentinel namespace."""
    if not isinstance(name, str):
        raise BadDeviceName("device name must be a string")
    name = name.strip()
    if not name:
        raise BadDeviceName("device name required")
    if len(name) > 64:
        raise BadDeviceName("device name too long (max 64)")
    if name.startswith("_"):
        raise BadDeviceName("device names may not start with '_'")
    if any(
        ch == "/" or ord(ch) < 32 or 127 <= ord(ch) <= 159 or ch in "\u2028\u2029"
        for ch in name
    ):
        raise BadDeviceName("device names may not contain '/' or control characters")
    return name


def add_device(name: str) -> tuple[str, str]:
    """Returns (token, created). Raises BadDeviceName / DeviceExists."""
    import datetime

    name = validate_name(name)
    with _write_lock:
        tokens = _load()
        if name in tokens:
            raise DeviceExists(name)
        token = secrets.token_urlsafe(32)
        created = datetime.date.today().isoformat()
        tokens[name] = {"token": token, "created": created}
        _save(tokens)
    return token, created


def revoke_device(name: str) -> bool:
    with _write_lock:
        tokens = _load()
        if tokens.pop(name, None) is None:
            return False
        _save(tokens)
    return True


def list_devices() -> list[dict]:
    """[{name, created}] — never exposes tokens."""
    return [
        {"name": name, "created": entry.get("created")}
        for name, entry in sorted(_load().items())
    ]


def require_token(request: Request) -> str:
    """FastAPI dependency: validates `Authorization: Bearer <token>`.
    Returns the device name. If no tokens are configured yet, allows loopback
    clients only (first-run bootstrap so you can mint the first token via UI/CLI).
    """
    tokens = _load()
    header = request.headers.get("authorization", "")
    supplied = header.removeprefix("Bearer ").strip() if header.startswith("Bearer ") else ""
    for device, entry in tokens.items():
        if supplied and hmac.compare_digest(supplied, entry["token"]):
            return device
    if supplied:
        # a token was presented and matched nothing — always reject, even in
        # bootstrap mode (a wrong token must never look like success)
        raise HTTPException(status_code=401, detail="invalid device token")
    if not tokens and request.client and request.client.host in ("127.0.0.1", "::1"):
        logging.getLogger("flopy.auth").warning(
            "bootstrap mode: no device tokens configured — allowing loopback "
            "request without auth (mint a token with `python -m server.tokens_cli add`)"
        )
        return "_bootstrap_loopback"
    raise HTTPException(status_code=401, detail="missing or invalid device token")

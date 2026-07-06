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

from fastapi import HTTPException, Request

from . import config


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
    # 0600 from the first byte — no window where the file is world-readable
    fd = os.open(config.TOKENS_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(tokens, fh, indent=2)


class DeviceExists(Exception):
    """A device with that name is already paired."""


def add_device(name: str) -> str:
    import datetime

    tokens = _load()
    if name in tokens:
        raise DeviceExists(name)
    token = secrets.token_urlsafe(32)
    tokens[name] = {
        "token": token,
        "created": datetime.date.today().isoformat(),
    }
    _save(tokens)
    return token


def revoke_device(name: str) -> bool:
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

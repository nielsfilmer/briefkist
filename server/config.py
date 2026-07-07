"""Runtime configuration. Environment variables, sane local-first defaults.

Security posture (plan.md §5.1): bind loopback by default. For LAN use set
FLOPY_HOST to the machine's LAN address explicitly; for road use bind the
Tailscale interface address (Phase 3). Never 0.0.0.0 in normal operation —
the server refuses it unless FLOPY_ALLOW_CONTAINER_BIND=1 (containers, where
the port mapping is the exposure decision — see validate_bind_host) or
FLOPY_ALLOW_ANY_BIND=1 (test escape hatch).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

# env prefix FLOPY_ predates the Briefkist rename; kept for compatibility (rename tracked in #44)
HOST = os.environ.get("FLOPY_HOST", "127.0.0.1")
PORT = int(os.environ.get("FLOPY_PORT", "8484"))
DATA_DIR = Path(os.environ.get("FLOPY_DATA_DIR", "data/archive")).resolve()
DB_PATH = DATA_DIR / "flopy.db"
ORIGINALS_DIR = DATA_DIR / "originals"
CLEANED_DIR = DATA_DIR / "cleaned"
THUMBS_DIR = DATA_DIR / "thumbs"
TOKENS_PATH = DATA_DIR / "tokens.json"

# OCR engine (plan.md §6.2): Apple Vision on macOS (the benchmarked primary),
# PaddleOCR everywhere else (Linux/Docker — Apple Vision doesn't exist off
# macOS; needs the `paddle` extra installed). Override with FLOPY_OCR_ENGINE.
OCR_ENGINE = os.environ.get("FLOPY_OCR_ENGINE") or (
    "apple_vision" if sys.platform == "darwin" else "paddleocr"
)

VLM_MODEL = os.environ.get("FLOPY_VLM_MODEL", "qwen3-vl:4b-instruct")
EMBED_MODEL = os.environ.get("FLOPY_EMBED_MODEL", "bge-m3")
EMBED_DIM = 1024  # bge-m3
OLLAMA_URL = os.environ.get("FLOPY_OLLAMA_URL", "http://127.0.0.1:11434")

MAX_UPLOAD_BYTES = 25 * 1024 * 1024  # per image; capture photos are ~2-6 MB


def ensure_dirs() -> None:
    for d in (DATA_DIR, ORIGINALS_DIR, CLEANED_DIR, THUMBS_DIR):
        d.mkdir(parents=True, exist_ok=True)


def validate_bind_host() -> None:
    """Refuse wildcard binds (plan.md §5.1: no public exposure) — covers
    0.0.0.0, ::, and empty-string forms, not just the IPv4 literal. Called from
    the app lifespan so it also guards direct `uvicorn server.app:app` runs.

    Escape hatches (both explicit opt-ins; the refusal stays the default):
    - FLOPY_ALLOW_CONTAINER_BIND=1 — for containers, where 0.0.0.0 binds the
      container's private namespace only and the *port mapping* is the real
      exposure decision; §5.1's "bind a specific interface" guidance moves to
      the host level (publish `127.0.0.1:8484:8484` or a LAN/overlay address,
      never a bare `8484:8484` on an internet-facing box). docker-compose.yml
      sets this; never set it on bare metal.
    - FLOPY_ALLOW_ANY_BIND=1 — test escape hatch.
    """
    import ipaddress

    if os.environ.get("FLOPY_ALLOW_ANY_BIND") == "1":
        return
    if os.environ.get("FLOPY_ALLOW_CONTAINER_BIND") == "1":
        return
    try:
        unspecified = ipaddress.ip_address(HOST).is_unspecified
    except ValueError:
        unspecified = HOST.strip() == ""  # hostnames like "localhost" are fine
    if unspecified:
        raise SystemExit(
            f"Refusing to bind {HOST!r} (plan.md §5.1: no public exposure). "
            "Set FLOPY_HOST to a specific interface address."
        )

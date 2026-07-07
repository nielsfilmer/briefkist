# Briefkist server image (Linux distribution path — the native macOS install
# stays the primary, best-tested path; see docs/RUNBOOK.md).
#
# OCR inside this image is PaddleOCR (the `paddle` extra): Apple Vision does
# not exist off macOS (plan.md §6.2, docs/research/oss-distribution-licensing.md
# §2). The PP-OCRv5 models are baked in at build time so the running container
# needs NO network access except Ollama — pre-download-at-install-time is the
# same egress-lockdown pattern as `ollama pull` (plan.md §5.1).

# ---- Stage 1: resolve + install dependencies with uv ------------------------
FROM python:3.12-slim-bookworm AS builder

COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /uvx /usr/local/bin/

# Use the image's CPython (matches the runtime stage); copy instead of
# hardlinking across Docker layers.
ENV UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy

WORKDIR /app
COPY pyproject.toml uv.lock ./
# Locked resolve only — the project itself is a non-package (no build-system),
# so this installs exactly the pinned dependency set incl. the paddle extra.
RUN uv sync --frozen --no-dev --extra paddle

# ---- Stage 2: runtime --------------------------------------------------------
FROM python:3.12-slim-bookworm

# System libraries the Python wheels link against but slim doesn't ship:
# - libgl1 + libglib2.0-0 (+ libsm6/libxext6/libxrender1): the classic
#   OpenCV-in-slim trap — paddleocr pulls in non-headless opencv bits that
#   dlopen libGL even when never showing a window.
# - libgomp1: OpenMP runtime required by paddlepaddle CPU inference.
# - curl + ca-certificates: healthcheck (and nothing else — the app itself
#   only ever talks to Ollama).
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
        libsm6 \
        libxext6 \
        libxrender1 \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Non-root runtime user; /data is the archive volume (SQLite DB + images).
RUN useradd --create-home --uid 1000 briefkist \
    && mkdir /data \
    && chown briefkist:briefkist /data

# /app stays root-owned and read-only to the runtime user (it only needs to
# read code; all writes go to /data and $HOME). No chown -R: that would
# duplicate the ~GB-scale venv layer.
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
# Only what the server needs at runtime: API + pipeline + static web UI.
COPY server/ server/
COPY spike/ spike/
COPY web/ web/

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    HOME=/home/briefkist

USER briefkist

# Bake the PaddleOCR models into the image (~tens of MB): instantiating the
# engine downloads PP-OCRv5 mobile det + latin rec into $HOME caches. This is
# also the build-time smoke test that the pinned paddleocr/paddlepaddle combo
# actually imports and initializes on linux/amd64. The engine hard-pins itself
# offline (spike/ocr_engines.py, plan.md §5.1) — for this one build step the
# two knobs are overridden so the vanilla paddlex first-run download works; a
# fresh container then never needs model egress.
RUN HF_HUB_OFFLINE=0 PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=False python -c \
    "from spike.ocr_engines import PaddleOCREngine; PaddleOCREngine()"

# 0.0.0.0 inside a container binds the container's private network namespace;
# actual exposure is decided by the port mapping on the host (plan.md §5.1
# guidance moves to that level — see server/config.py:validate_bind_host).
# The guard still refuses this bind unless FLOPY_ALLOW_CONTAINER_BIND=1 is set
# explicitly (docker-compose.yml sets it) — bare-metal refusal stays intact.
ENV FLOPY_DATA_DIR=/data \
    FLOPY_HOST=0.0.0.0

VOLUME /data
EXPOSE 8484

# /api/status answers 401 without a device token — that still means alive.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD ["/bin/sh", "-c", "code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8484/api/status); [ \"$code\" = 200 ] || [ \"$code\" = 401 ]"]

# server.app:main() = validate_bind_host() + uvicorn.run(app, host/port from
# env) — same uvicorn server as `uvicorn server.app:app`, but env-consistent
# and exec-form (PID 1 gets signals, so `docker stop` is graceful).
CMD ["python", "-m", "server.app"]

"""config guards: the §5.1 wildcard-bind refusal (and its explicit container
escape hatch) plus the platform-dependent OCR engine default."""

import importlib
import sys

import pytest

from server import config

_ENV_KEYS = (
    "FLOPY_HOST",
    "FLOPY_OCR_ENGINE",
    "FLOPY_ALLOW_ANY_BIND",
    "FLOPY_ALLOW_CONTAINER_BIND",
)


@pytest.fixture(autouse=True)
def _restore_config():
    # monkeypatch (function-scoped, torn down first) restores the env; this
    # re-reads config from the clean env so later test modules see real values
    yield
    importlib.reload(config)


def _reload_with(monkeypatch, **env):
    for key in _ENV_KEYS:
        monkeypatch.delenv(key, raising=False)
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    return importlib.reload(config)


@pytest.mark.parametrize("host", ["0.0.0.0", "::", ""])
def test_wildcard_bind_refused(monkeypatch, host):
    cfg = _reload_with(monkeypatch, FLOPY_HOST=host)
    with pytest.raises(SystemExit):
        cfg.validate_bind_host()


def test_container_bind_escape_allows_wildcard(monkeypatch):
    cfg = _reload_with(
        monkeypatch, FLOPY_HOST="0.0.0.0", FLOPY_ALLOW_CONTAINER_BIND="1"
    )
    cfg.validate_bind_host()  # must not raise


def test_specific_address_and_hostname_allowed(monkeypatch):
    for host in ("127.0.0.1", "192.168.1.20", "localhost"):
        cfg = _reload_with(monkeypatch, FLOPY_HOST=host)
        cfg.validate_bind_host()  # must not raise


def test_ocr_engine_platform_default(monkeypatch):
    cfg = _reload_with(monkeypatch)
    expected = "apple_vision" if sys.platform == "darwin" else "paddleocr"
    assert cfg.OCR_ENGINE == expected


def test_ocr_engine_env_override(monkeypatch):
    cfg = _reload_with(monkeypatch, FLOPY_OCR_ENGINE="apple_vision")
    assert cfg.OCR_ENGINE == "apple_vision"

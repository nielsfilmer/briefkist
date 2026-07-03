"""bge-m3 embeddings via local Ollama (plan.md §6.5)."""

from __future__ import annotations

import httpx

from . import config


def embed(text: str, timeout: float = 120.0) -> list[float]:
    response = httpx.post(
        f"{config.OLLAMA_URL}/api/embed",
        json={"model": config.EMBED_MODEL, "input": text[:8000]},
        timeout=timeout,
    )
    response.raise_for_status()
    return response.json()["embeddings"][0]

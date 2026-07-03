"""Photo-degradation: turn a clean rendered page into something that looks like a
phone photo. Three tiers matching the KPI buckets in plan.md §11:

- ``clean``  — the rendered page as-is (flatbed-scan quality).
- ``good``   — well-lit phone photo: slight perspective, mild shadow, light noise.
- ``poor``   — bad capture: stronger skew, hard shadow edge, blur, heavy noise.
"""

from __future__ import annotations

import random
from pathlib import Path

import cv2
import numpy as np

TIERS = ["clean", "good", "poor"]


def _perspective(img: np.ndarray, rng: random.Random, max_shift: float) -> np.ndarray:
    h, w = img.shape[:2]
    shift = lambda: rng.uniform(0, max_shift)  # noqa: E731
    src = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
    dst = np.float32(
        [
            [w * shift(), h * shift()],
            [w * (1 - shift()), h * shift()],
            [w * (1 - shift()), h * (1 - shift())],
            [w * shift(), h * (1 - shift())],
        ]
    )
    m = cv2.getPerspectiveTransform(src, dst)
    return cv2.warpPerspective(img, m, (w, h), borderValue=(120, 115, 110))


def _rotate(img: np.ndarray, rng: random.Random, max_deg: float) -> np.ndarray:
    h, w = img.shape[:2]
    m = cv2.getRotationMatrix2D((w / 2, h / 2), rng.uniform(-max_deg, max_deg), 1.0)
    return cv2.warpAffine(img, m, (w, h), borderValue=(120, 115, 110))


def _shadow(img: np.ndarray, rng: random.Random, strength: float, hard: bool) -> np.ndarray:
    h, w = img.shape[:2]
    x = np.linspace(0, 1, w, dtype=np.float32)
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    angle = rng.uniform(0, 1)
    grad = angle * x[None, :] + (1 - angle) * y
    if hard:
        edge = rng.uniform(0.35, 0.65)
        grad = 1 / (1 + np.exp(-(grad - edge) * 25))  # sigmoid edge
    mask = 1.0 - strength * grad
    return np.clip(img.astype(np.float32) * mask[:, :, None], 0, 255).astype(np.uint8)


def _noise(img: np.ndarray, rng: random.Random, sigma: float) -> np.ndarray:
    noise = np.random.default_rng(rng.randrange(2**32)).normal(0, sigma, img.shape)
    return np.clip(img.astype(np.float32) + noise, 0, 255).astype(np.uint8)


def degrade(clean_path: Path, out_path: Path, tier: str, rng: random.Random) -> None:
    img = cv2.imread(str(clean_path))
    if img is None:
        raise FileNotFoundError(clean_path)

    if tier == "clean":
        result = img
    elif tier == "good":
        img = _perspective(img, rng, 0.015)
        img = _rotate(img, rng, 1.2)
        img = _shadow(img, rng, strength=0.15, hard=False)
        result = _noise(img, rng, sigma=3)
    elif tier == "poor":
        img = _perspective(img, rng, 0.045)
        img = _rotate(img, rng, 3.5)
        img = _shadow(img, rng, strength=0.45, hard=True)
        img = cv2.GaussianBlur(img, (0, 0), sigmaX=1.1)
        result = _noise(img, rng, sigma=8)
    else:
        raise ValueError(f"unknown tier {tier!r}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    # JPEG round-trip like a real phone camera pipeline
    quality = {"clean": 95, "good": 88, "poor": 72}[tier]
    cv2.imwrite(str(out_path), result, [cv2.IMWRITE_JPEG_QUALITY, quality])

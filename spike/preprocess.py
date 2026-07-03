"""Backend cleanup pass (plan.md §6.1): find the page, correct perspective,
deskew, and enhance contrast before OCR.

Kept deliberately conservative: if page detection fails we fall back to the
original image rather than risk cropping content away.
"""

from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np

_MIN_PAGE_AREA_FRAC = 0.35  # a detected quad smaller than this is not the page


def _find_page_quad(gray: np.ndarray) -> np.ndarray | None:
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blurred, 50, 150)
    edges = cv2.dilate(edges, np.ones((3, 3), np.uint8), iterations=2)
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return None
    largest = max(contours, key=cv2.contourArea)
    if cv2.contourArea(largest) < _MIN_PAGE_AREA_FRAC * gray.shape[0] * gray.shape[1]:
        return None
    peri = cv2.arcLength(largest, True)
    approx = cv2.approxPolyDP(largest, 0.02 * peri, True)
    if len(approx) != 4:
        return None
    return approx.reshape(4, 2).astype(np.float32)


def _order_corners(quad: np.ndarray) -> np.ndarray:
    s = quad.sum(axis=1)
    d = np.diff(quad, axis=1).ravel()
    return np.array(
        [quad[np.argmin(s)], quad[np.argmin(d)], quad[np.argmax(s)], quad[np.argmax(d)]],
        dtype=np.float32,
    )  # tl, tr, br, bl


def _deskew_angle(gray: np.ndarray) -> float:
    """Estimate residual skew from near-horizontal text lines via Hough transform."""
    edges = cv2.Canny(gray, 50, 150)
    lines = cv2.HoughLinesP(
        edges, 1, np.pi / 180, threshold=120, minLineLength=gray.shape[1] // 4, maxLineGap=20
    )
    if lines is None:
        return 0.0
    angles = []
    # HoughLinesP output shape varies by build: (N,1,4) or (N,4) — normalize
    for x1, y1, x2, y2 in lines.reshape(-1, 4):
        angle = np.degrees(np.arctan2(y2 - y1, x2 - x1))
        if abs(angle) < 15:  # only near-horizontal lines vote
            angles.append(angle)
    return float(np.median(angles)) if angles else 0.0


def preprocess(image_path: Path, out_path: Path) -> dict:
    """Clean one capture. Returns a small report of what was applied."""
    img = cv2.imread(str(image_path))
    if img is None:
        raise FileNotFoundError(image_path)
    report: dict = {"page_detected": False, "deskew_deg": 0.0}

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    quad = _find_page_quad(gray)
    if quad is not None:
        corners = _order_corners(quad)
        (tl, tr, br, bl) = corners
        w = int(max(np.linalg.norm(br - bl), np.linalg.norm(tr - tl)))
        h = int(max(np.linalg.norm(tr - br), np.linalg.norm(tl - bl)))
        dst = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
        m = cv2.getPerspectiveTransform(corners, dst)
        img = cv2.warpPerspective(img, m, (w, h))
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        report["page_detected"] = True

    angle = _deskew_angle(gray)
    if abs(angle) > 0.3:
        hh, ww = img.shape[:2]
        m = cv2.getRotationMatrix2D((ww / 2, hh / 2), angle, 1.0)
        img = cv2.warpAffine(
            img, m, (ww, hh), flags=cv2.INTER_LINEAR, borderValue=(255, 255, 255)
        )
        report["deskew_deg"] = round(angle, 2)

    # Illumination flattening + gentle contrast (shadow removal), stay grayscale-safe
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    background = cv2.medianBlur(cv2.dilate(gray, np.ones((7, 7), np.uint8)), 21)
    flattened = cv2.divide(gray, background, scale=255)
    enhanced = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(flattened)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(out_path), enhanced, [cv2.IMWRITE_PNG_COMPRESSION, 3])
    return report

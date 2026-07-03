"""OCR engines behind one interface (plan.md §6.2 — Phase 0 benchmarks these
head-to-head and the winner becomes primary).

- AppleVisionOCR: macOS Vision framework via pyobjc. Fully on-device, ~zero
  extra resident RAM — the frontrunner on the 8 GB host.
- PaddleOCREngine: PP-OCR via the paddleocr package. Imported lazily; on this
  host paddlepaddle may not be installable, in which case the benchmark
  records the engine as unavailable instead of failing.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path


@dataclass
class OcrResult:
    engine: str
    text: str
    mean_confidence: float
    seconds: float


class AppleVisionOCR:
    name = "apple_vision"

    def __init__(self, languages: list[str] | None = None) -> None:
        import Vision  # pyobjc-framework-Vision

        self._vision = Vision
        self._languages = languages or ["nl-NL", "de-DE", "en-GB"]

    def recognize(self, image_path: Path) -> OcrResult:
        import Quartz
        from Foundation import NSURL

        vision = self._vision
        start = time.perf_counter()

        url = NSURL.fileURLWithPath_(str(image_path))
        src = Quartz.CGImageSourceCreateWithURL(url, None)
        if src is None:
            raise FileNotFoundError(image_path)
        cg_image = Quartz.CGImageSourceCreateImageAtIndex(src, 0, None)

        request = vision.VNRecognizeTextRequest.alloc().init()
        request.setRecognitionLevel_(vision.VNRequestTextRecognitionLevelAccurate)
        request.setUsesLanguageCorrection_(True)
        request.setRecognitionLanguages_(self._languages)

        handler = vision.VNImageRequestHandler.alloc().initWithCGImage_options_(cg_image, None)
        ok, error = handler.performRequests_error_([request], None)
        if not ok:
            raise RuntimeError(f"Vision OCR failed: {error}")

        lines: list[str] = []
        confidences: list[float] = []
        for observation in request.results() or []:
            candidate = observation.topCandidates_(1)[0]
            lines.append(str(candidate.string()))
            confidences.append(float(candidate.confidence()))

        return OcrResult(
            engine=self.name,
            text="\n".join(lines),
            mean_confidence=sum(confidences) / len(confidences) if confidences else 0.0,
            seconds=time.perf_counter() - start,
        )


class PaddleOCREngine:
    name = "paddleocr"

    def __init__(self) -> None:
        import os

        # paddlex phones home ("checking connectivity to the model hosters") on
        # init unless disabled — an egress violation (plan.md §5.1). Models must
        # instead be pre-downloaded once at install time (like `ollama pull`).
        # Even then, its hf-hub layer still revalidates caches over HTTPS
        # (observed) — HF_HUB_OFFLINE forces true offline operation.
        os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
        os.environ.setdefault("HF_HUB_OFFLINE", "1")
        from paddleocr import PaddleOCR  # heavy import, deferred

        # paddleocr 3.x pipeline API. lang="nl" resolves to the latin
        # PP-OCRv5 recognition model, which covers nl/de/en in one model
        # (lang="latin" itself is rejected by 3.4's model registry). Models
        # download once at first init (install-time), then run offline.
        # Page-level orientation/unwarp is our preprocess step's job — off here.
        # mobile detection model: the default server-class det model costs
        # minutes/page on M1 CPU (measured); mobile is ~10× faster and fine for
        # single-column letters
        self._ocr = PaddleOCR(
            lang="nl",
            text_detection_model_name="PP-OCRv5_mobile_det",
            use_doc_orientation_classify=False,
            use_doc_unwarping=False,
            use_textline_orientation=True,
        )

    def recognize(self, image_path: Path) -> OcrResult:
        start = time.perf_counter()
        pages = self._ocr.predict(str(image_path))
        lines: list[str] = []
        confidences: list[float] = []
        for page in pages or []:
            lines.extend(page["rec_texts"])
            confidences.extend(float(s) for s in page["rec_scores"])
        return OcrResult(
            engine=self.name,
            text="\n".join(lines),
            mean_confidence=sum(confidences) / len(confidences) if confidences else 0.0,
            seconds=time.perf_counter() - start,
        )


def available_engines() -> dict[str, object]:
    """Instantiate every engine that works on this host; report the rest."""
    engines: dict[str, object] = {}
    errors: dict[str, str] = {}
    for cls in (AppleVisionOCR, PaddleOCREngine):
        try:
            engines[cls.name] = cls()
        except Exception as exc:  # noqa: BLE001 — availability probe, record and move on
            errors[cls.name] = f"{type(exc).__name__}: {exc}"
    engines["_errors"] = errors  # type: ignore[assignment]
    return engines

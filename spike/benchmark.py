"""Phase 0 benchmark: run the full pipeline over a test set and score it
against ground truth + the KPI targets in plan.md §11.

Usage:
    uv run python -m spike.benchmark --set data/testset --model qwen3-vl:4b-instruct
    uv run python -m spike.benchmark --set data/testset-real   # owner's real letters

Writes results JSON + a markdown report to --out (default docs/phase0/).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import threading
import time
from pathlib import Path

from rapidfuzz.distance import Levenshtein

from .extract import DEFAULT_MODEL, extract
from .ocr_engines import available_engines
from .preprocess import preprocess
from .validate import normalize_amount, normalize_date, normalize_iban, reconcile_tags

# ---------------------------------------------------------------- monitors


class ResourceMonitor:
    """Samples peak RSS of the interesting processes and any established
    non-loopback network connections they hold (the egress check).
    Sampling-based: an exhaustive egress proof is Phase 3's formal
    airplane-mode test; this catches anything persistent."""

    _PROC_HINT = re.compile(r"ollama|python|paddle", re.IGNORECASE)
    _LOCAL = re.compile(r"127\.0\.0\.1|\[::1\]|localhost")

    def __init__(self) -> None:
        self.peak_rss_mb = 0.0
        self.egress: set[str] = set()
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)

    def _sample(self) -> None:
        ps = subprocess.run(
            ["ps", "-axo", "rss=,comm="], capture_output=True, text=True, check=False
        )
        total_kb = 0
        for line in ps.stdout.splitlines():
            parts = line.strip().split(None, 1)
            if len(parts) == 2 and self._PROC_HINT.search(parts[1]):
                total_kb += int(parts[0])
        self.peak_rss_mb = max(self.peak_rss_mb, total_kb / 1024)

        lsof = subprocess.run(
            ["lsof", "-i", "TCP", "-n", "-P", "-sTCP:ESTABLISHED"],
            capture_output=True, text=True, check=False,
        )
        for line in lsof.stdout.splitlines()[1:]:
            if self._PROC_HINT.search(line) and not self._LOCAL.search(line):
                self.egress.add(" ".join(line.split()[:2]) + " " + line.split()[-2])

    def _run(self) -> None:
        while not self._stop.is_set():
            self._sample()
            self._stop.wait(2.0)

    def __enter__(self) -> ResourceMonitor:
        self._thread.start()
        return self

    def __exit__(self, *exc: object) -> None:
        self._stop.set()
        self._thread.join(timeout=5)


# ---------------------------------------------------------------- scoring


def _clean(text: str) -> str:
    """Whitespace- and case-insensitive form for character accuracy. Whitespace:
    OCR reading order and line wrapping legitimately differ from the source text.
    Case: deliberate — the archive's uses of the transcript (FTS5 search, VLM
    extraction input) are case-insensitive, and format-critical fields (IBAN,
    amounts, dates) are scored separately via exact normalized comparison, so
    case slips there still count where they matter."""
    return re.sub(r"\s+", " ", text).strip().lower()


def char_accuracy(ocr_text: str, truth_text: str) -> float:
    truth = _clean(truth_text)
    if not truth:
        return 0.0
    dist = Levenshtein.distance(_clean(ocr_text), truth)
    return max(0.0, 1.0 - dist / len(truth))


def _norm_str(value: str | None) -> str:
    return re.sub(r"\s+", " ", (value or "")).strip().lower()


def score_fields(extraction: dict, truth: dict) -> dict:
    """Per-field correctness after deterministic normalization."""
    scores: dict[str, bool | None] = {}
    scores["doc_type"] = extraction.get("doc_type") == truth["doc_type"]
    scores["language"] = extraction.get("language") == truth["language"]
    scores["sender_name"] = _norm_str(extraction.get("sender_name")) == _norm_str(
        truth["sender_name"]
    )
    scores["document_date"] = normalize_date(extraction.get("document_date")) == truth[
        "document_date"
    ]
    scores["due_date"] = normalize_date(extraction.get("due_date")) == truth["due_date"]
    scores["amount_due"] = normalize_amount(extraction.get("amount_due")) == truth["amount_due"]
    scores["iban"] = normalize_iban(extraction.get("iban")) == truth["iban"]
    scores["reference"] = _norm_str(extraction.get("reference")) == _norm_str(truth["reference"])
    truth_tags = set(truth["controlled_tags"])
    # score the PIPELINE's tags: model suggestion + §6.4 reconciliation
    final_tags = set(
        reconcile_tags(
            extraction.get("doc_type") or "",
            extraction.get("tags") or [],
            has_amount=normalize_amount(extraction.get("amount_due")) is not None,
        )
    )
    scores["tags_hit"] = bool(final_tags & truth_tags)
    # KPI §11 asks for tag PRECISION ≥ 90% on the controlled vocabulary
    scores["tags_precision"] = (
        len(final_tags & truth_tags) / len(final_tags) if final_tags else 0.0
    )
    return scores


# ---------------------------------------------------------------- run

def run_benchmark(set_dir: Path, model: str, out_dir: Path, limit: int | None) -> dict:
    images_dir = set_dir / "images"
    truth_dir = set_dir / "truth"
    work_dir = out_dir / "preprocessed"
    image_paths = sorted(images_dir.glob("*.[jp][pn]g"))
    if limit:
        image_paths = image_paths[:limit]
    if not image_paths:
        raise SystemExit(f"no images found in {images_dir}")

    engines = available_engines()
    engine_errors = engines.pop("_errors")
    results: list[dict] = []

    with ResourceMonitor() as monitor:
        for image_path in image_paths:
            letter_id = image_path.stem
            truth_path = truth_dir / f"{letter_id}.json"
            truth = json.loads(truth_path.read_text()) if truth_path.exists() else None
            row: dict = {"letter_id": letter_id, "stages": {}}

            t0 = time.perf_counter()
            cleaned = work_dir / f"{letter_id}.png"
            row["preprocess"] = preprocess(image_path, cleaned)
            row["stages"]["preprocess_s"] = round(time.perf_counter() - t0, 2)

            # OCR: every available engine on the cleaned image; also raw for the primary
            ocr_texts: dict[str, str] = {}
            for name, engine in engines.items():
                res = engine.recognize(cleaned)  # type: ignore[attr-defined]
                ocr_texts[name] = res.text
                row.setdefault("ocr", {})[name] = {
                    "seconds": round(res.seconds, 2),
                    "mean_confidence": round(res.mean_confidence, 3),
                    "char_accuracy": (
                        round(char_accuracy(res.text, truth["full_text"]), 4) if truth else None
                    ),
                }
            primary = "apple_vision" if "apple_vision" in ocr_texts else next(iter(ocr_texts), "")
            ocr_text = ocr_texts.get(primary, "")

            t0 = time.perf_counter()
            try:
                extraction, stats = extract(cleaned, ocr_text, model=model)
                row["extraction"] = extraction.model_dump()
                row["stages"]["extract_s"] = stats["seconds"]
                row["stages"]["extract_load_s"] = stats["load_seconds"]
            except Exception as exc:  # noqa: BLE001 — a failed letter is a data point
                row["extraction_error"] = f"{type(exc).__name__}: {exc}"
                row["stages"]["extract_s"] = round(time.perf_counter() - t0, 2)

            if truth and "extraction" in row:
                row["field_scores"] = score_fields(row["extraction"], truth)
            results.append(row)
            done = sum(1 for _ in results)
            print(f"[{done}/{len(image_paths)}] {letter_id} "
                  f"ocr={ {k: v['char_accuracy'] for k, v in row.get('ocr', {}).items()} } "
                  f"extract={row['stages'].get('extract_s')}s")

    summary = summarize(results, engine_errors, monitor, model)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "results.json").write_text(
        json.dumps({"summary": summary, "letters": results}, indent=2, ensure_ascii=False)
    )
    (out_dir / "report.md").write_text(render_report(summary, model))
    return summary


def summarize(
    results: list[dict], engine_errors: dict, monitor: ResourceMonitor, model: str
) -> dict:
    def tier_of(letter_id: str) -> str:
        return letter_id.rsplit("_", 1)[-1]

    ocr_by_engine_tier: dict[str, dict[str, list[float]]] = {}
    field_totals: dict[str, list[bool]] = {}
    extract_times: list[float] = []
    failures: list[str] = []

    for row in results:
        tier = tier_of(row["letter_id"])
        for engine, stats in row.get("ocr", {}).items():
            if stats["char_accuracy"] is not None:
                ocr_by_engine_tier.setdefault(engine, {}).setdefault(tier, []).append(
                    stats["char_accuracy"]
                )
        for field, ok in row.get("field_scores", {}).items():
            field_totals.setdefault(field, []).append(ok)  # bool or float (precision)
        if "extraction_error" in row:
            failures.append(f"{row['letter_id']}: {row['extraction_error']}")
        elif "extract_s" in row["stages"]:
            extract_times.append(row["stages"]["extract_s"])

    mean = lambda xs: round(sum(xs) / len(xs), 4) if xs else None  # noqa: E731
    return {
        "model": model,
        "letters": len(results),
        "engine_errors": engine_errors,
        "ocr_char_accuracy": {
            engine: {tier: mean(vals) for tier, vals in tiers.items()}
            for engine, tiers in ocr_by_engine_tier.items()
        },
        "field_accuracy": {f: mean([float(v) for v in vals])
                           for f, vals in field_totals.items()},
        "extract_seconds": {
            "mean": mean(extract_times),
            "median": (
                round(sorted(extract_times)[len(extract_times) // 2], 2)
                if extract_times
                else None
            ),
            "max": max(extract_times) if extract_times else None,
        },
        "extraction_failures": failures,
        "peak_pipeline_rss_mb": round(monitor.peak_rss_mb, 1),
        "egress_connections": sorted(monitor.egress),
    }


def render_report(s: dict, model: str) -> str:
    lines = [
        "# Phase 0 benchmark report",
        "",
        f"- **Model:** {model}",
        f"- **Letters:** {s['letters']}",
        f"- **Peak pipeline RSS:** {s['peak_pipeline_rss_mb']} MB "
        "(ollama + python processes, sampled)",
        f"- **Egress observed (must be empty):** "
        f"{s['egress_connections'] or 'none — no non-loopback connections'}",
        "",
        "## OCR character accuracy by engine and tier",
        "",
        "KPI (§11): ≥ 98% well-lit (`clean`/`good`), ≥ 95% average (`poor`).",
        "",
    ]
    for engine, tiers in s["ocr_char_accuracy"].items():
        lines.append(f"- **{engine}**: " + ", ".join(
            f"{tier}: {acc:.2%}" for tier, acc in sorted(tiers.items()) if acc is not None
        ))
    if s["engine_errors"]:
        lines.append("")
        for engine, err in s["engine_errors"].items():
            lines.append(f"- *{engine} unavailable on this host:* `{err}`")
    lines += [
        "",
        "## Field accuracy (after deterministic normalization; tag rows are "
        "scored on the pipeline output, i.e. after §6.4 reconciliation — raw "
        "model tags are in results.json per letter)",
        "",
    ]
    targets = {
        "doc_type": 0.95, "sender_name": 0.90, "document_date": 0.95,
        "amount_due": 0.98, "iban": 0.98, "reference": 0.98,
        "tags_hit": 0.90, "tags_precision": 0.90,
    }
    for field, acc in s["field_accuracy"].items():
        if acc is None:
            continue
        target = targets.get(field)
        if target is None:
            verdict = ""
        else:
            verdict = " ✅" if acc >= target else f" ❌ (target {target:.0%})"
        lines.append(f"- **{field}**: {acc:.2%}{verdict}")
    lines += [
        "",
        "## Timing",
        "",
        f"- Extraction per letter: mean {s['extract_seconds']['mean']}s, "
        f"median {s['extract_seconds'].get('median')}s, "
        f"max {s['extract_seconds']['max']}s (KPI: full pipeline ≤ 15 s/page)",
    ]
    if s["extraction_failures"]:
        lines += ["", "## Extraction failures", ""]
        lines += [f"- {f}" for f in s["extraction_failures"]]
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--set", type=Path, default=Path("data/testset"), dest="set_dir")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--out", type=Path, default=Path("docs/phase0"))
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()
    summary = run_benchmark(args.set_dir, args.model, args.out, args.limit)
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

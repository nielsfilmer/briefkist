# Phase 0 spike — pipeline + benchmark

Proves the hard part (plan.md §10 Phase 0): local preprocess → OCR → VLM
extraction → deterministic validation, scored against ground truth and the
KPI targets in plan.md §11, on the production host (8 GB M1 Mac mini).

## Prerequisites

- Ollama running natively (`ollama serve`) with `qwen3-vl:4b-instruct` pulled
  (`qwen3-vl:2b-instruct` as the low-RAM fallback). **Always the `-instruct`
  tags** — the bare tags are thinking models that return empty JSON under
  constrained decoding (plan.md decision log #8).
- The synthetic test set generated: `uv run python -m testset.generate`
  (see `testset/README.md`).

## Run the benchmark

```bash
uv run python -m spike.benchmark --set data/testset --model qwen3-vl:4b-instruct
# owner's real letters (definitive numbers):
uv run python -m spike.benchmark --set data/testset-real
```

Writes `results.json` + `report.md` to `--out` (default `docs/phase0/` —
the committed report of record lives there).

## What it measures

- **OCR character accuracy** per engine (Apple Vision; PaddleOCR when
  installable — `uv sync --extra paddle`) per degradation tier, against
  `truth/*.json` `full_text` (whitespace-normalized: OCR reading order and
  line wrapping legitimately differ).
- **Field accuracy** after deterministic normalization (`spike/validate.py`):
  ISO dates from NL/DE/EN display forms, decimal amounts from EU formats,
  checksum-validated IBANs. Structural JSON validity is enforced at the
  decoding layer (Ollama `format` = Pydantic schema, plan.md §6.4).
- **Timing** per stage (KPI: full pipeline ≤ 15 s/page) and **peak pipeline
  RSS** (ollama + python, sampled) — the 8 GB fit is a go/no-go condition.
- **Egress sampling**: any established non-loopback TCP connection held by
  pipeline processes during the run is reported (must be none). The formal
  airplane-mode acceptance test is Phase 3's gate; this catches anything
  persistent early.

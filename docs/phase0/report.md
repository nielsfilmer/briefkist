# Phase 0 benchmark report

- **Model:** qwen3-vl:4b-instruct
- **Letters:** 30
- **Peak pipeline RSS:** 997.2 MB (ollama + python processes, sampled)
- **Egress observed (must be empty):** none — no non-loopback connections

## OCR character accuracy by engine and tier

KPI (§11): ≥ 98% well-lit (`clean`/`good`), ≥ 95% average (`poor`).

- **apple_vision**: clean: 99.87%, good: 99.92%, poor: 99.90%
- **paddleocr**: clean: 95.43%, good: 94.67%, poor: 92.53%

## Field accuracy (after deterministic normalization; tag rows are scored on the pipeline output, i.e. after §6.4 reconciliation — raw model tags are in results.json per letter)

- **doc_type**: 100.00% ✅
- **language**: 100.00%
- **sender_name**: 100.00% ✅
- **document_date**: 100.00% ✅
- **due_date**: 100.00%
- **amount_due**: 100.00% ✅
- **iban**: 100.00% ✅
- **reference**: 100.00% ✅
- **tags_hit**: 100.00% ✅
- **tags_precision**: 100.00% ✅

## Timing

- Extraction per letter: mean 21.9337s, median 18.93s, max 70.44s (KPI: full pipeline ≤ 15 s/page)

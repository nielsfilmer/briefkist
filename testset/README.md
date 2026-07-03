# Phase 0 test set

Synthetic-first (plan.md decision log #5): generated NL/DE/EN letters with known
ground truth stand in for real mail so the pipeline can be built and benchmarked
immediately. The definitive go/no-go numbers come from re-running the same benchmark
on photos of real letters once the owner provides them.

## Generate the synthetic set

```bash
uv run python -m testset.generate --count 30 --seed 42
```

Writes to `data/testset/` (gitignored — regenerate with the same seed for the
identical set):

- `clean/<id>.png` — rendered A4 page, flatbed-scan quality
- `images/<id>.jpg` — photo-degraded capture, what the pipeline actually sees
- `truth/<id>.json` — ground truth: normalized fields + `full_text` (exact page text)
- `manifest.json` — run parameters + per-letter index

Letters rotate through 3 languages (nl/de/en) × 6 document types (invoice,
government_tax, insurance, medical, bank, subscription) × 3 degradation tiers
(`clean` / `good` / `poor` — matching the KPI buckets in plan.md §11). IBANs carry
valid mod-97 checksums; dates and amounts use per-language display formats while the
truth JSON stores normalized ISO dates and decimal amounts.

## Real letters (the definitive benchmark)

Drop phone photos of real letters into `data/testset-real/images/` (gitignored —
**never commit real mail**, see the repo `.gitignore`). For each photo you want
scored on field accuracy (not just OCR sanity), add a matching
`data/testset-real/truth/<same-name>.json` with any subset of the truth fields
above — absent fields are simply skipped in scoring. The Phase 0 benchmark
(`spike/`, next PR) takes `--set data/testset-real` and reports the same metrics.

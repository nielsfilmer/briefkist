"""my-flopy backend: FastAPI + SQLite (FTS5 + sqlite-vec), all native processes.

Architecture: plan.md §5 (v0.2). The processing pipeline reuses the proven
Phase 0 spike components (spike/preprocess, spike/ocr_engines, spike/extract,
spike/validate) — moving them to a neutral package name is deliberately
deferred until after Phase 1 (churn vs. review traceability).
"""

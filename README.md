# my-flopy

A fully local, self-hosted system to **photograph, read, tag, archive, and search
your physical (snail) mail** — with nothing ever leaving hardware you control.

Snap a letter with your phone; a self-hosted backend on an always-on Apple Silicon
**Mac mini** cleans the image, OCRs it, and uses a local vision-language model to
extract structured metadata (sender, recipient, dates, amounts, references, document
type) and tags, then files it into a searchable archive (full-text + semantic). Use
it on the road via a private WireGuard/Tailscale overlay — **no cloud, no public
ports, no third party in the data path.**

> **Status:** planning → Phase 0 (feasibility spike). No application code yet.

## Documents

- **[plan.md](plan.md)** — the canonical plan: goal, scope, architecture, remote-access
  & leak-hardening (§5.1), technology decisions, data model, pipeline, roadmap,
  measurables, and risks. **Start here.**
- **[CLAUDE.md](CLAUDE.md)** — working conventions for Claude Code sessions on this repo
  (PR-per-task workflow, review discipline, permission model, phase tracking).

## Planned stack (see plan.md §6–§7)

| Layer | Choice |
|---|---|
| App (mobile + desktop) | Flutter |
| Capture | Native OS scanners (VisionKit / ML Kit) |
| OCR | PaddleOCR |
| Understanding | Qwen3-VL-8B via Ollama/MLX |
| Search | Postgres + pgvector + FTS (or fork Paperless-ngx) · bge-m3 embeddings |
| Backend | FastAPI, Docker Compose |
| Host | Always-on Apple Silicon Mac mini |
| Remote access | Tailscale / WireGuard overlay |

## Development workflow

Every change goes on a feature branch → PR against `main` → parallel code + QA review →
merge (the human is the merge gate). Phase progress is tracked in GitHub milestones and
`phase-tracker` issues, not in a roadmap checklist. See [CLAUDE.md](CLAUDE.md) for the
full workflow, and run `/status` for the live per-phase snapshot.

## Privacy

This is a privacy project first. **Never commit** real mail, captured documents, `.env`
files, model/API keys, or WireGuard/Tailscale keys — see `.gitignore`. The repo is
public; the design docs are, the data never is.

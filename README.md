# Briefkist

**Turn the paper mail piling up at home into a private, searchable family
archive — on a server you control.**

Photograph a letter with your phone. Your own server cleans the image, reads
it (OCR), and uses a local vision-language model to understand it — category,
sender and place, date, reference, subject, a short summary, curated
keywords — then files it into an archive you can search by words or by
meaning. It is an archive, not an invoicing tool.

**Nothing ever leaves hardware you control.** No cloud APIs, no telemetry, no
third party in the data path. The AI runs on your machine; the process that
sees your documents in plaintext has no route to the internet. Remote access
is over a private WireGuard/Tailscale overlay — no public ports.

## Install

Two supported paths — same product, full features on both:

- **Linux (Docker Compose)** — any box you own: a NUC, a home server, an old
  desktop. `docker compose pull && docker compose up -d`, pull the two models
  once, mint a device token — the quickstart is at the top of
  [docker-compose.yml](docker-compose.yml). Images are published to
  `ghcr.io/nielsfilmer/briefkist`.
- **macOS (native)** — what the author runs: an always-on Apple Silicon Mac
  mini (8 GB is enough). Native gets Apple Vision OCR and Metal-accelerated
  Ollama. Setup, operations, backup, and model knobs are in
  [docs/RUNBOOK.md](docs/RUNBOOK.md); [deploy/](deploy/) installs it as a
  login service.

Then pair your devices: the **native iOS + macOS apps** live in
[briefkist-app](https://github.com/nielsfilmer/briefkist-app) (Flutter, one
codebase, Apache-2.0), and a zero-install **web app** (phone capture page +
desktop browse) is served by the backend itself.

## How it works

| Layer | Choice |
|---|---|
| Apps | Flutter iOS + macOS ([briefkist-app](https://github.com/nielsfilmer/briefkist-app)) + web fallback served by the backend |
| Capture | iOS document scanner (VisionKit) in the app; phone-browser camera in the web fallback; OpenCV cleanup server-side |
| OCR | Apple Vision (macOS) or PaddleOCR (Linux, models baked into the image) |
| Understanding | Qwen3-VL-4B (2B fallback) via Ollama — local, Apache-2.0-licensed weights |
| Search | SQLite FTS5 + sqlite-vec · bge-m3 embeddings |
| Backend | FastAPI + SQLite — native processes on macOS, Compose stack on Linux |
| Remote access | Tailscale / WireGuard overlay — never the public internet |

The full design — goal, scope, architecture, the §5.1 remote-access and
leak-hardening model, technology decisions with rationale, data model,
pipeline, roadmap, risks — is in **[plan.md](plan.md)**.

## Privacy stance

This is a privacy project first:

- The OCR/VLM processes run with **no network egress** — documents cannot
  leave, even if a dependency misbehaves (plan.md §5.1).
- The server **refuses to bind 0.0.0.0** on bare metal; exposure is an
  explicit, host-level decision.
- Every device gets its **own revocable token**; the phone talks only to your
  server.
- Model and dependency licences are vetted for actual usability (EU included)
  — see plan.md §6.3.

We deliberately never describe Briefkist with the words "zero-knowledge" or
"end-to-end encrypted" — precise claims only. What the system does and does
not protect against is written out in plan.md §5.1.

## Contributing

Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) (DCO sign-off,
no CLA; the privacy constraints are non-negotiable review criteria). Security
reports: [SECURITY.md](SECURITY.md). This repo also carries the design system
mirror ([design/](design/)) and the development conventions
([CLAUDE.md](CLAUDE.md)); live phase state is on GitHub milestones.

**Never commit** real mail, captured documents, `.env` files, model/API keys,
or WireGuard/Tailscale keys — see `.gitignore`. The repo is public; the
design docs are, the data never is.

## License

Copyright © 2026 Niels Filmer.

The server (this repository) is licensed under the
**[GNU AGPL-3.0](LICENSE)** — if you run a modified Briefkist for others over
a network, you must offer them your modified source. The native apps
([briefkist-app](https://github.com/nielsfilmer/briefkist-app)) are
**Apache-2.0**. Rationale: plan.md decision log v0.6 #19.

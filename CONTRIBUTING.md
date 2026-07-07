# Contributing to Briefkist

Thanks for wanting to help. Briefkist (the server in this repo) is AGPL-3.0;
the mobile/desktop apps live in their own repo under Apache-2.0.

## Ground rules

- **DCO, not CLA.** Every commit must be signed off (`git commit -s`),
  certifying the [Developer Certificate of Origin](https://developercertificate.org/).
  You keep your copyright.
- **One PR = one concern.** Small, reviewable changes over grand rewrites.
- **The privacy constraints are load-bearing and non-negotiable:** no outbound
  network calls from the processing path, no telemetry, no third-party
  services in the data path, models/licences must be EU-usable. PRs that
  violate these are declined regardless of how useful the feature is.
- Match the surrounding code's style; `uv run ruff check .` and
  `uv run pytest` must pass.

## Getting started

- Bugs → GitHub Issues (use the template).
- Features / direction → GitHub Discussions first; the roadmap lives in
  [plan.md](plan.md) §10 and GitHub milestones.
- Docs fixes are always welcome and merged fast.

## Development setup

See the README quickstart and [CLAUDE.md](CLAUDE.md) "How to run it" for the
dev workflow (Python via `uv`, tests via `uv run pytest`).

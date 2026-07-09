# Claude project notes — Briefkist (local-first snail-mail archiver)

> Product name: **Briefkist** (repo: nielsfilmer/briefkist; apps:
> nielsfilmer/briefkist-app; control plane: nielsfilmer/briefkist-cloud).

Persistent context for future Claude sessions on this repo. Read this first.

**Source of truth for product / architecture is [plan.md](plan.md). Read it before
making changes.**

---

## Workflow (mandatory)

Every task ends with a pull request. Do **not** push directly to `main`.

1. **Work on a feature branch** — branch off `main` with a short descriptive
   name (e.g. `add-x`, `fix-y`).
2. **Commit and push the branch**, then open a PR against `main` via
   `gh pr create`. Title is concise; description summarises the change and
   flags anything the reviewer should look at.
3. **Spawn the review agents — in parallel.** Two reviewers look at the PR at
   once; both must come back clean, and their findings are amendments under
   step 4. **Prefer the `/review-loop` skill when it's available** — it runs
   steps 3–4 end-to-end (parallel spawn, app hosting for QA, the two-round
   cap, durable capture of deferred remarks) and uses this repo's prompt
   templates — the **`review-prompts` project skill**
   (`.claude/skills/review-prompts/SKILL.md`, the source of truth for both
   agent prompts) — so the static-analysis, spec-fidelity, and smell passes
   still apply. Hand-rolled fallback: use the `Agent` tool
   (`subagent_type: "general-purpose"`) for each.
   - **Senior-developer code review.** Framed as a senior dev reviewing the PR;
     give it the project goals (point it at plan.md and this file) and have it
     run a **static-analysis pass** (the repo's own linters/type-checkers/SAST,
     scoped to the diff), a **spec-fidelity pass** (the diff against the
     originating issue/spec: missing/partial requirements, scope creep,
     implemented-but-wrong), and the **smell baseline** (a fixed set of Fowler
     code smells as judgement calls), folding all three into its findings —
     the full prompt lives in the `review-prompts` project skill. It posts via
     `gh pr review N -R nielsfilmer/briefkist --comment` (or `--request-changes`
     if its gh account is allowed — GitHub blocks self-review on your own PR, so
     it falls back to `--comment`; flag blocking items explicitly in the body).
   - **QA agent — client-facing / visually-testable changes only.** Spawn it
     alongside the code reviewer. **The QA subagent can't start a server /
     long-running app itself** (interpreters and `npm run`-style commands are
     denied non-interactively in the subagent sandbox), so a QA agent told to
     "run the app" boots nothing. *Before* spawning it, the orchestrating agent
     **hosts a running instance** (build it first if needed; see "How to run it"
     below — on an off-port with throwaway data if it's a server), captures
     a screenshot, and hands the QA agent **both the live URL and the screenshot
     path** (capture the screenshot before spawning — this harness has no
     "message a running agent" tool, so it's a single launch). The QA agent then
     drives that instance (hit its endpoints / drive it with a browser if the QA
     agent has one) and reads the screenshot, confirming the change **visually +
     functionally**, not just by reading the diff:
     - **Frontend:** pixel-perfect against the design reference — **the mirror in
       `design/`** (brand + tokens in `design/readme.md` + `design/tokens/`, screen
       truth in `design/ui_kits/`): spacing, colour, type, the right states — and
       that it actually works: the happy path plus the specific change.
     - **Plus what a QAer normally tests:** edge cases, empty/loading/error
       states, invalid input + boundaries, and regressions in adjacent features
       — plus responsive/mobile, keyboard + a11y, and reconnect *where a live
       browser is available* (else verify the wiring from the served output +
       diff and say which you couldn't exercise).
     - Posts findings to the PR like the reviewer. **Skip** when the change
       isn't client-facing or isn't testable in the front end (backend /
       library / config / docs) — say so in the notification.
4. **Address every amendment the review and QA raise before notifying the user —
   including non-blocking nits.** "LGTM with a nit" is not done; fix it,
   re-review on the new commit, notify only when fully clean.
   - **Two-round cap on *novel* nits.** Prime the round-2 reviewer with the
     round-1 review so it verifies the specific fixes. New nits in round 2 →
     notify the user now and mention them. The cap is on novel nits, not
     re-attempts: "you fixed it, but inadequately" is still the round-1 nit.
   - **Code-quality, doc, and naming nits: fix without asking** — that's what
     the reviewer is for.
   - **Only bounce to the user for a product/UX decision** — user-facing copy,
     a default value, behaviour visible in the UI. Internal naming, logs, code
     comments, developer-facing wording are NOT product/UX decisions; fix them.
   - **Off-topic nits → a follow-up issue / separate PR** (one PR = one
     concern). Mention the spawn in the user notification.
   - **Capture every deferred remark the moment you triage it — never leave it
     only in the review thread.** Any remark you are *not* fixing in this PR
     (out-of-scope, later-phase, watch-item, won't-fix-now, observation) must be
     written to a durable tracker as you process the review, before notifying
     the user: a new `follow-up` issue (milestoned), a comment on the relevant
     issue, or — for an in-file caveat — a code comment. A review comment or a
     commit-message line is **not** durable tracking. Default: "if it was worth
     the reviewer raising, it's worth an issue." Mention the filed items in the
     notification.
   Push follow-up commits to the same PR branch; don't open a second PR for
   review fixes on this PR's stated concern.
5. **Merge the PR yourself once it is clean.** *(Amended 2026-07-03: the user
   removed themselves as merge gate for this repo — "divide the phases into as many
   PRs as you need, but only return to me when you have the actual deliverables from
   the plan for me to test." So: merge clean PRs after the review loop without
   waiting, and notify the user in batch when a testable deliverable exists, not per
   PR. Outward-facing gates unrelated to merging — publishing, deleting remote
   resources, spending — still require the user.)*
   **Verify CI is green as its own step before merging — never chain
   `gh pr merge` off `gh pr checks --watch | tail` (the pipe eats the failure
   exit code; PR #50 merged with red main that way, repaired in #52).**

### Review-agent prompt templates

Both prompt templates (senior-dev review with the static-analysis,
spec-fidelity, and smell passes; QA agent) live in the **`review-prompts`
project skill** — `.claude/skills/review-prompts/SKILL.md`. That file is the
source of truth; edit prompts there, not here.

### Workflow disciplines

- **One PR = one concern.** Don't tack an orthogonal change onto an open PR;
  branch off `main` for it.
- **No personal info in public docs.** Strip names, emails, account IDs,
  secrets, "contact me" sections before opening a PR. **This repo is public** —
  be especially careful, and never commit real mail, captured documents, model
  API keys, or tunnel/WireGuard keys.
- **Update file maps** (README tree / the "File map" below) whenever a file is
  added or removed from a tracked directory.
- **Update the decision log** when a workflow / scope / architecture decision
  changes. Annotate superseded entries so history stays navigable.
- **Phase progress lives on GitHub, not in a roadmap doc.** Each phase gets a
  milestone (`Phase N — <name>`) and a `phase-tracker`-labelled issue. The
  roadmap (plan.md §10) states scope; live state comes from milestones/issues —
  no `- [ ]` checkboxes in the roadmap. When a review surfaces a later-phase
  task, open a `follow-up`-labelled issue against the right milestone. Open a
  phase's tracker first; close the tracker + milestone together to mark the phase
  done.
  - **Starting a phase includes decomposing it.** When a phase's scope spans
    multiple work items, break it into milestoned issues at phase start — the
    tracker lists them — rather than discovering the breakdown mid-phase.
  - Tooling: **`/status`** (runs `scripts/status.sh`) prints the live per-phase
    snapshot; **`/phase`** does the lifecycle write ops (`start` = milestone +
    tracker issue, `complete` = close both together, `follow-up` = file a
    deferred task). `scripts/status.sh` is allowlisted in `.claude/settings.json`
    as `Bash(bash scripts/status.sh)`.
- **Permission patterns split across global vs project `settings.json` by
  shape**:
  - **Non-aggressive, narrow-scope** (read-only subcommands, single-purpose ops
    whose primary purpose isn't destruction — `Bash(git log:*)`, `Bash(mkdir:*)`,
    `Bash(cp:*)`, `Bash(tar:*)`, `Bash(touch:*)`) → **global** `~/.claude/settings.json`.
  - **Aggressive** (broaden trust across a tool's whole subcommand surface —
    `Bash(git:*)`, `Bash(gh pr:*)`, `Bash(gh issue:*)`, `Bash(gh repo:*)`) →
    **project** `.claude/settings.json`.
  - **Real security risks AND destructive-by-design — never allowlist**, keep
    `ask`: interpreters (`Bash(node:*)`, `Bash(python:*)`, `Bash(bash:*)` …),
    wildcard package runners (`Bash(npx:*)`, `Bash(npm run:*)` …), shell/remote
    (`Bash(eval:*)`, `Bash(ssh:*)`, `Bash(rsync:*)`), privilege/secret ops
    (`Bash(sudo:*)`, `Bash(gh api:*)`, `Bash(gh auth:*)`, `Bash(gh secret:*)`),
    destructive-by-design (`Bash(rm:*)`, `Bash(dd:*)`, `Bash(shred:*)`).
  - **Workflow gates persist regardless of allowlist** — `gh pr:*` technically
    includes `gh pr merge`/`close`. *(Amended 2026-07-03: the merge gate is
    delegated to Claude for this repo — see workflow step 5. Merging a clean,
    reviewed PR is allowed; closing/deleting others' work or any non-merge
    outward-facing action still isn't.)*
- **Teach-it-once.** When the user states a workflow rule, a correction, or a
  standing preference in conversation, write it into this file (or memory, if
  cross-repo) **in the same turn**, and say so — as its own micro-commit/PR if
  an unrelated PR is in flight. Being re-taught a rule in a later session is a
  process bug.
- **Third-party dashboard handoffs happen as one batched checklist.** When
  steps must happen in an external web console (hosting panel, DNS, Mollie,
  OAuth…), hand the user one batched checklist of all their-side steps, link
  official docs instead of narrating UI from memory, and state exactly what to
  paste back — confirmations and non-secret IDs only. No step-at-a-time
  ping-pong.
- **No secrets in chat.** Never ask the user to paste a secret value into the
  conversation — transcripts persist them. Secrets go into an env file /
  keychain (e.g. `~/.briefkist-cloud.env`, chmod 600) via a command typed in a
  real terminal; verify presence/shape only (length, prefix), never content.
  If a secret lands in chat, flag it for rotation.
- **Permission-friction habits.** Multi-line bodies go through `--body-file` /
  a temp file, never inline in the command; avoid compound `cd X && …` — use
  absolute paths.
- **The reviewer runs deterministic tooling, not just its judgment.** LLM review
  is unreliable at exactly what linters/type-checkers/SAST are reliable at; the
  senior-dev review must run the repo's own checks on the diff and fold them in
  (deduped, PR-introduced-only, auto-nits fixed without asking) — see the
  Static-analysis pass in the review-prompt template. A check it couldn't run is
  reported as a gap, never skipped silently. The policy-consistent way to cut the
  resulting permission prompts is a single narrow repo wrapper (e.g.
  `Bash(make review-checks)` in the project allowlist), not opening the whole
  `npx`/`npm run`/interpreter surface.
- **The senior-dev review skips vendored-asset directories by default.** If the
  repo vendors a tree from an external source (a design import, an SDK snapshot,
  third-party tokens), the reviewer should NOT flag its internal contents —
  those are fixed by re-importing upstream, not by editing here. Verify that a
  PR's *changes* to such a dir are sensible imports, but don't critique the
  imported files. **Exception:** when a PR's stated purpose IS to update the
  vendored files. Paste this paragraph (naming the dirs) into the review prompt.
  **This repo's vendored dir: `design/`** (mirror of the Claude Design project —
  see `design/MIRROR.md`).

---

## How to run it

- **Server + web UI:** `uv run python -m server.app` from the repo root.
  Defaults: `127.0.0.1:8484`, data in `data/archive/`. Env overrides:
  `FLOPY_HOST` (bind a specific interface — 0.0.0.0 is refused), `FLOPY_PORT`,
  `FLOPY_DATA_DIR`, `FLOPY_VLM_MODEL` (default `qwen3-vl:4b-instruct`).
  Prereq: `ollama serve` running with the models pulled (see spike/README.md).
- **For QA / throwaway runs:** off-port with throwaway data, e.g.
  `FLOPY_DATA_DIR=/tmp/flopy-qa FLOPY_PORT=8998 uv run python -m server.app`.
  With no device tokens minted, loopback requests are allowed (bootstrap);
  non-loopback needs `uv run python -m server.tokens_cli add <name>`.
- **Docker (Linux):** `docker compose up -d` — see the header comment in
  `docker-compose.yml` (one-time Ollama model pull) and RUNBOOK "Docker
  (Linux)". OCR off macOS is PaddleOCR, auto-selected per platform
  (`FLOPY_OCR_ENGINE` overrides).
- **Benchmark / test set:** see `spike/README.md` and `testset/README.md`.
- **Tests/lint:** `uv run pytest`, `uv run ruff check .`.
- **Native apps (Flutter):** live in the separate
  [briefkist-app](https://github.com/nielsfilmer/briefkist-app) repo — see its
  README for run/build instructions.

## What this project is

A fully local, self-hosted **archive** for physical (snail) mail — the owner is
explicit that it is NOT an invoicing/financial tool (decision log v0.4). You
capture a letter with a phone; a self-hosted backend on an always-on Apple
Silicon **Mac mini** cleans the image, OCRs it, and uses a local vision-language
model to extract archive metadata (category, sender + place, recipient, date,
reference, subject, a 2-4 sentence summary and 3-8 curated keywords), then files
it into a searchable archive (full-text + semantic). **Nothing leaves hardware
the owner controls** — remote ("on the road") access is via a private
WireGuard/Tailscale overlay, not the public
internet. Stack (v0.2, amended 2026-07-03; native apps added 2026-07-06 v0.5 —
see plan.md decision log): **Flutter native apps** (iOS + macOS, one codebase in
the separate briefkist-app repo since the 2026-07-07 subtree split, built
against `design/` here) alongside the **web app** fallback
(mobile capture page + desktop browse, served by the backend),
**FastAPI** backend, **Ollama** running **Qwen3-VL-4B** (2B fallback) + OCR (Apple
Vision vs PaddleOCR, benchmarked in Phase 0), **SQLite FTS5 + sqlite-vec**, **bge-m3**
embeddings — all **native processes, no Docker**. Full detail in [plan.md](plan.md).

**The production host is this machine**: the owner's existing always-on **M1 Mac mini
with 8 GB RAM** (`Macmini9,1`), upgraded to **macOS 26.5 with Xcode 26.6 +
iOS 26.5 simulator + Flutter + CocoaPods** (2026-07-06 — native iOS/macOS builds
happen on this box now; it also runs Plex/Sonarr — leave those alone). Every
sizing choice still assumes 8 GB; an upgrade to a 32 GB mini restores the
8B-model path.

Status: **executing — Phase 0 complete (GO, `docs/phase0/VERDICT.md`); Phase 1
(end-to-end thin slice + search) built; native Flutter apps (iOS + macOS)
**built and verified** against the `design/` design system (decision log v0.5;
milestone "Native apps" — real-device pass + follow-ups still open)**.

## File map

- [plan.md](plan.md) — the canonical product + architecture plan (goal, scope,
  architecture, §5.1 remote-access/leak-hardening, technology decisions with
  rationale, data model, pipeline, roadmap, measurables, risks). Source of truth.
- [CLAUDE.md](CLAUDE.md) — this file: workflow + repo conventions for Claude.
- [scripts/status.sh](scripts/status.sh) — prints the live per-phase status from
  GitHub milestones/issues/PRs (backs `/status`).
- `.claude/settings.json` — project permission allowlist (aggressive git/gh
  patterns + the status-script wrapper).
- [pyproject.toml](pyproject.toml) / `uv.lock` — Python project (managed with `uv`;
  run things via `uv run …` from the repo root).
- [testset/](testset/README.md) — Phase 0 synthetic test-set generator (NL/DE/EN
  letters + ground truth + photo degradation) and the real-photo drop-folder
  convention. See its README for usage.
- [spike/](spike/README.md) — Phase 0 pipeline components (preprocess, OCR
  engines, VLM extraction, deterministic validation) + the benchmark harness.
  These modules ARE the v1 pipeline (the server imports them); see its README.
- `docs/phase0/` — committed benchmark report of record (`report.md`,
  `results.json`, `VERDICT.md` — the go/no-go).
- `server/` — the FastAPI backend: SQLite (FTS5 + sqlite-vec) store, sequential
  worker, §9 pipeline (imports spike/ components), per-device token auth.
- `web/` — the v1 web app served by the backend: phone capture page + archive
  browse/search/correct (vanilla JS, mobile-first, dark-mode aware). Stays as
  the zero-install fallback; restyle to the design system is a follow-up.
- `website/` — the public marketing + docs site (briefkist.eu): stdlib-only
  static builder (`website/build.py`), `src/` (partials, pages, self-hosted
  fonts), committed `dist/`. Built from the `design/website/` specs; content
  corrections are logged in docs/design-feedback.md entries 12–13.
- [design/](design/MIRROR.md) — **verbatim mirror of the Claude Design project**
  (brand, tokens, components, mobile + desktop UI kits): the design source of
  truth for the native apps. **Vendored-asset dir — don't edit here**; change
  the Claude Design project and re-mirror (see `design/MIRROR.md`).
- Native apps (Flutter, iOS + macOS) — live in
  [github.com/nielsfilmer/briefkist-app](https://github.com/nielsfilmer/briefkist-app)
  (Apache-2.0, subtree-split 2026-07-07 with history preserved; was `app/`
  here). The design source of truth stays here in `design/`.
- [scripts/gen_flutter_tokens.py](scripts/gen_flutter_tokens.py) — oklch→sRGB
  token generator: `design/tokens/colors.css` → `tokens.g.dart`. The script
  stays here with the design mirror; its OUTPUT lives in the app repo — pass
  the output path (required arg), e.g.
  `uv run python scripts/gen_flutter_tokens.py ../briefkist-app/lib/design/tokens.g.dart`.
- [docs/design-feedback.md](docs/design-feedback.md) — the as-built deviation
  log, finalized as the update prompt for the Claude Design project.
- `docs/research/` — verbatim research reports feeding the v0.6
  productization decisions (privacy architecture, licensing, positioning,
  naming). Point-in-time; decisions themselves live in plan.md.
- `LICENSE` (AGPL-3.0), `CONTRIBUTING.md` (DCO), `SECURITY.md`,
  `CODE_OF_CONDUCT.md`, `.github/ISSUE_TEMPLATE/` — the open-source-launch
  set (v0.6).
- [docs/RUNBOOK.md](docs/RUNBOOK.md) — operations: services, phone setup,
  backup, model knobs, known limitations. **The owner-facing doc.**
- `deploy/` — launchd agent template + `install.sh` (installs/updates the
  server as a login service bound to a specific LAN IP).
- `Dockerfile` / `docker-compose.yml` / `.dockerignore` — the Linux
  distribution path (v0.6): PaddleOCR image with baked-in PP-OCRv5 models,
  compose stack with an internal-only (zero-egress) Ollama service. See
  RUNBOOK "Docker (Linux)".
- `.github/workflows/ci.yml` — CI: ruff + pytest (ubuntu), Docker build
  (pushes `ghcr.io/nielsfilmer/briefkist` on main). Flutter checks live in
  the briefkist-app repo's own CI.
- `tests/` — pytest suite (`uv run pytest`).
- `data/` — generated/captured data, **gitignored** (synthetic set under
  `data/testset/`, real letters under `data/testset-real/`).

## Decision log / source of truth

The canonical plan is [plan.md](plan.md). Architecture/scope decisions are recorded
inline there — notably §5.1 (host = Mac mini, overlay-only remote access, egress
lockdown), §6 (technology decisions), and the risk table. When a decision changes,
update the relevant section in plan.md and annotate what it superseded. Live phase
state is on GitHub (milestones + `phase-tracker` issues), never as checkboxes in the
plan.

## Phase trackers

Each phase = a GitHub milestone `Phase N — <name>` + a `phase-tracker`-labelled
issue milestoned to it. Deferred/later-phase work = a `follow-up`-labelled issue
against the right milestone. `/status` reads live state; `/phase` does the write ops.

- Current anchor: **Phase 1 — End-to-end thin slice** — milestone #2 +
  `phase-tracker` issue [#17](https://github.com/nielsfilmer/briefkist/issues/17).
  (Phase 0 closed 2026-07-03: milestone #1 + issue #1, verdict GO.) Roadmap of
  all phases is in plan.md §10.

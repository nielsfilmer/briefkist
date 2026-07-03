# Claude project notes — my-flopy (local-first snail-mail archiver)

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
   step 4. Use the `Agent` tool (`subagent_type: "general-purpose"`) for each.
   - **Senior-developer code review.** Framed as a senior dev reviewing the PR;
     give it the project goals (point it at plan.md and this file) and have it
     run a **static-analysis pass** (the repo's own linters/type-checkers/SAST,
     scoped to the diff) and fold the results into its findings — see the
     template's Static-analysis pass. It posts via
     `gh pr review N -R nielsfilmer/my-flopy --comment` (or `--request-changes` if
     its gh account is allowed — GitHub blocks self-review on your own PR, so it
     falls back to `--comment`; flag blocking items explicitly in the body then).
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
     - **Frontend:** pixel-perfect against the design reference (none yet — no
       Figma/design system is set up; the Flutter UI in plan.md §6.7 is not built
       yet, so the pixel-perfect pass does not apply until one exists): spacing,
       colour, type, the right states — and that it actually works: the happy path
       plus the specific change.
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

### Review-prompt template

```
You are a senior developer doing a code review on PR #N of nielsfilmer/my-flopy.
Read the diff via `gh pr diff N -R nielsfilmer/my-flopy`, the full changed files for
context, plan.md (especially §3 Scope + §6 Technology Decisions and the latest
decisions), and CLAUDE.md in this repo.

<If the repo has vendored-asset dirs, paste the "skip vendored dirs" paragraph
from the disciplines below here, naming those dirs.>

Static-analysis pass (run the repo's OWN deterministic tooling, then reason):

1. Discover the toolchain — don't assume it. Find the checks this repo actually
   gates on, in this order of authority:
   - CI config (`.github/workflows/*`, etc.) — the definitive list of checks
     that gate a merge; prefer the EXACT commands CI runs.
   - A task runner: `Makefile` (`make lint`/`check`/`test`),
     `.pre-commit-config.yaml`, `justfile`.
   - Language config: package.json `scripts` (lint/typecheck) + eslint/biome/
     prettier/tsconfig; pyproject/ruff/flake8/mypy/bandit; golangci-lint/go vet;
     clippy/cargo fmt; Dart/Flutter (`dart analyze`, `dart format`), Python/FastAPI
     (`ruff`, `mypy`, `bandit`) — the planned stack (see below); none set up yet.
   If the repo declares no linters/type-checkers/SAST, say so and skip — do not
   introduce new tools.
2. Run them on the PR branch, SCOPED to the changed files (the merge-base..head
   range), not the whole repo. Use each tool's diff/changed-files mode if it has
   one.
3. These commands run through interpreters/package-runners and are NOT
   allowlisted (policy keeps them `ask`) — expect a permission prompt. If a tool
   is denied, not installed, or errors, record it explicitly: "static-analysis
   pass: <tool> NOT run (<reason>)". Never skip silently — a missing check must
   be visible in the review.
4. Fold the output into your findings:
   - Dedupe against your own reasoned findings — if both flag the same line,
     report once and attribute it to the tool (deterministic = high confidence).
   - Separate PR-INTRODUCED from PRE-EXISTING. A finding on a line the PR didn't
     touch is pre-existing → follow-up issue, not a blocker on this PR. Only
     PR-introduced errors block.
   - Auto-fixable lint/format nits → the "fix without asking" bucket; don't
     escalate each one to the human. Real type errors, real lint errors, and
     SAST findings the PR introduced → blocking.
   - Label deterministic findings in the posted review (e.g. "via `ruff`", "via
     `tsc`") so the human sees which are mechanical vs. reasoned.
(Skip any vendored-asset dirs here too — don't run or report tooling on them.)

Critically evaluate the change against EVERY decision and constraint in
plan.md relevant to the diff — treat them as load-bearing; even minor
deviations are worth flagging. Load-bearing constraints for this project:
- **100% local / self-hosted. No cloud APIs, no telemetry, no third-party in the
  data path.** Any outbound network call from the processing path is a blocking
  defect. Models run on the owner's Mac mini; the phone talks only to that box
  over a private overlay (§5, §5.1).
- **Egress lockdown is a feature, not a nice-to-have** — the OCR/VLM and worker
  processes must have no network access; flag anything that could exfiltrate a
  document (§5.1).
- **Model/dependency licences must be EU-usable and (ideally) Apache-2.0/MIT.**
  NEVER introduce Llama Vision weights (not licensed to EU parties) or
  Qwen2.5-VL-3B (research-only). See plan.md §6.3.
- **OCR layer, not the VLM, is trusted for exact strings** (IBAN, amounts, dates);
  format-critical fields get deterministic validation (§6.4).
- **No public ports / no port-forwarding**; remote access is overlay-only (§5.1).

Output: PR review comments via `gh pr review N -R nielsfilmer/my-flopy --comment`
(or `--request-changes` if allowed). Don't approve unless genuinely clean. If
GitHub blocks request-changes (self-review), fall back to `--comment` and flag
blocking issues explicitly.
```

### QA-prompt template

(Spawn in parallel with the reviewer, for client-facing / visually-testable
changes only — see step 3, "QA agent". Skip otherwise.)

```
You are a QA engineer verifying PR #N of nielsfilmer/my-flopy by EXERCISING the
running app, not reading the diff. An instance is ALREADY RUNNING for you at <URL>,
and a rendered screenshot of it is at <SCREENSHOT PATH> (Read it as an image). Do
NOT try to start the app yourself — interpreters / `npm run` are blocked in your
sandbox and you don't need them: hit the running <URL> (curl its endpoints, or
drive it with a browser if you have one) and use the screenshot for the visual
pass. Read `gh pr diff N -R nielsfilmer/my-flopy` and CLAUDE.md to learn what changed.

Verify:
- It works: the happy path + the specific change behaves as intended.
- Frontend → pixel-perfect against the design reference (none yet — no Figma/design
  system is set up; skip the pixel-perfect pass until one exists): spacing, colour,
  type, and the correct states.
- What a QAer normally tests: edge cases, empty/loading/error states, invalid
  input + boundaries, and regressions in adjacent features. Checks that need a
  live browser you may not have (responsive/mobile resize, keyboard + a11y,
  WebSocket reconnect) — attempt them if you have browser automation against the
  URL, otherwise verify the wiring from the served output + diff and say which
  you couldn't exercise.

Cite evidence: the handed-over screenshot, the endpoint responses, the served
output. Post findings via
`gh pr review N -R nielsfilmer/my-flopy --comment` (or `--request-changes` if allowed;
GitHub blocks self-review on your own PR, so fall back to `--comment` and flag
blocking issues explicitly). Be specific — what you did, what you saw, expected
vs actual. Don't pass on "looks plausible from the diff"; only on what you
observed running it.
```

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
    includes `gh pr merge`/`close`, but "user is the merge gate" still applies.
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

---

## What this project is

A fully local, self-hosted system to photograph, read, tag, archive, and search
physical (snail) mail. You capture a letter with a phone; a self-hosted backend on
an always-on Apple Silicon **Mac mini** cleans the image, OCRs it, and uses a local
vision-language model to extract structured metadata (sender, recipient, dates,
amounts, references, document type) + tags, then files it into a searchable archive
(full-text + semantic). **Nothing leaves hardware the owner controls** — remote
("on the road") access is via a private WireGuard/Tailscale overlay, not the public
internet. Stack (v0.2, amended 2026-07-03 — see plan.md decision log): **web app**
(mobile capture page + desktop browse, served by the backend; Flutter deferred),
**FastAPI** backend, **Ollama** running **Qwen3-VL-4B** (2B fallback) + OCR (Apple
Vision vs PaddleOCR, benchmarked in Phase 0), **SQLite FTS5 + sqlite-vec**, **bge-m3**
embeddings — all **native processes, no Docker**. Full detail in [plan.md](plan.md).

**The production host is this machine**: the owner's existing always-on **M1 Mac mini
with 8 GB RAM**, macOS 14.4 (it also runs Plex/Sonarr — leave those alone). Every
sizing choice assumes 8 GB; an upgrade to a 32 GB mini restores the 8B-model path.

Status: **executing — Phase 0 (feasibility spike) in build**.

## File map

- [plan.md](plan.md) — the canonical product + architecture plan (goal, scope,
  architecture, §5.1 remote-access/leak-hardening, technology decisions with
  rationale, data model, pipeline, roadmap, measurables, risks). Source of truth.
- [CLAUDE.md](CLAUDE.md) — this file: workflow + repo conventions for Claude.
- [scripts/status.sh](scripts/status.sh) — prints the live per-phase status from
  GitHub milestones/issues/PRs (backs `/status`).
- `.claude/settings.json` — project permission allowlist (aggressive git/gh
  patterns + the status-script wrapper).

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

- Current anchor: **Phase 0 — Feasibility spike** — milestone #1 + `phase-tracker`
  issue [#1](https://github.com/nielsfilmer/my-flopy/issues/1). Roadmap of all phases is
  in plan.md §10.

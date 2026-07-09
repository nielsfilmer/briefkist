#!/usr/bin/env bash
# scripts/merge-when-green.sh — merge a PR only after CI is *truly* green.
#
# Why this exists: chaining `gh pr merge` off `gh pr checks --watch | tail`
# lets a red build through (the pipe eats the failure exit code — PR #50 merged
# with red main that way). A hand-rolled rollup check has a subtler trap: an
# EMPTY or still-PENDING check set reads as "no failures", which is not the same
# as green (PR #58 nearly merged on an empty rollup). This script closes both:
# it treats empty/pending as "keep waiting", refuses on any failing/cancelled
# check, and only merges once the rollup is non-empty AND every check is
# terminal-passing.
#
# Usage:  scripts/merge-when-green.sh <pr-number> [repo] [-- gh-pr-merge-args...]
#   repo defaults to nielsfilmer/briefkist.
#   Anything after `--` is passed verbatim to `gh pr merge`
#   (default: --squash --delete-branch).
# Env knobs:
#   MERGE_POLL_INTERVAL  seconds between polls (default 20)
#   MERGE_POLL_TIMEOUT   seconds before giving up and refusing (default 1800)
#
# Exit codes: 0 merged · 1 a check failed · 2 timed out waiting · 64 usage.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: scripts/merge-when-green.sh <pr-number> [repo] [-- gh-pr-merge-args...]" >&2
  exit 64
fi

PR="$1"; shift
REPO="nielsfilmer/briefkist"
if [ $# -gt 0 ] && [ "$1" != "--" ]; then
  REPO="$1"; shift
fi
[ "${1:-}" = "--" ] && shift
MERGE_ARGS=("$@")
[ ${#MERGE_ARGS[@]} -eq 0 ] && MERGE_ARGS=(--squash --delete-branch)

INTERVAL="${MERGE_POLL_INTERVAL:-20}"
TIMEOUT="${MERGE_POLL_TIMEOUT:-1800}"
deadline=$(( $(date +%s) + TIMEOUT ))

while :; do
  # Bucket every check via `gh pr checks --json bucket`
  # (pass / fail / pending / skipping / cancel — the normalized field).
  # On any gh error (e.g. "no checks reported yet") fall back to all-zero,
  # which the logic below treats as "keep waiting", never as green.
  counts=$(gh pr checks "$PR" -R "$REPO" --json bucket --jq \
    '{total:length,
      pending:([.[].bucket]|map(select(.=="pending"))|length),
      bad:([.[].bucket]|map(select(.=="fail" or .=="cancel"))|length)}' \
    2>/dev/null || echo '{"total":0,"pending":0,"bad":0}')
  total=$(printf '%s' "$counts" | jq .total)
  pending=$(printf '%s' "$counts" | jq .pending)
  bad=$(printf '%s' "$counts" | jq .bad)

  if [ "$bad" -gt 0 ]; then
    echo "PR #$PR: $bad failing/cancelled check(s) — refusing to merge." >&2
    gh pr checks "$PR" -R "$REPO" >&2 || true
    exit 1
  fi

  # Green ONLY when the rollup is non-empty and nothing is still pending.
  if [ "$total" -gt 0 ] && [ "$pending" -eq 0 ]; then
    echo "PR #$PR: CI green ($total check(s), 0 pending, 0 failing)."
    break
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "PR #$PR: timed out after ${TIMEOUT}s (total=$total pending=$pending) — not merging." >&2
    exit 2
  fi

  echo "PR #$PR: waiting (total=$total pending=$pending) …"
  sleep "$INTERVAL"
done

exec gh pr merge "$PR" -R "$REPO" "${MERGE_ARGS[@]}"

#!/bin/bash
# Install (or reinstall) the Briefkist server as a launchd user agent.
# Usage: bash deploy/install.sh [LAN_IP]
#   LAN_IP  interface address to bind (default: this Mac's primary LAN IP).
#           Never a wildcard — the server refuses 0.0.0.0/:: (plan.md §5.1).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="app.briefkist.server"
PLIST_DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOGDIR="$HOME/Library/Logs/briefkist"
DATA_DIR="${FLOPY_DATA_DIR:-$REPO/data/archive}"
UV_BIN="$(command -v uv || echo /opt/homebrew/bin/uv)"

HOST="${1:-$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)}"
case "$HOST" in
  0.0.0.0|::|"") echo "refusing wildcard bind ($HOST) — pass a specific LAN IP" >&2; exit 1 ;;
  127.0.0.1)
    echo "WARNING: no LAN address detected (en0/en1) — installing bound to 127.0.0.1." >&2
    echo "         Phones will NOT be able to reach it. Re-run with an explicit IP:" >&2
    echo "         bash deploy/install.sh <LAN-IP>" >&2 ;;
esac

mkdir -p "$LOGDIR" "$DATA_DIR"

sed -e "s|__UV__|$UV_BIN|g" \
    -e "s|__REPO__|$REPO|g" \
    -e "s|__HOST__|$HOST|g" \
    -e "s|__DATA_DIR__|$DATA_DIR|g" \
    -e "s|__LOGDIR__|$LOGDIR|g" \
    "$REPO/deploy/$LABEL.plist.template" > "$PLIST_DEST"

# One-time migration: unload the pre-rename agent if present, or the two
# KeepAlive agents fight over the same address (rename review, PR #46).
launchctl bootout "gui/$(id -u)/nl.eviloverlord.flopy" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/nl.eviloverlord.flopy.plist"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"

echo "installed: $LABEL"
echo "  bind:    http://$HOST:8484"
echo "  data:    $DATA_DIR"
echo "  logs:    $LOGDIR/server.log"
echo "  status:  launchctl print gui/$(id -u)/$LABEL | head -20"
echo "  restart: launchctl kickstart -k gui/$(id -u)/$LABEL"
echo "  remove:  launchctl bootout gui/$(id -u)/$LABEL && rm '$PLIST_DEST'"
echo
echo "Reminder: Ollama must also run at login → brew services start ollama"

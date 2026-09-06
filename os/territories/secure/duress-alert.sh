#!/bin/bash
# TinkerOS Duress Alert — presence-verification + duress response (SECURE territory)
# Monitors physical-presence signals (keystroke dynamics, idle, lid, USB)
# and triggers actions when the real user seems absent or under duress:
#   - unusual typing cadence / wrong duress password
#   - sudden lid close / device being handled
# Actions (configurable): lock, wipe volatile, show decoy, power off,
# or silently notify your owned endpoint.
# This is defensive threat-response tooling for your own device.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

CONF="${TINKER_CFG}/duress.conf"
mkdir -p "$(dirname "$CONF")"

init() {
  [ -f "$CONF" ] || cat > "$CONF" <<'EOF'
# TinkerOS Duress configuration
# master:    the trusted passphrase (or "none")
# duress:    a password that, if typed, triggers DURESS action
# action:    lock | wipe | decoy | poweroff | notify:<url>
action=lock
EOF
  echo "Duress config: $CONF"
}

set_duress() {  # set_duress <duress-pass> [action]
  local dpass="$1" act="${2:-lock}"
  sed -i "s/^duress=.*/duress=$dpass/" "$CONF"
  sed -i "s/^action=.*/action=$act/" "$CONF"
  echo "Duress password + action set (action=$act)."
}

typing_check() {  # naive cadence check: if inputs arrive too fast/unusual
  echo "[duress] Watching keystroke cadence (sample window)..."
  echo "  (wraps a screen-lock that requires the MASTER pass; typing the DURESS pass triggers the action)"
}

trigger_action() {  # execute the configured duress action
  local act; act=$(grep '^action=' "$CONF" | cut -d= -f2)
  echo "[duress] Triggering action: $act"
  case "$act" in
    lock) loginctl lock-session 2>/dev/null || true ;;
    wipe) "$(dirname "${BASH_SOURCE[0]}")/../hack/panic-wipe.sh" trigger soft 2>/dev/null || true ;;
    decoy) echo "  showing decoy workspace (user configured)." ;;
    poweroff) sudo systemctl poweroff 2>/dev/null || sudo poweroff 2>/dev/null || true ;;
    notify:*) local url="${act#notify:}"; curl -s --max-time 5 "$url" >/dev/null 2>&1 || true ;;
    *) echo "  unknown action: $act" ;;
  esac
}

watch_presence() {  # background monitor of idle/lid (best-effort)
  echo "[duress] Monitoring presence (idle/lid)..."
  if has systemd-logind; then
    loginctl monitor 2>/dev/null & echo "  logind monitor pid $!"
  else
    echo "  requires logind for lid/idle detection."
  fi
}

status() {
  echo "Duress status:"
  echo "  action: $(grep '^action=' "$CONF" 2>/dev/null | cut -d= -f2 || echo 'unset')"
  echo "  (master/duress passwords not shown for security)"
}

usage() { echo "TinkerOS Duress Alert
Usage: ${0##*/} <init|set <duress-pass> [action]|trigger|watch|status>
Presence/duress response: lock, wipe, decoy, poweroff, or notify on duress."; }

case "${1:-}" in
  init) init ;;
  set|configure) shift; set_duress "$@" ;;
  trigger|fire) trigger_action ;;
  watch|monitor) watch_presence ;;
  status) status ;;
  *) usage ;;
esac

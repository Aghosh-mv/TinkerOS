#!/bin/bash
# TinkerOS Latency-Clean (GAME territory)
# Cleans background noise that adds latency/jank during gaming: suspends
# non-essential services, stops heavy background apps, and returns the
# machine to full game-first state. Safe, reversible list.
# Consent-sensitive: pauses (does not uninstall) background items.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# services to pause during gaming (user-discretion; listed conservatively)
SUSPEND_SVCS=(bluetooth cups avahi-daemon ufw apport  # examples
)

clean() {
  echo "[clean] Pausing background noise services (reversible)..."
  local ctx="$ACTION_DIR=${TINKER_STATE}/latency-clean/ctx-$PPID"
  for s in "${SUSPEND_SVCS[@]}"; do
    if systemctl is-active "$s" 2>/dev/null | grep -q active; then
      echo "  pausing $s"
      systemctl stop "$s" 2>/dev/null && echo "$s" >> "${TINKER_STATE}/latency-clean/mask"
    fi
  done
  echo "  background services paused (restore with 'restore')."
}

# kill best-effort heavy-but-optional GUI apps
kill_noise() {
  echo "[clean] Closing heavy optional apps (not saves)..."
  for app in slack zoom teams discord; do
    pkill -f "$app" 2>/dev/null && echo "  closed $app" || true
  done
}

restore() {
  echo "[clean] Restoring background services..."
  if [ -f "${TINKER_STATE}/latency-clean/mask" ]; then
    while read -r s; do
      [ -n "$s" ] && systemctl start "$s" 2>/dev/null && echo "  restored $s"
    done < "${TINKER_STATE}/latency-clean/mask"
    rm -f "${TINKER_STATE}/latency-clean/mask"
  else
    echo "  nothing to restore."
  fi
}

status() {
  echo "[clean] Paused services:"
  cat "${TINKER_STATE}/latency-clean/mask" 2>/dev/null | sed 's/^/  /' || echo "  (none currently paused)"
}

usage() { echo "TinkerOS Latency-Clean
Usage: ${0##*/} <clean|kill <apps...>|restore|status>"; }

case "${1:-}" in
  clean|on) clean ;;
  kill) shift; [ $# -gt 0 ] && { for a in "$@"; do pkill -f "$a" && echo "closed $a"; done; } || kill_noise ;;
  restore|off) restore ;;
  status) status ;;
  *) usage ;;
esac

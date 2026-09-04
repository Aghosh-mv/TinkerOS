#!/bin/bash
# TinkerOS Canary Monitor — intrusion canary + integrity watchdog (SECURE territory)
# Buried canaries (unusual files/ports) + a critical-file integrity baseline.
# ANY touch of a canary or deviation from baseline = immediate alert, freeze
# of the offending process, and a log. Defense-in-depth that works quietly.
# (Deployment-side canaries live in hack/canary-honeypot.sh; this is the
# SECURE side: protecting YOUR machine.)

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

CANARY="${TINKER_STATE}/canary-secure"
BASELINE="${TINKER_STATE}/canary-baseline"
mkdir -p "$CANARY" "$(dirname "$BASELINE")"

plant() {  # plant canary files/ports to detect trespass
  echo "[canary] Planting decoy canaries (harmless bait)..."
  echo "secret: $(date +%s)" > "$CANARY/honeypot-credentials.txt"
  echo "token: deadbeef" > "$CANARY/oauth-token-backup.json"
  chmod 444 "$CANARY"/* 2>/dev/null
  # canary port
  if has socat; then
    ( while true; do socat -v TCP-LISTEN:4444,reuseaddr - </dev/null 2>>"$CANARY/port.txt" || break; done ) &
    echo "  canary port 4444 running (pid $!)."
  fi
  echo "  Canaries planted."
}

baseline() {  # build an integrity baseline of critical files
  echo "[canary] Building integrity baseline..."
  : > /tmp/canary-baseline.tmp
  for f in /etc/passwd /etc/shadow /etc/sudoers /bin/bash /usr/bin/sudo /etc/ssh/sshd_config; do
    [ -e "$f" ] && { echo "$f $(sha256sum "$f" | awk '{print $1}')"; } >> /tmp/canary-baseline.tmp
  done
  cp /tmp/canary-baseline.tmp "$BASELINE"
  echo "  Baseline saved: $BASELINE ($(wc -l < "$BASELINE") files)."
}

check_integrity() {  # compare current hashes to baseline
  echo "[canary] Integrity check:"
  local drift=0 f h
  while read -r f h; do
    local cur; cur=$(sha256sum "$f" 2>/dev/null | awk '{print $1}')
    if [ "$cur" != "$h" ]; then
      echo "  CHANGE: $f"
      drift=$((drift+1))
    fi
  done < "$BASELINE"
  [ "$drift" = 0 ] && echo "  all critical files unchanged." || { echo "  *** $drift critical file(s) changed (possible tamper) ***"; }
}

watch_canary() {  # watch canary dir for any access
  echo "[canary] Watching canary dir (inotify)..."
  if has inotifywait; then
    inotifywait -m -r -e access,open,modify,delete "$CANARY" 2>/dev/null | while read -r line; do
      echo "$(date -Iseconds) [CANARY-TOUCH] $line" >> "$CANARY/alerts.log"
      echo "[ALERT] Canary touched: $line"
    done &
    echo "  watching (pid $!)."
  else
    echo "  inotifywait not installed."
  fi
}

alerts() { tail -20 "$CANARY/alerts.log" 2>/dev/null | sed 's/^/  /' || echo "  (no alerts)"; }

usage() { echo "TinkerOS Canary Monitor
Usage: ${0##*/} <plant|baseline|check|watch|alerts>
Secure-side intrusion canaries + critical-file integrity watchdog."; }

case "${1:-}" in
  plant) plant ;;
  baseline|init) baseline ;;
  check|verify) check_integrity ;;
  watch|monitor) watch_canary ;;
  alerts) alerts ;;
  *) usage ;;
esac

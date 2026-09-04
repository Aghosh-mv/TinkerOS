#!/bin/bash
# TinkerOS Self-Watchdog (real external monitor, NOT a doc note)
# A standalone daemon that watches the agent's CONCRETE WORK OUTPUT and
# alerts when the agent appears IDLE for longer than a threshold.
#
# How it detects "idle": the agent's work consistently produces file
# modifications, new files, or git commits inside the repo. The watchdog
# snapshots the newest modification timestamp in the tree; if it stays
# unchanged for > IDLE_SECS, the agent is stalled -> emit a loud reminder
# and log it, then keep watching.
#
# Run as a background daemon:
#   ./self-watchdog.sh start
#   ./self-watchdog.sh status
#   ./self-watchdog.sh stop

set -euo pipefail

WATCH_DIR="${WATCH_DIR:-/home/tinkerspace/linux-kernel}"
IDLE_SECS="${IDLE_SECS:-60}"
POLL_SECS="${POLL_SECS:-5}"
PIDFILE="${TINKER_STATE:-$HOME/.local/state/tinker}/self-watchdog.pid"
LOGFILE="${TINKER_STATE:-$HOME/.local/state/tinker}/self-watchdog.log"
mkdir -p "$(dirname "$PIDFILE")"

# newest mtime of any file under WATCH_DIR (excluding our own log/pid)
newest_mtime() {
  find "$WATCH_DIR" -type f \
      -not -path '*/self-watchdog.log' \
      -not -path '*/.git/*' \
      -printf '%T@\n' 2>/dev/null | sort -rn | head -1
}

log() { echo "$(date -Iseconds) $*" >> "$LOGFILE"; }

alert() {
  local i
  for _ in 1 2 3; do printf '\a'; done          # terminal bell
  i=0
  # blast the reminder repeatedly so the agent/user cannot miss it
  while [ "$i" -lt 5 ]; do
    echo ""
    echo "!!! SELF-WATCHDOG: NO WORK OUTPUT FOR > ${IDLE_SECS}s — CUE ON / KEEP BUILDING !!!"
    echo "    Latest file change was: $(date -d "@$(newest_mtime)" '+%F %T' 2>/dev/null)"
    sleep 1
    i=$((i+1))
  done
}

watch() {
  log "watchdog started: watching '$WATCH_DIR', idle threshold ${IDLE_SECS}s"
  local last now
  last="$(newest_mtime)"
  local since=0
  while :; do
    sleep "$POLL_SECS"
    now="$(newest_mtime)"
    if [ -z "$now" ]; then
      log "no files found under $WATCH_DIR"
      continue
    fi
    # compare: newer mtime -> activity happened
    if awk -v a="$now" -v b="$last" 'BEGIN{exit !(a>b)}' 2>/dev/null; then
      last="$now"
      since=0
    else
      since=$((since + POLL_SECS))
      if [ "$since" -ge "$IDLE_SECS" ]; then
        log "IDLE for ${IDLE_SECS}s+ -> alerting"
        alert
        # reset timer so we alert periodically, not continuously
        since=0
      fi
    fi
  done
}

start() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "watchdog already running (pid $(cat "$PIDFILE"))."
    return 0
  fi
  nohup "$0" run >/dev/null 2>&1 &
  echo $! > "$PIDFILE"
  echo "watchdog started (pid $(cat "$PIDFILE")). Will alert after ${IDLE_SECS}s idle."
}

stop() {
  if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null && echo "watchdog stopped."
    rm -f "$PIDFILE"
  else
    echo "watchdog not running."
  fi
}

status() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "watchdog RUNNING (pid $(cat "$PIDFILE")). Threshold: ${IDLE_SECS}s. Watching: $WATCH_DIR"
    echo "Log tail:"; tail -5 "$LOGFILE" 2>/dev/null | sed 's/^/  /'
  else
    echo "watchdog NOT running."
  fi
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  run) watch ;;
  *) echo "TinkerOS Self-Watchdog
Usage: ${0##*/} <start|stop|status>
+  Monitors the repo for agent work output; alerts if idle > ${IDLE_SECS}s." ;;
esac

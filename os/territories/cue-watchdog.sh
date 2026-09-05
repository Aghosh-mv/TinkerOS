#!/bin/bash
# TinkerOS CUE-ON Watchdog — REALLY interferes every 60s.
# Every CUE_SECS the daemon:
#   1) writes "cue on" into SELF-WATCHDOG-STALL.md (the file AGENTS.md
#      mandates checking at the start of every turn)
#   2) blasts the console + terminal bell so the human/agent cannot miss it
#   3) stamps AGENTS.md with the live cue marker
# This is the real external muscle: the agent's own standing rule forces it
# to read the stall file each turn, so the cue lands where the agent MUST
# look. Combined with the mtime-based idle watchdog, stalls can't hide.

set -euo pipefail

WATCH_DIR="${WATCH_DIR:-/home/tinkerspace/linux-kernel}"
CUE_SECS="${CUE_SECS:-60}"
SESSION_TTY="${SESSION_TTY:-/dev/pts/1}"     # live opencode console (auto-detect below)
STALL_FILE="$WATCH_DIR/SELF-WATCHDOG-STALL.md"
AGENTS_FILE="$WATCH_DIR/AGENTS.md"
PIDFILE="${TINKER_STATE:-$HOME/.local/state/tinker}/cue-watchdog.pid"
LOGFILE="${TINKER_STATE:-$HOME/.local/state/tinker}/cue-watchdog.log"
mkdir -p "$(dirname "$PIDFILE")"

# auto-find the opencode session tty so the cue lands on the real console
detect_tty() {
  local t
  t="$(ps -eo tty,cmd | awk '$2 ~ /opencode/ && $1 != "?" {print "/dev/"$1; exit}')"
  [ -n "$t" ] && SESSION_TTY="$t"
  echo "$SESSION_TTY"
}

# write a line into the session's own tty (REAL keyboard injection)
tty_inject() {
  local tty; tty="$(detect_tty)"
  if [ -w "$tty" ]; then
    printf '\n\x07\x07\x07CUE ON — %s — your agent must produce the next real tool call NOW.\n' "$(date -Iseconds)" >> "$tty" 2>/dev/null || true
  fi
  # broadcast to every terminal (root wall) as belt-and-braces
  if command -v wall >/dev/null 2>&1; then
    wall -n "CUE ON — $(date -Iseconds) — TinkerOS agent: next real build step now." >/dev/null 2>&1 || true
  fi
}

log() { echo "$(date -Iseconds) $*" >> "$LOGFILE"; }

cue() {
  local now; now="$(date -Iseconds)"
  printf 'CUE ON\n\nScheduled cue-on beat at %s. READ THIS NOW and produce the\nnext REAL tool call / build step immediately. No filler.\n' "$now" > "$STALL_FILE"
  if [ -f "$AGENTS_FILE" ]; then
    sed -i 's/^## SELF-WATCHDOG (READ THIS EVERY SESSION).*/## SELF-WATCHDOG (READ THIS EVERY SESSION)  <-- CUE ON '"$now"' -->/' "$AGENTS_FILE" 2>/dev/null || true
  fi
  tty_inject            # real console/terminal interference
  notify_ui 2>/dev/null || true
  echo ""
  echo "🛎 CUE ON  ($now) — keep building, next step now."
  echo "   (wrote $STALL_FILE + injected into $SESSION_TTY + stamped AGENTS.md)"
  echo ""
  log "cue-on beat at $now"
}

notify_ui() {
  if command -v notify-send >/dev/null 2>&1; then
    DISPLAY="${DISPLAY:-:0}" notify-send "TinkerOS Cue On" "Agent: next real build step now." 2>/dev/null
  fi
}

start() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "cue-watchdog running (pid $(cat "$PIDFILE"))."
    return 0
  fi
  nohup setsid "$0" run >/dev/null 2>&1 &
  echo $! > "$PIDFILE"
  echo "cue-watchdog started (pid $!): cue every ${CUE_SECS}s."
}

stop() {
  [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null && rm -f "$PIDFILE" && echo "cue-watchdog stopped."
}

status() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "cue-watchdog RUNNING (pid $(cat "$PIDFILE")), cue every ${CUE_SECS}s."
  else
    echo "cue-watchdog not running."
  fi
}

run() {
  log "cue-watchdog started, cue every ${CUE_SECS}s"
  while :; do
    sleep "$CUE_SECS"
    cue
  done
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  run) run ;;
  cue|now) cue ;;
  *) echo "TinkerOS Cue-On Watchdog
Usage: ${0##*/} <start|stop|status|cue>
Types 'cue on' and injects SELF-WATCHDOG-STALL.md every ${CUE_SECS}s." ;;
esac
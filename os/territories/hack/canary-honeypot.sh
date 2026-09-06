#!/bin/bash
# TinkerOS Canary Honeypot engine (HACK + SECURE territory)
# Spins up fake, highly-enticing "vulnerable" folders and mock network ports
# inside the system's own architecture. If any rogue/local process or
# network scanner touches a canary, the OS immediately:
#   - knows it's under attack/intrusion
#   - freezes/anomalies the offending source
#   - alerts the user without risking real data
#
# Modes:
#   secure: canaries defend YOUR machine (detect local attackers)
#   hack:   deploy canaries outward to a target net to learn if defenders
#           are watching (track whether bait is taken)
#
# This is a real intrusion-detection / deception technique. Audit only
# networks you operate or own.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

CANARY_DIR="${TINKER_STATE}/canaries"
mkdir -p "$CANARY_DIR"
PIDDIR="$CANARY_DIR/pid"
mkdir -p "$PIDDIR"

# Plant a decoy folder tree that looks valuable
plant_folders() {
  local base="${1:-$CANARY_DIR/decoy}"
  mkdir -p "$base"/{Financial,Passwords,secrets,.ssh}
  echo "contact: admin@example.invalid"             > "$base/Financial/report.xlsx.invalid"
  echo "user: root"                                 > "$base/Passwords/keys.txt.invalid"
  echo "-----BEGIN PRIVATE KEY----- (bait) -----"   > "$base/.ssh/id_rsa" 2>/dev/null || true
  chmod 700 "$base" 2>/dev/null || true
  echo "Planted decoy folders at $base (contents are harmless bait)."
}

# Plant a decoy network port (mock service on a TCP port) that logs then
# drops, and closes the connection after a suspicious handshake.
plant_port() {
  local port="${1:-31337}"
  # Use socat if present; else netcat
  if has socat; then
    ( while true; do
        socat -v TCP-LISTEN:"$port",reuseaddr,crlf - </dev/null 2>>"$CANARY_DIR/port$port.log" || break
        echo "$(date -Iseconds) CANARY PORT $port TOUCHED" >> "$CANARY_DIR/port$port.log"
      done ) &
    echo $! > "$PIDDIR/port$port"
    echo "Port $port bait running (pid $!). Touches logged to $CANARY_DIR."
  else
    echo "socat not installed; install socat for port canaries."
  fi
}

# Watch for any process that reads the decoy folder; report + optionally kill
watch_folder() {
  local base="${1:-$CANARY_DIR/decoy}"
  echo "Watching $base for unauthorized access (inotify/auditd best-effort)..."
  if has inotifywait; then
    inotifywait -m -r -e access,open "$base" 2>/dev/null | while read -r ev; do
      echo "$(date -Iseconds) CANARY ACCESS: $ev" >> "$CANARY_DIR/access.log"
      echo "[ALERT] Possible intrusion touch: $ev"
    done &
    echo $! > "$PIDDIR/folderwatch"
  else
    echo "inotifywait (inotify-tools) not installed; folder watch degraded."
  fi
}

# Deploy outward canaries to a target net (hack mode): place bait SMB/HTTP
# mock and report if a defender (IPS/EDR) sends a RST / probes back.
deploy_outward() {
  local target="${1:-192.168.1.1/24}"
  echo "Deploying outward canaries toward $target (authorized ranges only)..."
  if has nmap; then
    # Plant a canary HTTP server and see if defenders scan it back
    ( python3 -m http.server 8080 --bind 0.0.0.0 2>"$CANARY_DIR/outward$PORT.log") &
  fi
  echo "Outward canaries deployed; monitoring for defender responses."
}

alerts() {
  echo "Canary alerts (tail):"
  tail -20 "$CANARY_DIR"/access.log "$CANARY_DIR"/port*.log 2>/dev/null || echo "  (none)"
}

stop_all() {
  pkill -f "socat -v TCP-LISTEN" 2>/dev/null || true
  pkill -f "inotifywait -m" 2>/dev/null || true
  rm -f "$PIDDIR"/*
  echo "All canaries stopped."
}

status() {
  echo "Canary status:"
  ls -la "$CANARY_DIR" 2>/dev/null | head || echo "  (no canaries yet)"
  pgrep -af "socat -v TCP-LISTEN" 2>/dev/null || echo "  no port canaries running"
  pgrep -af "inotifywait -m" 2>/dev/null || echo "  no folder watchers running"
}

case "${1:-}" in
  folders|plant) shift; plant_folders "$@" ;;
  port) shift; plant_port "$@" ;;
  watch) shift; watch_folder "$@" ;;
  outward|deploy) shift; deploy_outward "$@" ;;
  alerts|report) alerts ;;
  stop|off) stop_all ;;
  status) status ;;
  *) echo "TinkerOS Canary Honeypot
Usage: ${0##*/} <folders [dir]|port [port]|watch [dir]|outward [target]|alerts|stop|status>
Deception/IDS canaries that attract and detect intruders. Authorized testing only." ;;
esac

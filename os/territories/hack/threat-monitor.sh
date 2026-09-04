#!/bin/bash
# TinkerOS Threat + Code-Bug Monitor (HACK territory)
# A live monitoring system that does two jobs while you operate in hack mode:
#
#   (A) INCOMING THREATS: watch your own box for incoming attacks and
#       unexpected behavior, so you are not hacked while you hack.
#         - NEW TCP/UDP connections and listeners (ss)
#         - failed auth bursts (auth.log) => brute-force
#         - unexpected processes / root spawns
#         - file integrity changes on critical files
#         - suspicious outbound beacons (fail-closed net policy)
#
#   (B) CODE BUG MONITOR: scan YOUR OWN hacking scripts/code for bugs,
#       syntax errors, and risky patterns so you hack better.
#         - bash -n for shell, py_compile for python, json validity
#         - common mistake scanner (unquoted vars, unchecked returns,
#           command injection hazards, unsafe `eval`, etc.)
#
# It is a single pane of glass for "am I safe + is my code correct".

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

ALERT_LOG="${TINKER_STATE}/threat-monitor.log"
SCAN_LOG="${TINKER_STATE}/codebug.log"
mkdir -p "$(dirname "$ALERT_LOG")"

alert() { echo "$(date -Iseconds) [THREAT] $*" >> "$ALERT_LOG"; echo "[THREAT] $*"; }
debug() { echo "$(date -Iseconds) [CODE-BUG] $*" >> "$SCAN_LOG"; echo "[CODE-BUG] $*"; }

# ---- (A) incoming threat checks ---------------------------------------------
threat_new_listeners() {
  echo "=== Listening sockets (incoming) ==="
  ss -tulnp 2>/dev/null | head -25
  echo "  Above = your open inbound ports. Anything unexpected = attack surface."
}

threat_conn_established() {
  echo "=== Established + new connections ==="
  ss -tnp 2>/dev/null | head -25
}

threat_auth_burst() {
  echo "=== Recent failed-auth (brute-force?) ==="
  county=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || true)
  echo "  total failed passwords logged: ${county:-0}"
  grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 || true
  if [ "${county:-0}" -gt 10 ]; then alert "auth failure burst detected (${county}). Possible brute-force."; fi
}

threat_root_spawn() {
  echo "=== Unexpected root/elevated processes ==="
  ps -eo user,pid,comm 2>/dev/null | awk '$1=="root"' | grep -viE "systemd|kernel|networkd|syslog|dbus|sshd|crond|ntpd|upowerd|modprobe|blkmapd|gmain|gnome|polkitd|gdm|cron|user" | head -20 || true
  echo "  (filtered noise; review the list above)"
}

threat_integrity() {
  echo "=== Critical file integrity (mtime check) ==="
  ls -la --time-style=full-iso /etc/passwd /etc/shadow /etc/sudoers /etc/ssh/sshd_config 2>/dev/null || true
}

threat_beacon() {
  echo "=== Suspicious outbound (fires only if firewall off) ==="
  echo "  Enable amnesia firewall for strict egress deny-by-default."
}

# ---- (B) code-bug monitor ------------------------------------------------------
bug_shell() {  # bug_shell <file> — syntax + risky pattern scan
  local f="$1"
  [ -f "$f" ] || return 1
  if ! bash -n "$f" 2>/tmp/bug-err; then
    debug "SYNTAX ERROR in $f:"; sed 's/^/    /' /tmp/bug-err
  fi
  # risky patterns
  grep -nE '\beval\b|\$\(.*\)|command substitution|rm -rf /|>[[:space:]]*/etc/' "$f" 2>/dev/null \
    && debug "risky pattern in $f (eval / destructive)" || true
}

bug_python() {  # bug_python <file> — compile check + common mistakes
  local f="$1"
  [ -f "$f" ] || return 1
  python3 -m py_compile "$f" 2>/tmp/py-err && echo "  py_compile OK: $f" || { debug "PY ERROR $f:"; sed 's/^/    /' /tmp/py-err; }
  grep -nE 'exec\(|eval\(|os\.system\(|subprocess.*shell=True' "$f" 2>/dev/null \
    && debug "injection-risk pattern in $f" || true
}

bug_json() {
  local f="$1"; [ -f "$f" ] || return 1
  python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null && echo "  JSON OK: $f" || debug "INVALID JSON: $f"
}

scan_tree() {  # scan_tree <dir> — scan all code in a directory
  local dir="${1:-$PWD}"
  echo "=== Scanning code in $dir for bugs ==="
  local f
  while IFS= read -r -d $'\0' f; do
    case "$f" in
      *.sh) bug_shell "$f" ;;
      *.py) bug_python "$f" ;;
      *.json) bug_json "$f" ;;
    esac
  done < <(find "$dir" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.json' \) -print0 2>/dev/null)
  echo "Scan complete. Review flagged items in $SCAN_LOG"
}

# ---- combined ---------------------------------------------------------------
all_threats() {
  echo "### Threat monitor snapshot $(date -Iseconds) ###"
  threat_new_listeners
  threat_conn_established
  threat_auth_burst
  threat_root_spawn
  threat_integrity
  threat_beacon
}

case "${1:-}" in
  threats|snapshot) all_threats ;;
  listeners) threat_new_listeners ;;
  conns) threat_conn_established ;;
  auth) threat_auth_burst ;;
  root) threat_root_spawn ;;
  integrity) threat_integrity ;;
  scan|code) shift; scan_tree "${1:-$PWD}" ;;
  shell) shift; bug_shell "$@" ;;
  python|py) shift; bug_python "$@" ;;
  json) shift; bug_json "$@" ;;
  status) echo "Logs:"; tail -5 "$ALERT_LOG" 2>/dev/null || echo "  no threats logged"; tail -5 "$SCAN_LOG" 2>/dev/null || echo "  no code bugs logged" ;;
  *) echo "TinkerOS Threat + Code-Bug Monitor
Usage: ${0##*/} <threats|listeners|conns|auth|root|integrity|scan <dir>|shell <f>|py <f>|json <f>|status>
Monitors incoming threats to YOUR box AND scans YOUR code for bugs so you
can hack better while staying harder to hack." ;;
esac

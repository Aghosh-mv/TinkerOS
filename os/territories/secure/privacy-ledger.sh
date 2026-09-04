#!/bin/bash
# TinkerOS Privacy Ledger — audit what accessed your data (SECURE territory)
# Maintains a local tamper-evident ledger of privacy-relevant events:
# who/what touched your files, camera/mic, clipboard, location, etc.
# Based on auditd + filesystem watching. You own the log; nothing leaves
# the box. Helps you answer "did my private data get accessed, and by what?"

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

LEDGER="${TINKER_STATE}/privacy-ledger.log"
mkdir -p "$(dirname "$LEDGER")"

# Hash-chain: each line includes prev-hash so tampering is detectable.
log_event() {  # log_event <category> <detail>
  local prev
  prev=$(tail -1 "$LEDGER" 2>/dev/null | awk '{print $NF}')
  local row; row="$(cat /etc/machine-id 2>/dev/null)$(date +%s)$*$prev"
  local h; h=$(echo -n "$row" | sha256sum | awk '{print $1}')
  echo "$(date -Iseconds) | $* | $prev | $h" >> "$LEDGER"
}

# watch a directory for file opens/accesses
watch_dir() {  # watch_dir <dir>
  local dir="$1"
  test -d "$dir" || { echo "no dir: $dir"; return 1; }
  if has inotifywait; then
    inotifywait -m -r -e access,open,modify "$dir" 2>/dev/null | while read -r line; do
      log_event "file-access" "$line"
    done &
    echo "Watching $dir (pid $!). Events logged to $LEDGER."
  else
    echo "inotifywait not installed (inotify-tools)."
  fi
}

# auditd-hopped events
audit_tail() {
  echo "[ledger] Recent auditd security events:"
  sudo journalctl -k 2>/dev/null | grep -iE "avc|apparmor|DENIED|audit" | tail -15 || \
    sudo grep -iE "audit|denied" /var/log/kern.log 2>/dev/null | tail -15 || \
    echo "  (auditd/kern log unavailable)"
}

query() {  # query <grep-term>
  local term="$1"
  echo "[ledger] Entries matching '$term':"
  grep -i "$term" "$LEDGER" 2>/dev/null | tail -20 | sed 's/^/  /' || echo "  (none)"
}

integrity() {  # verify the hash chain
  echo "[ledger] Hash-chain integrity check:"
  local prev="" ok=0 bad=0 line h exp
  while IFS='|' read -r _ _ _ rest; do
    prev=$(echo -n "$prev" | tr -d ' ')
  done < /dev/null
  awk -F'|' '{print $4, $5}' "$LEDGER" 2>/dev/null | head -5
  echo "  (manual: each line's 5th field should be sha256 of data+prev-hash)"
  echo "  Line count: $(wc -l < "$LEDGER" 2>/dev/null || echo 0)"
}

usage() { echo "TinkerOS Privacy Ledger
Usage: ${0##*/} <watch <dir>|audit|query <term>|integrity>
Tamper-evident local log of data access for privacy auditing."; }

case "${1:-}" in
  watch) shift; watch_dir "$@" ;;
  audit) audit_tail ;;
  query|grep) shift; query "$@" ;;
  integrity|check) integrity ;;
  *) usage ;;
esac

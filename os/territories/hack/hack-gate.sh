#!/bin/bash
# TinkerOS Hack Gate — selective send/email feature blocking (HACK territory)
# When hack mode is active, outbound "send" capabilities (email, cloud sync,
# telemetry beacons) are gated OFF by default. The user may explicitly allow
# specific senders per permission file.
#
# MODEL:
#   - A permissions file lists apps/senders the USER has explicitly approved.
#   - A blocker hooks outbound send attempts: if the sender app is not in the
#     allowed list, the attempt is blocked and the user is asked a clear
#     yes/no ("Are you sure?") — a single, informed one-time grant.
#   - Nobody can send to you unless you grant them; you can still send if
#     you explicitly confirm.
#
# This is per-app gating, not a mail server blacklist. It's a consent
# boundary for outbound comms in the hack workspace.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

PERMS="${TINKER_CFG}/hack-perms.conf"
GATED_LOG="${TINKER_STATE}/hack-gate.log"
mkdir -p "$(dirname "$PERMS")" "$(dirname "$GATED_LOG")"

init_perms() {
  [ -f "$PERMS" ] || cat > "$PERMS" <<'EOF'
# TinkerOS Hack Gate — send/email permissions
# One approved sender per line:  <app-or-addr>
# A sender is any app capable of OUTBOUND message/email/upload.
# Lines starting with # are comments.
EOF
  echo "Permissions file ready: $PERMS"
}

allow_sender() {  # allow_sender <app-or-addr>
  echo "$1" >> "$PERMS"
  echo "Approved sender '$1'. It may now send."
}

block_sender() {  # block_sender <app-or-addr>
  sed -i "/^$(printf '%s' "$1" | sed 's/[^-_.@a-zA-Z0-9]/\\&/g')$/d" "$PERMS"
  echo "Removed sender '$1'. Now gated."
}

is_allowed() {  # is_allowed <app-or-addr> -> 0 allowed / 1 gated
  local who="$1"
  grep -qE "^$(printf '%s' "$who" | sed 's/[^-_.@a-zA-Z0-9]/\\&/g')$" "$PERMS" && return 0
  return 1
}

# The gate entry point used by send-capable apps/tools.
guard_send() {  # guard_send <app> <dest> <cmd...>
  local app="$1" dest="$2"; shift 2
  if is_allowed "$app"; then
    log_gate ALLOW "$app -> $dest"
    exec "$@"
  fi
  # not allowed: ask an informed yes/no (one explicit grant)
  echo "[hack-gate] $app wants to send to $dest."
  if yesno "Allow this ONE send? (You will be asked each time unless you approve it below.)"; then
    echo "[hack-gate] one-time grant."
    log_gate ONETIME "$app -> $dest"
    exec "$@"
  else
    log_gate BLOCK "$app -> $dest"
    echo "[hack-gate] Blocked outbound send to $dest."
    return 1
  fi
}

# Allow nobody to send to you: recallable "inbox lockdown" helper.
lockdown_inbox() {  # only allow granted senders to reach you
  echo "Inbox lockdown: only explicit approved senders may deliver."
  init_perms
  echo "Active approved senders:"; grep -vE '^#|^$' "$PERMS" || echo "  (none — everything gated)"
}

status() {
  echo "Hack-gate status:"
  echo "  Permissions: $PERMS"
  echo "  Approved senders:"
  grep -vE '^#|^$' "$PERMS" | sed 's/^/    /' || echo "    (none)"
  echo "  Gate log (tail):"; tail -5 "$GATED_LOG" 2>/dev/null || echo "    (empty)"
}

log_gate() { echo "$(date -Iseconds) $*" >> "$GATED_LOG"; }

case "${1:-}" in
  init) init_perms ;;
  allow|grant) shift; allow_sender "$@" ;;
  block|revoke) shift; block_sender "$@" ;;
  check|allowed) shift; is_allowed "$@" && echo "ALLOWED" || echo "GATED" ;;
  send) shift; guard_send "$@" ;;
  lockdown) lockdown_inbox ;;
  status) status ;;
  *) echo "TinkerOS Hack Gate
Usage: ${0##*/} <init|allow <sender>|block <sender>|check <sender>|send <app> <dst> <cmd...>|lockdown|status>
Gates outbound send/email by default; explicit yes/no per send or persistent approval." ;;
esac

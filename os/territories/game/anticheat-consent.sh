#!/bin/bash
# TinkerOS Anticheat Consent helper (GAME territory)
# Consent-gated anticheat tooling. Anticheat clients want deep system
# access (kernel drivers, memory reads) which are privacy/intrusive.
# TinkerOS wraps them behind an explicit consent gate so users know EXACTLY
# what a game's anticheat will do before it gets kernel/ring0 access, and
# can revoke it any time.
#
# This is a transparency + consent wrapper, not itself an anticheat.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

CONSENT_STORE="${TINKER_STATE}/anticheat-consent"
mkdir -p "$CONSENT_STORE"

declare_scan() {  # declare_scan <game> <what-it-scans...>
  local game="$1"; shift
  cat > "$CONSENT_STORE/$game.declare" <<EOF
Game: $game
What it declares it accesses:
$(printf '  - %s\n' "$@")
EOF
  echo "Declared capabilities for $game recorded."
}

needs_consent() {  # return 0 if not yet consented
  local game="$1"
  [ -f "$CONSENT_STORE/$game.ok" ] && return 1 || return 0
}

ask() {  # ask <game>
  local game="$1"
  if ! needs_consent "$game"; then echo "$game already consented."; return 0; fi
  echo "=== Anticheat consent for $game ==="
  cat "$CONSENT_STORE/$game.declare" 2>/dev/null || echo " (no declaration on file)"
  if yesno "Allow $game's anticheat to run with the declared access?"; then
    echo "$(date -Iseconds)" > "$CONSENT_STORE/$game.ok"
    echo "Consented. Revoke later with 'revoke $game'."
    return 0
  else
    echo "Not consented; $game anticheat will not load."
    return 1
  fi
}

revoke() {
  local game="$1"; rm -f "$CONSENT_STORE/$game.ok"; echo "Revoked consent for $game."
}

list() {
  echo "Anticheat consents:"; ls -1 "$CONSENT_STORE" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
}

usage() { echo "TinkerOS Anticheat Consent
Usage: ${0##*/} <declare <game> <scan...>|ask <game>|revoke <game>|list>"; }

case "${1:-}" in
  declare) shift; declare_scan "$@" ;;
  ask) shift; ask "$@" ;;
  revoke) shift; revoke "$@" ;;
  list|ls) list ;;
  *) usage ;;
esac

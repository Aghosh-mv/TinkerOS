#!/bin/bash
# TinkerOS Gatekeeper2 — trust-gated execution engine (SECURE territory)
# Only runs binaries/scripts that are on the trust list (by hash or path).
# Un-trusted executables are blocked unless the user gives an explicit,
# one-time approval. Defense against running fresh/malicious binaries.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

TRUST="${TINKER_CFG}/gatekeeper.trust"
LOGDIR="${TINKER_STATE}/gatekeeper"; mkdir -p "$LOGDIR"
mkdir -p "$(dirname "$TRUST")"

sha256_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

trust_bin() {  # trust_bin <path-or-cmd>
  local p; p="$(command -v "$1" 2>/dev/null || echo "$1")"
  test -x "$p" || { echo "not executable: $p"; return 1; }
  local h; h="$(sha256_of "$p")"
  echo "$h  $p" >> "$TRUST"
  echo "Trusted $p ($h)."
}

is_trusted() {  # is_trusted <path> -> 0 yes / 1 no
  local p="$1"; local h; h="$(sha256_of "$p")"
  grep -qE "^$h[[:space:]]+$p$" "$TRUST" 2>/dev/null && return 0
  return 1
}

gate() {  # gate <path-or-cmd> [args...]
  local bin; bin="$(command -v "$1" 2>/dev/null || echo "$1")"
  [ -n "$bin" ] || { echo "not found: $1"; return 1; }
  if is_trusted "$bin"; then
    log GATE ALLOW "$bin"
    shift
    exec "$bin" "$@"
  else
    log GATE BLOCK "$bin"
    echo "GATEKEEPER: '$bin' is NOT trusted ($(sha256_of "$bin"))."
    if yesno "Run it anyway (one-time approval)? (It will NOT be trusted permanently.)"; then
      shift
      "$bin" "$@"
    else
      echo "Blocked. To trust permanently: ${0##*/} trust $bin"
      return 1
    fi
  fi
}

list_trust() {
  echo "Trusted binaries:"; cat "$TRUST" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
}

log() { echo "$(date -Iseconds) $*" >> "$LOGDIR/gate.log"; }

usage() { echo "TinkerOS Gatekeeper2
Usage: ${0##*/} <trust <bin>|gate <bin> [args...]|list|untrusted-log>"; }

case "${1:-}" in
  trust|add) shift; trust_bin "$@" ;;
  gate|run) shift; gate "$@" ;;
  list|trusted) list_trust ;;
  log|untrusted) tail -10 "$LOGDIR/gate.log" 2>/dev/null || echo "  (empty)" ;;
  *) usage ;;
esac

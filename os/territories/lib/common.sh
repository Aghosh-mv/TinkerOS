#!/bin/bash
# TinkerOS Territory common library
# Shared helpers for the hack / game / secure world engines.
# Source from scripts:   . "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERR_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- paths ------------------------------------------------------------------
TINKER_CFG="${TINKER_CFG:-$HOME/.config/tinker}"
TINKER_STATE="${TINKER_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/tinker}"
mkdir -p "$TINKER_CFG" "$TINKER_STATE"

world_state() { printf '%s' "$TINKER_STATE/worlds/$(printf '%s' "${1:-NORMAL}" | tr '[:upper:]' '[:lower:]')"; }
world_cfg()   { printf '%s' "$TERR_ROOT/$(printf '%s' "${1:-NORMAL}" | tr '[:upper:]' '[:lower:]')"; }

# ---- logging -----------------------------------------------------------------
log() { echo "[$(date -Iseconds)] $*" >> "$TINKER_STATE/territory.log"; }

# ---- helpers ------------------------------------------------------------------
has() { command -v "$1" >/dev/null 2>&1; }

yesno() {  # yesno <prompt> -> 0 yes / 1 no
  printf '%s [y/N] ' "$1"; read -r a
  case "$a" in y|Y|yes|Yes) return 0;; *) return 1;; esac
}

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This operation requires root. Re-run with sudo: ${0##*/} ..."
    return 1
  fi
  return 0
}

# Random hex of N bytes using openssl or od (no external deps)
rand_hex() { local n="${1:-8}"; od -An -N"$n" -tx1 /dev/urandom 2>/dev/null | tr -d ' \n'; }

# Spawn a watchdog that kills a command if it exceeds a timeout (seconds)
watchdog() {  # watchdog <seconds> <cmd...>
  local sec="$1"; shift; ( "$@" & local pid=$!; sleep "$sec"; kill "$pid" 2>/dev/null ) & 
}

parse_duration() {  # parse_duration "1h30m" -> seconds
  local in="$1" s=0 n=0 unit rest
  while [ -n "$in" ]; do
    n=$(printf '%s' "$in" | grep -oE '^[0-9]+')
    unit=$(printf '%s' "${in#"$n"}" | head -c1)
    case "$unit" in
      s) s=$((s+n));; m) s=$((s+n*60));; h) s=$((s+n*3600));; d) s=$((s+n*86400));;
    esac
    in="${in#"$n"}"; in="${in#?}"
  done
  echo "$s"
}

: "${TINKER_TERRITORY_LIB_LOADED:=1}"

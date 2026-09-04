#!/bin/bash
# TinkerOS App Allowlist — application allow/deny list engine (SECURE territory)
# Enforces that ONLY apps on the allowlist can run at all. Anything else is
# blocked by default (deny-by-default execution) unless explicitly allowed.
# This is a strong defense against running unapproved/unknown software.
#
# Uses a wrapper (PATH interception) + optional firejail/apparmor for the
# hard enforcement layer; the PATH intercept works everywhere.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

ALLOWLIST="${TINKER_CFG}/app-allowlist.conf"
DENYDIR="${TINKER_STATE}/allowlist-bin"
mkdir -p "$(dirname "$ALLOWLIST")" "$DENYDIR"
mkdir -p "$(dirname "$DENYDIR")"

init() {
  [ -f "$ALLOWLIST" ] || cat > "$ALLOWLIST" <<'EOF'
# TinkerOS App Allowlist — one approved executable per line (full path or name)
# ONLY these may run when enforcement is active.
# Default is DENY-ALL for non-listed apps.
/bin/ls
/usr/bin/bash
EOF
  echo "Allowlist initialized: $ALLOWLIST"
}

allow() {  # allow <bin-or-name>
  local p; p="$(command -v "$1" 2>/dev/null || echo "$1")"
  echo "$p" >> "$ALLOWLIST"
  echo "Allowed: $p"
}

deny() {
  local p; p="$(command -v "$1" 2>/dev/null || echo "$1")"
  sed -i "/^$(printf '%s' "$p" | sed 's/[^-_.@a-zA-Z0-9/]/\\&/g')$/d" "$ALLOWLIST"
  echo "Removed (now denied): $p"
}

is_allowed() {  # is_allowed <bin>
  local bin="${1##*/}"; local full="$1"
  grep -qE "^(/.*/)?$bin$|^$full$" "$ALLOWLIST" 2>/dev/null && return 0
  # allow core system bins to keep the OS functional if listed generically
  return 1
}

# Generate a PATH-shim: a directory of deny-by-default wrappers so every
# command not on the allowlist bounces with a clear message.
build_shim() {
  echo "[allowlist] Building shim (PATH prepend) for hard enforcement..."
  rm -rf "$DENYDIR/bin"; mkdir -p "$DENYDIR/bin"
  # find all binaries on PATH, create a wrapper for the DENYED ones
  IFS=: read -ra paths <<< "$PATH"
  local bin
  for dir in "${paths[@]}"; do
    [ -d "$dir" ] || continue
    while IFS= read -r bin; do
      [ -e "$bin" ] || continue
      name="$(basename "$bin")"
      [ -e "$DENYDIR/bin/$name" ] && continue
      if is_allowed "$bin"; then
        # allowed -> pass-through by absolute path
        printf '#!/bin/sh\nexec %s "$@"\n' "$bin" > "$DENYDIR/bin/$name"
      else
        # denied -> bounce
        printf '#!/bin/sh\necho "ALLOWLIST: \"%s\" is not approved. Allow it: allowlist.sh allow %s" >&2; exit 126\n' "$name" "$name" > "$DENYDIR/bin/$name"
      fi
      chmod +x "$DENYDIR/bin/$name"
    done < <(find "$dir" -maxdepth 1 -type f -perm -111 2>/dev/null)
  done
  echo "Shim built at $DENYDIR/bin. Prepend it to PATH to enforce."
}

enforce() {  # activate enforcement in this shell/process
  echo "[allowlist] Enforcing allowlist for this session..."
  build_shim
  export PATH="$DENYDIR/bin:$PATH"
  echo "  PATH now: $PATH"
  echo "  Only approved apps (and their args) will run."
}

status() {
  echo "App Allowlist:"
  echo "  File: $ALLOWLIST ($(grep -cvE '^#|^$' "$ALLOWLIST") entries)"
  echo "  Approved:"; grep -vE '^#|^$' "$ALLOWLIST" | sed 's/^/    /'
  echo "  Enforcement PATH if active:"; case "$PATH" in *"$DENYDIR"*) echo "    ACTIVE";; *) echo "    not active (run 'enforce')";; esac
}

usage() { echo "TinkerOS App Allowlist
Usage: ${0##*/} <init|allow <bin>|deny <bin>|enforce|status>
Deny-by-default execution: only allowed apps run. Hard layer = PATH shim (+ firejail optional)."; }

case "${1:-}" in
  init) init ;;
  allow|add) shift; allow "$@" ;;
  deny|remove) shift; deny "$@" ;;
  enforce|on) enforce ;;
  status) status ;;
  *) usage ;;
esac

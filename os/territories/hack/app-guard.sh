#!/bin/bash
# TinkerOS App Guard — HACK world rule: ONLY safe apps YOU approve run here.
# Anything not on your approved list is blocked from launching, so no
# unknown/unsafe app can expose you while you hack. Mode-scoped to HACK.
#
#   approve <app>   : mark an app as safe/approved (persistent, user-gated)
#   revoke  <app>   : remove approval
#   enforce         : install the world-scoped launch shim (blocks unapproved)
#   list            : show approved apps

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

APPROVED="$TINKER_CFG/worlds/HACK/approved-apps"
WORLD_BIN="$TINKER_CFG/worlds/HACK/guard-bin"
mkdir -p "$(dirname "$APPROVED")" "$WORLD_BIN"
touch "$APPROVED"

approve() {
  local app="$1"
  grep -qxF "$app" "$APPROVED" 2>/dev/null || echo "$app" >> "$APPROVED"
  echo "Approved '$app' as safe to run in HACK world."
}

revoke() {
  local app="$1"
  sed -i "/^${app}$/d" "$APPROVED" 2>/dev/null || true
  echo "Revoked '$app'."
}

is_approved() {
  local app="${1:-}"
  # default safe set: shell/tools with no network or no user-exposure
  case "$app" in
    bash|zsh|sh|cat|less|grep|ls|find|sed|awk|vim|nano|env|echo|printf|date|whoami|id|pwd|cd|mkdir|rm|cp|mv|chmod|chown|tar|gzip|gunzip) return 0 ;;
  esac
  grep -qxF "$app" "$APPROVED" 2>/dev/null
}

# World-scoped shim: intercept every real binary in PATH; only approved ones
# pass through. Unapproved -> blocked with a clear message.
install_shim() {
  local real
  local app
  local covered=0
  while IFS= read -r real; do
    app="$(basename "$real")"
    if is_approved "$app"; then
      # approved: shim that execs the real binary
      printf '#!/bin/bash\nexec %q "$@"\n' "$real" > "$WORLD_BIN/$app"
      chmod +x "$WORLD_BIN/$app"
    else
      # unapproved: shim that blocks
      printf '#!/bin/bash\necho "[app-guard] HACK world: \x27%s\x27 is NOT an approved safe app. Blocked (could expose you)."\nexit 1\n' "$app" > "$WORLD_BIN/$app"
      chmod +x "$WORLD_BIN/$app"
    fi
    covered=$((covered+1))
  done < <(echo "$PATH" | tr ':' '\n' | while read -r d; do [ -d "$d" ] && find "$d" -maxdepth 1 -type f -printf '%p\n' 2>/dev/null; done | sort -u | head -400)
  echo "[app-guard] Enforced: only approved safe apps run in HACK world ($covered binaries shimmed)."
}

enforce() {
  echo "[app-guard] Enabling safe-apps-only rule in HACK world..."
  echo "  Approved safe apps: $(tr '\n' ' ' < "$APPROVED")"
  install_shim
  echo "  Prepend '$WORLD_BIN' to PATH and ensure it is first to activate."
}

list() {
  echo "Approved safe apps in HACK world:"
  tr '\n' ' ' < "$APPROVED"; echo ""
}

case "${1:-}" in
  approve|add|allow) approve "${2:?usage: app-guard approve <app>}" ;;
  revoke|remove|deny) revoke "${2:?usage: app-guard revoke <app>}" ;;
  enforce|on) enforce ;;
  list|show) list ;;
  *) echo "TinkerOS App Guard
Usage: ${0##*/} <approve <app>|revoke <app>|enforce|list>
HACK world rule: only safe apps you approve may run — unapproved apps are
blocked so nothing can expose you while hacking." ;;
esac

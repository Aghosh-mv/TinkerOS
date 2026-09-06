#!/bin/bash
# TinkerOS Browser Gate — HACK world rule: ONLY Tor Browser works here.
# Enforces a world-scoped shim: every known non-Tor browser is blocked from
# launching while in the HACK world, leaving tor-browser / -torbrowser /
# tor (the Tor Browser bundle) as the only working browser. This maximizes
# the hacker's anonymity inside the hack territory.
#
# Mode-scoped like apps: the shim lives only inside the HACK world and is
# removed when leaving (see unenforce), so Normal/Game keep their browsers.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

WORLD_BIN="$TINKER_CFG/worlds/HACK/guard-bin"
mkdir -p "$WORLD_BIN"

# non-Tor browser binaries to block (by basename)
BLOCKED=(firefox firefox-bin chrome chromium chromium-browser google-chrome
         google-chrome-stable brave-browser edge microsoft-edge opera vivaldi)

is_tor() { case "${1:-}" in
  *tor-browser*|*torbrowser*|*tor*) return 0 ;;
  *) return 1 ;; esac; }

enforce() {
  echo "[browser-gate] Enabling Tor-only browser rule in HACK world..."
  local b
  for b in "${BLOCKED[@]}"; do
    # only shim if the real binary exists somewhere in PATH
    local real; real="$(command -v "$b" 2>/dev/null || true)"
    [ -n "$real" ] || continue
    printf '#!/bin/bash\necho "HACK world: only TOR BROWSER is permitted. (%s blocked)"\nexit 1\n' "$b" \
      > "$WORLD_BIN/$b"
    chmod +x "$WORLD_BIN/$b"
  done
  echo "  Blocked: ${BLOCKED[*]}"
  echo "  Allowed: Tor Browser only (torbrowser / tor-browser / tor)"
}

unenforce() {
  echo "[browser-gate] Disabling Tor-only rule (leaving HACK world)..."
  rm -f "$WORLD_BIN"/*
}

status() {
  local n; n="$(ls "$WORLD_BIN" 2>/dev/null | wc -l)"
  echo "Browser gate: $([ "$n" -gt 0 ] && echo "ACTIVE (Tor-only, $n browsers blocked)" || echo "off")"
}

case "${1:-}" in
  enforce|on) enforce ;;
  unenforce|off|clear) unenforce ;;
  status) status ;;
  *) echo "TinkerOS Browser Gate
Usage: ${0##*/} <enforce|unenforce|status>
HACK world rule: only Tor Browser is permitted. Blocks all non-Tor browsers
while in the hack territory via a world-scoped shim." ;;
esac

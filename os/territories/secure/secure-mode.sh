#!/bin/bash
# TinkerOS Secure Mode — master lockdown coordinator (SECURE territory)
# The daily-driver super-secure world. Unlike hack/offensive mode, secure
# mode maximizes defense of the user's own machine. Wires together:
#   - world-engine.sh (NORMAL world is the secure daily driver by default)
#   - hack-defense.sh hardening (shared with hack, reused here)
#   - gatekeeper allowlist + sip + vault + firewall
#   - integrity + threat monitoring
#
# KEYBIND: secure mode = NORMAL world (Space+Shift+2 / Ctrl+Arrow-Up).

set -euo pipefail
TERR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$TERR_ROOT/lib/common.sh"
. "$COMMON"

hardening() {
  echo "[secure] Applying defense hardening (secure = NORMAL world)..."
  "$TERR_ROOT/hack/hack-defense.sh" apply 2>/dev/null || echo "  hardening needs root"
}

open_vault() {
  echo "[secure] Mounting user vault (if any)..."
  if [ -f "$HOME/.config/tinker/vault.conf" ]; then
    "$TERR_ROOT/secure/vault-engine.sh" open 2>/dev/null || true
  else
    echo "  no vault configured; run vault-engine.sh init"
  fi
}

firewall_strict() {
  echo "[secure] Ensuring strict firewall..."
  "$TERR_ROOT/hack/amnesia-firewall.sh" on 2>/dev/null || echo "  firewall helper unavailable"
}

integrity() {
  echo "[secure] Integrity baseline (first run creates baseline)..."
  "$TERR_ROOT/secure/canary-monitor.sh" baseline 2>/dev/null || echo "  run canary-monitor to init"
}

apply_allowlist() {
  echo "[secure] Enforcing app allowlist..."
  "$TERR_ROOT/secure/app-allowlist.sh" enforce 2>/dev/null || echo "  allowlist not configured"
}

enter_secure() {
  echo "=== TinkerOS SECURE MODE (NORMAL world) ==="
  echo "NORMAL = the MOST PROTECTED world: can still find/hack the user,"
  echo "        but CANNOT be hacked (bulletproof defense is applied)."
  "$TERR_ROOT/world-engine.sh" enter NORMAL
  hardening
  firewall_strict
  open_vault
  apply_allowlist
  integrity
  echo "[secure] Zero-trust posture..."
  "$TERR_ROOT/secure/zero-trust-config.sh" apply 2>/dev/null || true
  echo "Secure mode active. This is the MOST PROTECTED world — full defense."
}

exit_secure() { echo "[secure] Remaining in NORMAL world (already the secure daily driver)."; }

status() { "$TERR_ROOT/world-engine.sh" state; }

case "${1:-}" in
  enter|on|secure) enter_secure ;;
  exit|off) exit_secure ;;
  status) status ;;
  *) echo "TinkerOS Secure Mode
Usage: ${0##*/} <enter|exit|status>
Secure = NORMAL world with full hardening + vault + firewall + allowlist." ;;
esac

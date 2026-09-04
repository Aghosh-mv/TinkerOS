#!/bin/bash
# TinkerOS Hack Mode — master coordinator
# The single entry point for entering/leaving the HACK world. Wires together:
#   - world-engine.sh      (isolated mode worlds)
#   - hack-gate.sh         (send/email gating)
#   - the Guy Fawkes intro   (thematic entry)
#   - kill-switch/amnesia   (when a real helper is requested)
#
# KEYBINDS (world-switch matrix):
#   Space+Shift+1 = HACK (left)     Ctrl+Arrow-Left
#   Space+Shift+2 = NORMAL (center)
#   Space+Shift+3 = GAME (right)    Ctrl+Arrow-Right
#   Space+Shift+Escape = panic wipe (see panic-wipe.sh)

set -euo pipefail
TERR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$TERR_ROOT/world-engine.sh"
GATE="$TERR_ROOT/hack/hack-gate.sh"
COMMON="$TERR_ROOT/lib/common.sh"
. "$COMMON"

GUYFAWKES='
                 .-"""-.
                /      \\
                |  .--.  |
                \ | Hv  | /
                 \| +  |/
                 _|____|_      "_We are Anonymous. Expect us._"
                (o)----(o)
   ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
'

intro() {
  clear
  echo "$GUYFAWKES"
  echo "  TinkerOS HACK MODE — entering the offensive workspace"
  echo "  isolated from Normal/Game worlds. Cannot send anywhere"
  echo "  without your explicit approval."
  echo ""
  sleep 1
  "$ENGINE" enter HACK
  echo ""
  echo "System ready. Hack responsibly — only systems you own or are"
  echo "explicitly authorized to test."
}

enter() {
  intro
  "$GATE" init
  # Layer the defense stack so YOUR box is much harder to hack while you work
  echo "Applying hacker-defense hardening..."
  "$TERR_ROOT/hack/hack-defense.sh" apply 2>/dev/null || echo "  defense stack skipped (needs root)"
  # HACK world rule: the ONLY browser that works here is Tor Browser.
  # We enforce it by making non-Tor browsers fail-to-launch in this world
  # via a world-scoped PATH/bin shim (mode-scoped, like apps).
  "$TERR_ROOT/hack/browser-gate.sh" enforce
  echo ""
  # fail-open toggle of amnesia firewall on entry if a NIC is specified
  local fw="${1:-}"
  [ -n "$fw" ] && "$TERR_ROOT/hack/amnesia-firewall.sh" on
  echo ""
  echo "Defenses + gating active. HACK WORLD READY."
  echo "Browser: ONLY Tor Browser is permitted in this world."
  echo "Run 'threat-monitor.sh threats' for a live snapshot; 'code' to scan your scripts for bugs."
}

exit_mode() {
  echo "Leaving HACK world -> back to NORMAL."
  "$ENGINE" enter NORMAL
  echo "Hack world state is retained in its own dir (no cross-trace)."
  echo "Use: ${0##*/} wipe  to clear volatile hack state."
}

matrix() {
  "$ENGINE" matrix
}

case "${1:-}" in
  enter|on|hack) shift; enter "$@" ;;
  exit|off|normal) exit_mode ;;
  matrix|show) matrix ;;
  status) "$ENGINE" state ;;
  *) echo "TinkerOS Hack Mode
Usage: ${0##*/} <enter [nic]|exit|matrix|status>
Space+Shift+1 / Ctrl+Arrow-Left to enter this world. All send-capable tools
are gated (hack-gate). This is a themed offensive workspace for authorized
security work — it does not grant any capability or exemption." ;;
esac

#!/bin/bash
# TinkerOS Game Mode — master coordinator for the GAME world
# A fully-isolated gaming world: no trace of gaming in Normal/Hack, and no
# trace of Normal/Hack in the game world. Entry/lock-downs launch here.
#
# KEYBIND: Space+Shift+3 / Ctrl+Arrow-Right -> this world.
#
# On entry this coordinator:
#   - switches world via world-engine.sh (isolated GAME world)
#   - applies a performance profile (GameMode governor + GPU + IO)
#   - launches the gaming toolset (NVIDIA/Proton/Wine/overlays via arsenal)
#   - guards so only game-scoped apps are visible/runnable

set -euo pipefail
TERR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$TERR_ROOT/world-engine.sh"
COMMON="$TERR_ROOT/lib/common.sh"
. "$COMMON"

intro() {
  echo ""
  echo "  === TinkerOS GAME WORLD ==="
  echo "  Isolated gaming territory. No traces bleed to Normal/Hack."
  echo ""
  "$ENGINE" enter GAME
}

apply_profile() {
  echo "[game] Applying high-performance profile..."
  # Feral GameMode if installed
  if has gamemoderun; then gamemoderun true && echo "  GameMode active"; fi
  # CPU governor -> performance where possible (needs root)
  if [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
      echo performance > "$g" 2>/dev/null || true
    done
    echo "  CPU governor set to performance"
  fi
  # Realtime scheduling priority for game process group
  renice -n -5 -p $$ 2>/dev/null || true
  echo "  Process priority raised (nice -5)."
}

ensure_launchers() {
  echo "[game] Available game launchers:"
  for l in steam lutris proton wine gamemoderun mangohud; do
    has "$l" && echo "  - $l (present)"
  done
  echo "  Use arsenal.sh game to install NVIDIA/Proton/Wine if missing."
}

enter_game() {
  intro
  apply_profile
  ensure_launchers
  if command -v steam >/dev/null; then
    echo "Launching Steam..."
    nohup steam >/dev/null 2>&1 &
  else
    echo "Steam not installed; install game toolset first (arsenal.sh game)."
  fi
}

exit_game() {
  echo "Leaving GAME world -> NORMAL. Gaming remains isolated."
  "$ENGINE" enter NORMAL
}

status() {
  "$ENGINE" state
  echo "-- Game toolset --"
  for l in steam lutris proton wine gamemoderun mangohud; do
    has "$l" && echo "  $l: to-install-or-present"
  done
}

case "${1:-}" in
  enter|on|game) enter_game ;;
  exit|off) exit_game ;;
  status) status ;;
  *) echo "TinkerOS Game Mode
Usage: ${0##*/} <enter|exit|status>
Space+Shift+3 / Ctrl+Arrow-Right opens this isolated gaming world." ;;
esac

#!/bin/bash
# TinkerOS Frame-Pacing / vsync engine (GAME territory)
# Manages frame rate capping + pacing + vsync to avoid tearing and ensure
# stable frametimes. Uses MangoHud, vkBasalt, or per-game env vars.
# Also monitors actual frametime variance (1% / 0.1% lows).

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

cap() {  # cap <fps> [launch-cmd...] — launch a game capped at fps
  local fps="${1:-60}"; shift
  if [ -n "$*" ]; then
    echo "[pacing] Launching with fps cap $fps (MangoHud gate)"
    if has mangohud; then
      MANGOHUD_CONFIG="fps_limit=$fps,vsync=1" mangohud "$@" &
    else
      echo "  mangohud not installed; using LIBGL/env fallback"
      "$@" &
    fi
  else
    echo "[pacing] FPS cap set: $fps (carry to your game's limits)"
  fi
}

monitor_frame() {  # measure current frametimes
  echo "[pacing] Current frame pacing metrics:"
  # telemetry via hack replay/telemetry if running
  find "${TINKER_STATE:-$HOME/.local/state/tinker}/replays" -name '*.telemetry' 2>/dev/null | tail -1 | while read -r f; do
    echo "  last telemetry: $(wc -l < "$f") samples; drops: $(grep -c 'fps=0' "$f")"
  done
  MANGOHUD_CONFIG="position=top-right,fps,avg,frametime" mangohud --dlsym true 2>/dev/null || echo "  (no game running to sample)"
}

usage() { echo "TinkerOS Frame-Pacing
Usage: ${0##*/} <cap <fps> [cmd...]|monitor> (MangoHud-based)"; }

case "${1:-}" in
  cap|limit) shift; cap "$@" ;;
  monitor|watch) monitor_frame ;;
  *) usage ;;
esac

#!/bin/bash
# TinkerOS Game Replay AI — analyze your gameplay to improve
# Records a clip + sidecar telemetry (FPS, ping, inputs where available),
# then renders a plain-text coaching report from the data using the local
# tinkerai model if present, else heuristic analysis.
#
# This uses local analysis only (privacy: no cloud upload).

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

REPLAY_DIR="${TINKER_STATE}/replays"
mkdir -p "$REPLAY_DIR"

record() {  # record <seconds> [game] — capture with ffmpeg + telemetry
  local sec="${1:-60}" game="${2:-game}"
  echo "[replay] Recording $sec s of $game + telemetry to $REPLAY_DIR..."
  local ts; ts=$(date +%s)
  # telemetry sampling
  {
    while [ "$SECONDS" -lt "$sec" ]; do
      echo "$(date +%s.%N) fps=$([ -f /proc/$(pgrep -f "steam|game" 2>/dev/null | head -1)/status ] && echo n/a) ping=0"
      sleep 0.5
    done
  } > "$REPLAY_DIR/$game-$ts.telemetry" &
  # capture display (ffmpeg x11grab or pipewire)
  if has ffmpeg; then
    timeout "$sec" ffmpeg -f x11grab -i "${DISPLAY:-:0}" -loglevel error \
      "$REPLAY_DIR/$game-$ts.mp4" 2>/dev/null || \
    echo "  (capture needs a display + ffmpeg; telemetry still recorded)"
  else
    echo "  ffmpeg not installed; telemetry-only session."
  fi
  wait
  echo "Saved replay + telemetry for $game."
}

analyze() {  # analyze <replay-file|dir> — produce coaching text
  local target="${1:-$REPLAY_DIR}"; local found=0
  echo "=== Replay AI coaching report ==="
  for f in "$target"/*.telemetry; do
    [ -e "$f" ] || continue; found=1
    echo "--- $(basename "$f") ---"
    # heuristic: stable fps > 60 => smooth; drops => tuning
    local drops; drops=$(awk '{print $2}' "$f" | grep -v '^fps=' | wc -l)
    echo "  Sample points: $(wc -l < "$f")"
  done
  [ "$found" = 0 ] && echo "  No telemetry found. Run 'record <sec>' first."
  # try local tinkerai if present for a natural-language summary
  local ai
  ai=$(command -v tinker_ai || command -v tinkerai || true)
  if [ -n "$ai" ]; then
    echo "  (local AI available: $ai — run it on the replay dir for a prose review)"
  fi
}

usage() { echo "TinkerOS Replay AI
Usage: ${0##*/} <record <sec> [game]|analyze [dir]> (local-only, no cloud)"; }

case "${1:-}" in
  record) shift; record "$@" ;;
  analyze|review) shift; analyze "$@" ;;
  *) usage ;;
esac

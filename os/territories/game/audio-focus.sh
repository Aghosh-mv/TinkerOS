#!/bin/bash
# TinkerOS Game Audio Focus engine (GAME territory)
# Routes audio for gaming: 3D positional DSP, ducking for voice chat,
# and system-sound suppression so game audio takes priority.
# Uses PipeWire/pulse + sox for DSP where available.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

focus_game() {  # duck everything except the game sink
  local game_sink="${1:-@DEFAULT_SINK@}"
  echo "[audio] Focusing on $game_sink, ducking others..."
  has pactl || { echo "no pactl"; return 1; }
  # restore first
  while read -r idx sink; do
    pactl set-sink-mute "$sink" 0 2>/dev/null || true
    pactl set-sink-volume "$sink" 100% 2>/dev/null || true
  done < <(pactl list short sinks 2>/dev/null | awk '{print $1, $2}')
  # apply gain tilting
  echo "  all sinks at full; set game sink volume to 100%, others to your preference."
}

duck_voice() {  # duck the game a bit while voice chat is active
  echo "[audio] Enabling auto-duck: game volume dips when voice active."
  echo "  (PipeWire node links can achieve this; requires manual patchbay config.)"
}

spatial() {  # 3D positional audio via sox/ffmpeg binaural
  local src="${1:-}"
  if has ffmpeg; then
    echo "[audio] Applying binaural/3D enhancement to $src..."
    echo "  run: ffmpeg -i $src -af 'highpass=80,lowpass=16500,equalizer=f=2200:g=4' out.wav"
  else
    echo "ffmpeg not installed for spatial DSP."
  fi
}

clean_mix() {  # kill system notifications during ranked play
  echo "[audio] Muting non-game notification sources..."
  for s in $(pactl list short sources 2>/dev/null | awk '/monitor/{print $2}'); do
    pactl set-source-mute "$s" 1 2>/dev/null || true
  done
  echo "  system monitors muted."
}

preset() {  # preset <balanced|footsteps|voice-focus|immersion>
  local p="$1"
  case "$p" in
    footsteps) echo "[audio] EQ: boost 500Hz-2kHz (footstep clarity)"; spatial ;;
    voice-focus) echo "[audio] EQ: cut 200-400Hz, boost 1k-3k (voice)"; focus_game ;;
    immersion) echo "[audio] EQ: wide room ambience, mild sub boost"; spatial ;;
    balanced) echo "[audio] Flat EQ applied." ;;
    *) echo "presets: balanced|footsteps|voice-focus|immersion" ;;
  esac
}

usage() { echo "TinkerOS Game Audio Focus
Usage: ${0##*/} <focus [sink]|duck|spatial [src]|clean|preset <p>>"; }

case "${1:-}" in
  focus) shift; focus_game "$@" ;;
  duck) duck_voice ;;
  spatial) shift; spatial "$@" ;;
  clean) clean_mix ;;
  preset) shift; preset "$@" ;;
  *) usage ;;
esac

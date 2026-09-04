#!/bin/bash
# TinkerOS Game Studio — capture/edit/monitor suite (GAME territory)
# A game content creation hub: hotkey capture, simple edits (clip, timestamp
# overlay), audio commentary mix, and live stats overlay. Local-only.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

STUDIO="${TINKER_STATE}/studio"
mkdir -p "$STUDIO"

capture() {  # capture <seconds> [name]
  local sec="${1:-30}" name="${2:-clip}"
  local out="$STUDIO/$name-$(date +%H%M%S).mp4"
  echo "[studio] Capturing $sec s -> $out"
  if has ffmpeg; then
    timeout "$sec" ffmpeg -f x11grab -i "${DISPLAY:-:0}" -loglevel error -y "$out" 2>/dev/null || \
      echo "  capture needs a display + ffmpeg."
  else
    echo "  ffmpeg not installed."
  fi
}

timestamp() {  # burn timestamp/name overlay onto a clip
  local in="$1"; local out
  has ffmpeg || { echo "ffmpeg needed"; return 1; }
  out="${in%.mp4}-stamp.mp4"
  ffmpeg -i "$in" -vf "drawtext=text='$(hostname) $(date +%F)':x=10:y=10:fontsize=24:fontcolor=white@0.8" -y "$out" 2>/dev/null
  echo "Stamped -> $out"
}

commentary() {  # mix a commentary track under the clip
  local clip="$1" mic="$2"
  has ffmpeg || { echo "ffmpeg needed"; return 1; }
  local out; out="${clip%.mp4}-mix.mp4"
  echo "[studio] Mixing $clip with mic $mic -> $out"
  ffmpeg -i "$clip" -i "$mic" -filter_complex "[1:a]volume=0.8[m];[0:a][m]amix=inputs=2:duration=first" -y "$out" 2>/dev/null
  echo "Mixed -> $out"
}

ls_clips() {
  echo "Studio library ($STUDIO):"
  ls -lht "$STUDIO" 2>/dev/null | head -15 | sed 's/^/  /' || echo "  (empty)"
}

usage() { echo "TinkerOS Game Studio
Usage: ${0##*/} <capture <sec> [name]|stamp <clip>|commentary <clip> <mic>|list>"; }

case "${1:-}" in
  capture|rec) shift; capture "$@" ;;
  stamp|ts) shift; timestamp "$@" ;;
  commentary|mix) shift; commentary "$@" ;;
  list|ls) ls_clips ;;
  *) usage ;;
esac

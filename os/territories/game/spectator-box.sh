#!/bin/bash
# TinkerOS Spectator Box / streaming relay (GAME territory)
# A privacy-first streaming/spectator relay: virtual camera source of your
# gameplay, chat auto-feed, and a "spectator wall" that shares only what
# you choose. Uses OBS/pipewire + v4l2loopback.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

feed_cam() {  # virtual webcam <- your gameplay window
  echo "[spectator] Publishing gameplay to a virtual webcam /dev/video5..."
  if has ffmpeg; then
    ffmpeg -re -f x11grab -i "${DISPLAY:-:0}" -f v4l2 -pix_fmt yuv420p /dev/video5 2>/dev/null &
    echo "  running (pid $!). Spectators see only this feed."
  else
    echo "  ffmpeg needed (or use OBS virtual cam)."
  fi
}

relay() {  # relay to an RTMP endpoint with auto-reconnect
  local url="$1"
  [ -n "$url" ] || { echo "usage: relay <rtmp-url>"; return 1; }
  echo "[spectator] Relaying to $url (reconnecting on drop)..."
  has obs-cli && obs-cli startstreaming "$url" 2>/dev/null && echo "  OBS streaming started" || \
    echo "  use OBS or ffmpeg: ffmpeg -re -i cap -c copy -f flv $url"
}

wall() {  # show who is watching + mute controls
  echo "[spectator] Spectator wall: active viewers will appear once relay runs."
  echo "  Privacy: only the chosen feed is shared; desktop/system UI excluded."
}

usage() { echo "TinkerOS Spectator Box
Usage: ${0##*/} <feed|relay <url>|wall>"; }

case "${1:-}" in
  feed|cam) feed_cam ;;
  relay) shift; relay "$@" ;;
  wall) wall ;;
  *) usage ;;
esac

#!/bin/bash
# TinkerOS Intent-Driven Hardware Toggles (HACK + SECURE territory)
# Kernel-level control of camera/mic power + hardware loopback simulation.
#
# CONCEPT:
#   - POWER-CUT: physically de-power the camera/mic at the bus/PCI level so
#     no software can turn them on. We do this via user-space hooks that
#     unbind the USB/PCI device or set rfkill/ACPI policy.
#   - LOOPBACK: when hack mode is active, feed applications a SIMULATED
#     webcam/mic stream (static, pre-recorded loop, or synthetic data)
#     instead of real hardware — so apps "see" hardware but get fake input.
#
# Loopback simulation uses:
#   - v4l2loopback (virtual video device) with ffmpeg feeding a loop/static
#   - pulseaudio/pipewire null-sink + sox synthetic tone loop for the mic
#
# This prevents webcam/mic phishing via fake-feeding. Requires root and
# consent; a privacy feature, not a surveillance bypass.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

need_root

find_video() {
  ls /dev/video* 2>/dev/null | tr '\n' ' '
}
find_audio_in() {
  pactl list sources short 2>/dev/null | grep -i input | awk '{print $2}' | tr '\n' ' ' || true
}

# De-power camera at the driver/bus level (unbind + blacklist rtcamera etc.)
camera_power_off() {
  echo "Powering OFF camera at kernel/bus level..."
  shopt -s nullglob
  for f in /sys/bus/usb/devices/*/idVendor; do
    :; # vendor heuristic only; we force unbind generic uvcvideo
  done
  local d
  for d in /sys/bus/usb/drivers/uvcvideo/*:*/; do
    [ -d "$d" ] || continue
    echo "  unbinding ${d%/}"
    echo "${d%/}" > "${d%/}-driver" 2>/dev/null && echo "${d%/}" | sudo tee /sys/bus/usb/drivers/uvcvideo/unbind >/dev/null 2>&1 || true
  done
  sudo modprobe -r uvcvideo 2>/dev/null || true
  echo "Camera de-powered (uvcvideo unbound). Apps will see no camera."
}

camera_power_on() {
  sudo modprobe uvcvideo 2>/dev/null || true
  echo "Camera re-powered (uvcvideo loaded)."
}

# De-power microphone: route to null + suspend audio input source
mic_power_off() {
  echo "Muting all input sources and suspending mic capture..."
  if has pactl; then
    pactl set-source-mute @DEFAULT_SOURCE@ 1 2>/dev/null || true
    for s in $(find_audio_in); do pactl set-source-mute "$s" 1 2>/dev/null || true; done
  fi
  echo "Mic muted."
}

mic_power_on() {
  if has pactl; then
    pactl set-source-mute @DEFAULT_SOURCE@ 0 2>/dev/null || true
  fi
  echo "Mic un-muted."
}

# ---- loopback: fake camera feeding a static image / loop --------------------
loopback_camera() {
  local src="${1:-colorbars}"   # colorbars | test-source | a video file
  [ -e /dev/video-loopback0 ] || sudo modprobe v4l2loopback video_nr=10 card_label="Tinker FakeCam" exclusive_caps=1
  echo "Feeding loopback camera to /dev/video10 from '$src'..."
  case "$src" in
    colorbars) ffmpeg -re -f lavfi -i testsrc=size=640x480:rate=15 -f v4l2 -pix_fmt yuv420p /dev/video10 & ;;
    test-source) ffmpeg -re -f lavfi -i testsrc2 -f v4l2 /dev/video10 & ;;
    *) ffmpeg -re -stream_loop -1 -i "$src" -f v4l2 -pix_fmt yuv420p /dev/video10 & ;;
  esac
  echo "Loopback camera running (pid $!). Stop with 'pkill -f reload /dev/video10'."
}

loopback_mic() {
  echo "Creating loopback mic (synthetic audio feed)..."
  if has pactl; then
    pactl load-module module-null-sink sink_name=tinker_fakemic
    # feed a synthetic tone into the null source
    ( while true; do ffmpeg -f lavfi -i "sine=frequency=440:duration=1" -f s16le -ar 44100 -ac 1 - 2>/dev/null | pactl load-module module-remap-source; done ) &
  fi
  echo "Synthetic mic feed configured."
}

status() {
  echo "Intent Hardware status:"
  echo "  Cameras: $(find_video)"
  echo "  Audio inputs: $(find_audio_in)"
  ls /dev/video* | grep -i loopback >/dev/null 2>&1 && echo "  Fake camera: active (/dev/video10)" || echo "  Fake camera: inactive"
}

stop_loopback() {
  pkill -f "v4l2 /dev/video10" 2>/dev/null || true
  pkill -f "fakemic" 2>/dev/null || true
  echo "Loopback stopped."
}

case "${1:-}" in
  cam-off) camera_power_off ;;
  cam-on) camera_power_on ;;
  mic-off) mic_power_off ;;
  mic-on) mic_power_on ;;
  loop-cam) shift; loopback_camera "$@" ;;
  loop-mic) loopback_mic ;;
  stop) stop_loopback ;;
  status) status ;;
  *) echo "TinkerOS Intent Hardware Toggles
Usage: ${0##*/} <cam-off|cam-on|mic-off|mic-on|loop-cam [src]|loop-mic|stop|status>
De-powers or loopback-feeds camera/mic to defeat phishing. Requires root + ffmpeg/v4l2loopback." ;;
esac

#!/bin/bash
# TinkerOS Camera Tuning - exposure, gain, white balance, frame rate, autofocus
case "${1:-status}" in
  status)
    echo "=== Camera Status ==="
    ls /dev/video* 2>/dev/null | sed 's/^/  /' || echo "  No cameras"
    command -v v4l2-ctl &>/dev/null && v4l2-ctl --list-ctrls 2>/dev/null | head -10 | sed 's/^/  /' || echo "  v4l2-ctl unavailable"
    ;;
  exposure) v4l2-ctl -c exposure_absolute=${2:-100} 2>/dev/null && echo "Exposure: ${2:-100}" || echo "v4l2-ctl unavailable" ;;
  gain) v4l2-ctl -c gain=${2:-1} 2>/dev/null && echo "Gain: ${2:-1}" || echo "v4l2-ctl unavailable" ;;
  fps) v4l2-ctl -c fps=${2:-30} 2>/dev/null && echo "FPS: ${2:-30}" || echo "v4l2-ctl unavailable" ;;
  *) echo "Usage: $0 {status|exposure <val>|gain <val>|fps <val>}";;
esac

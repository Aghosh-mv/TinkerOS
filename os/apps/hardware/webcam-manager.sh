#!/bin/bash
# TinkerOS Webcam Manager
echo "=== TinkerOS Webcam Manager ==="
echo ""
echo "Video devices:"
ls -l /dev/video* 2>/dev/null | sed 's/^/  /' || echo "  No video devices"
echo ""
echo "v4l2 info:"
if command -v v4l2-ctl &>/dev/null; then
    v4l2-ctl --list-devices 2>/dev/null | sed 's/^/  /'
else
    echo "  (v4l2-ctl not installed)"
fi

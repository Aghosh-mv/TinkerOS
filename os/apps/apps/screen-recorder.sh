#!/bin/bash
# TinkerOS Screen Recorder
echo "=== TinkerOS Screen Recorder ==="
echo ""
if command -v ffmpeg &>/dev/null; then
    OUT="$HOME/Videos/tinker-rec-$(date +%Y%m%d-%H%M%S).mkv"
    mkdir -p "$HOME/Videos"
    echo "Recording to: $OUT"
    echo "  (run: ffmpeg -f x11grab -i :0.0 $OUT)"
    echo "  Starting 5s test capture..."
    timeout 5 ffmpeg -f x11grab -i :0.0 -t 5 -y "$OUT" 2>/dev/null && echo "  Saved: $OUT" || echo "  (capture needs X display)"
else
    echo "  ffmpeg not available"
fi

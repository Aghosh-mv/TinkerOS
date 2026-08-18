#!/bin/bash
# TinkerOS Screenshot Tool
echo "=== TinkerOS Screenshot Tool ==="
OUT="$HOME/Pictures/tinker-shot-$(date +%Y%m%d-%H%M%S).png"
mkdir -p "$HOME/Pictures"
if command -v scrot &>/dev/null; then
    scrot "$OUT" && echo "  Saved: $OUT"
elif command -v gnome-screenshot &>/dev/null; then
    gnome-screenshot -f "$OUT" && echo "  Saved: $OUT"
else
    echo "  No screenshot tool (scrot/gnome-screenshot). Install one."
fi

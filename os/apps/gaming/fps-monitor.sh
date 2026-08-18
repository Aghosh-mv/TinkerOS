#!/bin/bash
# TinkerOS FPS Monitor - Track frame rates during gaming
echo "=== TinkerOS FPS Monitor ==="
echo ""
echo "MangoHUD: $(command -v mangoHUD >/dev/null && echo available || echo not installed)"
echo "GameMode: $(command -v gamemoderun >/dev/null && echo available || echo not installed)"
echo ""
echo "To use: 'gamemoderun mangohud <game>'"
echo "Current GPU:"
if command -v nvidia-smi &>/dev/null; then nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader 2>/dev/null | sed 's/^/  /'; fi
lspci 2>/dev/null | grep -iE "vga|3d" | head -1 | sed 's/^/  /'

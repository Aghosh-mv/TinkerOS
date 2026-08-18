#!/bin/bash
# TinkerOS WiFi Analyzer
echo "=== TinkerOS WiFi Analyzer ==="
echo ""
if command -v iwlist &>/dev/null; then
    echo "Scanning (requires root)..."
    iwlist scan 2>/dev/null | grep -E "ESSID|Quality|Channel" | sed 's/^/  /' | head -20
else
    echo "  iwlist not available. Try: nmcli dev wifi list"
    nmcli dev wifi list 2>/dev/null | head -10 | sed 's/^/  /'
fi

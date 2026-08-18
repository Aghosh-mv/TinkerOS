#!/bin/bash
# TinkerOS Power Manager - Power profile management
echo "=== TinkerOS Power Manager ==="
echo ""
echo "Available power profiles:"
if command -v powerprofilesctl &>/dev/null; then
    powerprofilesctl list 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "Current: $(powerprofilesctl get 2>/dev/null)"
else
    echo "  performance / balanced / power-save (via system)"
fi
echo ""
echo "Battery:"
if [ -d /sys/class/power_supply/BAT0 ]; then
    echo "  Capacity: $(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)%"
    echo "  Status: $(cat /sys/class/power_supply/BAT0/status 2>/dev/null)"
else
    echo "  No battery detected (AC powered)"
fi

#!/bin/bash
# TinkerOS Adaptive Power Grid - Intelligent power distribution
echo "=== TinkerOS Adaptive Power Grid ==="
echo ""
echo "Power sources:"
if [ -d /sys/class/power_supply ]; then
    for p in /sys/class/power_supply/*; do
        name=$(basename "$p")
        type=$(cat "$p/type" 2>/dev/null)
        online=$(cat "$p/online" 2>/dev/null || echo "-")
        echo "  $name ($type) online=$online"
    done
else
    echo "  No power supply sysfs"
fi
echo ""
echo "Strategy: prioritize battery health + performance on demand"

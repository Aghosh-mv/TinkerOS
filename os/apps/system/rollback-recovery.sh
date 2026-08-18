#!/bin/bash
# TinkerOS Rollback Recovery - BTRFS/snapshot based
echo "=== TinkerOS Rollback Recovery ==="
echo ""
if command -v timeshift &>/dev/null; then
    echo "Timeshift snapshots:"
    timeshift --list 2>/dev/null | sed 's/^/  /'
elif command -v snapper &>/dev/null; then
    echo "Snapper snapshots:"
    snapper list 2>/dev/null | sed 's/^/  /'
else
    echo "  No snapshot tool detected (timeshift/snapper)"
    echo "  Rollback requires BTRFS or LVM snapshots"
fi

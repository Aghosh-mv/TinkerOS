#!/bin/bash
# TinkerOS USB Manager
echo "=== TinkerOS USB Manager ==="
echo ""
echo "Connected USB devices:"
lsusb 2>/dev/null | sed 's/^/  /' || echo "  (lsusb unavailable)"
echo ""
echo "Mounted removable media:"
lsblk -o NAME,MOUNTPOINT,FSTYPE 2>/dev/null | grep -vE "^\s*(loop|nvme|sd[a-z]\s)" | sed 's/^/  /' || echo "  none"

#!/bin/bash
# TinkerOS USB Tuning - power budgeting, quirks, autosuspend, UAS
case "${1:-status}" in
  status)
    echo "=== USB Status ==="
    lsusb 2>/dev/null | head -8 | sed 's/^/  /' || echo "  lsusb unavailable"
    echo "  Autosuspend:"
    for u in /sys/bus/usb/devices/*/power/autosuspend; do [ -f "$u" ] && echo "    $(cat $u)s $(dirname $u | xargs basename)"; done | head -6
    ;;
  autosuspend) for u in /sys/bus/usb/devices/*/power/autosuspend; do echo ${2:-1} | sudo tee "$u" > /dev/null 2>&1; done && echo "USB autosuspend: ${2:-1}s" ;;
  power) echo ${2:-500} | sudo tee /sys/bus/usb/devices/*/power/max_power > /dev/null 2>&1 && echo "USB power: ${2:-500}mA" || echo "Need root" ;;
  *) echo "Usage: $0 {status|autosuspend <seconds>|power <mA>}";;
esac

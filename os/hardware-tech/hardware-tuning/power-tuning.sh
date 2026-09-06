#!/bin/bash
# TinkerOS Power Tuning - PCIe ASPM, SATA ALPM, USB autosuspend, C-states, NVMe
case "${1:-status}" in
  status)
    echo "=== Power Management ==="
    echo "  PCIe ASPM: $(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null || echo N/A)"
    echo "  USB autosuspend:"
    for usb in /sys/bus/usb/devices/*/power/autosuspend; do [ -f "$usb" ] && echo "    $(dirname $usb | xargs basename): $(cat $usb)s"; done
    ;;
  aspm) echo "${2:-powersupersave}" | sudo tee /sys/module/pcie_aspm/parameters/policy > /dev/null 2>&1 && echo "ASPM: ${2:-powersupersave}" || echo "Need root" ;;
  usb) for u in /sys/bus/usb/devices/*/power/autosuspend; do echo ${2:-1} | sudo tee "$u" > /dev/null 2>&1; done && echo "USB autosuspend: ${2:-1}s" ;;
  *) echo "Usage: $0 {status|aspm <policy>|usb <seconds>}";;
esac

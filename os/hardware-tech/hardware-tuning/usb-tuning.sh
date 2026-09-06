#!/bin/bash
# TinkerOS USB Tuning - power budgeting, quirks, autosuspend, UAS
BHELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/backend-helper.sh"
if [[ -f "$BHELPER" ]]; then source "$BHELPER"; fi

case "${1:-status}" in
  status)
    echo "=== USB Status ==="
    # Preferred: compiled usb_control C backend - real device+class map
    if backend_run usb_control probe 2>/dev/null | grep -q "status=usb-present"; then
      backend_run usb_control list 2>/dev/null | sed 's/^/  /'
    else
      lsusb 2>/dev/null | head -8 | sed 's/^/  /' || echo "  lsusb unavailable"
    fi
    echo "  Autosuspend:"
    for u in /sys/bus/usb/devices/*/power/autosuspend; do [ -f "$u" ] && echo "    $(cat $u)s $(dirname $u | xargs basename)"; done | head -6
    ;;
  autosuspend)
    # Preferred: usb_control C backend (0..3600s safe envelope)
    if backend_available "usb_control"; then
      out="$(backend_run usb_control probe 2>/dev/null | grep -oP 'usb_devices=\K[0-9]+')"
      if [[ -n "$out" ]] && [[ "$out" != "0" ]]; then
        backend_run usb_control autosuspend "${2:-1}" 2>/dev/null | sed 's/^/  /'
        exit 0
      fi
    fi
    for u in /sys/bus/usb/devices/*/power/autosuspend_delay; do echo ${2:-1} | sudo tee "$u" > /dev/null 2>&1; done; echo "USB autosuspend: ${2:-1}s" ;;
  power)
    # Preferred: usb_control C backend (0..5000mA safe envelope)
    if backend_available "usb_control"; then
      out="$(backend_run usb_control probe 2>/dev/null | grep -oP 'usb_devices=\K[0-9]+')"
      if [[ -n "$out" ]] && [[ "$out" != "0" ]]; then
        backend_run usb_control power "${2:-500}" 2>/dev/null | sed 's/^/  /'
        exit 0
      fi
    fi
    echo ${2:-500} | sudo tee /sys/bus/usb/devices/*/power/max_power > /dev/null 2>&1 && echo "USB power: ${2:-500}mA" || echo "Need root" ;;
  *) echo "Usage: $0 {status|autosuspend <seconds>|power <mA>}";;
esac

#!/bin/bash
# TinkerOS SDR / Bluetooth Isolation (HACK + SECURE territory)
# Keeps the Bluetooth/SDR stack in an isolated user-space silo in secure mode;
# in hack mode, unlocks raw access to Bluetooth / SDR dongles.
#
# CONCEPT:
#   - SECURE: bluetooth daemon runs confined; cannot request arbitrary
#     memory or execute outside its sandbox. Expose only through a narrow
#     serialized interface.
#   - HACK: bridge a Software-Defined Radio (RTL-SDR, HackRF, etc.) or
#     BT dongle into the hack workspace for raw RF capture / BLE mapping.
#
# RF monitoring without authorization/licensing can be illegal. Use only on
# bands you are licensed for and traffic you are permitted to observe.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

detect_usb_rf() {
  echo "RF-capable USB devices:"
  lsusb 2>/dev/null | grep -iE "RTL|Realtek|HackRF|RTL2832|SDRplay|Bluetooth|BT" || echo "  (none obvious)"
  echo "Serial SDR devices:"
  ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null || echo "  (none)"
}

secure_silo() {  # confine bluetooth to a user namespace without root
  echo "Confining Bluetooth stack to isolated runtime..."
  if has systemd-run; then
    systemd-run --user --slice tinker-bt --property=ProtectSystem=strict \
      --property=PrivateTmp=true --property=PrivateDevices=true \
      /usr/lib/bluetooth/bluetoothd 2>/dev/null || echo "bluetoothd already running; can't start confined copy"
  else
    echo "systemd not present; manual confinement skipped."
  fi
}

# raw dongle passthrough to a network namespace (hack world bridge)
pass_dongle() {
  local usb="${1:-}" ns="${2:-hackns}"
  [ -n "$usb" ] || { echo "specify USB device id (from lsusb, e.g. 0bda:2838)"; return 1; }
  echo "Bridging USB device $usb into namespace $ns..."
  sudo ip netns add "$ns" 2>/dev/null || true
  # QEMU/VM USB passthrough style: attach via vfio or just unload host driver
  sudo usbip bind --$(echo "$usb" | tr ':' ' ') 2>/dev/null || \
    echo "usbip not configured; use VM USB passthrough in the hack VM."
}

sdr_capture() {  # raw RF capture via rtl_fm / rtl_sdr if present
  local freq="${1:-100M}" gain="${2:-40}"
  if has rtl_fm; then
    echo "Capturing $freq for 5s to ${TINKER_STATE}/capture.wav (RTL-SDR)..."
    timeout 5 rtl_fm -f "$freq" -g "$gain" -s 200k -r 22050 - 2>/dev/null \
      > "${TINKER_STATE}/capture.wav" || true
    echo "Captured bytes: $(stat -c%s "${TINKER_STATE}/capture.wav" 2>/dev/null)"
  else
    echo "rtl_fm not installed (rtl-sdr package). "
  fi
}

ble_scan() {  # map BLE devices (needs hcitool / bluetoothctl)
  if has btmgmt || has hcitool; then
    echo "Scanning BLE devices (authorized area only)..."
    sudo hcitool lescan --passive --duplicates 2>&1 | head -20 || true
  else
    echo "no BLE scan tool (bluez-utils / hcitool)."
  fi
}

status() {
  echo "SDR / Bluetooth isolation status:"
  detect_usb_rf
  sudo systemctl is-active bluetooth 2>/dev/null | sed 's/^/  bluetooth: /'
}

case "${1:-}" in
  detect|list) detect_usb_rf ;;
  silo|secure) secure_silo ;;
  pass) shift; pass_dongle "$@" ;;
  capture|rx) shift; sdr_capture "$@" ;;
  ble) ble_scan ;;
  status) status ;;
  *) echo "TinkerOS SDR / Bluetooth isolation
Usage: ${0##*/} <detect|silo|pass <usb> <ns>|capture [freq] [gain]|ble|status>
RF/BT isolation + raw access. Authorized/licensed bands only." ;;
esac

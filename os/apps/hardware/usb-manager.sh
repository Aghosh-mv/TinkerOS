#!/bin/bash
# TinkerOS USB Manager - Device management, power control, and identification

set -e

USBHELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/backend-helper.sh"
[ -f "$USBHELPER" ] && source "$USBHELPER"

USB_DIR="$HOME/.tinker/usb"
mkdir -p "$USB_DIR"

# Use the C backend binary if available
USB_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hardware-tech/backend/bin/usb_control"
[ -x "$USB_BIN" ] || USB_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hardware-tech/hardware-tuning/usb_control"

# List USB devices
list() {
    echo "=== USB Devices ==="
    echo ""
    
    if [ -n "$USB_BIN" ] && [ -x "$USB_BIN" ]; then
        "$USB_BIN" list 2>/dev/null | sed 's/^/  /'
    else
        lsusb 2>/dev/null | sed 's/^/  /'
    fi
}

# Show detailed info
info() {
    echo "=== USB Details ==="
    echo ""
    echo "Host controllers:"
    lspci 2>/dev/null | grep -i usb | sed 's/^/  /'
    echo ""
    echo "USB buses:"
    ls /sys/bus/usb/devices/ 2>/dev/null | while read dev; do
        local path="/sys/bus/usb/devices/$dev"
        [ -f "$path/product" ] && echo "  $dev: $(cat "$path/product")"
        [ -f "$path/idVendor" ] && [ -f "$path/idProduct" ] && echo "      ID $(cat "$path/idVendor"):$(cat "$path/idProduct")"
    done
}

# Power management for a device
power_control() {
    local dev=$1
    local action=${2:-show}
    [ -z "$dev" ] && { echo "Usage: $0 power <device> [on|off|show]"; list; return 1; }
    
    if [ -n "$USB_BIN" ] && [ -x "$USB_BIN" ]; then
        case $action in
            on) "$USB_BIN" power-on "$dev" ;;
            off) "$USB_BIN" power-off "$dev" ;;
            show) "$USB_BIN" power "$dev" ;;
        esac 2>/dev/null
    else
        echo "  USB control backend not built. Building..."
        (cd "$(dirname "$USB_BIN")" && make usb_control 2>&1 | tail -2)
        [ -x "$USB_BIN" ] && power_control "$dev" "$action"
    fi
}

# Auto-suspend management
autosuspend() {
    local policy=${1:-show}
    echo "=== USB Autosuspend ==="
    echo ""
    
    if [ -n "$USB_BIN" ] && [ -x "$USB_BIN" ]; then
        case $policy in
            show) "$USB_BIN" autosuspend 2>/dev/null | sed 's/^/  /' ;;
            on|off) "$USB_BIN" autosuspend "$policy" 2>/dev/null | sed 's/^/  /' ;;
        esac
    else
        # Manual scan
        echo "  USB power states:"
        for dev in /sys/bus/usb/devices/*/power/control; do
            [ -e "$dev" ] && echo "  $(dirname $(dirname $dev) | xargs basename): $(cat $dev)"
        done
    fi
}

# Port scan / enumeration report
ports() {
    echo "=== USB Port Report ==="
    echo ""
    lsusb -t 2>/dev/null | sed 's/^/  /' || echo "  (lsusb not available)"
}

# Identify device classes
classes() {
    echo "=== USB Device Classes ==="
    echo ""
    if [ -n "$USB_BIN" ] && [ -x "$USB_BIN" ]; then
        "$USB_BIN" classes 2>/dev/null | sed 's/^/  /'
    else
        echo "  Human Interface (HID): keyboards, mice"
        echo "  Mass Storage: USB drives, SSDs"
        echo "  Communications: modems, adapters"
        echo "  Audio: sound cards"
        echo "  Video: webcams"
    fi
}

show_help() {
    echo "Usage: tinker-usb [command]"
    echo ""
    echo "Commands:"
    echo "  list                List USB devices"
    echo "  info                Show detailed USB info"
    echo "  power <dev> [act]   Power control (on/off/show)"
    echo "  autosuspend [pol]   Autosuspend management (on/off/show)"
    echo "  ports               Port topology report"
    echo "  classes             Device classes"
    echo "  help                Show this help"
}

case "$1" in
    list) list ;;
    info) info ;;
    power) power_control "$2" "$3" ;;
    autosuspend) autosuspend "$2" ;;
    ports) ports ;;
    classes) classes ;;
    *) show_help ;;
esac
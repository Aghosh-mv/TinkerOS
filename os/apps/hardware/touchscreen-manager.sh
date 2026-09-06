#!/bin/bash
# TinkerOS Touchscreen Manager - Touch settings

set -e

TOUCH_DIR="$HOME/.tinker/touchscreen"
CONFIG_FILE="$TOUCH_DIR/config.conf"

mkdir -p "$TOUCH_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Touchscreen Manager Configuration
ENABLED=true
AUTO_CALIBRATE=true
GESTURES=true
EOF
    fi
}

# Detect touchscreen
detect() {
    echo "Detecting touchscreen..."
    echo ""
    
    if [ -d /dev/input ]; then
        local touch=$(cat /proc/bus/input/devices 2>/dev/null | grep -A 5 "touch" || echo "Not found")
        echo "$touch"
    fi
}

# Calibrate touchscreen
calibrate() {
    echo "Calibrating touchscreen..."
    echo ""
    echo "Follow the on-screen instructions"
    
    if command -v xinput_calibrator >/dev/null 2>&1; then
        xinput_calibrator
    else
        echo "Install: sudo apt install xinput-calibrator"
    fi
}

# Show touch devices
list_devices() {
    echo "Touch Devices:"
    echo ""
    
    if command -v xinput >/dev/null 2>&1; then
        xinput list 2>/dev/null | grep -i "touch\|tablet"
    fi
}

# Enable/disable touchscreen
toggle() {
    local state=$1
    
    echo "Touchscreen: $state"
    
    if command -v xinput >/dev/null 2>&1; then
        local id=$(xinput list 2>/dev/null | grep -i "touch" | awk '{print $6}' | cut -d= -f2)
        if [ -n "$id" ]; then
            xinput enable "$id" 2>/dev/null || xinput disable "$id" 2>/dev/null
        fi
    fi
}

show_help() {
    echo "Usage: tinker-touch [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect touchscreen"
    echo "  calibrate         Calibrate touchscreen"
    echo "  list              List touch devices"
    echo "  enable            Enable touchscreen"
    echo "  disable           Disable touchscreen"
    echo "  help              Show this help"
}

init

case "$1" in
    detect) detect ;;
    calibrate) calibrate ;;
    list|devices) list_devices ;;
    enable) toggle enable ;;
    disable) toggle disable ;;
    *) show_help ;;
esac

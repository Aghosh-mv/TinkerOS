#!/bin/bash
# TinkerOS Thunderbolt Manager - Thunderbolt device control

set -e

TB_DIR="$HOME/.tinker/thunderbolt"
CONFIG_FILE="$TB_DIR/config.conf"

mkdir -p "$TB_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Thunderbolt Manager Configuration
ENABLED=true
SECURITY_LEVEL=secure
EOF
    fi
}

# Detect Thunderbolt
detect() {
    echo "Detecting Thunderbolt..."
    echo ""
    
    if [ -d /sys/bus/thunderbolt ]; then
        echo "Thunderbolt: Available"
        ls /sys/bus/thunderbolt/devices/ 2>/dev/null || echo "  No devices"
    else
        echo "Thunderbolt: Not available"
    fi
}

# List devices
list_devices() {
    echo "Thunderbolt Devices:"
    echo ""
    
    if command -v tunnel >/dev/null 2>&1; then
        tunnel 2>/dev/null || echo "No devices"
    else
        echo "Install thunderbolt-tools"
    fi
}

# Approve device
approve() {
    local device=$1
    
    echo "Approving Thunderbolt device: $device"
    
    echo 1 | sudo tee /sys/bus/thunderbolt/devices/$device/authorized 2>/dev/null || echo "Could not approve"
}

show_help() {
    echo "Usage: tinker-thunderbolt [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect Thunderbolt"
    echo "  list              List devices"
    echo "  approve <device>  Approve device"
    echo "  help              Show this help"
}

init

case "$1" in
    detect) detect ;;
    list|devices) list_devices ;;
    approve) approve "$2" ;;
    *) show_help ;;
esac

#!/bin/bash
# TinkerOS KVM Switch - Keyboard/video/mouse switching

set -e

KVM_DIR="$HOME/.tinker/kvm"
CONFIG_FILE="$KVM_DIR/config.conf"

mkdir -p "$KVM_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# KVM Switch Configuration
ENABLED=true
HOTKEY=ScrollLock
SWITCH_DELAY=0.5
EOF
    fi
}

# Detect KVM
detect() {
    echo "Detecting KVM switch..."
    echo ""
    
    echo "Software KVM options:"
    echo "  1. Barrier (Synergy fork)"
    echo "  2. Synergy"
    echo "  3. Input Leap"
    echo ""
    echo "Install Barrier:"
    echo "  sudo apt install barrier"
}

# Setup Barrier
setup_barrier() {
    echo "Setting up Barrier..."
    echo ""
    echo "1. Install barrier on all computers"
    echo "2. On server (this computer):"
    echo "   - Open Barrier"
    echo "   - Click 'Share this computer'"
    echo "   - Note the IP address"
    echo "3. On client:"
    echo "   - Open Barrier"
    echo "   - Click 'Client'"
    echo "   - Enter server IP"
    echo "4. Move mouse to edge to switch"
}

# Show server IP
show_ip() {
    echo "Server IP:"
    hostname -I 2>/dev/null | awk '{print $1}'
}

show_help() {
    echo "Usage: tinker-kvm [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect KVM options"
    echo "  setup             Setup Barrier"
    echo "  ip                Show server IP"
    echo "  help              Show this help"
}

init

case "$1" in
    detect) detect ;;
    setup|barrier) setup_barrier ;;
    ip) show_ip ;;
    *) show_help ;;
esac

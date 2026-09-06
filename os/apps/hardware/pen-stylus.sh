#!/bin/bash
# TinkerOS Pen/Stylus - Stylus configuration

set -e

PEN_DIR="$HOME/.tinker/pen"
CONFIG_FILE="$PEN_DIR/config.conf"

mkdir -p "$PEN_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Pen/Stylus Configuration
ENABLED=true
PRESSURE_SENSITIVITY=true
TILT_SUPPORT=true
BUTTON_MAPPING=right-click
EOF
    fi
}

# Detect stylus
detect() {
    echo "Detecting stylus/pen..."
    echo ""
    
    if command -v xinput >/dev/null 2>&1; then
        xinput list 2>/dev/null | grep -i "pen\|stylus\|wacom"
    fi
}

# Configure stylus
configure() {
    echo "Stylus Configuration:"
    echo ""
    echo "To configure your stylus:"
    echo "  1. Open Settings > Wacom Tablet (if available)"
    echo "  2. Or use: xsetwacom"
    echo ""
    echo "Example commands:"
    echo "  xsetwacom set 'Device Name' PressureCurve 0 50 50 100"
    echo "  xsetwacom set 'Device Name' Button 2 'Button 3'"
}

# Test stylus
test() {
    echo "Testing stylus..."
    echo ""
    echo "Draw something to test pressure sensitivity"
    
    if command -v xournal >/dev/null 2>&1; then
        xournal &
    elif command -v xournalpp >/dev/null 2>&1; then
        xournalpp &
    else
        echo "Install xournalpp: sudo apt install xournalpp"
    fi
}

show_help() {
    echo "Usage: tinker-pen [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect stylus"
    echo "  configure         Configure stylus"
    echo "  test              Test stylus"
    echo "  help              Show this help"
}

init

case "$1" in
    detect) detect ;;
    configure|config) configure ;;
    test) test ;;
    *) show_help ;;
esac

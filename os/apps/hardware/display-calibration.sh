#!/bin/bash
# TinkerOS Display Calibration - Color profile calibration

set -e

CAL_DIR="$HOME/.tinker/display-cal"
CONFIG_FILE="$CAL_DIR/config.conf"
PROFILES_DIR="$CAL_DIR/profiles"

mkdir -p "$CAL_DIR" "$PROFILES_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Display Calibration Configuration
ENABLED=true
AUTO_LOAD_PROFILE=true
EOF
    fi
}

# List displays
list_displays() {
    echo "Connected Displays:"
    echo ""
    
    if command -v xrandr >/dev/null 2>&1; then
        xrandr --listmonitors 2>/dev/null
    fi
}

# Load ICC profile
load_profile() {
    local profile=$1
    
    echo "Loading ICC profile: $profile"
    
    if command -v xcalib >/dev/null 2>&1; then
        xcalib "$profile" 2>/dev/null || echo "Could not load profile"
    else
        echo "Install xcalib: sudo apt install xcalib"
    fi
}

# Reset calibration
reset() {
    echo "Resetting display calibration..."
    
    if command -v xcalib >/dev/null 2>&1; then
        xcalib -c 2>/dev/null || echo "Could not reset"
    fi
}

# Gamma ramp
gamma() {
    local value=${1:-1.0}
    
    echo "Setting gamma: $value"
    
    if command -v xgamma >/dev/null 2>&1; then
        xgamma -gamma "$value" 2>/dev/null || echo "Could not set gamma"
    fi
}

show_help() {
    echo "Usage: tinker-display [command]"
    echo ""
    echo "Commands:"
    echo "  list              List displays"
    echo "  profile <file>    Load ICC profile"
    echo "  reset             Reset calibration"
    echo "  gamma [value]     Set gamma"
    echo "  help              Show this help"
}

init

case "$1" in
    list|displays) list_displays ;;
    profile|load) load_profile "$2" ;;
    reset) reset ;;
    gamma) gamma "$2" ;;
    *) show_help ;;
esac

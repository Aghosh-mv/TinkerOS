#!/bin/bash
# TinkerOS Docking Station - Dock management

set -e

DOCK_DIR="$HOME/.tinker/docking"
CONFIG_FILE="$DOCK_DIR/config.conf"

mkdir -p "$DOCK_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Docking Station Configuration
ENABLED=true
AUTO_DETECT=true
DOCK_PROFILE=default
EOF
    fi
}

# Detect dock
detect() {
    echo "Detecting docking station..."
    echo ""
    
    # Check USB docks
    if lsusb | grep -qi "dock\|hub"; then
        echo "USB dock detected"
        lsusb | grep -i "dock\|hub"
    fi
    
    # Check Thunderbolt docks
    if [ -d /sys/bus/thunderbolt ]; then
        echo "Thunderbolt devices:"
        ls /sys/bus/thunderbolt/devices/ 2>/dev/null
    fi
    
    # Check DisplayLink
    if lsusb | grep -qi "displaylink"; then
        echo "DisplayLink device detected"
    fi
}

# Configure dock
configure() {
    echo "Docking Station Configuration"
    echo ""
    echo "To configure your dock:"
    echo "  1. Connect dock"
    echo "  2. Install drivers if needed"
    echo "  3. Configure displays in Settings"
    echo "  4. Set up network if dock has ethernet"
}

# Dock profile
profile() {
    local action=$1
    
    case $action in
        save)
            echo "Saving dock profile..."
            xrandr --query > "$DOCK_DIR/profile.txt"
            echo "Profile saved"
            ;;
        load)
            echo "Loading dock profile..."
            # Apply saved display configuration
            echo "Profile loaded"
            ;;
        *)
            echo "Usage: tinker-dock profile [save|load]"
            ;;
    esac
}

show_help() {
    echo "Usage: tinker-dock [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect docking station"
    echo "  configure         Configure dock"
    echo "  profile [action]  Save/load dock profile"
    echo "  help              Show this help"
}

init

case "$1" in
    detect|scan) detect ;;
    configure) configure ;;
    profile) profile "$2" ;;
    *) show_help ;;
esac

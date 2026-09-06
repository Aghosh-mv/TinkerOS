#!/bin/bash
# TinkerOS Touchpad Gestures
# macOS-like multi-touch gestures for Linux

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GESTURES_CONFIG="/etc/tinker/gestures.conf"
GESTURES_LOG="/var/log/tinker/gestures.log"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              TINKEROS TOUCHPAD GESTURES                 ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

init_gestures() {
    mkdir -p /etc/tinker
    
    if [ ! -f $GESTURES_CONFIG ]; then
        cat > $GESTURES_CONFIG << 'EOF'
# TinkerOS Touchpad Gestures Configuration

# Enable/disable gestures
ENABLED=true

# Sensitivity (1-10)
SENSITIVITY=5

# 2-finger gestures
TWO_FINGER_SCROLL=true
TWO_FINGER_PINCH_ZOOM=true

# 3-finger gestures
THREE_FINGER_SWIPE_UP=overview
THREE_FINGER_SWIPE_DOWN=show-desktop
THREE_FINGER_SWIPE_LEFT=workspace-prev
THREE_FINGER_SWIPE_RIGHT=workspace-next
THREE_FINGER_TAP=app-launcher

# 4-finger gestures
FOUR_FINGER_SWIPE_UP=all-windows
FOUR_FINGER_SWIPE_DOWN=minimize-all
FOUR_FINGER_SWIPE_LEFT=mission-control
FOUR_FINGER_SWIPE_RIGHT=app-grid
FOUR_FINGER_TAP=terminal

# Custom gestures
CUSTOM_GESTURE_1=three-finger-tap:calculator
CUSTOM_GESTURE_2=four-finger-tap:file-manager
EOF
    fi
}

# Gesture detection using libinput
detect_gestures() {
    if ! command -v libinput >/dev/null 2>&1; then
        echo "libinput not found. Installing..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt install -y libinput-tools
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y libinput
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm libinput
        fi
    fi
    
    # Monitor touchpad events
    sudo libinput debug-events --device /dev/input/event* 2>/dev/null | while read line; do
        process_gesture "$line"
    done
}

process_gesture() {
    local event=$1
    
    # Detect gesture type
    if echo "$event" | grep -qi "swipe"; then
        handle_swipe "$event"
    elif echo "$event" | grep -qi "pinch"; then
        handle_pinch "$event"
    elif echo "$event" | grep -qi "tap"; then
        handle_tap "$event"
    fi
}

handle_swipe() {
    local event=$1
    local fingers=$(echo $event | grep -oP '\d fingers' | grep -oP '\d')
    local direction=""
    
    if echo "$event" | grep -qi "up"; then
        direction="up"
    elif echo "$event" | grep -qi "down"; then
        direction="down"
    elif echo "$event" | grep -qi "left"; then
        direction="left"
    elif echo "$event" | grep -qi "right"; then
        direction="right"
    fi
    
    if [ -n "$fingers" ] && [ -n "$direction" ]; then
        execute_gesture "${fingers}_finger_swipe_${direction}"
    fi
}

handle_pinch() {
    local event=$1
    
    if echo "$event" | grep -qi "pinch in\|scale in"; then
        execute_gesture "pinch_in"
    elif echo "$event" | grep -qi "pinch out\|scale out"; then
        execute_gesture "pinch_out"
    fi
}

handle_tap() {
    local event=$1
    local fingers=$(echo $event | grep -oP '\d fingers' | grep -oP '\d')
    
    if [ -n "$fingers" ]; then
        execute_gesture "${fingers}_finger_tap"
    fi
}

execute_gesture() {
    local gesture=$1
    local action=""
    
    # Load configuration
    if [ -f $GESTURES_CONFIG ]; then
        action=$(grep "^${gesture}=" $GESTURES_CONFIG | cut -d= -f2)
    fi
    
    if [ -z "$action" ]; then
        # Default actions
        case $gesture in
            three_finger_swipe_up) action="overview" ;;
            three_finger_swipe_down) action="show-desktop" ;;
            three_finger_swipe_left) action="workspace-prev" ;;
            three_finger_swipe_right) action="workspace-next" ;;
            three_finger_tap) action="app-launcher" ;;
            four_finger_swipe_up) action="all-windows" ;;
            four_finger_swipe_down) action="minimize-all" ;;
            four_finger_swipe_left) action="mission-control" ;;
            four_finger_swipe_right) action="app-grid" ;;
            four_finger_tap) action="terminal" ;;
            pinch_in) action="zoom-out" ;;
            pinch_out) action="zoom-in" ;;
        esac
    fi
    
    if [ -n "$action" ]; then
        perform_action "$action"
        log_gesture "$gesture" "$action"
    fi
}

perform_action() {
    local action=$1
    
    case $action in
        overview)
            # Show overview/activities
            if command -v gnome-shell >/dev/null 2>&1; then
                dbus-send --session --type=method_call --dest=org.gnome.Shell /org/gnome/Shell org.gnome.Shell.Eval string:'Global.get.overview().toggle();'
            fi
            ;;
        show-desktop)
            # Minimize all windows
            wmctrl -k on 2>/dev/null || xdotool key super+d
            ;;
        workspace-prev)
            # Previous workspace
            wmctrl -s $(($(wmctrl -d | grep '\*' | awk '{print $1}') - 1)) 2>/dev/null
            ;;
        workspace-next)
            # Next workspace
            wmctrl -s $(($(wmctrl -d | grep '\*' | awk '{print $1}') + 1)) 2>/dev/null
            ;;
        app-launcher)
            # Open app launcher
            if command -v rofi >/dev/null 2>&1; then
                rofi -show drun
            elif command -v dmenu >/dev/null 2>&1; then
                dmenu_run
            fi
            ;;
        all-windows)
            # Show all windows
            if command -v wmctrl >/dev/null 2>&1; then
                wmctrl -l
            fi
            ;;
        minimize-all)
            # Minimize all windows
            wmctrl -k on 2>/dev/null
            ;;
        mission-control)
            # Mission control view
            echo "Mission control"
            ;;
        app-grid)
            # Show app grid
            echo "App grid"
            ;;
        terminal)
            # Open terminal
            if command -v gnome-terminal >/dev/null 2>&1; then
                gnome-terminal &
            elif command -v xfce4-terminal >/dev/null 2>&1; then
                xfce4-terminal &
            fi
            ;;
        zoom-in)
            # Zoom in
            xdotool key ctrl+plus
            ;;
        zoom-out)
            # Zoom out
            xdotool key ctrl+minus
            ;;
        calculator)
            # Open calculator
            if command -v gnome-calculator >/dev/null 2>&1; then
                gnome-calculator &
            fi
            ;;
        file-manager)
            # Open file manager
            if command -v nautilus >/dev/null 2>&1; then
                nautilus &
            elif command -v thunar >/dev/null 2>&1; then
                thunar &
            fi
            ;;
    esac
}

log_gesture() {
    local gesture=$1
    local action=$2
    echo "$(date): $gesture -> $action" >> $GESTURES_LOG
}

show_gestures() {
    echo -e "${YELLOW}Available Gestures:${NC}"
    echo ""
    echo "2-finger gestures:"
    echo "  ✓ Scroll (up/down)"
    echo "  ✓ Pinch to zoom"
    echo ""
    echo "3-finger gestures:"
    echo "  ↑ Swipe up: Overview"
    echo "  ↓ Swipe down: Show desktop"
    echo "  ← Swipe left: Previous workspace"
    echo "  → Swipe right: Next workspace"
    echo "  Tap: App launcher"
    echo ""
    echo "4-finger gestures:"
    echo "  ↑ Swipe up: All windows"
    echo "  ↓ Swipe down: Minimize all"
    echo "  ← Swipe left: Mission control"
    echo "  → Swipe right: App grid"
    echo "  Tap: Terminal"
    echo ""
}

edit_gestures() {
    ${EDITOR:-nano} $GESTURES_CONFIG
}

show_help() {
    echo "Usage: tinker-gestures [command]"
    echo ""
    echo "Commands:"
    echo "  enable          Enable gesture support"
    echo "  disable         Disable gesture support"
    echo "  show            Show available gestures"
    echo "  edit            Edit gesture configuration"
    echo "  calibrate       Calibrate touchpad"
    echo "  help            Show this help"
}

# Main
init_gestures

case "$1" in
    enable)
        echo -e "${GREEN}Enabling gesture support...${NC}"
        # Start gesture daemon
        detect_gestures &
        echo $! > /tmp/tinker-gestures.pid
        echo -e "${GREEN}✓ Gesture support enabled!${NC}"
        ;;
    disable)
        echo -e "${YELLOW}Disabling gesture support...${NC}"
        if [ -f /tmp/tinker-gestures.pid ]; then
            kill $(cat /tmp/tinker-gestures.pid) 2>/dev/null
            rm -f /tmp/tinker-gestures.pid
        fi
        echo -e "${GREEN}✓ Gesture support disabled!${NC}"
        ;;
    show)
        show_header
        show_gestures
        ;;
    edit)
        show_header
        edit_gestures
        ;;
    calibrate)
        show_header
        echo -e "${YELLOW}Touchpad Calibration${NC}"
        echo ""
        echo "Follow the on-screen instructions..."
        echo "This feature requires a graphical interface."
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Touchpad Gestures${NC}"
        echo ""
        echo "macOS-like multi-touch gestures for Linux."
        echo ""
        echo "Quick commands:"
        echo "  tinker-gestures enable   - Enable gestures"
        echo "  tinker-gestures show     - Show gestures"
        ;;
esac

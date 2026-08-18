#!/bin/bash
# TinkerOS Controller Mapper - Map keyboard/mouse to controller

set -e

MAPPER_DIR="$HOME/.tinker/controller"
CONFIG_FILE="$MAPPER_DIR/config.conf"
PROFILES_DIR="$MAPPER_DIR/profiles"

mkdir -p "$MAPPER_DIR" "$PROFILES_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Controller Mapper Configuration
ENABLED=true
DEFAULT_PROFILE=default
DETECT_AUTOMATICALLY=true
RUMBLE_ENABLED=true
DEADZONE=10
EOF
    fi
}

# Detect connected controllers
detect() {
    echo "Detecting controllers..."
    echo ""
    
    # Check evdev
    if [ -d /dev/input ]; then
        echo "Input devices:"
        ls -la /dev/input/js* 2>/dev/null || echo "  No joystick devices"
        echo ""
    fi
    
    # Check SDL
    if command -v sdl2-controllermap >/dev/null 2>&1; then
        echo "SDL2 controller support: OK"
    else
        echo "SDL2 controller support: Not installed"
    fi
    
    # Check xboxdrv
    if command -v xboxdrv >/dev/null 2>&1; then
        echo "Xbox driver: OK"
    else
        echo "Xbox driver: Not installed"
    fi
    
    # Check ds4drv
    if command -v ds4drv >/dev/null 2>&1; then
        echo "DS4 driver: OK"
    else
        echo "DS4 driver: Not installed"
    fi
}

# Map controller buttons
map_buttons() {
    local profile=${1:-default}
    
    echo "Controller Button Mapping"
    echo ""
    echo "Profile: $profile"
    echo ""
    echo "To create a mapping:"
    echo "  1. Run: sdl2-controllermap"
    echo "  2. Follow instructions"
    echo "  3. Save to: $PROFILES_DIR/$profile.map"
}

# Create profile
create_profile() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo "Usage: tinker-controller create <profile-name>"
        return 1
    fi
    
    cat > "$PROFILES_DIR/$name.conf" << EOF
# Controller Profile: $name
# Created: $(date)

# Button mappings
A_BUTTON=x
B_BUTTON=c
X_BUTTON=z
Y_BUTTON=y
START_BUTTON=return
SELECT_BUTTON=escape
LB_BUTTON=q
RB_BUTTON=e
L3_BUTTON=shift
R3_BUTTON=ctrl
DPAD_UP=up
DPAD_DOWN=down
DPAD_LEFT=left
DPAD_RIGHT=right
LEFT_STICK_X=left
LEFT_STICK_Y=up/down
RIGHT_STICK_X=a/d
RIGHT_STICK_Y=w/s
LEFT_TRIGGER=space
RIGHT_TRIGGER=f
EOF
    
    echo "Profile created: $PROFILES_DIR/$name.conf"
}

# List profiles
list_profiles() {
    echo "Controller Profiles:"
    echo ""
    ls "$PROFILES_DIR"/*.conf 2>/dev/null | while read f; do
        echo "  $(basename $f .conf)"
    done
}

# Install drivers
install_drivers() {
    echo "Installing controller drivers..."
    echo ""
    echo "For Xbox controllers:"
    echo "  sudo apt install xboxdrv"
    echo ""
    echo "For PS4/PS5 controllers:"
    echo "  sudo pip install ds4drv"
    echo ""
    echo "For generic controllers:"
    echo "  sudo apt install joystick"
    echo ""
    echo "Test with: jstest /dev/input/js0"
}

show_help() {
    echo "Usage: tinker-controller [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect connected controllers"
    echo "  map [profile]     Map controller buttons"
    echo "  create <name>     Create new profile"
    echo "  list              List profiles"
    echo "  install           Install controller drivers"
    echo "  help              Show this help"
}

init

case "$1" in
    detect|scan) detect ;;
    map) map_buttons "$2" ;;
    create|new) create_profile "$2" ;;
    list|ls) list_profiles ;;
    install|drivers) install_drivers ;;
    *) show_help ;;
esac

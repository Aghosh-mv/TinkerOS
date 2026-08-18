#!/bin/bash
# TinkerOS Window Animations - Custom animations

set -e

ANIM_DIR="$HOME/.tinker/animations"
CONFIG_FILE="$ANIM_DIR/config.conf"

mkdir -p "$ANIM_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Window Animation Configuration
ENABLED=true
ANIMATION_SPEED=fast
EFFECTS=true
EOF
    fi
}

# Set animation speed
set_speed() {
    local speed=${1:-fast}
    
    echo "Setting animation speed: $speed"
    
    case $speed in
        none)
            gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
            ;;
        slow|normal|fast)
            gsettings set org.gnome.desktop.interface enable-animations true 2>/dev/null || true
            gsettings set org.gnome.shell enabled-extensions "['animations@tinkeros.dev']" 2>/dev/null || true
            ;;
    esac
    
    echo "Animation speed set: $speed"
}

# Enable/disable effects
toggle_effects() {
    local state=${1:-true}
    
    echo "Window effects: $state"
    
    if [ "$state" = "true" ]; then
        gsettings set org.gnome.desktop.interface enable-animations true 2>/dev/null || true
    else
        gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
    fi
}

# List effects
list_effects() {
    echo "Available Window Effects:"
    echo ""
    echo "  - Fade in/out"
    echo "  - Slide animations"
    echo "  - Scale animations"
    echo "  - Workspace switch"
    echo "  - Minimize/Maximize"
    echo "  - Snap windows"
}

show_help() {
    echo "Usage: tinker-animations [command]"
    echo ""
    echo "Commands:"
    echo "  set <speed>       Set animation speed"
    echo "  effects [on/off]  Toggle effects"
    echo "  list              List available effects"
    echo "  help              Show this help"
}

init

case "$1" in
    set|speed) set_speed "$2" ;;
    effects|toggle) toggle_effects "$2" ;;
    list) list_effects ;;
    *) show_help ;;
esac

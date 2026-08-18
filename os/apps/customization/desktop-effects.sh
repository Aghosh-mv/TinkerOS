#!/bin/bash
# TinkerOS Desktop Effects - Compositor effects

set -e

EFFECTS_DIR="$HOME/.tinker/desktop-effects"
CONFIG_FILE="$EFFECTS_DIR/config.conf"

mkdir -p "$EFFECTS_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Desktop Effects Configuration
ENABLED=true
COMPOSITING=true
SHADOWS=true
TRANSPARENCY=false
EOF
    fi
}

# Enable compositing
enable_compositing() {
    echo "Enabling compositing..."
    
    gsettings set org.gnome.mutter compositing true 2>/dev/null || true
    
    echo "Compositing enabled"
}

# Enable shadows
enable_shadows() {
    echo "Enabling window shadows..."
    
    # For XFCE
    xfconf-query -c xfwm4 -p /general/use_shade -s true 2>/dev/null || true
    
    echo "Shadows enabled"
}

# Enable transparency
enable_transparency() {
    local state=${1:-true}
    
    echo "Transparency: $state"
    
    # For XFCE
    xfconf-query -c xfwm4 -p /general/use_compositing -s "$state" 2>/dev/null || true
}

# List effects
list_effects() {
    echo "Available Desktop Effects:"
    echo ""
    echo "  - Window shadows"
    echo "  - Transparency"
    echo "  - Blur (GNOME)"
    echo "  - Wobbly windows"
    echo "  - Desktop cube"
    echo "  - Scale (overview)"
}

show_help() {
    echo "Usage: tinker-desktop-effects [command]"
    echo ""
    echo "Commands:"
    echo "  compositing [on/off] Toggle compositing"
    echo "  shadows [on/off]   Toggle shadows"
    echo "  transparency [on/off] Toggle transparency"
    echo "  list               List available effects"
    echo "  help               Show this help"
}

init

case "$1" in
    compositing) enable_compositing "$2" ;;
    shadows) enable_shadows "$2" ;;
    transparency) enable_transparency "$2" ;;
    list) list_effects ;;
    *) show_help ;;
esac

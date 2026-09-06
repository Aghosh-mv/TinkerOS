#!/bin/bash
# TinkerOS Wine/Proton Manager - Easy Windows app compatibility

set -e

WINE_DIR="$HOME/.tinker/wine"
CONFIG_FILE="$WINE_DIR/config.conf"
PREFIXES_DIR="$WINE_DIR/prefixes"

mkdir -p "$WINE_DIR" "$PREFIXES_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Wine/Proton Manager Configuration
ENABLED=true
DEFAULT_WINE=system
ENABLE_PROTON=true
ENABLE_WINETRICKS=true
EOF
    fi
}

# Check Wine
check_wine() {
    echo "Checking Wine installation..."
    
    if command -v wine >/dev/null 2>&1; then
        echo "Wine: Installed"
        echo "  Version: $(wine --version 2>/dev/null)"
    else
        echo "Wine: Not installed"
        echo "  Install: sudo apt install wine"
    fi
    
    if command -v proton >/dev/null 2>&1; then
        echo "Proton: Installed"
    else
        echo "Proton: Available via Steam"
    fi
}

# Create Wine prefix
create_prefix() {
    local name=${1:-"default"}
    
    echo "Creating Wine prefix: $name"
    
    WINEPREFIX="$PREFIXES_DIR/$name" wineboot --init
    
    echo "Prefix created: $PREFIXES_DIR/$name"
}

# Run Windows app
run_app() {
    local app=$1
    local prefix=${2:-"default"}
    
    echo "Running: $app"
    
    WINEPREFIX="$PREFIXES_DIR/$prefix" wine "$app"
}

# Install winetricks
install_winetricks() {
    echo "Installing winetricks..."
    
    sudo apt install winetricks
    
    echo "Winetricks installed"
}

# List prefixes
list_prefixes() {
    echo "Wine Prefixes:"
    echo ""
    ls "$PREFIXES_DIR" 2>/dev/null || echo "  No prefixes"
}

show_help() {
    echo "Usage: tinker-wine [command]"
    echo ""
    echo "Commands:"
    echo "  check             Check Wine installation"
    echo "  create [name]     Create Wine prefix"
    echo "  run <app> [prefix] Run Windows app"
    echo "  winetricks        Install winetricks"
    echo "  list              List prefixes"
    echo "  help              Show this help"
}

init

case "$1" in
    check) check_wine ;;
    create|new) create_prefix "$2" ;;
    run|start) run_app "$2" "$3" ;;
    winetricks) install_winetricks ;;
    list|ls) list_prefixes ;;
    *) show_help ;;
esac

#!/bin/bash
# TinkerOS Discord Rich Presence - Show what you're playing

set -e

DISCORD_DIR="$HOME/.tinker/discord"
CONFIG_FILE="$DISCORD_DIR/config.conf"

mkdir -p "$DISCORD_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Discord Rich Presence Configuration
ENABLED=true
SHOW_GAME=true
SHOW_DETAILS=true
SHOW.timestamps=true
EOF
    fi
}

# Check Discord
check_discord() {
    echo "Checking Discord..."
    
    if command -v discord >/dev/null 2>&1; then
        echo "Discord: Installed"
    elif [ -d ~/.discord ]; then
        echo "Discord: Installed (user)"
    else
        echo "Discord: Not installed"
        echo "  Install: sudo apt install discord"
    fi
}

# Setup game detection
setup_detection() {
    echo "Setting up game detection..."
    echo ""
    echo "Discord automatically detects games via:"
    echo "  - Steam"
    echo "  - Lutris"
    echo "  - Wine/Proton"
    echo "  - Native Linux games"
    echo ""
    echo "To add custom games:"
    echo "  1. Open Discord"
    echo "  2. User Settings > Game Activity"
    echo "  3. Add it!"
}

show_help() {
    echo "Usage: tinker-discord [command]"
    echo ""
    echo "Commands:"
    echo "  check             Check Discord installation"
    echo "  detect            Setup game detection"
    echo "  help              Show this help"
}

init

case "$1" in
    check) check_discord ;;
    detect|setup) setup_detection ;;
    *) show_help ;;
esac

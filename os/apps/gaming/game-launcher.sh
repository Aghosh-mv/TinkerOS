#!/bin/bash
# TinkerOS Game Launcher - Unified game library

set -e

LAUNCHER_DIR="$HOME/.tinker/game-launcher"
CONFIG_FILE="$LAUNCHER_DIR/config.conf"
GAMES_DIR="$LAUNCHER_DIR/games"

mkdir -p "$LAUNCHER_DIR" "$GAMES_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Game Launcher Configuration
ENABLED=true
SCAN_STEAM=true
SCAN_LUTRIS=true
SCAN_WINE=true
SCAN_NATIVE=true
SHOW_COVER_ART=true
EOF
    fi
}

# Scan for games
scan_games() {
    echo "Scanning for games..."
    echo ""
    
    local count=0
    
    # Steam games
    if [ -d "$HOME/.steam/steam/steamapps" ]; then
        echo "Steam games:"
        ls "$HOME/.steam/steam/steamapps"/*.acf 2>/dev/null | while read f; do
            local name=$(grep "name" "$f" | cut -d'"' -f4)
            echo "  - $name"
        done
    fi
    
    # Lutris games
    if [ -d "$HOME/Games" ]; then
        echo "Lutris games:"
        ls "$HOME/Games" 2>/dev/null | while read d; do
            echo "  - $d"
        done
    fi
    
    # Wine games
    if [ -d "$HOME/.wine/drive_c/Program Files" ]; then
        echo "Wine games:"
        ls "$HOME/.wine/drive_c/Program Files" 2>/dev/null | grep -i game | while read d; do
            echo "  - $d"
        done
    fi
}

# Launch game
launch_game() {
    local game=$1
    
    echo "Launching: $game"
    
    # Try Steam
    steam steam://rungameid/$game 2>/dev/null || true
    
    # Try Lutris
    lutris $game 2>/dev/null || true
}

# List all games
list_games() {
    echo "Game Library:"
    echo ""
    
    scan_games
}

show_help() {
    echo "Usage: tinker-games [command]"
    echo ""
    echo "Commands:"
    echo "  scan             Scan for games"
    echo "  list             List all games"
    echo "  launch <game>    Launch a game"
    echo "  help              Show this help"
}

init

case "$1" in
    scan) scan_games ;;
    list|ls) list_games ;;
    launch|play) launch_game "$2" ;;
    *) show_help ;;
esac

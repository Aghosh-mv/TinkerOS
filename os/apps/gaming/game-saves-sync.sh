#!/bin/bash
# TinkerOS Game Saves Sync - Cloud sync for game saves

set -e

SYNC_DIR="$HOME/.tinker/game-sync"
CONFIG_FILE="$SYNC_DIR/config.conf"
SAVES_DIR="$SYNC_DIR/saves"

mkdir -p "$SYNC_DIR" "$SAVES_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Game Saves Sync Configuration
ENABLED=false
SYNC_METHOD=local
CLOUD_SERVICE=none
AUTO_SYNC=true
SYNC_INTERVAL=300
EOF
    fi
}

# Detect game saves
detect_saves() {
    echo "Detecting game saves..."
    echo ""
    
    local save_locations=(
        "$HOME/.local/share/Steam/userdata"
        "$HOME/.wine/drive_c/users/$USER/Documents/My Games"
        "$HOME/.config"
    )
    
    for loc in "${save_locations[@]}"; do
        if [ -d "$loc" ]; then
            echo "Found: $loc"
        fi
    done
}

# Backup saves
backup_saves() {
    echo "Backing up game saves..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup="$SAVES_DIR/backup_$timestamp"
    
    mkdir -p "$backup"
    
    # Backup Steam saves
    if [ -d "$HOME/.local/share/Steam/userdata" ]; then
        cp -r "$HOME/.local/share/Steam/userdata" "$backup/" 2>/dev/null || true
    fi
    
    echo "Saves backed up: $backup"
}

# Sync to cloud
sync_cloud() {
    local service=$1
    
    echo "Syncing to $service..."
    
    case $service in
        dropbox)
            if command -v dropbox >/dev/null 2>&1; then
                cp -r "$SAVES_DIR" ~/Dropbox/GameSaves/
            fi
            ;;
        gdrive)
            echo "Use rclone for Google Drive sync"
            ;;
        *)
            echo "Configure cloud service in config"
            ;;
    esac
}

show_help() {
    echo "Usage: tinker-game-sync [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect game saves"
    echo "  backup            Backup game saves"
    echo "  sync [service]    Sync to cloud"
    echo "  help              Show this help"
}

init

case "$1" in
    detect) detect_saves ;;
    backup) backup_saves ;;
    sync) sync_cloud "$2" ;;
    *) show_help ;;
esac

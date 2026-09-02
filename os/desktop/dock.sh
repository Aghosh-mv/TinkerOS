#!/bin/bash
# TinkerOS Dock/Taskbar

set -e

DOCK_DIR="$HOME/.tinker/dock"
FAVORITES_FILE="$DOCK_DIR/favorites"
RUNNING_FILE="$DOCK_DIR/running"

mkdir -p "$DOCK_DIR"

# Initialize dock
init_dock() {
    if [ ! -f "$FAVORITES_FILE" ]; then
        cat > "$FAVORITES_FILE" << EOF
firefox
gnome-terminal
nautilus
code
spotify
discord
steam
EOF
    fi
}

# Show dock
show_dock() {
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  📁  🌐  💻  📝  🎵  💬  🎮  ⚙️                        ║"
    echo "╚══════════════════════════════════════════════════════════╝"
}

# Add app to dock
add_to_dock() {
    local app=$1
    echo "$app" >> "$FAVORITES_FILE"
    echo "Added to dock: $app"
}

# Remove app from dock
remove_from_dock() {
    local app=$1
    sed -i "/^$app$/d" "$FAVORITES_FILE"
    echo "Removed from dock: $app"
}

# Show favorites
show_favorites() {
    echo "Dock Favorites:"
    cat "$FAVORITES_FILE" 2>/dev/null || echo "No favorites"
}

# Launch app from dock
launch_dock_app() {
    local app=$1
    
    case $app in
        firefox|chromium|brave) xdg-open "https://google.com" & ;;
        gnome-terminal|konsole|xfce4-terminal) gnome-terminal & ;;
        nautilus|thunar|dolphin) xdg-open ~ & ;;
        code|sublime) code . & ;;
        spotify) spotify & ;;
        discord) discord & ;;
        steam) steam & ;;
        *) $app & ;;
    esac
}

show_help() {
    echo "Usage: tinker-dock [command]"
    echo ""
    echo "Commands:"
    echo "  show              Show dock"
    echo "  add <app>         Add app to dock"
    echo "  remove <app>      Remove app"
    echo "  list              List favorites"
    echo "  launch <app>      Launch app"
    echo "  help              Show this help"
}

init_dock

case "$1" in
    show|dock) show_dock ;;
    add) add_to_dock "$2" ;;
    remove) remove_from_dock "$2" ;;
    list|favorites) show_favorites ;;
    launch) launch_dock_app "$2" ;;
    *) show_help ;;
esac

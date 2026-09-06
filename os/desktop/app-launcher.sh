#!/bin/bash
# TinkerOS App Launcher

set -e

APPS_DIR="/usr/share/applications"
FAVORITES_FILE="$HOME/.tinker/favorites"

# List installed apps
list_apps() {
    echo "Installed Applications:"
    echo ""
    
    if [ -d "$APPS_DIR" ]; then
        for desktop in "$APPS_DIR"/*.desktop; do
            if [ -f "$desktop" ]; then
                local name=$(grep "^Name=" "$desktop" | head -1 | cut -d= -f2)
                local exec=$(grep "^Exec=" "$desktop" | head -1 | cut -d= -f2)
                
                if [ -n "$name" ]; then
                    echo "  $name"
                fi
            fi
        done | sort
    fi
    echo ""
}

# Search apps
search_apps() {
    local query=$1
    
    echo "Searching for: $query"
    echo ""
    
    if [ -d "$APPS_DIR" ]; then
        for desktop in "$APPS_DIR"/*.desktop; do
            if [ -f "$desktop" ]; then
                local name=$(grep "^Name=" "$desktop" | head -1 | cut -d= -f2)
                
                if echo "$name" | grep -qi "$query"; then
                    echo "  $name"
                fi
            fi
        done
    fi
    echo ""
}

# Launch app
launch_app() {
    local app=$1
    
    if [ -d "$APPS_DIR" ]; then
        for desktop in "$APPS_DIR"/*.desktop; do
            if [ -f "$desktop" ]; then
                local name=$(grep "^Name=" "$desktop" | head -1 | cut -d= -f2)
                
                if echo "$name" | grep -qi "$app"; then
                    local exec=$(grep "^Exec=" "$desktop" | head -1 | cut -d= -f2)
                    if [ -n "$exec" ]; then
                        eval "$exec &"
                        echo "Launching: $name"
                        return 0
                    fi
                fi
            fi
        done
    fi
    
    echo "App not found: $app"
    return 1
}

# Add to favorites
add_favorite() {
    local app=$1
    
    mkdir -p "$(dirname "$FAVORITES_FILE")"
    echo "$app" >> "$FAVORITES_FILE"
    echo "Added to favorites: $app"
}

# Show favorites
show_favorites() {
    echo "Favorite Apps:"
    echo ""
    
    if [ -f "$FAVORITES_FILE" ]; then
        cat "$FAVORITES_FILE"
    else
        echo "No favorites yet."
    fi
    echo ""
}

show_help() {
    echo "Usage: tinker-launcher [command]"
    echo ""
    echo "Commands:"
    echo "  list              List all apps"
    echo "  search <query>    Search apps"
    echo "  launch <app>      Launch app"
    echo "  favorite <app>    Add to favorites"
    echo "  favorites         Show favorites"
    echo "  help              Show this help"
}

case "$1" in
    list|ls)
        list_apps
        ;;
    search|s)
        if [ -n "$2" ]; then
            search_apps "$2"
        else
            echo "Specify search query"
        fi
        ;;
    launch|run|open)
        if [ -n "$2" ]; then
            launch_app "$2"
        else
            echo "Specify app name"
        fi
        ;;
    favorite|fav)
        if [ -n "$2" ]; then
            add_favorite "$2"
        else
            echo "Specify app name"
        fi
        ;;
    favorites)
        show_favorites
        ;;
    *)
        show_help
        ;;
esac

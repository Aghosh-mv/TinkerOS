#!/bin/bash
# TinkerOS Cursor Themes - Custom cursor themes

set -e

CURSOR_DIR="$HOME/.tinker/cursor"
THEMES_DIR="$CURSOR_DIR/themes"
CONFIG_FILE="$CURSOR_DIR/config.conf"

mkdir -p "$CURSOR_DIR" "$THEMES_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Cursor Theme Configuration
ENABLED=true
DEFAULT_THEME=Adwaita
SIZE=24
EOF
    fi
}

# List cursor themes
list_themes() {
    echo "Available Cursor Themes:"
    echo ""
    
    ls /usr/share/icons/ 2>/dev/null | while read theme; do
        if [ -d "/usr/share/icons/$theme/cursors" ]; then
            echo "  $theme"
        fi
    done
    
    echo ""
    echo "User themes:"
    ls ~/.icons/ 2>/dev/null || echo "  None"
}

# Set cursor theme
set_theme() {
    local theme=${1:-Adwaita}
    local size=${2:-24}
    
    echo "Setting cursor theme: $theme"
    
    gsettings set org.gnome.desktop.interface cursor-theme "$theme" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size $size 2>/dev/null || true
    
    # Also set for GTK
    sed -i "s/gtk-cursor-theme-name=.*/gtk-cursor-theme-name=\"$theme\"/" ~/.config/gtk-3.0/settings.ini 2>/dev/null || true
    sed -i "s/gtk-cursor-theme-size=.*/gtk-cursor-theme-size=$size/" ~/.config/gtk-3.0/settings.ini 2>/dev/null || true
    
    echo "Cursor theme set: $theme (size: $size)"
}

# Install cursor theme
install_theme() {
    local url=$1
    local name=$2
    
    echo "Installing cursor theme: $name"
    
    mkdir -p ~/.icons
    cd ~/.icons
    
    if [[ "$url" == *.zip ]]; then
        wget -q "$url" -O "$name.zip" && unzip -q "$name.zip" && rm "$name.zip"
    elif [[ "$url" == *.tar.* ]]; then
        wget -q "$url" -O "$name.tar.*" && tar xf "$name.tar.*" && rm "$name.tar.*"
    fi
    
    cd -
    echo "Installed: $name"
}

show_help() {
    echo "Usage: tinker-cursor [command]"
    echo ""
    echo "Commands:"
    echo "  list              List cursor themes"
    echo "  set <theme> [size] Set cursor theme"
    echo "  install <url> <name> Install theme"
    echo "  help              Show this help"
}

init

case "$1" in
    list|ls) list_themes ;;
    set|apply) set_theme "$2" "$3" ;;
    install) install_theme "$2" "$3" ;;
    *) show_help ;;
esac

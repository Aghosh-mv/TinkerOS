#!/bin/bash
# TinkerOS Icon Packs - Custom icon themes

set -e

ICON_DIR="$HOME/.tinker/icons"
THEMES_DIR="$ICON_DIR/themes"
CONFIG_FILE="$ICON_DIR/config.conf"

mkdir -p "$ICON_DIR" "$THEMES_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Icon Pack Configuration
ENABLED=true
DEFAULT_THEME=Adwaita
EOF
    fi
}

# List icon themes
list_themes() {
    echo "Available Icon Themes:"
    echo ""
    
    ls /usr/share/icons/ 2>/dev/null | while read theme; do
        if [ -d "/usr/share/icons/$theme/scalable" ] || [ -d "/usr/share/icons/$theme/48x48" ]; then
            echo "  $theme"
        fi
    done
    
    echo ""
    echo "User themes:"
    ls ~/.icons/ 2>/dev/null || echo "  None"
}

# Set icon theme
set_theme() {
    local theme=${1:-Adwaita}
    
    echo "Setting icon theme: $theme"
    
    gsettings set org.gnome.desktop.interface icon-theme "$theme" 2>/dev/null || true
    
    # Also set for GTK
    sed -i "s/gtk-icon-theme-name=.*/gtk-icon-theme-name=\"$theme\"/" ~/.config/gtk-3.0/settings.ini 2>/dev/null || true
    
    echo "Icon theme set: $theme"
}

# Install icon theme
install_theme() {
    local url=$1
    local name=$2
    
    echo "Installing icon theme: $name"
    
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
    echo "Usage: tinker-icons [command]"
    echo ""
    echo "Commands:"
    echo "  list              List icon themes"
    echo "  set <theme>       Set icon theme"
    echo "  install <url> <name> Install theme"
    echo "  help              Show this help"
}

init

case "$1" in
    list|ls) list_themes ;;
    set|apply) set_theme "$2" ;;
    install) install_theme "$2" "$3" ;;
    *) show_help ;;
esac

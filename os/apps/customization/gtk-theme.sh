#!/bin/bash
# TinkerOS GTK Theme - GTK theme manager
set -e
GTK_DIR="$HOME/.tinker/gtk-theme"
mkdir -p "$GTK_DIR"

list_themes() {
    echo "Available GTK Themes:" && echo ""
    ls /usr/share/themes/ 2>/dev/null | while read theme; do
        [ -d "/usr/share/themes/$theme/gtk-3.0" ] && echo "  $theme"
    done
}

set_theme() {
    local theme=${1:-Adwaita}
    gsettings set org.gnome.desktop.interface gtk-theme "$theme" 2>/dev/null || true
    mkdir -p ~/.config/gtk-3.0
    echo -e "[Settings]\ngtk-theme-name=$theme" > ~/.config/gtk-3.0/settings.ini
    echo "GTK theme set: $theme"
}

install_theme() {
    local url=$1 name=$2
    mkdir -p ~/.themes && cd ~/.themes
    wget -q "$url" -O "$name.tar.*" 2>/dev/null && tar xf "$name.tar.*" 2>/dev/null
    echo "Installed: $name"
}

show_help() { echo "Usage: tinker-gtk-theme [list|set|install]"; }

case "$1" in
    list|ls) list_themes ;;
    set|apply) set_theme "$2" ;;
    install) install_theme "$2" "$3" ;;
    *) show_help ;;
esac

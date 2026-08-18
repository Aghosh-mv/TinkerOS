#!/bin/bash
# TinkerOS Shell Theme - GNOME Shell themes
set -e
SHELL_DIR="$HOME/.tinker/shell-theme"
mkdir -p "$SHELL_DIR"

list_themes() {
    echo "Available Shell Themes:" && echo ""
    ls /usr/share/gnome-shell/themes/ 2>/dev/null || echo "No themes found"
}

set_theme() {
    local theme=${1:-Adwaita}
    gsettings set org.gnome.shell.theme name "$theme" 2>/dev/null || true
    echo "Shell theme set: $theme"
}

install_theme() {
    local url=$1 name=$2
    mkdir -p ~/.themes && cd ~/.themes
    wget -q "$url" -O "$name.tar.*" 2>/dev/null && tar xf "$name.tar.*" 2>/dev/null
    echo "Installed: $name"
}

show_help() { echo "Usage: tinker-shell-theme [list|set|install]"; }

case "$1" in
    list|ls) list_themes ;;
    set|apply) set_theme "$2" ;;
    install) install_theme "$2" "$3" ;;
    *) show_help ;;
esac

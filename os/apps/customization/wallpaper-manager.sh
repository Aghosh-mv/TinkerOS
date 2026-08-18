#!/bin/bash
# TinkerOS Wallpaper Manager - Auto-rotate wallpapers
set -e
WP_DIR="$HOME/.tinker/wallpaper"
CONFIG_FILE="$WP_DIR/config.conf"
WALLPAPERS_DIR="$WP_DIR/wallpapers"
mkdir -p "$WP_DIR" "$WALLPAPERS_DIR"

[ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'CONF'
AUTO_ROTATE=false
ROTATE_INTERVAL=3600
FOLDER=~/Pictures/Wallpapers
CONF

set_wallpaper() {
    [ -f "$1" ] && gsettings set org.gnome.desktop.background picture-uri "file://$1" 2>/dev/null && echo "Wallpaper set" || echo "File not found"
}

random() {
    local dir=$(grep "FOLDER" "$CONFIG_FILE" | cut -d= -f2)
    dir=${dir:-~/Pictures/Wallpapers}
    [ -d "$dir" ] && set_wallpaper "$(find "$dir" -type f \( -name '*.jpg' -o -name '*.png' \) | shuf -n 1)" || echo "No wallpapers found"
}

auto_rotate() { while true; do random; sleep $(grep "ROTATE_INTERVAL" "$CONFIG_FILE" | cut -d= -f2); done; }

download() {
    for i in {1..5}; do wget -q "https://picsum.photos/1920/1080?random=$i" -O "$WALLPAPERS_DIR/wallpaper_$i.jpg" 2>/dev/null; done
    echo "Downloaded wallpapers"
}

list_wallpapers() { ls "$WALLPAPERS_DIR" 2>/dev/null || echo "No wallpapers"; }

show_help() { echo "Usage: tinker-wallpaper [set|random|auto-rotate|download|list]"; }

case "$1" in
    set) set_wallpaper "$2" ;;
    random|shuffle) random ;;
    auto-rotate|rotate) auto_rotate ;;
    download) download ;;
    list|ls) list_wallpapers ;;
    *) show_help ;;
esac

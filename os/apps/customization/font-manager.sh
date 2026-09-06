#!/bin/bash
# TinkerOS Font Manager - Install/manage fonts
set -e
FONT_DIR="$HOME/.tinker/fonts"
LOCAL_FONTS="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR" "$LOCAL_FONTS"

list_fonts() { echo "Installed Fonts:" && echo "" && fc-list 2>/dev/null | head -30; }

install_font() {
    local file=$1
    if [ -f "$file" ]; then
        cp "$file" "$LOCAL_FONTS/" && fc-cache -f 2>/dev/null || true
        echo "Font installed: $(basename $file)"
    else
        echo "File not found: $file"
    fi
}

install_from_url() {
    local url=$1
    local name=${2:-"font"}
    cd /tmp && wget -q "$url" -O "$name.zip" 2>/dev/null || wget -q "$url" -O "$name.tar.gz" 2>/dev/null
    [ -f "$name.zip" ] && unzip -q "$name.zip" 2>/dev/null
    [ -f "$name.tar.gz" ] && tar xf "$name.tar.gz" 2>/dev/null
    find . -name "*.ttf" -o -name "*.otf" | while read f; do install_font "$f"; done
    cd - && rm -rf /tmp/$name*
}

remove_font() { rm "$LOCAL_FONTS/$1" 2>/dev/null && fc-cache -f 2>/dev/null && echo "Font removed"; }

show_help() { echo "Usage: tinker-font [list|install|install-url|remove]"; }

case "$1" in
    list|ls) list_fonts ;;
    install) install_font "$2" ;;
    install-url|download) install_from_url "$2" "$3" ;;
    remove|delete) remove_font "$2" ;;
    *) show_help ;;
esac

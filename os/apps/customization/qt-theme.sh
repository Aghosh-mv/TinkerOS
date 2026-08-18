#!/bin/bash
# TinkerOS Qt Theme - Qt theme manager
set -e
QT_DIR="$HOME/.tinker/qt-theme"
mkdir -p "$QT_DIR"

list_themes() {
    echo "Available Qt Themes:" && echo ""
    command -v qt5ct >/dev/null 2>&1 && ls /usr/share/qt5ct/styles/ 2>/dev/null || echo "qt5ct not available"
}

set_theme() {
    local theme=${1:-qt5ct}
    export QT_STYLE_OVERRIDE="$theme"
    echo "export QT_STYLE_OVERRIDE=$theme" >> ~/.bashrc
    echo "Qt theme set: $theme"
}

configure_qt5ct() {
    command -v qt5ct >/dev/null 2>&1 && qt5ct & || echo "Install qt5ct: sudo apt install qt5ct"
}

show_help() { echo "Usage: tinker-qt-theme [list|set|configure]"; }

case "$1" in
    list|ls) list_themes ;;
    set|apply) set_theme "$2" ;;
    configure|config) configure_qt5ct ;;
    *) show_help ;;
esac

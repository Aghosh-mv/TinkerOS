#!/bin/bash
# TinkerOS Gaming Meta-Package
# ONE-CLICK "Enable Gaming Mode" - pulls in the entire gaming stack
# in the background with a single command. Non-gamers never install it.
#
#   Install:   tinker-gaming-meta install
#   Remove:    tinker-gaming-meta uninstall
#   Status:    tinker-gaming-meta status

set -e

META_MARKER="$HOME/.tinker/gaming-meta.installed"
GAMING_SUPPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../apps" && pwd)/gaming-support.sh"

log() { echo "[meta] $*"; }

# The single meta-package that pulls everything in
install_all() {
    echo "══════════════════════════════════════════════"
    echo "   TinkerOS Gaming Meta-Package (Enable Gaming)"
    echo "══════════════════════════════════════════════"
    echo ""
    echo "  This single step installs the complete gaming stack:"
    echo "    • NVIDIA/AMD GPU driver (matched to your hardware)"
    echo "    • Steam + Proton (Windows game compatibility)"
    echo "    • Wine"
    echo "    • MangoHUD (FPS overlay)"
    echo "    • GameMode (performance boost)"
    echo "    • Gamescope (compositor)"
    echo "    • Lutris (multi-platform game manager)"
    echo ""
    echo "  Non-gamers: this stays hidden unless you opt in."
    echo ""
    
    if [ -f "$GAMING_SUPPORT" ]; then
        bash "$GAMING_SUPPORT" install-all
    else
        log "gaming-support.sh not found - installing core packages directly"
        if command -v apt >/dev/null 2>&1; then
            sudo apt update
            sudo apt install -y steam lutris wine mangohud gamemode gamescope
        fi
    fi
    
    touch "$META_MARKER"
    echo ""
    echo "✓ Gaming mode packages installed."
    echo "  Reboot to load the GPU driver, then launch Steam."
}

# Remove the gaming stack (optional)
uninstall_all() {
    echo "Removing gaming meta-package..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt remove -y steam-installer steam lutris wine mangohud gamemode gamescope 2>/dev/null | tail -1 || true
    fi
    rm -f "$META_MARKER"
    echo "Gaming packages removed."
}

# Status
status() {
    echo "=== Gaming Meta-Package Status ==="
    echo ""
    if [ -f "$META_MARKER" ]; then
        echo "  Installed: YES"
    else
        echo "  Installed: NO (gaming stack hidden from menus)"
    fi
    echo ""
    echo "  Gaming components present:"
    for tool in steam lutris wine mangohud gamemode gamescope; do
        local st="absent"
        command -v "$tool" >/dev/null 2>&1 && st="present"
        printf "    %-10s %s\n" "$tool" "$st"
    done
}

show_help() {
    echo "Usage: tinker-gaming-meta [command]"
    echo ""
    echo "Commands:"
    echo "  install     Install the complete gaming stack (one click)"
    echo "  uninstall   Remove the gaming stack"
    echo "  status      Show installation status"
    echo "  help        Show this help"
}

case "$1" in
    install|enable|on) install_all ;;
    uninstall|remove|off) uninstall_all ;;
    status) status ;;
    *) show_help ;;
esac
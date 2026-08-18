#!/bin/bash
# TinkerOS Emulator Manager - RetroArch/Dolphin integration

set -e

EMU_DIR="$HOME/.tinker/emulators"
CONFIG_FILE="$EMU_DIR/config.conf"
ROMS_DIR="$HOME/ROMs"

mkdir -p "$EMU_DIR" "$ROMS_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Emulator Manager Configuration
ENABLED=true
ROMS_DIRECTORY=~/ROMs
AUTO_DETECT=true
EOF
    fi
}

# Check emulators
check_emulators() {
    echo "Checking emulators..."
    echo ""
    
    local emulators=(
        "retroarch:RetroArch"
        "dolphin-emu:Dolphin (GameCube/Wii)"
        "pcsx2:PCSX2 (PS2)"
        "rpcs3:RPCS3 (PS3)"
        "yuzu:Yuzu (Switch)"
        "cemu:Cemu (Wii U)"
        "mupen64plus:Mupen64Plus (N64)"
        "ppsspp:PPSSPP (PSP)"
        "duckstation:DuckStation (PS1)"
        "suyu:Suyu (Switch)"
    )
    
    for emu in "${emulators[@]}"; do
        IFS=':' read -r cmd name <<< "$emu"
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  [OK] $name"
        else
            echo "  [--] $name"
        fi
    done
}

# Create ROMs directory structure
setup_roms() {
    echo "Setting up ROMs directory..."
    
    local systems=(
        "nes"
        "snes"
        "n64"
        "gameboy"
        "gba"
        "nds"
        "gamecube"
        "wii"
        "ps1"
        "ps2"
        "ps3"
        "psp"
        "switch"
        "genesis"
        "saturn"
        "dreamcast"
        "arcade"
    )
    
    for system in "${systems[@]}"; do
        mkdir -p "$ROMS_DIR/$system"
    done
    
    echo "ROMs directories created: $ROMS_DIR"
}

# Install RetroArch
install_retroarch() {
    echo "Installing RetroArch..."
    
    sudo apt install retroarch
    
    # Install common cores
    sudo apt install libretro-* 2>/dev/null || true
    
    echo "RetroArch installed"
}

show_help() {
    echo "Usage: tinker-emulator [command]"
    echo ""
    echo "Commands:"
    echo "  check             Check installed emulators"
    echo "  setup-roms        Create ROMs directory structure"
    echo "  install-retroarch Install RetroArch"
    echo "  help              Show this help"
}

init

case "$1" in
    check|list) check_emulators ;;
    setup-roms|roms) setup_roms ;;
    install-retroarch|retroarch) install_retroarch ;;
    *) show_help ;;
esac

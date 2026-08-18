#!/bin/bash
# TinkerOS NFC Manager - NFC device support

set -e

NFC_DIR="$HOME/.tinker/nfc"
CONFIG_FILE="$NFC_DIR/config.conf"

mkdir -p "$NFC_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# NFC Manager Configuration
ENABLED=true
AUTO_DETECT=true
EOF
    fi
}

# Detect NFC
detect() {
    echo "Detecting NFC reader..."
    echo ""
    
    if command -v nfc-list >/dev/null 2>&1; then
        nfc-list 2>/dev/null || echo "No NFC reader found"
    else
        echo "libnfc not installed"
        echo "Install: sudo apt install libnfc-utils"
    fi
}

# Read NFC tag
read_tag() {
    echo "Reading NFC tag..."
    echo ""
    echo "Place tag near reader..."
    
    if command -v nfc-poll >/dev/null 2>&1; then
        nfc-poll 2>/dev/null || echo "No tag detected"
    fi
}

# Write NFC tag
write_tag() {
    local data=$1
    
    echo "Writing to NFC tag..."
    echo ""
    echo "Place tag near reader..."
    
    if command -v nfc-mfclassic >/dev/null 2>&1; then
        echo "Use nfc-mfclassic for MIFARE tags"
    fi
}

show_help() {
    echo "Usage: tinker-nfc [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect NFC reader"
    echo "  read              Read NFC tag"
    echo "  write <data>      Write to NFC tag"
    echo "  help              Show this help"
}

init

case "$1" in
    detect) detect ;;
    read) read_tag ;;
    write) write_tag "$2" ;;
    *) show_help ;;
esac

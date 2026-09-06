#!/bin/bash
# TinkerOS Fingerprint Manager - Fingerprint reader setup

set -e

FP_DIR="$HOME/.tinker/fingerprint"
CONFIG_FILE="$FP_DIR/config.conf"

mkdir -p "$FP_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Fingerprint Manager Configuration
ENABLED=true
AUTO_DETECT=true
EOF
    fi
}

# Detect fingerprint reader
detect() {
    echo "Detecting fingerprint reader..."
    echo ""
    
    if command -v fprintd-list >/dev/null 2>&1; then
        local devices=$(fprintd-list "$USER" 2>/dev/null | grep -E "finger|Device")
        if [ -n "$devices" ]; then
            echo "Fingerprint reader found:"
            echo "$devices"
        else
            echo "No fingerprint reader detected"
        fi
    else
        echo "fprintd not installed"
        echo "Install: sudo apt install fprintd libpam-fprintd"
    fi
}

# Enroll fingerprint
enroll() {
    echo "Enrolling fingerprint..."
    echo ""
    echo "Follow the instructions on screen"
    
    fprintd-enroll "$USER"
}

# List fingerprints
list() {
    echo "Enrolled fingerprints:"
    echo ""
    
    fprintd-list "$USER" 2>/dev/null || echo "No fingerprints enrolled"
}

# Delete fingerprint
delete() {
    echo "Deleting all fingerprints..."
    
    fprintd-delete "$USER" 2>/dev/null || echo "No fingerprints to delete"
}

# Test fingerprint
test() {
    echo "Testing fingerprint..."
    echo ""
    echo "Place your finger on the reader..."
    
    fprintd-verify "$USER" 2>/dev/null || echo "Verification failed"
}

show_help() {
    echo "Usage: tinker-fingerprint [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect fingerprint reader"
    echo "  enroll            Enroll fingerprint"
    echo "  list              List enrolled fingerprints"
    echo "  delete            Delete all fingerprints"
    echo "  test              Test fingerprint"
    echo "  help              Show this help"
}

init

case "$1" in
    detect|scan) detect ;;
    enroll|add) enroll ;;
    list|ls) list ;;
    delete|remove) delete ;;
    test|verify) test ;;
    *) show_help ;;
esac

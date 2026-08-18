#!/bin/bash
# TinkerOS Scanner Manager - Scanner support

set -e

SCANNER_DIR="$HOME/.tinker/scanner"
CONFIG_FILE="$SCANNER_DIR/config.conf"

mkdir -p "$SCANNER_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Scanner Manager Configuration
ENABLED=true
SAVE_DIRECTORY=~/Scans
DEFAULT_FORMAT=pdf
DEFAULT_RESOLUTION=300
EOF
    fi
}

# Detect scanners
detect() {
    echo "Detecting scanners..."
    echo ""
    
    if command -v scanimage >/dev/null 2>&1; then
        scanimage -L 2>/dev/null || echo "No scanners found"
    else
        echo "SANE not installed"
        echo "Install: sudo apt install sane"
    fi
}

# Scan document
scan() {
    local output=${1:-"scan_$(date +%Y%m%d_%H%M%S).pdf"}
    local resolution=${2:-300}
    
    echo "Scanning at ${resolution} DPI..."
    
    if command -v scanimage >/dev/null 2>&1; then
        scanimage --resolution "$resolution" --format pdf > "$output" 2>/dev/null
        echo "Scan saved: $output"
    else
        echo "Install sane: sudo apt install sane"
    fi
}

# Scan to image
scan_image() {
    local output=${1:-"scan_$(date +%Y%m%d_%H%M%S).png"}
    local resolution=${2:-300}
    
    echo "Scanning to image at ${resolution} DPI..."
    
    if command -v scanimage >/dev/null 2>&1; then
        scanimage --resolution "$resolution" --format png > "$output" 2>/dev/null
        echo "Image saved: $output"
    fi
}

# Test scanner
test() {
    echo "Testing scanner..."
    echo ""
    
    if command -v xsane >/dev/null 2>&1; then
        xsane &
    elif command -v simple-scan >/dev/null 2>&1; then
        simple-scan &
    else
        echo "Install scanning frontend:"
        echo "  sudo apt install xsane"
        echo "  or"
        echo "  sudo apt install simple-scan"
    fi
}

show_help() {
    echo "Usage: tinker-scanner [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect scanners"
    echo "  scan [output]     Scan to PDF"
    echo "  image [output]    Scan to image"
    echo "  test              Test scanner"
    echo "  help              Show this help"
}

init

case "$1" in
    detect|scan) detect ;;
    scan|pdf) scan "$2" "$3" ;;
    image|img) scan_image "$2" "$3" ;;
    test) test ;;
    *) show_help ;;
esac

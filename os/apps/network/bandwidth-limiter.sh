#!/bin/bash
# TinkerOS Bandwidth Limiter - Limit per-app bandwidth

set -e

BW_DIR="$HOME/.tinker/bandwidth"
CONFIG_FILE="$BW_DIR/config.conf"

mkdir -p "$BW_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Bandwidth Limiter Configuration
ENABLED=false
DEFAULT_LIMIT=1024
EOF
    fi
}

# Limit bandwidth
limit() {
    local app=$1
    local rate=${2:-1024}
    
    echo "Limiting $app to ${rate}KB/s"
    
    if command -v trickle >/dev/null 2>&1; then
        trickle -d "$rate" -u "$rate" "$app"
    else
        echo "Install trickle: sudo apt install trickle"
    fi
}

# Show current limits
show_limits() {
    echo "Bandwidth Limits:"
    echo ""
    
    if command -v tc >/dev/null 2>&1; then
        tc qdisc show 2>/dev/null
    fi
}

# Clear limits
clear_limits() {
    echo "Clearing bandwidth limits..."
    
    if command -v tc >/dev/null 2>&1; then
        sudo tc qdisc del dev eth0 root 2>/dev/null || true
    fi
    
    echo "Limits cleared"
}

show_help() {
    echo "Usage: tinker-bandwidth [command]"
    echo ""
    echo "Commands:"
    echo "  limit <app> <rate> Limit bandwidth"
    echo "  limits            Show current limits"
    echo "  clear             Clear all limits"
    echo "  help              Show this help"
}

init

case "$1" in
    limit|set) limit "$2" "$3" ;;
    limits|show) show_limits ;;
    clear|reset) clear_limits ;;
    *) show_help ;;
esac

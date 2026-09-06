#!/bin/bash
# TinkerOS Mesh Network - Tailscale/ZeroTier integration

set -e

MESH_DIR="$HOME/.tinker/mesh"
CONFIG_FILE="$MESH_DIR/config.conf"

mkdir -p "$MESH_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Mesh Network Configuration
ENABLED=false
SERVICE=none
NETWORK_ID=
EOF
    fi
}

# Check Tailscale
check_tailscale() {
    echo "Tailscale Status:"
    echo ""
    
    if command -v tailscale >/dev/null 2>&1; then
        tailscale status 2>/dev/null || echo "Not connected"
    else
        echo "Tailscale not installed"
        echo "Install: curl -fsSL https://tailscale.com/install.sh | sh"
    fi
}

# Connect Tailscale
connect_tailscale() {
    echo "Connecting to Tailscale..."
    
    if command -v tailscale >/dev/null 2>&1; then
        sudo tailscale up
    else
        echo "Install Tailscale first"
    fi
}

# Check ZeroTier
check_zerotier() {
    echo "ZeroTier Status:"
    echo ""
    
    if command -v zerotier-cli >/dev/null 2>&1; then
        zerotier-cli status 2>/dev/null || echo "Not connected"
    else
        echo "ZeroTier not installed"
        echo "Install: curl -s https://install.zerotier.com | sudo bash"
    fi
}

# Join ZeroTier network
join_zerotier() {
    local network_id=$1
    
    echo "Joining ZeroTier network: $network_id"
    
    if command -v zerotier-cli >/dev/null 2>&1; then
        sudo zerotier-cli join "$network_id"
    else
        echo "Install ZeroTier first"
    fi
}

show_help() {
    echo "Usage: tinker-mesh [command]"
    echo ""
    echo "Commands:"
    echo "  tailscale          Check Tailscale"
    echo "  tailscale-up       Connect Tailscale"
    echo "  zerotier           Check ZeroTier"
    echo "  zerotier-join <id> Join ZeroTier network"
    echo "  help              Show this help"
}

init

case "$1" in
    tailscale|ts) check_tailscale ;;
    tailscale-up|ts-up) connect_tailscale ;;
    zerotier|zt) check_zerotier ;;
    zerotier-join|zt-join) join_zerotier "$2" ;;
    *) show_help ;;
esac

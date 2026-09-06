#!/bin/bash
# TinkerOS Hotspot Manager - Mobile hotspot

set -e

HOTSPOT_DIR="$HOME/.tinker/hotspot"
CONFIG_FILE="$HOTSPOT_DIR/config.conf"

mkdir -p "$HOTSPOT_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Hotspot Manager Configuration
ENABLED=false
SSID=TinkerOS-Hotspot
PASSWORD=tinkeros123
INTERFACE=wlan0
EOF
    fi
}

# Start hotspot
start() {
    local ssid=${1:-TinkerOS-Hotspot}
    local pass=${2:-tinkeros123}
    
    echo "Starting hotspot: $ssid"
    
    if command -v nmcli >/dev/null 2>&1; then
        nmcli device wifi hotspot ifname wlan0 ssid "$ssid" password "$pass" 2>/dev/null || \
        sudo create-ap wlan0 "$ssid" --passphrase "$pass" 2>/dev/null || \
        echo "Could not start hotspot"
    fi
    
    echo "Hotspot started"
    echo "  SSID: $ssid"
    echo "  Password: $pass"
}

# Stop hotspot
stop() {
    echo "Stopping hotspot..."
    
    if command -v nmcli >/dev/null 2>&1; then
        nmcli connection down Hotspot 2>/dev/null || true
    fi
    
    echo "Hotspot stopped"
}

# Show status
status() {
    echo "Hotspot Status:"
    echo ""
    
    if command -v nmcli >/dev/null 2>&1; then
        nmcli connection show --active 2>/dev/null | grep hotspot || echo "Not active"
    fi
}

# Show connected clients
clients() {
    echo "Connected Clients:"
    echo ""
    
    if command -v arp >/dev/null 2>&1; then
        arp -a 2>/dev/null | grep -v "incomplete"
    fi
}

show_help() {
    echo "Usage: tinker-hotspot [command]"
    echo ""
    echo "Commands:"
    echo "  start [ssid] [pass] Start hotspot"
    echo "  stop              Stop hotspot"
    echo "  status            Show hotspot status"
    echo "  clients           Show connected clients"
    echo "  help              Show this help"
}

init

case "$1" in
    start|on) start "$2" "$3" ;;
    stop|off) stop ;;
    status) status ;;
    clients) clients ;;
    *) show_help ;;
esac

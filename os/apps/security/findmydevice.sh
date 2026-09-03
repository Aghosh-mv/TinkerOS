#!/bin/bash
# TinkerOS Find My Device - Track device, send alert, and locate lost laptops

set -e

FMD_DIR="$HOME/.tinker/findmy"
CONFIG_FILE="$FMD_DIR/config.conf"
LOG_FILE="$FMD_DIR/events.log"
mkdir -p "$FMD_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Find My Device Configuration
OWNER_NAME=
ALERT_MESSAGE="This device is lost. If found, please contact the owner."
ENABLE_PING=true
LOG_EVENTS=true
EOF
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Get device identity
identity() {
    echo "=== Device Identity ==="
    echo ""
    echo "  Hostname: $(hostname)"
    echo "  User: $USER"
    echo "  Machine ID: $(cat /etc/machine-id 2>/dev/null || echo unknown)"
    echo "  Kernel: $(uname -r)"
    echo "  Arch: $(uname -m)"
    echo ""
    echo "  Public IP: $(timeout 5 curl -s https://ipinfo.io/ip 2>/dev/null || echo offline)"
    echo "  MAC (active): $(ip link show 2>/dev/null | awk '/ether/ {print $2; exit}')"
}

# Locate via network (public IP/geo)
locate() {
    echo "=== Device Location (network-based) ==="
    echo ""
    echo "  Public IP: $(timeout 5 curl -s https://ipinfo.io/ip 2>/dev/null || echo offline)"
    echo "  City: $(timeout 5 curl -s https://ipinfo.io/city 2>/dev/null || echo -)"
    echo "  Region: $(timeout 5 curl -s https://ipinfo.io/region 2>/dev/null || echo -)"
    echo "  Country: $(timeout 5 curl -s https://ipinfo.io/country 2>/dev/null || echo -)"
    echo "  ISP: $(timeout 5 curl -s https://ipinfo.io/org 2>/dev/null || echo -)"
    echo ""
    echo "  Note: Approximate location from public IP. Not GPS."
    echo "  For GPS, use a companion mobile app or manual reporting."
}

# Send alert (display message on screen)
alert() {
    echo "=== Sending Alert ==="
    echo ""
    local msg=$(grep ALERT_MESSAGE "$CONFIG_FILE" | cut -d= -f2-)
    msg=${msg:-"This device is lost."}
    local owner=$(grep OWNER_NAME "$CONFIG_FILE" | cut -d= -f2-)
    
    echo "  Message: $msg"
    [ -n "$owner" ] && echo "  Owner: $owner"
    echo ""
    
    # Display on screen if possible
    if [ -n "$DISPLAY" ]; then
        command -v zenity &>/dev/null && zenity --info --title="FIND MY DEVICE" --text="$msg
Owner: ${owner:-unknown}" &
        notify-send "🔔 GOOD NEWS" "A good Samaritan found your device. They see: $msg" 2>/dev/null &
    fi
    
    # Write a prominent marker file
    local marker="$HOME/IF_FOUND.txt"
    {
        echo "=============================================="
        echo "  THIS DEVICE BELONGS TO: ${owner:-[owner name]}"
        echo "=============================================="
        echo ""
        echo "$msg"
        echo ""
        echo "Contact instructions below. Alert date: $(date)"
        echo ""
        echo "System info for identification:"
        echo "  Hostname: $(hostname)"
        echo "  Device ID: $(cat /etc/machine-id 2>/dev/null)"
    } > "$marker"
    chmod 644 "$marker"
    echo "  ✓ Wrote alert file: $marker"
    grep -q LOG_EVENTS "$CONFIG_FILE" && echo "$(date +%s)|alert" >> "$LOG_FILE"
}

# Start tracking (periodic location logging)
track() {
    local interval=${1:-300}
    echo "=== Find My Device Tracking (every ${interval}s) ==="
    echo "  Logging location periodically. Ctrl+C to stop."
    echo ""
    while true; do
        local ip=$(timeout 5 curl -s https://ipinfo.io/ip 2>/dev/null || echo "offline")
        local ts=$(date +%s)
        echo "$ts|$ip" >> "$LOG_FILE"
        echo "  $(date +%H:%M:%S) — $ip"
        sleep "$interval"
    done
}

# Set owner contact
set_owner() {
    local owner=${1:-}
    [ -z "$owner" ] && { echo "Usage: $0 owner <name-or-contact>"; return 1; }
    sed -i "s/^OWNER_NAME=.*/OWNER_NAME=$owner/" "$CONFIG_FILE"
    echo "  ✓ Owner set: $owner"
}

# Show tracking history
history() {
    echo "=== Location History ==="
    echo ""
    [ -s "$LOG_FILE" ] && tail -20 "$LOG_FILE" | while read line; do
        local ts=$(echo $line | cut -d'|' -f1)
        local loc=$(echo $line | cut -d'|' -f2)
        echo "  $(date -d @$ts '+%Y-%m-%d %H:%M' 2>/dev/null)  $loc"
    done || echo "  No tracking data"
}

show_help() {
    echo "Usage: tinker-findmy [command]"
    echo ""
    echo "Commands:"
    echo "  identity            Show device identity"
    echo "  locate              Locate via public IP"
    echo "  alert               Display lost-device alert"
    echo "  track [sec]         Start periodic tracking"
    echo "  owner <name>        Set owner contact"
    echo "  history             Show location history"
    echo "  help                Show this help"
}

init

case "$1" in
    identity) identity ;;
    locate|location) locate ;;
    alert|lost) alert ;;
    track) track "$2" ;;
    owner) set_owner "$2" ;;
    history) history ;;
    *) show_help ;;
esac
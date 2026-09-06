#!/bin/bash
# TinkerOS Firewall Manager

set -e

SECURITY_DIR="$HOME/.tinker/security"
FIREWALL_LOG="$SECURITY_DIR/firewall.log"
mkdir -p "$SECURITY_DIR"

setup_firewall() {
    echo "Setting up Firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw --force enable
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw deny from any to any port 23
        sudo ufw deny from any to any port 113
        echo "Firewall enabled with UFW!"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --permanent --set-default-zone=drop
        sudo firewall-cmd --reload
        echo "Firewall enabled with firewalld!"
    else
        echo "No firewall found. Installing ufw..."
        sudo apt install -y ufw
        setup_firewall
    fi
}

allow_app() {
    local app=$1
    local port=$2
    sudo ufw allow $port/tcp comment "$app"
    echo "$app allowed on port $port"
}

block_app() {
    local app=$1
    local port=$2
    sudo ufw deny $port/tcp comment "$app"
    echo "$app blocked on port $port"
}

show_status() {
    echo "Firewall Status:"
    echo ""
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw status verbose
    else
        echo "UFW not installed"
    fi
}

show_rules() {
    echo "Firewall Rules:"
    echo ""
    sudo ufw status numbered
}

log_firewall() {
    local action=$1
    local details=$2
    echo "$(date -Iseconds) | $action | $details" >> "$FIREWALL_LOG"
}

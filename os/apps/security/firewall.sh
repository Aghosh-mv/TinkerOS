#!/bin/bash
# TinkerOS Firewall - UFW/firewalld/iptables management (security category)

set -e

# Delegate to the network firewall-gui implementation if present (same engine)
NET_IMPL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/network/firewall-gui.sh"
if [ -f "$NET_IMPL" ] && [ -s "$NET_IMPL" ]; then
    exec bash "$NET_IMPL" "$@"
fi

FW_DIR="$HOME/.tinker/firewall"
mkdir -p "$FW_DIR"

status() {
    echo "=== TinkerOS Firewall ==="
    echo ""
    if command -v ufw &>/dev/null; then
        echo "UFW status:"
        ufw status 2>/dev/null | sed 's/^/  /'
    elif command -v firewall-cmd &>/dev/null; then
        echo "firewalld: $(firewall-cmd --state 2>/dev/null)"
        firewall-cmd --list-all 2>/dev/null | sed 's/^/  /'
    else
        echo "  No firewall tool (ufw/firewalld)"
    fi
}

enable() {
    echo "Enabling firewall..."
    if command -v ufw &>/dev/null; then ufw enable
    elif command -v firewall-cmd &>/dev/null; then systemctl start firewalld
    else echo "  No firewall tool"
    fi
}

disable() {
    echo "Disabling firewall..."
    if command -v ufw &>/dev/null; then ufw disable
    elif command -v firewall-cmd &>/dev/null; then systemctl stop firewalld
    else echo "  No firewall tool"
    fi
}

allow() {
    local port=$1 proto=${2:-tcp}
    [ -z "$port" ] && { echo "Usage: $0 allow <port> [tcp|udp]"; return 1; }
    echo "Allowing $port/$proto..."
    if command -v ufw &>/dev/null; then ufw allow "$port/$proto"
    elif command -v firewall-cmd &>/dev/null; then firewall-cmd --permanent --add-port="$port/$proto" && firewall-cmd --reload
    else echo "  No firewall tool"
    fi
}

deny() {
    local port=$1 proto=${2:-tcp}
    [ -z "$port" ] && { echo "Usage: $0 deny <port> [tcp|udp]"; return 1; }
    echo "Denying $port/$proto..."
    if command -v ufw &>/dev/null; then ufw deny "$port/$proto"
    elif command -v firewall-cmd &>/dev/null; then firewall-cmd --permanent --remove-port="$port/$proto" && firewall-cmd --reload
    else echo "  No firewall tool"
    fi
}

show_help() {
    echo "Usage: tinker-firewall [command]"
    echo ""
    echo "Commands:"
    echo "  status              Show firewall status"
    echo "  enable              Enable firewall"
    echo "  disable             Disable firewall"
    echo "  allow <port> [pr]   Allow port"
    echo "  deny <port> [pr]    Deny port"
    echo "  help                Show this help"
}

case "$1" in
    status) status ;;
    enable|on) enable ;;
    disable|off) disable ;;
    allow) allow "$2" "$3" ;;
    deny) deny "$2" "$3" ;;
    *) show_help ;;
esac
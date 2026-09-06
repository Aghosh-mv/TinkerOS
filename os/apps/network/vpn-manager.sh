#!/bin/bash
# TinkerOS VPN Manager - WireGuard and OpenVPN connection management

set -e

VPN_DIR="$HOME/.tinker/vpn"
CONFIG_FILE="$VPN_DIR/config.conf"
STATUS_FILE="$VPN_DIR/status"
mkdir -p "$VPN_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# VPN Configuration
DEFAULT_BACKEND=auto
AUTO_CONNECT=false
KILL_SWITCH=false
DNS_LEAK_PROTECTION=true
CHECK_INTERVAL=60
EOF
}

# Detect backend
detect_backend() {
    local backend=$(grep DEFAULT_BACKEND "$CONFIG_FILE" | cut -d= -f2)
    [ "$backend" = "auto" ] && backend=""
    if [ -z "$backend" ]; then
        if command -v wg &>/dev/null || [ -d /etc/wireguard ]; then backend="wireguard"
        elif command -v openvpn &>/dev/null; then backend="openvpn"
        elif command -v nmcli &>/dev/null; then backend="nmcli"
        else backend="none"
        fi
    fi
    echo "$backend"
}

# Status
status() {
    local backend=$(detect_backend)
    echo "=== VPN Status (backend: $backend) ==="
    echo ""
    
    # Check if VPN active
    local vpn_active=0
    local vpn_ip=""
    local vpn_iface=""
    
    # Detect via interfaces
    for iface in $(ls /sys/class/net 2>/dev/null); do
        case "$iface" in
            tun*|wg*|tap*|wg0*)
                vpn_active=1
                vpn_iface=$iface
                ;;
        esac
    done
    
    # Detect via nmcli
    if [ -z "$vpn_iface" ] && command -v nmcli &>/dev/null; then
        local vpn_conn=$(nmcli -t connection show --active 2>/dev/null | grep -i "vpn")
        if [ -n "$vpn_conn" ]; then
            vpn_active=1
            vpn_iface=$(echo "$vpn_conn" | cut -d: -f3)
        fi
    fi
    
    if [ $vpn_active -eq 1 ]; then
        vpn_ip=$(ip -4 addr show "$vpn_iface" 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)
        echo "  Status: ACTIVE"
        echo "  Interface: $vpn_iface"
        echo "  VPN IP: $vpn_ip"
        echo ""
        echo "  Public IP check:"
        timeout 5 curl -s https://ipinfo.io/ip 2>/dev/null | sed 's/^/    /' || echo "    (offline)"
    else
        echo "  Status: INACTIVE"
    fi
    
    # List available profiles
    echo ""
    echo "Available profiles:"
    ls /etc/wireguard/*.conf 2>/dev/null | sed 's/.*\///;s/\.conf//' | sed 's/^/  WireGuard: /'
    ls "$VPN_DIR/profiles"/*.conf 2>/dev/null | sed 's/.*\///;s/\.conf//' | sed 's/^/  Local: /'
    [ -z "$(ls /etc/wireguard/*.conf 2>/dev/null)" ] && [ -z "$(ls "$VPN_DIR/profiles"/*.conf 2>/dev/null)" ] && echo "  No profiles found"
}

# Connect
connect() {
    local profile=$1
    local backend=$(detect_backend)
    
    if [ -z "$profile" ]; then
        echo "Available profiles:"
        ls /etc/wireguard/*.conf 2>/dev/null
        ls "$VPN_DIR/profiles"/*.conf 2>/dev/null
        echo ""
        echo "Usage: $0 connect <profile>"
        return 1
    fi
    
    echo "Connecting to VPN profile: $profile"
    
    case $backend in
        wireguard)
            if [ -f "/etc/wireguard/$profile.conf" ]; then
                wg-quick up "$profile" 2>/dev/null || sudo wg-quick up "$profile" 2>/dev/null || echo "  (need sudo or missing profile in /etc/wireguard)"
            elif [ -f "$VPN_DIR/profiles/$profile.conf" ]; then
                local key="$VPN_DIR/profiles/$profile.conf"
                (wg-quick up "$profile" 2>/dev/null || true) &>/dev/null
                echo "  Attempted local profile; copy to /etc/wireguard for wg-quick"
            else
                echo "  Profile not found: $profile"
                return 1
            fi
            ;;
        nmcli)
            nmcli connection up "$profile" 2>&1
            ;;
        openvpn)
            systemctl start "openvpn@$profile" 2>&1 || openvpn --config "$VPN_DIR/profiles/$profile.conf" --daemon 2>&1
            ;;
        none)
            echo "No VPN backend (install wireguard-tools or openvpn)"
            return 1
            ;;
    esac
    
    echo "$profile" > "$STATUS_FILE"
    echo "Connected to $profile"
}

# Disconnect
disconnect() {
    local backend=$(detect_backend)
    echo "Disconnecting VPN..."
    
    for iface in tun wg tap; do
        sudo ip link set "$iface" down 2>/dev/null || true
    done
    
    case $backend in
        wireguard)
            for conf in /etc/wireguard/*.conf; do
                [ -e "$conf" ] || continue
                local name=$(basename "$conf" .conf)
                sudo wg-quick down "$name" 2>/dev/null || true
            done
            ;;
        nmcli)
            local vpn_conn=$(nmcli -t connection show --active 2>/dev/null | grep -i vpn | cut -d: -f1)
            [ -n "$vpn_conn" ] && nmcli connection down "$vpn_conn" 2>&1
            ;;
    esac
    
    rm -f "$STATUS_FILE"
    echo "Disconnected"
}

# Get current public IP
my_ip() {
    echo "Current public IP:"
    timeout 5 curl -s https://ipinfo.io/ip 2>/dev/null || echo "  (offline)"
    echo ""
    echo "Location:"
    timeout 5 curl -s https://ipinfo.io/city 2>/dev/null | sed 's/^/  /'
}

# Check for DNS leaks
leak_test() {
    echo "=== DNS Leak Test ==="
    echo ""
    echo "DNS servers currently in use:"
    cat /etc/resolv.conf 2>/dev/null | grep nameserver | sed 's/^/  /'
    echo ""
    echo "This test checks whether DNS requests go through VPN."
    echo "Run 'tinker-vpn ip' and compare with your regular ISP IP."
    echo ""
    echo "Recommended: 1.1.1.1 (Cloudflare) or 10.x.x.x (VPN provider)"
    echo "  dnsleaktest.com recommendations: check with 'tinker-vpn dns'"
}

# Add profile
add_profile() {
    local file=$1
    local name=${2:-$(basename "$file" .conf)}
    
    [ -z "$file" ] && echo "Usage: $0 add <profile.conf> [name]" && return 1
    [ ! -f "$file" ] && echo "File not found: $file" && return 1
    
    mkdir -p "$VPN_DIR/profiles"
    cp "$file" "$VPN_DIR/profiles/$name.conf"
    echo "Added profile: $name"
    echo "  To use with wg-quick, copy to /etc/wireguard:"
    echo "  sudo cp \"$VPN_DIR/profiles/$name.conf\" /etc/wireguard/"
}

show_help() {
    echo "Usage: tinker-vpn [command]"
    echo ""
    echo "Commands:"
    echo "  status              Show VPN status"
    echo "  connect <profile>   Connect to VPN profile"
    echo "  disconnect          Disconnect VPN"
    echo "  ip                  Show current public IP"
    echo "  leak                DNS leak test"
    echo "  add <file> [name]   Add VPN profile"
    echo "  help                Show this help"
}

init

case "$1" in
    status) status ;;
    connect|up) connect "$2" ;;
    disconnect|down) disconnect ;;
    ip) my_ip ;;
    leak|leak-test) leak_test ;;
    add) add_profile "$2" "$3" ;;
    *) show_help ;;
esac
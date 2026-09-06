#!/bin/bash
# TinkerOS DNS Manager - Change DNS servers

set -e

DNS_DIR="$HOME/.tinker/dns"
CONFIG_FILE="$DNS_DIR/config.conf"

mkdir -p "$DNS_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# DNS Manager Configuration
ENABLED=true
PRIMARY_DNS=1.1.1.1
SECONDARY_DNS=8.8.8.8
EOF
    fi
}

# Show current DNS
show_dns() {
    echo "Current DNS Servers:"
    echo ""
    
    cat /etc/resolv.conf | grep nameserver
}

# Set DNS
set_dns() {
    local primary=${1:-1.1.1.1}
    local secondary=${2:-8.8.8.8}
    
    echo "Setting DNS servers..."
    echo "  Primary: $primary"
    echo "  Secondary: $secondary"
    
    sudo bash -c "cat > /etc/resolv.conf" << EOF
# TinkerOS DNS Configuration
nameserver $primary
nameserver $secondary
EOF
    
    echo "DNS updated"
}

# Test DNS
test_dns() {
    echo "Testing DNS resolution..."
    echo ""
    
    echo "Google:"
    nslookup google.com 2>/dev/null | tail -2
    
    echo ""
    echo "Cloudflare:"
    nslookup cloudflare.com 1.1.1.1 2>/dev/null | tail -2
}

# Popular DNS servers
popular() {
    echo "Popular DNS Servers:"
    echo ""
    echo "  Cloudflare: 1.1.1.1, 1.0.0.1"
    echo "  Google:     8.8.8.8, 8.8.4.4"
    echo "  Quad9:      9.9.9.9, 149.112.112.112"
    echo "  OpenDNS:    208.67.222.222, 208.67.220.220"
    echo "  AdGuard:    94.140.14.14, 94.140.15.15"
}

show_help() {
    echo "Usage: tinker-dns [command]"
    echo ""
    echo "Commands:"
    echo "  show              Show current DNS"
    echo "  set <primary> [secondary] Set DNS"
    echo "  test              Test DNS resolution"
    echo "  popular           List popular DNS servers"
    echo "  help              Show this help"
}

init

case "$1" in
    show|current) show_dns ;;
    set|change) set_dns "$2" "$3" ;;
    test) test_dns ;;
    popular|list) popular ;;
    *) show_help ;;
esac

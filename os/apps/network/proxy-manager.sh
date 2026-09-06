#!/bin/bash
# TinkerOS Proxy Manager - Configure proxies

set -e

PROXY_DIR="$HOME/.tinker/proxy"
CONFIG_FILE="$PROXY_DIR/config.conf"

mkdir -p "$PROXY_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Proxy Manager Configuration
ENABLED=false
PROXY_TYPE=none
PROXY_HOST=
PROXY_PORT=
PROXY_USER=
PROXY_PASS=
EOF
    fi
}

# Show current proxy
show_proxy() {
    echo "Current Proxy Settings:"
    echo ""
    
    echo "HTTP_PROXY: ${HTTP_PROXY:-not set}"
    echo "HTTPS_PROXY: ${HTTPS_PROXY:-not set}"
    echo "ALL_PROXY: ${ALL_PROXY:-not set}"
}

# Set proxy
set_proxy() {
    local host=$1
    local port=$2
    local user=$3
    local pass=$4
    
    echo "Setting proxy..."
    
    if [ -n "$user" ]; then
        export http_proxy="http://$user:$pass@$host:$port"
        export https_proxy="http://$user:$pass@$host:$port"
    else
        export http_proxy="http://$host:$port"
        export https_proxy="http://$host:$port"
    fi
    
    # Save to profile
    cat >> ~/.bashrc << EOF
export http_proxy="$http_proxy"
export https_proxy="$https_proxy"
EOF
    
    echo "Proxy set: $host:$port"
}

# Clear proxy
clear_proxy() {
    echo "Clearing proxy..."
    
    unset http_proxy https_proxy all_proxy
    
    sed -i '/http_proxy/d' ~/.bashrc 2>/dev/null || true
    sed -i '/https_proxy/d' ~/.bashrc 2>/dev/null || true
    
    echo "Proxy cleared"
}

# Test proxy
test_proxy() {
    echo "Testing proxy..."
    echo ""
    
    curl -I --proxy "$http_proxy" http://example.com 2>/dev/null && echo "Proxy working" || echo "Proxy not working"
}

show_help() {
    echo "Usage: tinker-proxy [command]"
    echo ""
    echo "Commands:"
    echo "  show              Show current proxy"
    echo "  set <host> <port> [user] [pass] Set proxy"
    echo "  clear             Clear proxy"
    echo "  test              Test proxy connection"
    echo "  help              Show this help"
}

init

case "$1" in
    show|status) show_proxy ;;
    set) set_proxy "$2" "$3" "$4" "$5" ;;
    clear|off) clear_proxy ;;
    test) test_proxy ;;
    *) show_help ;;
esac

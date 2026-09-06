#!/bin/bash
# TinkerOS Firewall - Comprehensive firewall management (UFW/firewalld/iptables)

set -e

FW_DIR="$HOME/.tinker/firewall"
CONFIG_FILE="$FW_DIR/config.conf"
LOG_FILE="$FW_DIR/firewall.log"

mkdir -p "$FW_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Firewall Configuration
DEFAULT_TOOL=auto
DEFAULT_POLICY=deny
ENABLE_LOGGING=true
ENABLE_ICMP=true
ALLOW_SSH=true
ALLOW_PING=true
ENABLE_DOS_PROTECTION=true
ENABLE_PORT_SCAN_PROTECTION=true
ENABLE_SYN_FLOOD_PROTECTION=true
EOF
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Detect firewall backend
detect_backend() {
    local tool=$(grep DEFAULT_TOOL "$CONFIG_FILE" | cut -d= -f2)
    [ "$tool" = "auto" ] && tool=""
    if [ -z "$tool" ]; then
        if command -v ufw &>/dev/null && systemctl is-active ufw 2>/dev/null | grep -q active; then tool="ufw"
        elif command -v firewall-cmd &>/dev/null && systemctl is-active firewalld 2>/dev/null | grep -q active; then tool="firewalld"
        elif command -v iptables &>/dev/null; then tool="iptables"
        else tool="none"
        fi
    fi
    echo "$tool"
}

# Status
status() {
    local tool=$(detect_backend)
    echo "=== TinkerOS Firewall (backend: $tool) ==="
    echo ""
    
    case $tool in
        ufw)
            ufw status verbose 2>/dev/null | sed 's/^/  /'
            echo ""
            echo "App rules:"
            ufw app list 2>/dev/null | sed 's/^/  /'
            ;;
        firewalld)
            firewall-cmd --state 2>/dev/null
            echo "Default zone: $(firewall-cmd --get-default-zone 2>/dev/null)"
            echo "Active zones:"
            firewall-cmd --get-active-zones 2>/dev/null | sed 's/^/  /'
            echo "Open ports:"
            firewall-cmd --list-ports 2>/dev/null | sed 's/^/  /'
            ;;
        iptables)
            echo "Filter table:"
            iptables -L -n -v 2>/dev/null | sed 's/^/  /' | head -30
            ;;
        none)
            echo "  No firewall backend detected"
            ;;
    esac
}

# Enable firewall
enable() {
    local tool=$(detect_backend)
    echo "Enabling firewall ($tool)..."
    
    case $tool in
        ufw) ufw enable 2>&1 ;;
        firewalld) systemctl start firewalld; systemctl enable firewalld ;;
        iptables) systemctl enable --now iptables 2>&1 || true ;;
        none) echo "No firewall backend"; return 1 ;;
    esac
    
    echo "$(date +%s)|enable|$tool" >> "$LOG_FILE"
}

# Disable firewall
disable() {
    local tool=$(detect_backend)
    echo "Disabling firewall ($tool)..."
    
    case $tool in
        ufw) ufw disable 2>&1 ;;
        firewalld) systemctl stop firewalld ;;
        iptables) systemctl stop iptables 2>&1 || true ;;
        none) echo "No firewall backend"; return 1 ;;
    esac
    
    echo "$(date +%s)|disable|$tool" >> "$LOG_FILE"
}

# Allow port
allow() {
    local port=$1
    local proto=${2:-tcp}
    local tool=$(detect_backend)
    
    [ -z "$port" ] && echo "Usage: $0 allow <port> [tcp|udp]" && return 1
    
    echo "Allowing port $port/$proto ($tool)..."
    
    case $tool in
        ufw) ufw allow $port/$proto 2>&1 ;;
        firewalld) firewall-cmd --permanent --add-port=$port/$proto; firewall-cmd --reload ;;
        iptables) iptables -A INPUT -p $proto --dport $port -j ACCEPT ;;
        none) echo "No firewall backend"; return 1 ;;
    esac
    
    echo "$(date +%s)|allow|$port/$proto" >> "$LOG_FILE"
    echo "Port $port/$proto allowed"
}

# Deny port
deny() {
    local port=$1
    local proto=${2:-tcp}
    local tool=$(detect_backend)
    
    [ -z "$port" ] && echo "Usage: $0 deny <port> [tcp|udp]" && return 1
    
    echo "Denying port $port/$proto ($tool)..."
    
    case $tool in
        ufw) ufw deny $port/$proto 2>&1 ;;
        firewalld) firewall-cmd --permanent --remove-port=$port/$proto; firewall-cmd --reload ;;
        iptables) iptables -A INPUT -p $proto --dport $port -j DROP ;;
        none) echo "No firewall backend"; return 1 ;;
    esac
    
    echo "$(date +%s)|deny|$port/$proto" >> "$LOG_FILE"
}

# Allow IP
allow_ip() {
    local ip=$1
    local tool=$(detect_backend)
    [ -z "$ip" ] && echo "Usage: $0 allow-ip <ip>" && return 1
    
    case $tool in
        ufw) ufw allow from $ip 2>&1 ;;
        firewalld) firewall-cmd --permanent --add-source=$ip; firewall-cmd --reload ;;
        iptables) iptables -A INPUT -s $ip -j ACCEPT ;;
    esac
}

# Deny IP
deny_ip() {
    local ip=$1
    local tool=$(detect_backend)
    [ -z "$ip" ] && echo "Usage: $0 deny-ip <ip>" && return 1
    
    case $tool in
        ufw) ufw deny from $ip 2>&1 ;;
        firewalld) firewall-cmd --permanent --remove-source=$ip; firewall-cmd --reload ;;
        iptables) iptables -A INPUT -s $ip -j DROP ;;
    esac
}

# Apply default policy
set_policy() {
    local policy=${1:-deny}
    local tool=$(detect_backend)
    
    echo "Setting default policy: $policy"
    
    case $tool in
        ufw)
            if [ "$policy" = "deny" ]; then
                echo "ufw default deny incoming, allow outgoing"
                ufw default deny incoming
                ufw default allow outgoing
            else
                echo "ufw default allow"
                ufw default allow
            fi
            ;;
        firewalld)
            if [ "$policy" = "deny" ]; then
                firewall-cmd --permanent --set-default-zone=drop
                firewall-cmd --reload
            else
                firewall-cmd --permanent --set-default-zone=public
                firewall-cmd --reload
            fi
            ;;
        iptables)
            if [ "$policy" = "deny" ]; then
                iptables -P INPUT DROP
                iptables -P FORWARD DROP
            else
                iptables -P INPUT ACCEPT
                iptables -P FORWARD ACCEPT
            fi
            ;;
        none) echo "No firewall backend"; return 1 ;;
    esac
    
    echo "$(date +%s)|policy|$policy" >> "$LOG_FILE" 2>/dev/null || true &>/dev/null
}

# Enable DOS protection
enable_dos_protection() {
    echo "Enabling DoS protection rules..."
    local tool=$(detect_backend)
    
    # TCP SYN flood protection
    echo "  SYN flood protection"
    sysctl -w net.ipv4.tcp_syncookies=1 2>/dev/null
    
    # Port scan protection
    echo "  Port scan protection"
    iptables -A INPUT -m recent --name portscan --rcheck --seconds 60 -j DROP 2>/dev/null || true
    iptables -A FORWARD -m recent --name portscan --rcheck --seconds 60 -j DROP 2>/dev/null || true
}

# Show logs
logs() {
    echo "=== Firewall Logs ==="
    echo ""
    if command -v ufw &>/dev/null; then
        grep -i "UFW" /var/log/kern.log 2>/dev/null | tail -20 | sed 's/^/  /' || journalctl -k -n 30 2>/dev/null | grep -i ufw | sed 's/^/  /' || echo "  (no kernel UFW logs)"
    elif command -v journalctl &>/dev/null; then
        journalctl -u firewalld -n 30 --no-pager 2>/dev/null | sed 's/^/  /'
    else
        echo "  (no firewall logs available)"
    fi
}

show_help() {
    echo "Usage: tinker-firewall [command]"
    echo ""
    echo "Commands:"
    echo "  status              Show firewall status"
    echo "  enable              Enable firewall"
    echo "  disable             Disable firewall"
    echo "  allow <port> [proto] Allow port (tcp/udp)"
    echo "  deny <port> [proto]  Deny port"
    echo "  allow-ip <ip>       Allow IP address"
    echo "  deny-ip <ip>        Deny IP address"
    echo "  policy [deny|allow] Set default policy"
    echo "  dos                 Enable DoS protection"
    echo "  logs                Show firewall logs"
    echo "  help                Show this help"
}

init

case "$1" in
    status) status ;;
    enable|on) enable ;;
    disable|off) disable ;;
    allow) allow "$2" "$3" ;;
    deny) deny "$2" "$3" ;;
    allow-ip) allow_ip "$2" ;;
    deny-ip) deny_ip "$2" ;;
    policy) set_policy "$2" ;;
    dos) enable_dos_protection ;;
    logs) logs ;;
    *) show_help ;;
esac
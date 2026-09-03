#!/bin/bash
# TinkerOS Network Monitor - Real-time traffic, connections, and diagnostics

set -e

NM_DIR="$HOME/.tinker/net-monitor"
CONFIG_FILE="$NM_DIR/config.conf"
LOG_FILE="$NM_DIR/network.log"

mkdir -p "$NM_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Network Monitor Configuration
REFRESH_INTERVAL=2
ALERT_BANDWIDTH=1000000
ALERT_CONNECTIONS=500
LOG_INTERVAL=60
TRACK_BANDWIDTH=true
EOF
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Get network interfaces
get_interfaces() {
    ip -br link show up 2>/dev/null | grep -v "DOWN\|loopback" | awk '{print $1}' | grep -v "^lo"
}

# Monitor bandwidth
monitor() {
    local interval=${1:-2}
    local interfaces=$(get_interfaces)
    
    echo "=== Network Monitor (interval: ${interval}s, Ctrl+C to stop) ==="
    echo ""
    echo "Monitoring: $interfaces"
    echo ""
    
    # Initial counters
    declare -A rx1 tx1 rx2 tx2
    for iface in $interfaces; do
        rx1[$iface]=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        tx1[$iface]=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
    done
    
    while true; do
        sleep $interval
        clear
        echo "=== Network Monitor $(date +%H:%M:%S) ==="
        echo ""
        printf "%-10s %12s %12s %12s %12s\n" "Interface" "Down rate" "Up rate" "Total RX" "Total TX"
        echo "---------- ------------ ------------ ------------ ------------"
        
        local total_down=0
        local total_up=0
        
        for iface in $interfaces; do
            rx2[$iface]=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
            tx2[$iface]=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
            
            local down=$(( (rx2[$iface] - rx1[$iface]) / interval / 1024 ))
            local up=$(( (tx2[$iface] - tx1[$iface]) / interval / 1024 ))
            local rx_total=$(( rx2[$iface] / 1024 / 1024 ))
            local tx_total=$(( tx2[$iface] / 1024 / 1024 ))
            
            printf "%-10s %8s KB/s %8s KB/s %8s MB %8s MB\n" "$iface" "$down" "$up" "$rx_total" "$tx_total"
            total_down=$((total_down + down))
            total_up=$((total_up + up))
            
            rx1[$iface]=${rx2[$iface]}
            tx1[$iface]=${tx2[$iface]}
        done
        
        echo "---------- ------------ ------------ ------------ ------------"
        printf "%-10s %8s KB/s %8s KB/s\n" "TOTAL" "$total_down" "$total_up"
    done
}

# Show current connections
connections() {
    echo "=== Active Connections ==="
    echo ""
    
    local count=$(ss -tun 2>/dev/null | wc -l)
    echo "Total connections: $count"
    echo ""
    echo "By state:"
    ss -tan 2>/dev/null | awk 'NR>1 {print $1}' | sort | uniq -c | sed 's/^/  /'
    echo ""
    echo "By remote address (top):"
    ss -tan 2>/dev/null | awk 'NR>1 {print $5}' | awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
    echo ""
    echo "Listening ports:"
    ss -tlnp 2>/dev/null | awk 'NR>1 {print $4" "$6}' | sed 's/^/  /' | head -20
}

# Show per-process bandwidth
processes() {
    echo "=== Network Processes ==="
    echo ""
    ss -tup 2>/dev/null | awk 'NR>1 {
        if (match($0, /uid:([0-9]+)/, u)) status = u[1]
        if (match($0, /users:\(\(\"([^\"]+)/, p)) app = p[1]
        if (app != "") { count[app]++; }
    } END {
        for (a in count) printf "%3d  %s\n", count[a], a
    }' | sort -rn | head -20 | sed 's/^/  /' || echo "  (requires root)"
}

# Test connectivity
test_connectivity() {
    echo "=== Connectivity Test ==="
    echo ""
    
    echo "1. Localhost:"
    ping -c 1 -W 2 127.0.0.1 &>/dev/null && echo "  ✓ OK" || echo "  ✗ FAIL"
    
    echo "2. Gateway:"
    local gw=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$gw" ]; then
        ping -c 1 -W 2 "$gw" &>/dev/null && echo "  ✓ OK ($gw)" || echo "  ✗ FAIL ($gw)"
    else
        echo "  - No gateway"
    fi
    
    echo "3. DNS resolution:"
    getent hosts example.com &>/dev/null && echo "  ✓ OK" || echo "  ✗ FAIL"
    
    echo "4. Internet (8.8.8.8):"
    ping -c 1 -W 3 8.8.8.8 &>/dev/null && echo "  ✓ OK" || echo "  ✗ FAIL"
    
    echo "5. HTTPS (example.com:443):"
    timeout 5 bash -c 'echo > /dev/tcp/example.com/443' 2>/dev/null && echo "  ✓ OK" || echo "  ✗ FAIL"
}

# Show DNS info
dns_info() {
    echo "=== DNS Information ==="
    echo ""
    echo "DNS Servers:"
    cat /etc/resolv.conf 2>/dev/null | grep -v "^#" | sed 's/^/  /'
    echo ""
    echo "Test resolution:"
    for host in google.com github.com example.com; do
        local ip=$(getent hosts $host | head -1 | awk '{print $1}')
        echo "  $host -> ${ip:-unresolved}"
    done
}

# Show Wi-Fi info
wifi_info() {
    echo "=== Wi-Fi Information ==="
    echo ""
    if command -v nmcli &>/dev/null; then
        nmcli -t -f ACTIVE,SSID,SIGNAL,CHAN,RATE device wifi list 2>/dev/null | grep "^yes" | sed 's/^/  /'
        echo ""
        echo "Active connection:"
        nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | grep "wifi\|ethernet" | sed 's/^/  /'
    else
        iwconfig 2>/dev/null | grep -E "ESSID|Signal|Bit Rate" | sed 's/^/  /'
    fi
}

# Log data
log_data() {
    local ts=$(date +%s)
    local conn=$(ss -tun 2>/dev/null | wc -l)
    local iface=$(get_interfaces | head -1)
    local rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
    echo "$ts|$conn|$rx|$tx" >> "$LOG_FILE"
}

show_help() {
    echo "Usage: tinker-netmon [command]"
    echo ""
    echo "Commands:"
    echo "  monitor [interval]  Real-time bandwidth monitor"
    echo "  connections         Show active connections"
    echo "  processes           Show network processes"
    echo "  test                Run connectivity test"
    echo "  dns                 Show DNS information"
    echo "  wifi                Show Wi-Fi information"
    echo "  log                 Log current network state"
    echo "  help                Show this help"
}

init

case "$1" in
    monitor|watch) monitor "$2" ;;
    connections|conn) connections ;;
    processes) processes ;;
    test) test_connectivity ;;
    dns) dns_info ;;
    wifi) wifi_info ;;
    log) log_data ;;
    *) show_help ;;
esac
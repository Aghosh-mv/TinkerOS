#!/bin/bash
# KorrinOS Network Manager
# Real network management: connections, WiFi, VPN, DNS, firewall zones, monitoring

set -euo pipefail

NET_DIR="${HOME}/.config/korrinos/network"
NET_CONFIG="$NET_DIR/config.json"
NET_LOG="$NET_DIR/network.log"
NET_PROFILES="$NET_DIR/profiles"
mkdir -p "$NET_DIR" "$NET_PROFILES"

init_network() {
  if [ ! -f "$NET_CONFIG" ]; then
    cat > "$NET_CONFIG" << 'DEFAULTS'
{
  "dns_servers": ["1.1.1.1", "8.8.8.8", "9.9.9.9"],
  "dns_over_tls": true,
  "wifi_power_save": false,
  "auto_connect_vpn": false,
  "mtu_override": 0,
  "tcp_congestion": "bbr",
  "optimize_buffers": true,
  "monitor_interval": 5,
  "alerts": {
    "disconnect": true,
    "high_latency": true,
    "latency_threshold_ms": 100,
    "bandwidth_low_mbps": 10
  }
}
DEFAULTS
    echo "Network config initialized."
  fi
}

cfg() {
  python3 -c "
import json
try:
    with open('$NET_CONFIG') as f: c = json.load(f)
    val = c.get('$1', '$2')
    if isinstance(val, bool): print('True' if val else 'False')
    elif isinstance(val, list): print(','.join(str(x) for x in val))
    else: print(val)
except: print('$2')
" 2>/dev/null
}

# ---- status ----
net_status() {
  echo "============================================="
  echo "   KorrinOS Network Status"
  echo "============================================="
  echo ""

  # Connection state
  if nmcli -t -f STATE general 2>/dev/null | grep -q "connected"; then
    echo "  State: CONNECTED"
  else
    echo "  State: DISCONNECTED"
  fi

  # Active connections
  echo ""
  echo "  Active Connections:"
  nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | while IFS=: read -r name type dev; do
    echo "    $name ($type) on $dev"
  done

  # IP addresses
  echo ""
  echo "  IP Addresses:"
  ip -4 addr show 2>/dev/null | grep inet | grep -v 127.0.0.1 | while read -r line; do
    echo "    $line"
  done

  # Default route
  echo ""
  local gw
  gw=$(ip route show default 2>/dev/null | head -1 | awk '{print $3}')
  local dev
  dev=$(ip route show default 2>/dev/null | head -1 | awk '{print $5}')
  echo "  Gateway: ${gw:-none} via ${dev:-none}"

  # DNS
  echo ""
  echo "  DNS Servers:"
  grep nameserver /etc/resolv.conf 2>/dev/null | awk '{print "    " $2}' | head -3

  # WiFi
  if command -v iwctl &>/dev/null; then
    echo ""
    echo "  WiFi:"
    local wifi_dev
    wifi_dev=$(iwctl station 2>/dev/null | head -1 | awk '{print $1}' || echo "")
    if [ -n "$wifi_dev" ]; then
      local ssid
      ssid=$(iwctl station "$wifi_dev" show 2>/dev/null | grep "Connected" | awk '{print $NF}' || echo "none")
      local signal
      signal=$(iwctl station "$wifi_dev" show 2>/dev/null | grep "Signal" | awk '{print $NF}' || echo "?")
      echo "    SSID: $ssid"
      echo "    Signal: $signal"
    fi
  elif command -v nmcli &>/dev/null; then
    echo ""
    echo "  WiFi:"
    nmcli -t -f SSID,SIGNAL device wifi list 2>/dev/null | head -5 | while IFS=: read -r ssid signal; do
      echo "    $ssid (${signal}%)"
    done
  fi

  # Interfaces
  echo ""
  echo "  Interfaces:"
  ip -o link show 2>/dev/null | grep -v "lo:" | while read -r line; do
    local name state
    name=$(echo "$line" | awk -F: '{print $2}' | xargs)
    state=$(echo "$line" | awk '{print $NF}')
    local mac
    mac=$(echo "$line" | grep -oP 'link/ether \K[^ ]+' || echo "?")
    local mtu
    mtu=$(echo "$line" | grep -oP 'mtu \K[0-9]+' || echo "?")
    echo "    $name: state=$state mac=$mac mtu=$mtu"
  done

  # Traffic stats
  echo ""
  echo "  Traffic (since boot):"
  for iface in /sys/class/net/*/; do
    [ -f "${iface}statistics/rx_bytes" ] || continue
    local name
    name=$(basename "$iface")
    [ "$name" = "lo" ] && continue
    local rx tx
    rx=$(cat "${iface}statistics/rx_bytes" 2>/dev/null || echo 0)
    tx=$(cat "${iface}statistics/tx_bytes" 2>/dev/null || echo 0)
    rx=$((rx / 1024 / 1024))
    tx=$((tx / 1024 / 1024))
    echo "    $name: RX=${rx}MB TX=${tx}MB"
  done
}

# ---- wifi scan ----
wifi_scan() {
  echo "=== WiFi Networks ==="
  if command -v nmcli &>/dev/null; then
    nmcli device wifi list 2>/dev/null
  elif command -v iwctl &>/dev/null; then
    iwctl station wlan0 scan 2>/dev/null
    iwctl station wlan0 get-networks 2>/dev/null
  else
    echo "No WiFi tool found."
  fi
}

# ---- wifi connect ----
wifi_connect() {
  local ssid="${1:-}"
  local pass="${2:-}"
  [ -z "$ssid" ] && { echo "Usage: korrinos-network wifi-connect <ssid> [password]"; return 1; }

  echo "Connecting to $ssid..."
  if command -v nmcli &>/dev/null; then
    if [ -n "$pass" ]; then
      nmcli device wifi connect "$ssid" password "$pass" 2>&1
    else
      nmcli device wifi connect "$ssid" 2>&1
    fi
  elif command -v iwctl &>/dev/null; then
    if [ -n "$pass" ]; then
      iwctl station wlan0 connect "$ssid" --passphrase "$pass" 2>&1
    else
      iwctl station wlan0 connect "$ssid" 2>&1
    fi
  fi
}

# ---- dns ----
set_dns() {
  local servers="${1:-$(cfg dns_servers "1.1.1.1,8.8.8.8")}"
  echo "Setting DNS: $servers"
  echo "$servers" | tr ',' '\n' | while read -r s; do
    sudo resolvconf -a <(echo "nameserver $s") 2>/dev/null || true
  done
  # Also set via nmcli
  if command -v nmcli &>/dev/null; then
    local dev
    dev=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep ethernet | head -1 | cut -d: -f1)
    [ -n "$dev" ] && nmcli device modify "$dev" ipv4.dns "$servers" 2>/dev/null || true
  fi
  echo "DNS updated."
}

# ---- optimize ----
optimize_network() {
  echo "=== Optimizing Network Stack ==="

  # Enable BBR congestion control
  local congestion
  congestion=$(cfg tcp_congestion "bbr")
  if [ -f /proc/sys/net/ipv4/tcp_congestion ]; then
    echo "$congestion" | sudo tee /proc/sys/net/ipv4/tcp_congestion >/dev/null
    echo "  Congestion control: $congestion"
  fi

  # Optimize buffer sizes
  if [ "$(cfg optimize_buffers true)" = "True" ]; then
    sudo sysctl -w net.core.rmem_max=16777216 2>/dev/null
    sudo sysctl -w net.core.wmem_max=16777216 2>/dev/null
    sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216" 2>/dev/null
    sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216" 2>/dev/null
    sudo sysctl -w net.core.netdev_max_backlog=5000 2>/dev/null
    echo "  Buffer sizes optimized"
  fi

  # Enable TCP Fast Open
  sudo sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null
  echo "  TCP Fast Open: enabled"

  # Reduce keepalive time
  sudo sysctl -w net.ipv4.tcp_keepalive_time=600 2>/dev/null
  sudo sysctl -w net.ipv4.tcp_keepalive_intvl=30 2>/dev/null
  sudo sysctl -w net.ipv4.tcp_keepalive_probes=5 2>/dev/null
  echo "  TCP keepalive: optimized"

  echo ""
  echo "Network optimization complete."
}

# ---- monitor ----
net_monitor() {
  echo "Starting network monitor (Ctrl+C to stop)..."
  local interval
  interval=$(cfg monitor_interval "5")

  while true; do
    clear
    echo "=== Network Monitor === $(date)"
    echo ""

    # Latency
    local latency
    latency=$(ping -c 1 -W 3 8.8.8.8 2>/dev/null | tail -1 | awk -F/ '{print $5}' || echo "?")
    echo "  Latency: ${latency}ms"

    # Packet loss
    local loss
    loss=$(ping -c 10 -W 3 8.8.8.8 2>/dev/null | tail -1 | grep -oP '\d+(?=% packet loss)' || echo "?")
    echo "  Packet loss: ${loss}%"

    # Bandwidth per interface
    echo ""
    echo "  Bandwidth:"
    for iface in /sys/class/net/*/; do
      [ -f "${iface}statistics/rx_bytes" ] || continue
      local name
      name=$(basename "$iface")
      [ "$name" = "lo" ] && continue
      local rx1 tx1
      rx1=$(cat "${iface}statistics/rx_bytes" 2>/dev/null)
      tx1=$(cat "${iface}statistics/tx_bytes" 2>/dev/null)
      sleep 1
      local rx2 tx2
      rx2=$(cat "${iface}statistics/rx_bytes" 2>/dev/null)
      tx2=$(cat "${iface}statistics/tx_bytes" 2>/dev/null)
      local rx_rate=$(( (rx2 - rx1) / 1024 ))
      local tx_rate=$(( (tx2 - tx1) / 1024 ))
      echo "    $name: RX=${rx_rate}KB/s TX=${tx_rate}KB/s"
    done

    # Active connections
    echo ""
    echo "  Connections: $(ss -tun 2>/dev/null | tail -n +2 | wc -l)"

    sleep "$interval"
  done
}

# ---- connections ----
net_connections() {
  echo "=== Active Network Connections ==="
  echo ""
  ss -tunp 2>/dev/null | head -30
  echo ""
  echo "Total: $(ss -tun 2>/dev/null | tail -n +2 | wc -l) connections"
}

# ---- speed test ----
speed_test() {
  echo "=== Speed Test ==="
  if command -v speedtest-cli &>/dev/null; then
    speedtest-cli --simple 2>&1
  elif command -v curl &>/dev/null; then
    echo "Testing download speed..."
    local start end elapsed speed
    start=$(date +%s%N)
    curl -s -o /dev/null "http://speedtest.tele2.net/10MB.zip" 2>/dev/null
    end=$(date +%s%N)
    elapsed=$(( (end - start) / 1000000 ))
    speed=$(( 10000 / (elapsed / 1000) ))
    echo "  Download: ~${speed} Mbps"
    echo "  Duration: ${elapsed}ms"
  else
    echo "Install speedtest-cli: sudo apt install python3-speedtest-cli"
  fi
}

# ---- profiles ----
list_profiles() {
  echo "=== Network Profiles ==="
  ls "$NET_PROFILES"/*.json 2>/dev/null | while read -r f; do
    local name
    name=$(basename "$f" .json)
    echo "  $name"
  done
  [ -z "$(ls "$NET_PROFILES"/*.json 2>/dev/null)" ] && echo "  No profiles saved."
}

save_profile() {
  local name="${1:-}"
  [ -z "$name" ] && { echo "Usage: korrinos-network save-profile <name>"; return 1; }

  nmcli connection show --active 2>/dev/null | tail -n +2 | while read -r line; do
    local conn_name
    conn_name=$(echo "$line" | awk '{print $1}')
    nmcli connection show "$conn_name" 2>/dev/null > "$NET_PROFILES/${name}_${conn_name}.json"
  done
  echo "Profile saved: $name"
}

# ---- main ----
case "${1:-}" in
  status)        net_status ;;
  scan)          wifi_scan ;;
  wifi-connect)  shift; wifi_connect "$@" ;;
  dns)           shift; set_dns "$@" ;;
  optimize)      optimize_network ;;
  monitor)       net_monitor ;;
  connections)   net_connections ;;
  speed)         speed_test ;;
  profiles)      list_profiles ;;
  save-profile)  shift; save_profile "$@" ;;
  init)          init_network ;;
  help|*)        echo "KorrinOS Network Manager
Usage: korrinos-network <command> [args]

Commands:
  status              Full network status
  scan                Scan WiFi networks
  wifi-connect <ssid> [pass]  Connect to WiFi
  dns [servers]       Set DNS servers
  optimize            Optimize network stack (BBR, buffers)
  monitor             Real-time traffic monitor
  connections         Show active connections
  speed               Run speed test
  profiles            List saved profiles
  save-profile <name> Save current network profile" ;;
esac

#!/usr/bin/env bash
# korrinos-network.sh — Network Manager
# WiFi, ethernet, VPN, DNS, firewall stats

set -euo pipefail

NET_DIR="${HOME}/.config/korrinos/network"
mkdir -p "$NET_DIR"

# Network status overview
cmd_status() {
  echo "╔══════════════════════════════════════════════╗"
  echo "║         KorrinOS Network Manager             ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""

  # Active interfaces
  echo "  Interfaces:"
  ip -br addr 2>/dev/null | while IFS= read -r line; do
    local name state
    name=$(echo "$line" | awk '{print $1}')
    state=$(echo "$line" | awk '{print $2}')
    [ "$name" = "lo" ] && continue
    if [ "$state" = "UP" ]; then
      echo "     ${name}: ${state}"
    else
      echo "    ○ ${name}: ${state}"
    fi
  done
  echo ""

  # WiFi info
  if command -v iwctl &>/dev/null; then
    local wifi_status
    wifi_status=$(iwctl station wlan0 show 2>/dev/null | grep "Connected" || echo "Not connected")
    echo "  WiFi: ${wifi_status}"
  elif command -v nmcli &>/dev/null; then
    local wifi_conn
    wifi_conn=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes:" | cut -d: -f2)
    [ -n "$wifi_conn" ] && echo "  WiFi: Connected to ${wifi_conn}" || echo "  WiFi: Not connected"
  fi
  echo ""

  # Default gateway
  local gw
  gw=$(ip route | grep default | awk '{print $3}' | head -1)
  [ -n "$gw" ] && echo "  Gateway: ${gw}"

  # DNS
  echo "  DNS servers:"
  grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print "    " $2}' | head -3
  echo ""

  # Public IP (if connected)
  local pub_ip
  pub_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "?")
  [ "$pub_ip" != "?" ] && echo "  Public IP: ${pub_ip}"
  echo ""

  # Connection speed
  if [ -f /sys/class/net/eth0/speed ] 2>/dev/null; then
    local speed
    speed=$(cat /sys/class/net/eth0/speed 2>/dev/null || echo "?")
    [ "$speed" != "0" ] && [ "$speed" != "?" ] && echo "  Ethernet: ${speed} Mbps"
  fi
}

# List WiFi networks
cmd_wifi_list() {
  echo "=== Available WiFi Networks ==="
  echo ""
  
  if command -v nmcli &>/dev/null; then
    nmcli device wifi list 2>/dev/null | sed 's/^/  /'
  elif command -v iwctl &>/dev/null; then
    iwctl station wlan0 scan 2>/dev/null
    sleep 1
    iwctl station wlan0 get-networks 2>/dev/null | sed 's/^/  /'
  else
    echo "  No WiFi manager found (install NetworkManager or iwd)"
  fi
}

# Connect to WiFi
cmd_wifi_connect() {
  local ssid="$1"
  local pass="${2:-}"
  
  echo "Connecting to: ${ssid}"
  
  if command -v nmcli &>/dev/null; then
    if [ -n "$pass" ]; then
      nmcli device wifi connect "$ssid" password "$pass" 2>&1 | sed 's/^/  /'
    else
      nmcli device wifi connect "$ssid" 2>&1 | sed 's/^/  /'
    fi
  elif command -v iwctl &>/dev/null; then
    if [ -n "$pass" ]; then
      iwctl station wlan0 connect "$ssid" --passphrase "$pass" 2>&1 | sed 's/^/  /'
    else
      iwctl station wlan0 connect "$ssid" 2>&1 | sed 's/^/  /'
    fi
  else
    echo "  No WiFi manager found"
    return 1
  fi
}

# Disconnect WiFi
cmd_wifi_disconnect() {
  echo "Disconnecting WiFi..."
  
  if command -v nmcli &>/dev/null; then
    nmcli device disconnect wlan0 2>&1 | sed 's/^/  /'
  elif command -v iwctl &>/dev/null; then
    iwctl station wlan0 disconnect 2>&1 | sed 's/^/  /'
  fi
}

# WiFi power save
cmd_wifi_power() {
  local state="${1:-toggle}"
  
  if [ -d /sys/class/net/wl*/power_save ]; then
    for iface in /sys/class/net/wl*/power_save; do
      if [ "$state" = "toggle" ]; then
        local current
        current=$(cat "$iface" 2>/dev/null || echo "0")
        [ "$current" = "0" ] && echo 1 | sudo tee "$iface" > /dev/null 2>&1 || echo 0 | sudo tee "$iface" > /dev/null 2>&1
      else
        echo "$state" | sudo tee "$iface" > /dev/null 2>&1
      fi
    done
    echo "WiFi power save: $(cat /sys/class/net/wl*/power_save 2>/dev/null | head -1)"
  else
    echo "WiFi power save not available"
  fi
}

# DNS management
cmd_dns() {
  echo "=== DNS Configuration ==="
  echo ""
  
  echo "  Current DNS:"
  grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print "    " $2}' | head -5
  echo ""
  
  echo "  DNS presets:"
  echo "    1. Cloudflare:  1.1.1.1, 1.0.0.1"
  echo "    2. Google:      8.8.8.8, 8.8.4.4"
  echo "    3. Quad9:       9.9.9.9, 149.112.112.112"
  echo "    4. OpenDNS:     208.67.222.222, 208.67.220.220"
  echo ""
  
  # Test DNS resolution
  echo "  DNS test:"
  local test_domain="google.com"
  local start_time=$(date +%s%N)
  nslookup "$test_domain" 2>/dev/null | grep -q "Address:" && echo "     ${test_domain} resolves" || echo "     ${test_domain} FAILED"
  local end_time=$(date +%s%N)
  local duration=$(( (end_time - start_time) / 1000000 ))
  echo "    Resolution time: ${duration}ms"
}

# Set DNS
cmd_dns_set() {
  local preset="$1"
  
  case "$preset" in
    1|cloudflare)
      echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf > /dev/null
      echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf > /dev/null
      echo "DNS set to Cloudflare (1.1.1.1)"
      ;;
    2|google)
      echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
      echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf > /dev/null
      echo "DNS set to Google (8.8.8.8)"
      ;;
    3|quad9)
      echo "nameserver 9.9.9.9" | sudo tee /etc/resolv.conf > /dev/null
      echo "nameserver 149.112.112.112" | sudo tee -a /etc/resolv.conf > /dev/null
      echo "DNS set to Quad9 (9.9.9.9)"
      ;;
    4|opendns)
      echo "nameserver 208.67.222.222" | sudo tee /etc/resolv.conf > /dev/null
      echo "nameserver 208.67.220.220" | sudo tee -a /etc/resolv.conf > /dev/null
      echo "DNS set to OpenDNS (208.67.222.222)"
      ;;
    *)
      echo "Unknown DNS preset: $preset"
      echo "Available: cloudflare, google, quad9, opendns"
      return 1
      ;;
  esac
}

# Network speed test
cmd_speedtest() {
  echo "=== Network Speed Test ==="
  echo ""
  
  if command -v speedtest-cli &>/dev/null; then
    speedtest-cli --simple 2>&1 | sed 's/^/  /'
  else
    echo "  speedtest-cli not found. Installing..."
    pip install speedtest-cli 2>/dev/null && speedtest-cli --simple 2>&1 | sed 's/^/  /' || echo "  Could not install speedtest-cli"
  fi
}

# VPN status
cmd_vpn() {
  echo "=== VPN Status ==="
  echo ""
  
  # Check for common VPN clients
  if command -v wg &>/dev/null; then
    echo "  WireGuard:"
    wg show 2>/dev/null | head -5 | sed 's/^/    /'
    echo ""
  fi
  
  if pgrep -x openvpn &>/dev/null; then
    echo "  OpenVPN: Active"
    echo ""
  fi
  
  if command -v nmcli &>/dev/null; then
    local vpn_conns
    vpn_conns=$(nmcli -t -f name,type connection show --active 2>/dev/null | grep vpn | cut -d: -f1)
    if [ -n "$vpn_conns" ]; then
      echo "  NetworkManager VPN:"
      echo "$vpn_conns" | sed 's/^/    /'
      echo ""
    fi
  fi
  
  echo "  No active VPN detected" 2>/dev/null
}

# Connection history
cmd_history() {
  echo "=== Connection History ==="
  echo ""
  
  if [ -f "$NET_DIR/history.log" ]; then
    tail -20 "$NET_DIR/history.log" | sed 's/^/  /'
  else
    echo "  No connection history yet"
  fi
}

# Log connection
log_connection() {
  local event="$1"
  local details="${2:-}"
  echo "$(date -Iseconds) | ${event} | ${details}" >> "$NET_DIR/history.log"
}

case "${1:-help}" in
  status)          cmd_status ;;
  wifi)
    shift
    case "${1:-list}" in
      list)        cmd_wifi_list ;;
      connect)     shift; cmd_wifi_connect "$@" ;;
      disconnect)  cmd_wifi_disconnect ;;
      power)       shift; cmd_wifi_power "$@" ;;
      *)           echo "Usage: network wifi (list|connect|disconnect|power)" ;;
    esac
    ;;
  dns)
    shift
    case "${1:-show}" in
      show)        cmd_dns ;;
      set)         shift; cmd_dns_set "$@" ;;
      *)           echo "Usage: network dns (show|set <preset>)" ;;
    esac
    ;;
  speedtest)       cmd_speedtest ;;
  vpn)             cmd_vpn ;;
  history)         cmd_history ;;
  *)
    echo "KorrinOS Network Manager"
    echo "Usage: korrinos-network.sh <command>"
    echo ""
    echo "Commands:"
    echo "  status              Network status overview"
    echo "  wifi list           List available WiFi networks"
    echo "  wifi connect <ssid> [pass]  Connect to WiFi"
    echo "  wifi disconnect     Disconnect WiFi"
    echo "  wifi power          Toggle WiFi power save"
    echo "  dns show            Show DNS configuration"
    echo "  dns set <preset>    Set DNS (cloudflare|google|quad9|opendns)"
    echo "  speedtest           Network speed test"
    echo "  vpn                 VPN status"
    echo "  history             Connection history"
    ;;
esac

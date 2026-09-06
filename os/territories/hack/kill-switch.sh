#!/bin/bash
# TinkerOS Kill Switch + Monitor Mode engine (HACK territory)
# 1) Kill switch: physically detach a network interface from the default
#    system stack and hand it to a scoped workspace; blocks telemetry.
# 2) Monitor mode: switch a wireless NIC into monitor mode (frame capture)
#    and (with consent/permission) enable raw-capable tooling.
#
# IMPORTANT: monitoring networks you do not own / lack authorization to test
# is illegal in most jurisdictions. This tool is for authorized security
# work on your own hardware and networks only.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

list_ifaces() {
  command -v ip >/dev/null 2>&1 && ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$'
}

killswitch_down() {
  local iface="${1:-}"
  [ -z "$iface" ] && { echo "Specify interface (see list)."; return 1; }
  echo "Kill switch: taking $iface down and removing default routes..."
  sudo ip link set "$iface" down 2>/dev/null || true
  # isolate: remove it from any bridge (hand to the hack workspace)
  sudo ip route flush dev "$iface" 2>/dev/null || true
  echo "Interface $iface is now detached/offline."
}

killswitch_assigned() {  # pass interface to a scoped network namespace
  local iface="$1" ns="$2"
  sudo ip netns add "$ns" 2>/dev/null || true
  sudo ip link set "$iface" netns "$ns" 2>/dev/null
  echo "Moved $iface into network namespace '$ns' (isolated)."
  echo "  Run commands inside: sudo ip netns exec $ns <cmd>"
}

spoof_rand_mac() {
  local iface="$1"; local new
  new="02:$(od -An -N5 -tx1 /dev/urandom | tr -d ' \n' | sed 's/\(..\)/:\1/g')"
  echo "Setting $iface MAC to randomized $new"
  sudo ip link set "$iface" address "$new" 2>/dev/null && echo "OK" || echo "need root / interface up restrictions"
}

monitor_on() {
  local iface="$1"
  echo "Switching $iface to monitor mode..."
  sudo ip link set "$iface" down 2>/dev/null || true
  sudo iw dev "$iface" set type monitor 2>/dev/null || {
    sudo airmon-ng start "$iface" 2>/dev/null || echo "need airmon-ng (aircrack-ng) or supported driver";
  }
  sudo ip link set "$iface" up 2>/dev/null || true
  echo "Interface $iface set to monitor mode."
}

monitor_off() {
  local iface="$1"
  sudo ip link set "$iface" down 2>/dev/null || true
  sudo iw dev "$iface" set type managed 2>/dev/null || sudo airmon-ng stop "$iface" 2>/dev/null || true
  sudo ip link set "$iface" up 2>/dev/null || true
  echo "Interface $iface returned to managed (client) mode."
}

scan_edr() {  # fast friendly scan helper using nmap if present
  if has nmap; then
    echo "Running friendly local scan (authorized use only):"
    sudo nmap -sn 192.168.1.0/24 2>/dev/null | head -20 || true
  else
    echo "nmap not installed."
  fi
}

status() {
  echo "Kill Switch / Monitor status:"
  local iface
  for iface in $(list_ifaces); do
    local mode
    mode=$(iw dev "$iface" info 2>/dev/null | awk -F'[ \t]+' '/type/{print $2}')
    printf '  %-6s mode=%s\n' "$iface" "${mode:-n/a}"
  done
}

case "${1:-}" in
  list) list_ifaces ;;
  down|kill) shift; killswitch_down "$@" ;;
  ns|namespace) shift; killswitch_assigned "$@" ;;
  mac|spoof) shift; spoof_rand_mac "$@" ;;
  mon|monitor-on) shift; monitor_on "$@" ;;
  monoff|monitor-off) shift; monitor_off "$@" ;;
  scan) scan_edr ;;
  status) status ;;
  *) echo "TinkerOS Kill-Switch / Monitor engine
Usage: ${0##*/} <list|kill <iface>|ns <iface> <namespace>|mac <iface>|monitor-on|monitor-off <iface>|scan|status>
MONITORING/AUDITING UNOWNED NETWORKS WITHOUT AUTHORIZATION IS ILLEGAL. Test only your own hardware." ;;
esac

#!/bin/bash
# TinkerOS Kernel-Level Reverse-Proxy (HACK territory)
# Forces ALL outbound traffic from a specific workspace through a multi-hop
# proxy chain (Tor / WireGuard mesh) at the routing layer, with fail-closed
# semantics so no packet leaks the real IP when the chain drops.
#
# This uses policy routing (ip rule + ip route) per network namespace:
#   - traffic from the hack workspace is marked and routed into the chain
#   - if the chain is down (no route), the packet is dropped (fail-closed)
#
# NETWORKING/PRIVACY: Tor is illegal or restricted in some jurisdictions.
# Misconfiguring routing can leak. Use responsibly and understand the policy.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

NS="tinker-proxy"
TABLE=100
MARK=0x100

setup_ns() {
  sudo ip netns add "$NS" 2>/dev/null || true
  sudo ip rule add fwmark $MARK table $TABLE pref 100 2>/dev/null || true
  echo "Network namespace '$NS' + policy routing table $TABLE configured."
}

# Route a workspace's traffic through the proxy chain.
force_proxy() {
  local gw="${1:-10.0.0.1}" dev="${2:-tun0}"
  echo "Forcing hack-workspace traffic through $gw via $dev (fail-closed)..."
  sudo ip route add default via "$gw" dev "$dev" table $TABLE 2>/dev/null || \
    sudo ip route replace default via "$gw" dev "$dev" table $TABLE
  # mark workspace sockets
  sudo iptables -t mangle -A OUTPUT -m owner --uid-owner "$(whoami)" -j MARK --set-mark $MARK 2>/dev/null || true
  echo "Traffic for UID $(whoami) now marked and routed through proxy table."
}

fail_closed() {  # drop any packets that can't reach the chain
  echo "Setting fail-closed: unmatched marked packets are dropped..."
  sudo iptables -t mangle -A OUTPUT -m mark --mark $MARK -j DROP 2>/dev/null || true
  echo "Fail-closed enabled."
}

open() {
  local device="$1"
  has wg-quick && { echo "Bringing up $device"; sudo wg-quick up "$device" 2>&1 | tail -5; }
  has tor && { echo "Starting tor service"; sudo systemctl start tor 2>/dev/null || true; }
  echo "Proxy chain boots."
}

status() {
  echo "Reverse-proxy status:"
  echo "  ns: $NS, table $TABLE, mark 0x$MARK"
  sudo ip rule show 2>/dev/null | grep -E "0x|$TABLE" || true
  sudo ip route show table $TABLE 2>/dev/null | head || true
  sudo iptables -t mangle -L OUTPUT 2>/dev/null | grep -i mark || true
  echo "External IP check (should show the proxy exit, not yours):"
  curl -s --max-time 5 https://ifconfig.me 2>/dev/null && echo "" || echo "  (offline/blocked)"
}

disable() {
  sudo ip rule del fwmark $MARK 2>/dev/null || true
  sudo iptables -t mangle -D OUTPUT -m mark --mark $MARK -j DROP 2>/dev/null || true
  sudo ip netns del "$NS" 2>/dev/null || true
  echo "Reverse-proxy disabled."
}

case "${1:-}" in
  setup) setup_ns ;;
  force) shift; force_proxy "$@" ;;
  closed|fail) fail_closed ;;
  up|open) shift; open "$@" ;;
  status) status ;;
  off|disable) disable ;;
  *) echo "TinkerOS Kernel Reverse-Proxy
Usage: ${0##*/} <setup|force <gw> <dev>|closed|up <device>|status|off>
Fail-closed multi-hop proxying via policy routing. Respect law/Tor policy." ;;
esac

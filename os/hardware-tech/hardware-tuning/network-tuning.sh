#!/bin/bash
# TinkerOS Network Tuning - WiFi power, ring buffers, offloads, WoL, interrupt coalescing
case "${1:-status}" in
  status)
    echo "=== Network Status ==="
    ip -brief addr 2>/dev/null | sed 's/^/  /'
    echo "  WiFi power: $(iwconfig 2>/dev/null | grep "Power Management" | head -1 || echo N/A)"
    ;;
  power) iwconfig ${2:-wlan0} power ${3:-on} 2>/dev/null && echo "WiFi power: ${3:-on}" || echo "iwconfig unavailable" ;;
  ring) ethtool -g ${2:-eth0} 2>/dev/null | head -8 | sed 's/^/  /' || echo "ethtool unavailable" ;;
  offload) ethtool -K ${2:-eth0} tso ${3:-on} gro ${3:-on} 2>/dev/null && echo "Offloads: $3" || echo "ethtool unavailable" ;;
  *) echo "Usage: $0 {status|power <iface> <on|off>|ring <iface>|offload <iface> <on|off>}";;
esac

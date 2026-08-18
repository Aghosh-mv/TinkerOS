#!/bin/bash
# TinkerOS VPN Manager
echo "=== TinkerOS VPN Manager ==="
echo ""
if command -v nmcli &>/dev/null; then
    echo "VPN connections:"
    nmcli connection show 2>/dev/null | grep -i vpn | sed 's/^/  /' || echo "  none configured"
    echo ""
    echo "Active: $(nmcli connection show --active 2>/dev/null | grep -i vpn | awk '{print $1}' || echo none)"
else
    echo "  NetworkManager not available"
fi

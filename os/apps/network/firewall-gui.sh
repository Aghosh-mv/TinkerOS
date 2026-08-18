#!/bin/bash
# TinkerOS Firewall GUI
echo "=== TinkerOS Firewall ==="
echo ""
if command -v ufw &>/dev/null; then
    echo "UFW status: $(ufw status 2>/dev/null | head -1)"
elif command -v firewall-cmd &>/dev/null; then
    echo "firewalld: $(firewall-cmd --state 2>/dev/null)"
else
    echo "  No firewall tool (ufw/firewalld)"
fi

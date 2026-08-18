#!/bin/bash
# TinkerOS Network Monitor
echo "=== TinkerOS Network Monitor ==="
echo ""
echo "Interfaces:"
ip -brief addr 2>/dev/null | sed 's/^/  /' || echo "  (ip unavailable)"
echo ""
echo "Active connections:"
ss -tun 2>/dev/null | head -10 | sed 's/^/  /' || echo "  (ss unavailable)"
echo ""
echo "Public IP: $(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo unknown)"

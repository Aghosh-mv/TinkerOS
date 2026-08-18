#!/bin/bash
# TinkerOS Fast Boot - Boot optimization
echo "=== TinkerOS Fast Boot ==="
echo ""
echo "Boot time: $(systemd-analyze 2>/dev/null | grep "Startup finished" | sed 's/.*= //' || echo unknown)"
echo ""
echo "Slowest boot units:"
systemd-analyze blame 2>/dev/null | head -5 | sed 's/^/  /' || echo "  (systemd-analyze unavailable)"

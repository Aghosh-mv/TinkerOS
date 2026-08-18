#!/bin/bash
# TinkerOS Printer Manager
echo "=== TinkerOS Printer Manager ==="
echo ""
if command -v lpstat &>/dev/null; then
    echo "Configured printers:"
    lpstat -p 2>/dev/null | sed 's/^/  /' || echo "  none"
else
    echo "  CUPS not available"
fi

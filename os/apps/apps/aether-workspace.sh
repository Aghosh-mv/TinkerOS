#!/bin/bash
# TinkerOS Aether Workspace launcher (Control Center integration)
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aether-workspace"
echo "=== TinkerOS Aether Workspace ==="
case "${1:-status}" in
    status)
        [ -f "$APP_DIR/package.json" ] && echo "  Status: bundled (v$(grep -o '"version": *"[^"]*"' "$APP_DIR/package.json" | cut -d'"' -f4 2>/dev/null || echo 1.0.0))"
        echo "  Run:     bun dev  (in $APP_DIR)"
        ;;
    serve)
        echo "  Starting Aether dev server..."
        (cd "$APP_DIR" && bun dev) 2>/dev/null || echo "  bun not installed — run: cd $APP_DIR && bun dev"
        ;;
    *)
        echo "Usage: aether-workspace [status|serve]"
        ;;
esac
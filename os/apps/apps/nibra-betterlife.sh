#!/bin/bash
# TinkerOS Nibra BetterLife launcher (Control Center integration)
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nibra-betterlife"
echo "=== TinkerOS Nibra BetterLife ==="
case "${1:-status}" in
    status)
        [ -f "$APP_DIR/package.json" ] && echo "  Status: bundled (v$(grep -o '"version": *"[^"]*"' "$APP_DIR/package.json" | cut -d'"' -f4 2>/dev/null || echo 1.0.0))"
        echo "  Run:     bun run dev  (web) | npm run desktop  (electron)"
        ;;
    serve)
        echo "  Starting Nibra dev server..."
        (cd "$APP_DIR" && bun run dev) 2>/dev/null || echo "  bun not installed — run: cd $APP_DIR && bun run dev"
        ;;
    *)
        echo "Usage: nibra-betterlife [status|serve]"
        ;;
esac
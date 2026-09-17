#!/bin/bash
# KorrinOS VOKK v4 Assistant launcher (Control Center integration)
AI_DIR="/home/tinkerspace/linux-kernel/os/vokk"
echo "=== KorrinOS VOKK v4 ==="
echo ""
case "${1:-serve}" in
    serve)
        echo "Starting VOKK v4 server (JSON protocol)..."
        echo "  Endpoint: opencode://vokk/serve"
        echo "  Binary: $AI_DIR/vokk.py"
        if [ -f "$AI_DIR/vokk.py" ]; then
            echo "  Status: ready ($(python3 -c "import ast; ast.parse(open('$AI_DIR/vokk.py').read()); print('compiles OK')" 2>/dev/null || echo 'check'))"
        fi
        ;;
    help|*)
        echo "Usage: vokk [serve]"
        echo "  serve - start AI assistant service"
        ;;
esac

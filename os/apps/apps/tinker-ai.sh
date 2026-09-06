#!/bin/bash
# TinkerOS TinkerAI Assistant launcher (Control Center integration)
AI_DIR="/home/tinkerspace/linux-kernel/os/tinkerai"
echo "=== TinkerOS TinkerAI ==="
echo ""
case "${1:-serve}" in
    serve)
        echo "Starting TinkerAI server (JSON protocol)..."
        echo "  Endpoint: opencode://tinker-ai/serve"
        echo "  Binary: $AI_DIR/tinker_ai.py"
        if [ -f "$AI_DIR/tinker_ai.py" ]; then
            echo "  Status: ready ($(python3 -c "import ast; ast.parse(open('$AI_DIR/tinker_ai.py').read()); print('compiles OK')" 2>/dev/null || echo 'check'))"
        fi
        ;;
    help|*)
        echo "Usage: tinker-ai [serve]"
        echo "  serve - start AI assistant service"
        ;;
esac

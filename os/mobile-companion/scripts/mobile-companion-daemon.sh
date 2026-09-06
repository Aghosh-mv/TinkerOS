#!/bin/bash
# TinkerOS Mobile Companion Daemon
# WebSocket server for mobile companion protocol (stdlib Python RFC 6455)

DAEMON_PORT=8766
DAEMON_TOKEN="tinkeros-default"
DAEMON_WS_DIR="$HOME/.tinker/mobile-companion"
DAEMON_LOG="$HOME/.tinker/mobile-companion.log"
SERVER="$HOME/.tinker/mobile-companion/mobile-companion-server.py"
PIDFILE="$DAEMON_WS_DIR/daemon.pid"

mkdir -p "$DAEMON_WS_DIR"

# Install the server script into the per-user runtime dir
install_server() {
    cp "$(dirname "$0")/mobile-companion-server.py" "$SERVER"
    chmod +x "$SERVER"
}

# Generate QR/pairing code
generate_qr() {
    local code="$1"
    echo "Pairing code: $code"
    echo "Scan with: mobile companion app"
}

start_server() {
    install_server
    TINKER_WS_PORT="$DAEMON_PORT" \
    TINKER_WS_TOKEN="$DAEMON_TOKEN" \
    nohup python3 "$SERVER" >> "$DAEMON_LOG" 2>&1 &
    echo $! > "$PIDFILE"
}

case "${1:-}" in
    start)
        echo "Starting Mobile Companion Daemon..."
        echo "Port: $DAEMON_PORT"
        echo "Token: $DAEMON_TOKEN"
        if command -v python3 >/dev/null 2>&1; then
            start_server
            echo "WebSocket: ws://$(hostname -I 2>/dev/null | awk '{print $1}'):$DAEMON_PORT/ws?token=$DAEMON_TOKEN"
            sleep 1
            echo "Daemon log: $DAEMON_LOG"
            echo "Status: $(grep -q listening "$DAEMON_LOG" && echo RUNNING || echo STARTING)"
        else
            echo "ERROR: python3 not installed — required for the WebSocket server"
            exit 1
        fi
        ;;
    stop)
        if [ -f "$PIDFILE" ]; then
            kill "$(cat "$PIDFILE")" 2>/dev/null && echo "Stopped"
            rm -f "$PIDFILE"
        else
            pkill -f "mobile-companion-server.py" 2>/dev/null && echo "Stopped" || echo "Not running"
        fi
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "RUNNING (pid $(cat "$PIDFILE"))"
        else
            echo "STOPPED"
        fi
        ;;
    pair)
        generate_qr "$2"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|pair [code]}"
        echo "  start   - Start the mobile companion WebSocket daemon"
        echo "  stop    - Stop the daemon"
        echo "  status  - Check daemon status"
        echo "  pair    - Generate QR/pairing code"
        ;;
esac

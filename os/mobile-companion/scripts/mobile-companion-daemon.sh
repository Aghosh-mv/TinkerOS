#!/bin/bash
# TinkerOS Mobile Companion Daemon
# WebSocket server for mobile companion protocol

DAEMON_PORT=8766
DAEMON_TOKEN="tinkeros-default"
DAEMON_WS_DIR="$HOME/.tinker/mobile-companion"
DAEMON_LOG="$HOME/.tinker/mobile-companion.log"

mkdir -p "$DAEMON_WS_DIR" "$DAEMON_LOG"

# Check if websocat or ws available
check_ws_tool() {
    if command -v websocat &>/dev/null; then
        echo "websocat"
    elif command -v ws &>/dev/null; then
        echo "ws"
    elif command -v python3 &>/dev/null; then
        echo "python3"
    else
        echo "none"
    fi
}

# Generate QR code for pairing
generate_qr() {
    local code="$1"
    echo "QR Code: $code"
    echo "Scan with: mobile companion app"
    echo "Or enter code: $code"
}

# Handle incoming WebSocket message
handle_ws_message() {
    local message="$1"
    
    python3 -c "
import json, sys
message = json.loads('''$message''')
msg_type = message.get('type', 'command')
data = message.get('data', {})

type msg_type

# Remote control actions
if msg_type == 'command':
    action = data.get('action', '')
    params = data.get('params', {})
    print(f'Remote control: {action} {params}')
    
    # Example actions
    case \$action in
        media_play) print('Play') ;;
        media_pause) print('Pause') ;;
        volume_up) print('Volume up') ;;
        volume_down) print('Volume down') ;;
        lock_screen) print('Lock screen') ;;
        sleep) print('Sleep') ;;
        shutdown) print('Shutdown') ;;
        reboot) print('Reboot') ;;
    esac
    
# File transfer initiation
elif msg_type == 'file_start':
    filename = data.get('filename', '')
    filesize = data.get('filesize', 0)
    print(f'File transfer start: {filename} ({filesize} bytes)')
    
# Notification mirroring
elif msg_type == 'notification':
    title = data.get('title', '')
    body = data.get('body', '')
    print(f'Notification: {title} - {body}')
    
# Status request
elif msg_type == 'status':
    print('Sending status: CPU, RAM, battery, network')
    
# Second screen request
elif msg_type == 'second_screen':
    layout = data.get('layout', 'extend')
    print(f'Second screen setup: {layout} layout')
"
}

# Main daemon loop (simplified - would use actual WebSocket server)
case "${1:-}" in
    start)
        echo "Starting Mobile Companion Daemon..."
        echo "Port: $DAEMON_PORT"
        echo "Token: $DAEMON_TOKEN"
        echo "QR Code: "
        CODE=$(head -c 6 /dev/urandom | base64 | tr -d '=' | cut -c1-6)
        generate_qr "$CODE"
        echo "Pair by entering code: $CODE"
        echo "WebSocket: ws://$(hostname -I | awk '{print $1}'):$DAEMON_PORT/ws?device_id=\$CODE&token=$DAEMON_TOKEN"
        echo ""
        echo "Press Ctrl+C to stop"
        # In production, would start actual WebSocket server here
        while true; do
            sleep 60
        done
        ;;
    stop)
        echo "Stopping Mobile Companion Daemon"
        ;;
    pair)
        generate_qr "$2"
        ;;
    *)
        echo "Usage: $0 {start|stop|pair [code]}"
        echo "  start   - Start the mobile companion daemon"
        echo "  stop    - Stop the daemon"
        echo "  pair    - Generate QR code/pairing code"
        ;;
    esac

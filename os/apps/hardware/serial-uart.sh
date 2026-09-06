#!/bin/bash
# TinkerOS Serial/UART - Serial port manager

set -e

SERIAL_DIR="$HOME/.tinker/serial"
CONFIG_FILE="$SERIAL_DIR/config.conf"

mkdir -p "$SERIAL_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Serial/UART Configuration
ENABLED=true
DEFAULT_BAUD=115200
DEFAULT_BITS=8
DEFAULT_STOP=1
DEFAULT_PARITY=none
EOF
    fi
}

# List serial ports
list_ports() {
    echo "Serial Ports:"
    echo ""
    
    ls /dev/tty* 2>/dev/null | grep -E "ttyS|ttyUSB|ttyACM" || echo "No serial ports"
    
    if command -v setserial >/dev/null 2>&1; then
        echo ""
        setserial -g /dev/tty* 2>/dev/null | grep -v "unknown" || true
    fi
}

# Open serial monitor
monitor() {
    local port=${1:-/dev/ttyUSB0}
    local baud=${2:-115200}
    
    echo "Opening serial monitor: $port @ $baud"
    echo "Press Ctrl+A then X to exit"
    echo ""
    
    if command -v screen >/dev/null 2>&1; then
        screen "$port" "$baud"
    elif command -v minicom >/dev/null 2>&1; then
        minicom -b "$baud" -D "$port"
    else
        echo "Install screen or minicom"
        echo "  sudo apt install screen"
    fi
}

# Send data
send() {
    local port=$1
    local data=$2
    
    echo "Sending to $port: $data"
    
    echo "$data" > "$port" 2>/dev/null || echo "Could not send"
}

show_help() {
    echo "Usage: tinker-serial [command]"
    echo ""
    echo "Commands:"
    echo "  list              List serial ports"
    echo "  monitor [port] [baud] Open serial monitor"
    echo "  send <port> <data> Send data"
    echo "  help              Show this help"
}

init

case "$1" in
    list|ports) list_ports ;;
    monitor|screen) monitor "$2" "$3" ;;
    send|write) send "$2" "$3" ;;
    *) show_help ;;
esac

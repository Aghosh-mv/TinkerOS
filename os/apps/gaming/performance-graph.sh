#!/bin/bash
# TinkerOS Performance Graph - Real-time performance overlay

set -e

GRAPH_DIR="$HOME/.tinker/perf-graph"
CONFIG_FILE="$GRAPH_DIR/config.conf"

mkdir -p "$GRAPH_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Performance Graph Configuration
ENABLED=false
SHOW_CPU=true
SHOW_MEMORY=true
SHOW_DISK=true
SHOW_NETWORK=true
UPDATE_INTERVAL=1
GRAPH_STYLE=minimal
EOF
    fi
}

# Show performance graph
show_graph() {
    echo "Performance Monitor"
    echo ""
    
    while true; do
        clear
        echo "=== TinkerOS Performance ==="
        echo ""
        
        # CPU
        local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
        echo "CPU: ${cpu}%"
        
        # Memory
        local mem=$(free -m | awk '/^Mem:/{printf "%.1f", $3/$2*100}')
        echo "RAM: ${mem}%"
        
        # Disk
        local disk=$(df / | tail -1 | awk '{print $5}')
        echo "Disk: ${disk}"
        
        # Network
        local net=$(cat /proc/net/dev | awk 'NR>2{rx+=$2; tx+=$10}END{printf "RX:%.1f TX:%.1f", rx/1048576, tx/1048576}')
        echo "Net: $net MB"
        
        echo ""
        echo "Press Ctrl+C to exit"
        
        sleep ${1:-1}
    done
}

show_help() {
    echo "Usage: tinker-perf [command]"
    echo ""
    echo "Commands:"
    echo "  show [interval]   Show performance graph"
    echo "  help              Show this help"
}

init

case "$1" in
    show|monitor) show_graph "$2" ;;
    *) show_help ;;
esac

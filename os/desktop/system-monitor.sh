#!/bin/bash
# TinkerOS System Monitor GUI

set -e

# Get CPU usage
get_cpu() {
    top -bn1 | grep "Cpu(s)" | awk '{print int($2)}'
}

# Get memory usage
get_memory() {
    free | grep Mem | awk '{printf "%d", $3/$2 * 100}'
}

# Get disk usage
get_disk() {
    df -h / | tail -1 | awk '{print $5}' | tr -d '%'
}

# Get network usage
get_network() {
    local rx=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | awk '{s+=$1}END{print s}')
    local tx=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | awk '{s+=$1}END{print s}')
    echo "RX: $((rx/1024/1024))MB TX: $((tx/1024/1024))MB"
}

# Get uptime
get_uptime() {
    uptime -p 2>/dev/null || uptime
}

# Get top processes
get_top_processes() {
    ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "%-20s CPU:%5s%% MEM:%5s%%\n", $11, $3, $4}'
}

# Show dashboard
show_dashboard() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                 SYSTEM MONITOR                           ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    # CPU bar
    local cpu=$(get_cpu)
    local cpu_bar=$(printf '%0.s█' $(seq 1 $((cpu/5))))
    local cpu_empty=$(printf '%0.s░' $(seq 1 $((20-cpu/5))))
    echo "  CPU:    [$cpu_bar$cpu_empty] $cpu%"
    
    # Memory bar
    local mem=$(get_memory)
    local mem_bar=$(printf '%0.s█' $(seq 1 $((mem/5))))
    local mem_empty=$(printf '%0.s░' $(seq 1 $((20-mem/5))))
    echo "  RAM:    [$mem_bar$mem_empty] $mem%"
    
    # Disk bar
    local disk=$(get_disk)
    local disk_bar=$(printf '%0.s█' $(seq 1 $((disk/5))))
    local disk_empty=$(printf '%0.s░' $(seq 1 $((20-disk/5))))
    echo "  DISK:   [$disk_bar$disk_empty] $disk%"
    
    echo ""
    echo "  Network: $(get_network)"
    echo "  Uptime:  $(get_uptime)"
    echo ""
    echo "  Top Processes:"
    get_top_processes | while read line; do
        echo "    $line"
    done
    echo ""
}

# Show processes
show_processes() {
    clear
    echo "Processes:"
    echo ""
    ps aux --sort=-%cpu | head -20
    echo ""
}

# Show memory details
show_memory() {
    clear
    echo "Memory Usage:"
    echo ""
    free -h
    echo ""
}

# Show disk details
show_disk() {
    clear
    echo "Disk Usage:"
    echo ""
    df -h
    echo ""
}

# Kill process
kill_process() {
    local pid=$1
    read -p "Kill process $pid? (y/N): " confirm
    [ "$confirm" = "y" ] && kill $pid
}

show_help() {
    echo "Usage: tinker-monitor [command]"
    echo ""
    echo "Commands:"
    echo "  dashboard         Show full dashboard"
    echo "  processes         Show processes"
    echo "  memory            Show memory"
    echo "  disk              Show disk"
    echo "  kill <pid>        Kill process"
    echo "  help              Show this help"
}

case "$1" in
    dashboard|dash) show_dashboard ;;
    processes|ps) show_processes ;;
    memory|mem) show_memory ;;
    disk|df) show_disk ;;
    kill) kill_process "$2" ;;
    watch|live)
        while true; do
            show_dashboard
            sleep 2
        done
        ;;
    *) show_dashboard ;;
esac

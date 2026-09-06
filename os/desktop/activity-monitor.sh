#!/bin/bash
# TinkerOS Activity Monitor

set -e

# Show processes
show_processes() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                 ACTIVITY MONITOR                        ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "  PID    CPU%   MEM%   COMMAND"
    echo "  ─────────────────────────────────────────────────────"
    
    ps aux --sort=-%cpu | head -20 | awk '{printf "  %-7s %-6s %-6s %s\n", $2, $3, $4, $11}'
    echo ""
}

# Show top processes
show_top() {
    clear
    echo "Top Processes (by CPU):"
    echo ""
    ps aux --sort=-%cpu | head -15
    echo ""
}

# Show memory usage
show_memory() {
    clear
    echo "Memory Usage:"
    echo ""
    free -h
    echo ""
}

# Show disk usage
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
    
    if [ -n "$pid" ]; then
        read -p "Kill process $pid? (y/N): " confirm
        if [ "$confirm" = "y" ]; then
            kill $pid
            echo "Process $pid killed"
        fi
    else
        echo "Specify PID"
    fi
}

# Show system info
show_info() {
    clear
    echo "System Information:"
    echo ""
    echo "  Kernel: $(uname -r)"
    echo "  Uptime: $(uptime -p)"
    echo "  CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    echo "  RAM: $(free -h | grep Mem | awk '{print $2}')"
    echo "  Hostname: $(hostname)"
    echo ""
}

# Monitor live
live_monitor() {
    echo "Live Monitor (press q to quit)"
    echo ""
    
    while true; do
        clear
        echo "System Monitor - $(date)"
        echo ""
        
        # CPU
        local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
        echo "  CPU: ${cpu}%"
        
        # Memory
        local mem=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        echo "  RAM: ${mem}%"
        
        # Top 5 processes
        echo ""
        echo "  Top Processes:"
        ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "    %-20s CPU: %s%%  MEM: %s%%\n", $11, $3, $4}'
        
        sleep 2
    done
}

show_help() {
    echo "Usage: tinker-monitor [command]"
    echo ""
    echo "Commands:"
    echo "  processes         Show all processes"
    echo "  top               Top processes"
    echo "  memory            Memory usage"
    echo "  disk              Disk usage"
    echo "  info              System info"
    echo "  live              Live monitor"
    echo "  kill <pid>        Kill process"
    echo "  help              Show this help"
}

case "$1" in
    processes|ps)
        show_processes
        ;;
    top)
        show_top
        ;;
    memory|mem)
        show_memory
        ;;
    disk|df)
        show_disk
        ;;
    info)
        show_info
        ;;
    live|watch)
        live_monitor
        ;;
    kill)
        kill_process "$2"
        ;;
    *)
        show_processes
        ;;
esac

#!/usr/bin/env bash
# korrinos-procmon.sh — Process monitor for KorrinOS
# Shows running processes, resource usage, and allows management

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

cmd_top() {
    echo -e "${CYAN}=== Top Processes (CPU) ===${NC}"
    ps aux --sort=-%cpu | head -11
    echo ""
    echo -e "${CYAN}=== Top Processes (RAM) ===${NC}"
    ps aux --sort=-%mem | head -11
}

cmd_watch() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        echo "Usage: korrinos-procmon.sh watch <process_name>"
        return 1
    fi
    
    echo -e "${CYAN}Watching: $target${NC} (Ctrl+C to stop)"
    while true; do
        clear
        echo -e "${CYAN}=== Process Monitor: $target ===${NC} $(date)"
        echo ""
        ps aux | grep "$target" | grep -v grep || echo "Process not found"
        echo ""
        echo -e "${CYAN}=== Resource Usage ===${NC}"
        top -bn1 | head -5
        sleep 2
    done
}

cmd_kill() {
    local target="$1"
    local signal="${2:-TERM}"
    
    echo "Killing '$target' with signal $signal..."
    pkill -"$signal" "$target" 2>/dev/null && echo "Sent $signal to $target" || echo "No matching processes"
}

cmd_tree() {
    local pid="${1:-$$}"
    pstree -p "$pid" 2>/dev/null || ps --forest -o pid,ppid,cmd | head -30
}

cmd_open_files() {
    local pid="$1"
    if [ -z "$pid" ]; then
        echo "Usage: korrinos-procmon.sh files <pid>"
        return 1
    fi
    
    echo -e "${CYAN}=== Open Files for PID $pid ===${NC}"
    ls -la /proc/"$pid"/fd 2>/dev/null | head -20
    echo ""
    echo -e "${CYAN}=== Memory Maps ===${NC}"
    cat /proc/"$pid"/maps 2>/dev/null | head -10
}

cmd_resource_summary() {
    echo -e "${CYAN}=== System Resources ===${NC}"
    echo ""
    
    echo "CPU Cores: $(nproc)"
    echo "CPU Model: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "CPU Usage: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}')%"
    echo ""
    
    echo "Total RAM: $(free -h | awk '/Mem:/ {print $2}')"
    echo "Used RAM: $(free -h | awk '/Mem:/ {print $3}')"
    echo "Free RAM: $(free -h | awk '/Mem:/ {print $4}')"
    echo "Cached: $(free -h | awk '/Mem:/ {print $6}')"
    echo ""
    
    echo "Swap Total: $(free -h | awk '/Swap:/ {print $2}')"
    echo "Swap Used: $(free -h | awk '/Swap:/ {print $3}')"
    echo ""
    
    echo "Disk /: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
    echo "Disk /home: $(df -h /home 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}' || echo 'N/A')"
    echo ""
    
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        echo "CPU Temp: $(($(cat /sys/class/thermal/thermal_zone0/temp)/1000))°C"
    fi
}

case "${1:-help}" in
    top)        cmd_top ;;
    watch)      cmd_watch "${2:-}" ;;
    kill)       cmd_kill "${2:-}" "${3:-TERM}" ;;
    tree)       cmd_tree "${2:-}" ;;
    files)      cmd_open_files "${2:-}" ;;
    summary)    cmd_resource_summary ;;
    *)
        echo "KorrinOS Process Monitor"
        echo "Usage: korrinos-procmon.sh <command>"
        echo ""
        echo "Commands:"
        echo "  top            Show top processes"
        echo "  watch <name>   Watch a process in real-time"
        echo "  kill <name>    Kill a process (TERM)"
        echo "  tree [pid]     Show process tree"
        echo "  files <pid>    Show open files for PID"
        echo "  summary        Full resource summary"
        ;;
esac

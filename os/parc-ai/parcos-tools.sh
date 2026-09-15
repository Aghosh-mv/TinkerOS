#!/usr/bin/env bash
# korrinos-health.sh — System health monitor
# Shows CPU, RAM, disk, temperature, and process info

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

header() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

cmd_health() {
    header "CPU"
    if command -v mpstat &>/dev/null; then
        mpstat 1 1 | tail -1
    else
        top -bn1 | head -5
    fi

    header "Memory"
    free -h

    header "Disk Usage"
    df -h / /home 2>/dev/null | grep -v tmpfs

    header "Temperature"
    if command -v sensors &>/dev/null; then
        sensors 2>/dev/null | grep -E "Core|temp" | head -8
    elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo "CPU: $((temp/1000))°C"
    else
        echo "No temperature sensor available"
    fi

    header "Top Processes (by CPU)"
    ps aux --sort=-%cpu | head -6

    header "Top Processes (by RAM)"
    ps aux --sort=-%mem | head -6

    header "Uptime & Load"
    uptime
}

cmd_disk_analyze() {
    header "Disk Usage by Directory"
    local dir="${1:-/home}"
    du -h --max-depth=2 "$dir" 2>/dev/null | sort -rh | head -20

    header "Largest Files"
    find "$dir" -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -15 | awk '{printf "%.1fMB %s\n", $1/1048576, $2}'

    header "Trash Size"
    if [ -d "$HOME/.local/share/Trash" ]; then
        du -sh "$HOME/.local/share/Trash" 2>/dev/null || echo "Empty"
    else
        echo "No trash folder"
    fi
}

cmd_network_info() {
    header "Network Interfaces"
    ip -br addr show 2>/dev/null || ifconfig 2>/dev/null | head -10

    header "Public IP"
    curl -s ifconfig.me 2>/dev/null || echo "Cannot reach internet"

    header "DNS Servers"
    cat /etc/resolv.conf 2>/dev/null | grep nameserver | head -3

    header "Active Connections"
    ss -tuln 2>/dev/null | head -15 || netstat -tuln 2>/dev/null | head -15
}

cmd_usb_list() {
    header "USB Devices"
    if command -v lsusb &>/dev/null; then
        lsusb
    else
        ls /dev/bus/usb/ 2>/dev/null || echo "No USB subsystem"
    fi

    header "Block Devices"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null
}

cmd_screenshot() {
    local out="${1:-/tmp/screenshot_$(date +%Y%m%d_%H%M%S).png}"
    if command -v scrot &>/dev/null; then
        scrot "$out"
    elif command -v gnome-screenshot &>/dev/null; then
        gnome-screenshot -f "$out"
    elif command -v import &>/dev/null; then
        import -window root "$out"
    else
        echo "No screenshot tool found. Install scrot: sudo apt install scrot"
        return 1
    fi
    echo "Screenshot saved: $out"
}

cmd_cleanup() {
    header "Cleaning system..."
    
    # Clear package manager cache
    if command -v apt &>/dev/null; then
        sudo apt autoremove -y 2>/dev/null || true
        sudo apt clean 2>/dev/null || true
        echo "APT cache cleaned"
    fi
    
    # Clear temp files older than 7 days
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null || true
    echo "Old temp files cleaned"
    
    # Clear user cache
    rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
    rm -rf ~/.cache/pip/http 2>/dev/null || true
    echo "User cache cleaned"
    
    # Show before/after
    echo ""
    header "Disk After Cleanup"
    df -h / /home 2>/dev/null | grep -v tmpfs
}

# Dispatcher
case "${1:-help}" in
    health)     cmd_health ;;
    disk)       cmd_disk_analyze "${2:-/home}" ;;
    network)    cmd_network_info ;;
    usb)        cmd_usb_list ;;
    screenshot) cmd_screenshot "${2:-}" ;;
    cleanup)    cmd_cleanup ;;
    *)
        echo "KorrinOS System Tools"
        echo "Usage: korrinos-tools.sh <command>"
        echo ""
        echo "Commands:"
        echo "  health      System health overview (CPU, RAM, disk, temp)"
        echo "  disk [dir]  Analyze disk usage"
        echo "  network     Network info and connections"
        echo "  usb         List USB and block devices"
        echo "  screenshot  Take a screenshot"
        echo "  cleanup     Clean caches and temp files"
        ;;
esac

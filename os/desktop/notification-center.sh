#!/bin/bash
# TinkerOS Notification Center

set -e

NOTIF_DIR="$HOME/.tinker/notifications"
NOTIF_LOG="$NOTIF_DIR/history.log"
MAX_NOTIFS=50

mkdir -p "$NOTIF_DIR"

# Send notification
send_notification() {
    local title=$1
    local message=$2
    local icon=${3:-"dialog-information"}
    local urgency=${4:-"normal"}
    
    # Send via notify-send
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -i "$icon" "$title" "$message"
    fi
    
    # Log notification
    echo "$(date -Iseconds) | $title | $message" >> "$NOTIF_LOG"
    
    # Keep only recent notifications
    tail -n $MAX_NOTIFS "$NOTIF_LOG" > "$NOTIF_LOG.tmp"
    mv "$NOTIF_LOG.tmp" "$NOTIF_LOG"
}

# Show notification history
show_history() {
    echo "Notification History:"
    echo ""
    
    if [ -f "$NOTIF_LOG" ]; then
        tail -20 "$NOTIF_LOG" | while IFS='|' read -r time title msg; do
            echo "[$time] $title: $msg"
        done
    else
        echo "No notifications yet."
    fi
    echo ""
}

# Clear history
clear_history() {
    rm -f "$NOTIF_LOG"
    echo "History cleared."
}

# Monitor for system events
monitor_events() {
    echo "Monitoring system events..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        # Check battery
        if [ -f /sys/class/power_supply/BAT0/capacity ]; then
            local bat=$(cat /sys/class/power_supply/BAT0/capacity)
            local status=$(cat /sys/class/power_supply/BAT0/status)
            
            if [ "$status" = "Discharging" ] && [ "$bat" -le 20 ]; then
                send_notification "Battery Low" "Battery at $bat%" "battery-caution" "critical"
            fi
        fi
        
        # Check disk space
        local disk_usage=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
        if [ "$disk_usage" -ge 90 ]; then
            send_notification "Disk Full" "Disk usage at $disk_usage%" "drive-harddisk" "critical"
        fi
        
        sleep 60
    done
}

show_help() {
    echo "Usage: tinker-notifications [command]"
    echo ""
    echo "Commands:"
    echo "  send <title> <message>  Send notification"
    echo "  history                 Show history"
    echo "  clear                   Clear history"
    echo "  monitor                 Monitor events"
    echo "  help                    Show this help"
}

case "$1" in
    send)
        send_notification "$2" "$3" "${4:-dialog-information}" "${5:-normal}"
        ;;
    history|log)
        show_history
        ;;
    clear)
        clear_history
        ;;
    monitor)
        monitor_events
        ;;
    *)
        show_help
        ;;
esac

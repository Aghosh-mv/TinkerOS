#!/bin/bash
# TinkerOS System Tray

# Battery indicator
show_battery() {
    if [ -f /sys/class/power_supply/BAT*/capacity ]; then
        local bat=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
        local status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)
        
        case $bat in
            [0-9]|[1-2][0-9]) icon="🔋" ;;
            [3-6][0-9]) icon="🔋" ;;
            [7-9][0-9]|100) icon="🔋" ;;
        esac
        
        if [ "$status" = "Charging" ]; then
            icon="⚡"
        fi
        
        echo "$icon $bat%"
    else
        echo "🔌 AC"
    fi
}

# WiFi indicator
show_wifi() {
    if command -v iwconfig >/dev/null 2>&1; then
        local wifi=$(iwconfig 2>/dev/null | grep -o "ESSID:\"[^\"]*\"" | cut -d'"' -f2)
        if [ -n "$wifi" ]; then
            echo "📶 $wifi"
        else
            echo "📵 Disconnected"
        fi
    else
        echo "📶"
    fi
}

# Bluetooth indicator
show_bluetooth() {
    if command -v bluetoothctl >/dev/null 2>&1; then
        local bt=$(bluetoothctl show 2>/dev/null | grep "Powered" | awk '{print $2}')
        if [ "$bt" = "yes" ]; then
            echo "🔷 On"
        else
            echo "⬜ Off"
        fi
    else
        echo "🔷"
    fi
}

# Volume indicator
show_volume() {
    if command -v pactl >/dev/null 2>&1; then
        local vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1)
        local mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -o "yes\|no")
        
        if [ "$mute" = "yes" ]; then
            echo "🔇"
        else
            case $vol in
                [0-9]|1[0-9]|2[0-9]) echo "🔈 $vol" ;;
                [3-6][0-9]) echo "🔉 $vol" ;;
                [7-9][0-9]|100) echo "🔊 $vol" ;;
            esac
        fi
    else
        echo "🔊"
    fi
}

# CPU indicator
show_cpu() {
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    echo "💻 ${cpu}%"
}

# Memory indicator
show_memory() {
    local mem=$(free | grep Mem | awk '{printf "%d", $3/$2 * 100}')
    echo "🧠 ${mem}%"
}

# Disk indicator
show_disk() {
    local disk=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
    echo "💾 ${disk}%"
}

# Show all tray items
show_tray() {
    echo "$(show_battery) | $(show_volume) | $(show_wifi) | $(show_bluetooth) | $(show_cpu) | $(show_memory) | $(show_disk)"
}

# Update tray (for continuous display)
update_tray() {
    while true; do
        echo -ne "\r$(show_tray)"
        sleep 5
    done
}

case "$1" in
    battery) show_battery ;;
    wifi) show_wifi ;;
    bluetooth) show_bluetooth ;;
    volume) show_volume ;;
    cpu) show_cpu ;;
    memory) show_memory ;;
    disk) show_disk ;;
    all|tray) show_tray ;;
    watch) update_tray ;;
    *) show_tray ;;
esac

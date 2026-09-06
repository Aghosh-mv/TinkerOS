#!/bin/bash
# TinkerOS Power Manager - Advanced power profile management

set -e

POWER_DIR="$HOME/.tinker/power-manager"
CONFIG_FILE="$POWER_DIR/config.conf"
PROFILES_DIR="$POWER_DIR/profiles"

mkdir -p "$POWER_DIR" "$PROFILES_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Power Manager Configuration
DEFAULT_PROFILE=balanced
AUTO_SWITCH_BATTERY=true
BATTERY_THRESHOLD=30
NOTIFICATIONS=true
CPU_GOVERNOR_PERFORMANCE=performance
CPU_GOVERNOR_BALANCED=ondemand
CPU_GOVERNOR_POWERSAVE=powersave
EOF

    # Create default profiles
    create_profile performance "Performance" "
# Performance Profile
cpu_governor=performance
cpu_min_freq=0
cpu_max_freq=0
gpu_performance=1
disk_scheduler=none
wifi_powersave=0
bluetooth=on
backlight=100
"

    create_profile balanced "Balanced" "
# Balanced Profile
cpu_governor=ondemand
cpu_min_freq=0
cpu_max_freq=0
gpu_performance=1
disk_scheduler=mq-deadline
wifi_powersave=1
bluetooth=on
backlight=80
"

    create_profile powersave "Power Saver" "
# Power Saver Profile
cpu_governor=powersave
cpu_min_freq=800000
cpu_max_freq=2000000
gpu_performance=0
disk_scheduler=bfq
wifi_powersave=2
bluetooth=off
backlight=50
"

    create_profile ultra "Ultra Power Save" "
# Ultra Power Save Profile
cpu_governor=powersave
cpu_min_freq=400000
cpu_max_freq=1200000
gpu_performance=0
disk_scheduler=bfq
wifi_powersave=3
bluetooth=off
backlight=20
usb_autosuspend=1
"
}

create_profile() {
    local id=$1
    local name=$2
    local content=$3
    
    echo "$content" > "$PROFILES_DIR/$id.conf"
}

# Apply profile
apply_profile() {
    local profile=$1
    local profile_file="$PROFILES_DIR/$profile.conf"
    
    [ ! -f "$profile_file" ] && echo "Profile not found: $profile" && return 1
    
    echo "Applying profile: $profile"
    source "$profile_file"
    
    # CPU Governor
    if [ -n "$cpu_governor" ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "$cpu_governor" > "$cpu" 2>/dev/null || true
        done
        echo "  CPU Governor: $cpu_governor"
    fi
    
    # CPU Min/Max Frequency
    if [ -n "$cpu_min_freq" ] && [ "$cpu_min_freq" != "0" ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq; do
            echo "$cpu_min_freq" > "$cpu" 2>/dev/null || true
        done
    fi
    if [ -n "$cpu_max_freq" ] && [ "$cpu_max_freq" != "0" ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
            echo "$cpu_max_freq" > "$cpu" 2>/dev/null || true
        done
    fi
    
    # GPU Performance (Intel)
    if [ -n "$gpu_performance" ]; then
        if [ "$gpu_performance" = "1" ]; then
            echo "on" > /sys/class/drm/card0/device/power_dpm_force_performance_level 2>/dev/null || true
        else
            echo "auto" > /sys/class/drm/card0/device/power_dpm_force_performance_level 2>/dev/null || true
        fi
    fi
    
    # Disk Scheduler
    if [ -n "$disk_scheduler" ]; then
        for disk in /sys/block/sd*/queue/scheduler /sys/block/nvme*/queue/scheduler; do
            echo "$disk_scheduler" > "$disk" 2>/dev/null || true
        done
        echo "  Disk Scheduler: $disk_scheduler"
    fi
    
    # WiFi Power Save
    if [ -n "$wifi_powersave" ] && command -v iw &>/dev/null; then
        for iface in $(iw dev | grep Interface | awk '{print $2}'); do
            iw dev "$iface" set power_save "$wifi_powersave" 2>/dev/null || true
        done
        echo "  WiFi Power Save: $wifi_powersave"
    fi
    
    # Bluetooth
    if [ -n "$bluetooth" ] && command -v bluetoothctl &>/dev/null; then
        bluetoothctl power "$bluetooth" 2>/dev/null || true
        echo "  Bluetooth: $bluetooth"
    fi
    
    # Backlight
    if [ -n "$backlight" ]; then
        for bl in /sys/class/backlight/*/brightness; do
            local max=$(cat "${bl%/brightness}/max_brightness" 2>/dev/null)
            [ -n "$max" ] && echo $((max * backlight / 100)) > "$bl" 2>/dev/null || true
        done
        echo "  Backlight: $backlight%"
    fi
    
    # USB Autosuspend
    if [ -n "$usb_autosuspend" ]; then
        for usb in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do
            echo 1000 > "$usb" 2>/dev/null || true
        done
        for usb in /sys/bus/usb/devices/*/power/control; do
            echo auto > "$usb" 2>/dev/null || true
        done
        echo "  USB Autosuspend: enabled"
    fi
    
    # Save current profile
    echo "$profile" > "$POWER_DIR/current_profile"
    
    if grep -q "NOTIFICATIONS=true" "$CONFIG_FILE" 2>/dev/null; then
        notify-send "Power Profile" "Switched to $profile" 2>/dev/null || true
    fi
    
    echo "Profile applied successfully"
}

# Get current status
status() {
    echo "=== TinkerOS Power Manager ==="
    echo ""
    
    # Current profile
    local current=$(cat "$POWER_DIR/current_profile" 2>/dev/null || echo "unknown")
    echo "Current Profile: $current"
    echo ""
    
    # CPU Governor
    local gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    echo "CPU Governor: ${gov:-unknown}"
    
    # CPU Frequencies
    local min=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null)
    local max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
    local cur=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    [ -n "$cur" ] && echo "CPU Frequency: $((cur/1000)) MHz (min: $((min/1000)), max: $((max/1000)))"
    
    # Battery
    echo ""
    echo "Battery:"
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        local cap=$(cat /sys/class/power_supply/BAT0/capacity)
        local stat=$(cat /sys/class/power_supply/BAT0/status)
        echo "  Capacity: ${cap}%"
        echo "  Status: $stat"
        
        if [ "$stat" = "Discharging" ]; then
            local curr=$(cat /sys/class/power_supply/BAT0/current_now 2>/dev/null || echo 0)
            local volt=$(cat /sys/class/power_supply/BAT0/voltage_now 2>/dev/null || echo 0)
            if [ $curr -gt 0 ]; then
                local watts=$((volt * curr / 1000000000000))
                local hours=$((cap * volt / curr / 3600))
                echo "  Power Draw: ${watts}W"
                echo "  Est. Time: ${hours}h"
            fi
        fi
    else
        echo "  No battery (AC powered)"
    fi
    
    # Thermal
    echo ""
    echo "Thermal:"
    for t in /sys/class/thermal/thermal_zone*/temp; do
        local zone=$(basename $(dirname $t))
        local type=$(cat /sys/class/thermal/$zone/type 2>/dev/null)
        local temp=$(cat $t 2>/dev/null)
        [ -n "$temp" ] && printf "  %s: %d°C\n" "$type" $((temp/1000))
    done
}

# List profiles
list_profiles() {
    echo "Available Profiles:"
    echo ""
    for p in "$PROFILES_DIR"/*.conf; do
        [ -f "$p" ] || continue
        local name=$(basename "$p" .conf)
        local desc=$(grep "^#" "$p" | head -2 | tail -1 | sed 's/^# //')
        local marker=""
        [ "$name" = "$(cat $POWER_DIR/current_profile 2>/dev/null)" ] && marker=" *"
        echo "  $name$marker - $desc"
    done
}

# Auto-switch based on battery
auto_switch() {
    if ! grep -q "AUTO_SWITCH_BATTERY=true" "$CONFIG_FILE" 2>/dev/null; then
        echo "Auto-switch disabled"
        return
    fi
    
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        local cap=$(cat /sys/class/power_supply/BAT0/capacity)
        local stat=$(cat /sys/class/power_supply/BAT0/status)
        local threshold=$(grep BATTERY_THRESHOLD "$CONFIG_FILE" | cut -d= -f2)
        
        if [ "$stat" = "Discharging" ] && [ $cap -le ${threshold:-30} ]; then
            local current=$(cat "$POWER_DIR/current_profile" 2>/dev/null)
            [ "$current" != "powersave" ] && apply_profile powersave
        elif [ "$stat" = "Charging" ] && [ $cap -gt ${threshold:-30} ]; then
            local current=$(cat "$POWER_DIR/current_profile" 2>/dev/null)
            [ "$current" != "balanced" ] && apply_profile balanced
        fi
    fi
}

# Create custom profile
create_custom() {
    local name=$1
    [ -z "$name" ] && echo "Usage: $0 create <name>" && return 1
    
    echo "Creating custom profile: $name"
    echo "Enter profile settings (press Enter for defaults):"
    
    read -p "CPU Governor (performance/ondemand/powersave) [ondemand]: " gov
    gov=${gov:-ondemand}
    
    read -p "Min CPU Freq (kHz, 0 for default) [0]: " minf
    minf=${minf:-0}
    
    read -p "Max CPU Freq (kHz, 0 for default) [0]: " maxf
    maxf=${maxf:-0}
    
    read -p "Backlight % [80]: " bl
    bl=${bl:-80}
    
    cat > "$PROFILES_DIR/$name.conf" << EOF
# Custom Profile: $name
cpu_governor=$gov
cpu_min_freq=$minf
cpu_max_freq=$maxf
gpu_performance=1
disk_scheduler=mq-deadline
wifi_powersave=1
bluetooth=on
backlight=$bl
EOF
    
    echo "Profile created: $name"
}

show_help() {
    echo "Usage: tinker-power-manager [command]"
    echo ""
    echo "Commands:"
    echo "  status              Show current power status"
    echo "  apply <profile>     Apply power profile"
    echo "  list                List available profiles"
    echo "  create <name>       Create custom profile"
    echo "  auto                Run auto-switch check"
    echo "  help                Show this help"
    echo ""
    echo "Profiles: performance, balanced, powersave, ultra"
}

init

case "$1" in
    status) status ;;
    apply|set) apply_profile "$2" ;;
    list) list_profiles ;;
    create) create_custom "$2" ;;
    auto) auto_switch ;;
    *) show_help ;;
esac
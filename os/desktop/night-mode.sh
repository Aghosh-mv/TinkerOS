#!/bin/bash
# TinkerOS Night Mode (Blue Light Filter)

set -e

NIGHT_MODE_FILE="/tmp/tinker-night-mode"
NIGHT_TEMP=4500  # Color temperature (lower = warmer)

# Enable night mode
enable_night_mode() {
    local temp=${1:-$NIGHT_TEMP}
    
    echo "Enabling night mode..."
    
    if command -v redshift >/dev/null 2>&1; then
        redshift -O "$temp"
    elif command -v gamma >/dev/null 2>&1; then
        gamma -g 1.0 -m 1.0 -b 1.0 -t "$temp"
    else
        # Fallback to xrandr gamma
        xrandr --output $(xrandr | grep " connected" | head -1 | awk '{print $1}') --gamma 1.0:0.9:0.8
    fi
    
    touch "$NIGHT_MODE_FILE"
    echo "Night mode enabled (temperature: ${temp}K)"
}

# Disable night mode
disable_night_mode() {
    echo "Disabling night mode..."
    
    if command -v redshift >/dev/null 2>&1; then
        redshift -x
    else
        xrandr --output $(xrandr | grep " connected" | head -1 | awk '{print $1}') --gamma 1.0:1.0:1.0
    fi
    
    rm -f "$NIGHT_MODE_FILE"
    echo "Night mode disabled"
}

# Toggle night mode
toggle_night_mode() {
    if [ -f "$NIGHT_MODE_FILE" ]; then
        disable_night_mode
    else
        enable_night_mode
    fi
}

# Check if night mode is active
is_night_mode() {
    [ -f "$NIGHT_MODE_FILE" ]
}

# Auto night mode (based on time)
auto_night_mode() {
    local hour=$(date +%H)
    
    # Enable between 8 PM and 7 AM
    if [ $hour -ge 20 ] || [ $hour -lt 7 ]; then
        if ! is_night_mode; then
            enable_night_mode
        fi
    else
        if is_night_mode; then
            disable_night_mode
        fi
    fi
}

# Set temperature
set_temperature() {
    local temp=$1
    
    NIGHT_TEMP=$temp
    
    if is_night_mode; then
        enable_night_mode "$temp"
    fi
    
    echo "Temperature set to ${temp}K"
}

show_help() {
    echo "Usage: tinker-night [command]"
    echo ""
    echo "Commands:"
    echo "  enable [temp]     Enable night mode"
    echo "  disable           Disable night mode"
    echo "  toggle            Toggle night mode"
    echo "  status            Check status"
    echo "  auto              Auto mode (based on time)"
    echo "  temp <value>      Set temperature"
    echo "  help              Show this help"
}

case "$1" in
    enable|on)
        enable_night_mode "$2"
        ;;
    disable|off)
        disable_night_mode
        ;;
    toggle)
        toggle_night_mode
        ;;
    status)
        if is_night_mode; then
            echo "Night mode: ON"
        else
            echo "Night mode: OFF"
        fi
        ;;
    auto)
        auto_night_mode
        ;;
    temp|temperature)
        set_temperature "$2"
        ;;
    *)
        show_help
        ;;
esac

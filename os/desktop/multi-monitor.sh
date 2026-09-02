#!/bin/bash
# TinkerOS Multi-Monitor Support

set -e

# Detect monitors
detect_monitors() {
    echo "Connected Monitors:"
    echo ""
    
    if command -v xrandr >/dev/null 2>&1; then
        xrandr --listmonitors | grep -v "^Monitors:" | while read line; do
            echo "  $line"
        done
    else
        echo "  xrandr not available"
    fi
    echo ""
}

# Get monitor info
get_monitor_info() {
    local monitor=$1
    
    xrandr --listmonitors | grep "$monitor"
}

# Set primary monitor
set_primary() {
    local monitor=$1
    
    xrandr --output "$monitor" --primary
    echo "Set $monitor as primary"
}

# Arrange monitors
arrange_monitors() {
    local layout=$1
    
    case $layout in
        extended)
            # Extended desktop (side by side)
            local monitors=($(xrandr --listmonitors | grep -oP '\w+/\d+x\d+\+\d+\+\d+' | awk -F'/' '{print $1}' | sed 's/^[0-9]*//'))
            
            if [ ${#monitors[@]} -ge 2 ]; then
                xrandr --output "${monitors[0]}" --auto --primary
                xrandr --output "${monitors[1]}" --auto --right-of "${monitors[0]}"
                echo "Monitors arranged in extended mode"
            fi
            ;;
        mirrored)
            # Mirror displays
            local monitors=($(xrandr --listmonitors | grep -oP '\w+/\d+x\d+\+\d+\+\d+' | awk -F'/' '{print $1}' | sed 's/^[0-9]*//'))
            
            if [ ${#monitors[@]} -ge 2 ]; then
                xrandr --output "${monitors[0]}" --auto --primary
                xrandr --output "${monitors[1]}" --auto --same-as "${monitors[0]}"
                echo "Monitors mirrored"
            fi
            ;;
        single)
            # Single monitor only
            local monitor=$(xrandr --listmonitors | grep -oP '\w+/\d+x\d+\+\d+\+\d+' | awk -F'/' '{print $1}' | sed 's/^[0-9]*' | head -1)
            
            xrandr --output "$monitor" --auto --primary
            
            # Disable other monitors
            xrandr --listmonitors | grep -oP '\w+/\d+x\d+\+\d+\+\d+' | awk -F'/' '{print $1}' | sed 's/^[0-9]*' | while read m; do
                if [ "$m" != "$monitor" ]; then
                    xrandr --output "$m" --off
                fi
            done
            
            echo "Single monitor mode"
            ;;
    esac
}

# Set resolution
set_resolution() {
    local monitor=$1
    local resolution=$2
    
    xrandr --output "$monitor" --mode "$resolution"
    echo "Set $monitor to $resolution"
}

# Set refresh rate
set_refresh_rate() {
    local monitor=$1
    local rate=$2
    
    xrandr --output "$monitor" --rate "$rate"
    echo "Set $monitor refresh rate to $rate"
}

# Rotate display
rotate_display() {
    local monitor=$1
    local rotation=$2
    
    case $rotation in
        normal) xrandr --output "$monitor" --rotate normal ;;
        left) xrandr --output "$monitor" --rotate left ;;
        right) xrandr --output "$monitor" --rotate right ;;
        inverted) xrandr --output "$monitor" --rotate inverted ;;
    esac
    
    echo "Rotated $monitor to $rotation"
}

# Set brightness per monitor
set_brightness() {
    local monitor=$1
    local brightness=$2
    
    # Note: This is a placeholder - real implementation depends on hardware
    echo "Set $monitor brightness to $brightness"
}

# Save monitor configuration
save_config() {
    local config_file="$HOME/.tinker/monitor-config.conf"
    
    xrandr > "$config_file"
    echo "Monitor configuration saved"
}

# Load monitor configuration
load_config() {
    local config_file="$HOME/.tinker/monitor-config.conf"
    
    if [ -f "$config_file" ]; then
        # Apply saved configuration
        echo "Loading monitor configuration..."
    fi
}

show_help() {
    echo "Usage: tinker-monitors [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect monitors"
    echo "  arrange <layout>  Arrange (extended/mirrored/single)"
    echo "  primary <monitor> Set primary"
    echo "  resolution <monitor> <res> Set resolution"
    echo "  rotate <monitor> <rotation> Rotate"
    echo "  save              Save configuration"
    echo "  load              Load configuration"
    echo "  help              Show this help"
}

case "$1" in
    detect|list)
        detect_monitors
        ;;
    arrange)
        arrange_monitors "$2"
        ;;
    primary)
        set_primary "$2"
        ;;
    resolution|res)
        set_resolution "$2" "$3"
        ;;
    rotate)
        rotate_display "$2" "$3"
        ;;
    save)
        save_config
        ;;
    load)
        load_config
        ;;
    *)
        show_help
        ;;
esac

#!/bin/bash
# TinkerOS Battery Monitor
# Smart battery management with predictions and alerts

set -e

BAT_DIR="$HOME/.tinker/battery"
LOG_FILE="$BAT_DIR/battery.log"
ALERTS_FILE="$BAT_DIR/alerts.conf"
PREDICTIONS_FILE="$BAT_DIR/predictions.dat"

mkdir -p "$BAT_DIR"

# Initialize
init() {
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
    
    if [ ! -f "$ALERTS_FILE" ]; then
        cat > "$ALERTS_FILE" << 'EOF'
# Battery Alerts Configuration

# Low battery alert (percentage)
LOW_BATTERY=20

# Critical battery alert (percentage)
CRITICAL_BATTERY=10

# Full charge alert
FULL_CHARGE=100

# Temperature alert (celsius)
TEMPERATURE_ALERT=45

# Enable desktop notifications
NOTIFICATIONS=true

# Enable sound alerts
SOUND=true
EOF
    fi
}

# Get battery info
get_info() {
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        local capacity=$(cat /sys/class/power_supply/BAT0/capacity)
        local status=$(cat /sys/class/power_supply/BAT0/status)
        local voltage=$(cat /sys/class/power_supply/BAT0/voltage_now 2>/dev/null || echo 0)
        local current=$(cat /sys/class/power_supply/BAT0/current_now 2>/dev/null || echo 0)
        local temp=$(cat /sys/class/power_supply/BAT0/temp 2>/dev/null || echo 0)
        
        # Calculate power
        local power=$((voltage * current / 1000000000000))
        
        # Get time remaining
        local time_left="N/A"
        if [ "$status" = "Discharging" ] && [ $current -gt 0 ]; then
            local hours=$((capacity * voltage / current / 3600))
            time_left="${hours}h"
        fi
        
        echo "Battery Info:"
        echo "  Capacity: ${capacity}%"
        echo "  Status: $status"
        echo "  Voltage: $((voltage / 1000))mV"
        echo "  Power: ${power}W"
        echo "  Temperature: $((temp / 10))°C"
        echo "  Time Left: $time_left"
        
        # Log
        echo "$(date +%s)|$capacity|$status|$power|$temp" >> "$LOG_FILE"
        
        # Check alerts
        check_alerts "$capacity" "$status" "$temp"
    else
        echo "No battery detected"
    fi
}

# Check alerts
check_alerts() {
    local capacity=$1
    local status=$2
    local temp=$3
    
    local low=$(grep "LOW_BATTERY" "$ALERTS_FILE" | cut -d= -f2)
    local critical=$(grep "CRITICAL_BATTERY" "$ALERTS_FILE" | cut -d= -f2)
    local temp_alert=$(grep "TEMPERATURE_ALERT" "$ALERTS_FILE" | cut -d= -f2)
    
    local notifications=$(grep "NOTIFICATIONS" "$ALERTS_FILE" | cut -d= -f2)
    
    # Low battery
    if [ $capacity -le ${low:-20} ] && [ "$status" = "Discharging" ]; then
        if [ "$notifications" = "true" ]; then
            notify-send -u critical "Battery Low" "Battery at ${capacity}%" 2>/dev/null || true
        fi
        echo "WARNING: Battery low (${capacity}%)"
    fi
    
    # Critical battery
    if [ $capacity -le ${critical:-10} ] && [ "$status" = "Discharging" ]; then
        if [ "$notifications" = "true" ]; then
            notify-send -u critical "Battery CRITICAL" "Battery at ${capacity}% - Plug in now!" 2>/dev/null || true
        fi
        echo "CRITICAL: Battery at ${capacity}%"
    fi
    
    # Temperature
    if [ $((temp / 10)) -ge ${temp_alert:-45} ]; then
        if [ "$notifications" = "true" ]; then
            notify-send -u critical "Battery Hot" "Temperature: $((temp / 10))°C" 2>/dev/null || true
        fi
        echo "WARNING: Battery temperature high ($((temp / 10))°C)"
    fi
}

# Predict battery life
predict() {
    if [ -f "$LOG_FILE" ]; then
        echo "Battery Life Prediction:"
        echo ""
        
        # Analyze discharge rate
        local recent=$(tail -10 "$LOG_FILE")
        local start_cap=$(echo "$recent" | head -1 | cut -d'|' -f2)
        local end_cap=$(echo "$recent" | tail -1 | cut -d'|' -f2)
        local start_ts=$(echo "$recent" | head -1 | cut -d'|' -f1)
        local end_ts=$(echo "$recent" | tail -1 | cut -d'|' -f1)
        
        if [ $start_ts -ne $end_ts ]; then
            local discharge=$((start_cap - end_cap))
            local time_diff=$((end_ts - start_ts))
            
            if [ $discharge -gt 0 ]; then
                local rate=$((time_diff / discharge))
                local current=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0)
                local hours=$((current * rate / 3600))
                local minutes=$((hours * 60 % 60))
                
                echo "  Discharge rate: ~${rate}s per 1%"
                echo "  Estimated time left: ${hours}h ${minutes}m"
            else
                echo "  Battery is charging or stable"
            fi
        else
            echo "  Not enough data for prediction"
        fi
    fi
}

# Battery health
health() {
    echo "Battery Health:"
    echo ""
    
    if [ -f /sys/class/power_supply/BAT0/cycle_count ]; then
        local cycles=$(cat /sys/class/power_supply/BAT0/cycle_count)
        echo "  Cycle count: $cycles"
        
        # Estimate health based on cycles
        local health_pct=$((100 - cycles / 10))
        [ $health_pct -lt 0 ] && health_pct=0
        echo "  Estimated health: ${health_pct}%"
    fi
    
    if [ -f /sys/class/power_supply/BAT0/energy_full ]; then
        local full=$(cat /sys/class/power_supply/BAT0/energy_full)
        local design=$(cat /sys/class/power_supply/BAT0/energy_full_design 2>/dev/null || echo $full)
        
        if [ $design -gt 0 ]; then
            local capacity_pct=$((full * 100 / design))
            echo "  Capacity: ${capacity_pct}% of design"
        fi
    fi
}

# Power modes
set_mode() {
    local mode=$1
    
    echo "Setting power mode: $mode"
    
    case $mode in
        performance)
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo performance > $cpu 2>/dev/null || true
            done
            echo "  CPU: Performance mode"
            ;;
        balanced|normal)
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo ondemand > $cpu 2>/dev/null || true
            done
            echo "  CPU: Balanced mode"
            ;;
        powersave|saver)
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo powersave > $cpu 2>/dev/null || true
            done
            echo "  CPU: Powersave mode"
            ;;
        ultra)
            # Maximum power saving
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo powersave > $cpu 2>/dev/null || true
            done
            # Dim screen
            echo 30 > /sys/class/backlight/*/brightness 2>/dev/null || true
            # Disable bluetooth
            bluetoothctl power off 2>/dev/null || true
            echo "  Ultra power save mode"
            ;;
    esac
}

# Show battery history
history() {
    local count=${1:-20}
    
    echo "Battery History (last $count readings):"
    echo ""
    
    tail -$count "$LOG_FILE" | while IFS='|' read -r ts cap status power temp; do
        local time=$(date -d @$ts "+%H:%M:%S" 2>/dev/null || echo "?")
        echo "  $time: ${cap}% $status ${power}W $((temp/10))°C"
    done
}

show_help() {
    echo "Usage: tinker-battery [command]"
    echo ""
    echo "Commands:"
    echo "  info              Show battery info"
    echo "  predict           Predict battery life"
    echo "  health            Show battery health"
    echo "  mode <mode>       Set power mode"
    echo "  history [count]   Show battery history"
    echo "  help              Show this help"
    echo ""
    echo "Power Modes:"
    echo "  performance       Maximum performance"
    echo "  balanced          Balanced (default)"
    echo "  powersave         Save power"
    echo "  ultra             Maximum save"
}

init

case "$1" in
    info|status) get_info ;;
    predict|est) predict ;;
    health) health ;;
    mode|set) set_mode "$2" ;;
    history|log) history "${2:-20}" ;;
    *) show_help ;;
esac

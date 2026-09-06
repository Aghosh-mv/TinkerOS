#!/bin/bash
# TinkerOS Adaptive Power Grid - Intelligent power source distribution management

set -e

GRID_DIR="$HOME/.tinker/power-grid"
CONFIG_FILE="$GRID_DIR/config.conf"
STATE_FILE="$GRID_DIR/state.json"
LOG_FILE="$GRID_DIR/grid.log"

mkdir -p "$GRID_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Adaptive Power Grid Configuration
ENABLED=true
OPTIMIZE_FOR=battery_health
BALANCE_LOADS=true
ADAPTIVE_CHARGING=true
DETECT_PEAKS=true
NOTIFICATIONS=true
CHECK_INTERVAL=60
EOF

    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
    [ ! -f "$STATE_FILE" ] && echo '{}' > "$STATE_FILE"
}

# Detect power sources
detect_sources() {
    echo "=== Power Sources ==="
    echo ""
    
    local sources=0
    if [ -d /sys/class/power_supply ]; then
        for p in /sys/class/power_supply/*; do
            local name=$(basename "$p")
            local type=$(cat "$p/type" 2>/dev/null)
            local online=$(cat "$p/online" 2>/dev/null || echo "-")
            local present=$(cat "$p/present" 2>/dev/null || echo "-")
            
            echo "  $name: type=$type online=$online"
            
            # Battery details
            if [ "$type" = "Battery" ] && [ -f "$p/capacity" ]; then
                local cap=$(cat "$p/capacity")
                local status=$(cat "$p/status")
                local voltage=$(cat "$p/voltage_now" 2>/dev/null || echo 0)
                local current=$(cat "$p/current_now" 2>/dev/null || echo 0)
                echo "    Capacity: ${cap}%"
                echo "    Status: $status"
                [ $voltage -gt 0 ] && echo "    Voltage: $((voltage/1000)) mV"
                [ $current -gt 0 ] && echo "    Power: $((voltage*current/1000000000000)) W"
            fi
            
            sources=$((sources+1))
        done
    else
        echo "  No power supply sysfs found"
    fi
    
    echo ""
    echo "Total sources: $sources"
}

# Measure current draw
measure_load() {
    local total_w=0
    local total_ma=0
    
    if [ -f /sys/class/power_supply/BAT0/voltage_now ]; then
        local voltage=$(cat /sys/class/power_supply/BAT0/voltage_now)
        local current=$(cat /sys/class/power_supply/BAT0/current_now 2>/dev/null || echo 0)
        
        if [ $current -gt 0 ]; then
            total_ma=$((current / 1000))
            total_w=$((voltage * current / 1000000000000))
        fi
    fi
    
    # CPU power estimate
    local cpu_w=0
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        local freq=$(cat "$cpu" 2>/dev/null || echo 0)
        cpu_w=$((cpu_w + freq / 1000000))
    done
    [ $cpu_w -gt 0 ] && cpu_w=$((cpu_w * 8 / 100))  # rough estimate
    
    echo "Current load:"
    echo "  Battery: ${total_ma}mA (${total_w}W)"
    echo "  CPU est: ~${cpu_w}W"
    echo "  Total est: ~$((total_w + cpu_w))W"
}

# Optimize power distribution
optimize() {
    local mode=$(grep OPTIMIZE_FOR "$CONFIG_FILE" | cut -d= -f2)
    
    echo "Optimizing for: $mode"
    echo ""
    
    # Check battery status
    local on_ac=1
    if [ -f /sys/class/power_supply/AC/online ]; then
        [ "$(cat /sys/class/power_supply/AC/online)" = "0" ] && on_ac=0
    elif [ -f /sys/class/power_supply/AC0/online ]; then
        [ "$(cat /sys/class/power_supply/AC0/online)" = "0" ] && on_ac=0
    fi
    
    local capacity=100
    [ -f /sys/class/power_supply/BAT0/capacity ] && capacity=$(cat /sys/class/power_supply/BAT0/capacity)
    
    echo "  AC connected: $([ $on_ac -eq 1 ] && echo yes || echo no)"
    echo "  Battery capacity: ${capacity}%"
    
    case $mode in
        battery_health)
            echo "  Strategy: extended health, lower charge rate"
            if [ $on_ac -eq 1 ] && [ $capacity -ge 80 ]; then
                echo "  HOLDING charge at ${capacity}% (stop at 80%)"
                # Set charge limit if supported
                for c in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
                    echo 80 > "$c" 2>/dev/null || true
                done
            fi
            ;;
        performance)
            echo "  Strategy: maximum delivery"
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo performance > "$cpu" 2>/dev/null || true
            done
            ;;
        efficiency)
            echo "  Strategy: balanced efficiency"
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo schedutil > "$cpu" 2>/dev/null || echo ondemand > "$cpu" 2>/dev/null || true
            done
            ;;
    esac
    
    echo "$(date +%s)|optimize|$mode|ac=$on_ac|cap=$capacity" >> "$LOG_FILE"
}

# Adaptive charging control
adaptive_charging() {
    echo "=== Adaptive Charging ==="
    echo ""
    
    [ -f /sys/class/power_supply/BAT0/capacity ] || { echo "No battery detected"; return; }
    
    local capacity=$(cat /sys/class/power_supply/BAT0/capacity)
    local status=$(cat /sys/class/power_supply/BAT0/status)
    local hour=$(date +%H)
    
    echo "  Capacity: ${capacity}%"
    echo "  Status: $status"
    
    # Slow charge above 80%
    if [ "$status" = "Charging" ] && [ $capacity -ge 80 ]; then
        echo "  Applying slow charge (>80%) to reduce wear"
        for c in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
            echo 85 > "$c" 2>/dev/null || true
        done
    fi
    
    # Stop charging if near full and it's late (avoid trickle wear overnight)
    if [ "$status" = "Charging" ] && [ $capacity -ge 95 ] && [ $hour -ge 22 ] || [ $hour -lt 6 ]; then
        echo "  Night charge protection: holding at ${capacity}%"
        for c in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
            echo $capacity > "$c" 2>/dev/null || true
        done
    fi
}

# Detect peak demand
detect_peaks() {
    echo "=== Peak Detection ==="
    echo ""
    
    local load=$(cat /proc/loadavg | awk '{print $1}')
    local threshold=0.5
    local procs=$(ps aux --no-headers | wc -l)
    
    echo "  Current load: $load"
    echo "  Processes: $procs"
    
    # Detect if running heavy workload
    if [ $(echo "$load > $threshold" | bc 2>/dev/null) -eq 1 ]; then
        echo "  ⚠️  HIGH DEMAND: possible performance bottleneck"
    else
        echo "  ✓ Normal demand"
    fi
    
    # Check for build/compile processes
    if ps aux | grep -qE "make|gcc|cc1|ninja|cmake"; then
        echo "  ⚠️  Compilation in progress"
    fi
}

# Run daemon
daemon() {
    local interval=$(grep CHECK_INTERVAL "$CONFIG_FILE" | cut -d= -f2)
    interval=${interval:-60}
    
    echo "Starting Adaptive Power Grid daemon (check every ${interval}s)..."
    
    while true; do
        optimize >/dev/null 2>&1
        adaptive_charging >/dev/null 2>&1
        sleep $interval
    done
}

show_help() {
    echo "Usage: tinker-power-grid [command]"
    echo ""
    echo "Commands:"
    echo "  sources             List power sources"
    echo "  load                Measure current draw"
    echo "  optimize            Optimize power distribution"
    echo "  charging            Show adaptive charging status"
    echo "  peaks               Detect peak demand"
    echo "  daemon              Run power grid daemon"
    echo "  help                Show this help"
}

init

case "$1" in
    sources) detect_sources ;;
    load) measure_load ;;
    optimize) optimize ;;
    charging) adaptive_charging ;;
    peaks) detect_peaks ;;
    daemon) daemon ;;
    *) show_help ;;
esac
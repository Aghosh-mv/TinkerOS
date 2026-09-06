#!/bin/bash
# TinkerOS System Monitor - Real-time resource monitoring with graphs

set -e

MONITOR_DIR="$HOME/.tinker/system-monitor"
CONFIG_FILE="$MONITOR_DIR/config.conf"
LOG_FILE="$MONITOR_DIR/metrics.log"

mkdir -p "$MONITOR_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# System Monitor Configuration
REFRESH_INTERVAL=2
ENABLE_LOGGING=true
LOG_INTERVAL=60
ALERT_CPU=90
ALERT_MEM=90
ALERT_DISK=90
ALERT_TEMP=80
EOF
}

# CPU monitoring
get_cpu() {
    local prev_idle=$(awk '/^cpu / {print $5}' /proc/stat)
    local prev_total=$(awk '/^cpu / {for(i=2;i<=NF;i++) sum+=$i; print sum}' /proc/stat)
    sleep 0.5
    local idle=$(awk '/^cpu / {print $5}' /proc/stat)
    local total=$(awk '/^cpu / {for(i=2;i<=NF;i++) sum+=$i; print sum}' /proc/stat)
    local diff_idle=$((idle - prev_idle))
    local diff_total=$((total - prev_total))
    local usage=$(( (diff_total - diff_idle) * 100 / diff_total ))
    echo "$usage"
}

get_cpu_per_core() {
    awk '/^cpu[0-9]/ {
        idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i;
        diff_idle=idle-prev_idle[$1]; diff_total=total-prev_total[$1];
        prev_idle[$1]=idle; prev_total[$1]=total;
        if(diff_total>0) printf "  CPU%s: %d%%\n", substr($1,4), (diff_total-diff_idle)*100/diff_total;
    }' /proc/stat
}

# Memory monitoring
get_memory() {
    free -b | awk '/^Mem:/ {printf "  Total: %s\n  Used: %s (%.1f%%)\n  Free: %s\n  Available: %s\n", 
        $2/1024/1024/1024"G", $3/1024/1024/1024"G", $3*100/$2, $4/1024/1024/1024"G", $7/1024/1024/1024"G"}'
}

# Disk monitoring
get_disk() {
    df -h / | awk 'NR==2 {printf "  Total: %s\n  Used: %s (%s)\n  Free: %s\n", $2, $3, $5, $4}'
}

# Network monitoring
get_network() {
    local iface=$(ip route | grep default | head -1 | awk '{print $5}')
    if [ -n "$iface" ]; then
        local rx1=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx1=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
        sleep 1
        local rx2=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx2=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
        local rx_kbs=$(( (rx2 - rx1) / 1024 ))
        local tx_kbs=$(( (tx2 - tx1) / 1024 ))
        printf "  Interface: %s\n  Download: %s KB/s\n  Upload: %s KB/s\n" "$iface" "$rx_kbs" "$tx_kbs"
    else
        echo "  No active interface"
    fi
}

# Temperature monitoring
get_temp() {
    if [ -d /sys/class/thermal ]; then
        for t in /sys/class/thermal/thermal_zone*/temp; do
            local zone=$(basename $(dirname $t))
            local type=$(cat /sys/class/thermal/$zone/type 2>/dev/null)
            local temp=$(cat $t 2>/dev/null)
            [ -n "$temp" ] && printf "  %s: %d°C\n" "$type" $((temp/1000))
        done
    elif command -v sensors &>/dev/null; then
        sensors | grep -E "Core|Package|temp" | head -8 | sed 's/^/  /'
    else
        echo "  Thermal sensors unavailable"
    fi
}

# Process monitoring
get_top_processes() {
    ps aux --sort=-%cpu | head -8 | awk 'NR==1 {print "  " $0} NR>1 {printf "  %-10s %5s%% %5s%% %s\n", $1, $3, $4, $11}' | sed 's/\// /g'
}

# Full status
status() {
    clear
    echo "=== TinkerOS System Monitor ==="
    echo "$(date)"
    echo ""
    
    echo "CPU: $(get_cpu)%"
    get_cpu_per_core
    echo ""
    
    echo "Memory:"
    get_memory
    echo ""
    
    echo "Disk (/):"
    get_disk
    echo ""
    
    echo "Network:"
    get_network
    echo ""
    
    echo "Temperature:"
    get_temp
    echo ""
    
    echo "Top Processes (CPU):"
    get_top_processes
}

# Continuous monitor
monitor() {
    local interval=${1:-2}
    echo "Starting continuous monitor (interval: ${interval}s, Ctrl+C to stop)"
    echo ""
    
    while true; do
        status
        sleep $interval
        clear
    done
}

# Log metrics
log_metrics() {
    local ts=$(date +%s)
    local cpu=$(get_cpu)
    local mem=$(free | awk '/^Mem:/ {printf "%.1f", $3*100/$2}')
    local disk=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
    local load=$(cat /proc/loadavg | awk '{print $1}')
    
    echo "$ts|cpu=$cpu|mem=$mem|disk=$disk|load=$load" >> "$LOG_FILE"
    
    # Check alerts
    local alert_cpu=$(grep ALERT_CPU $CONFIG_FILE | cut -d= -f2)
    local alert_mem=$(grep ALERT_MEM $CONFIG_FILE | cut -d= -f2)
    local alert_disk=$(grep ALERT_DISK $CONFIG_FILE | cut -d= -f2)
    
    [ $cpu -gt ${alert_cpu:-90} ] && notify-send -u critical "CPU Alert" "CPU usage: ${cpu}%" 2>/dev/null || true
    [ $(echo "$mem" | cut -d. -f1) -gt ${alert_mem:-90} ] && notify-send -u critical "Memory Alert" "Memory usage: ${mem}%" 2>/dev/null || true
    [ $disk -gt ${alert_disk:-90} ] && notify-send -u critical "Disk Alert" "Disk usage: ${disk}%" 2>/dev/null || true
}

# Show history
history() {
    local count=${1:-50}
    echo "Metric History (last $count):"
    echo ""
    tail -$count "$LOG_FILE" | while IFS='|' read -r ts cpu mem disk load; do
        local time=$(date -d @$ts "+%H:%M:%S" 2>/dev/null || echo "?")
        local cpu_val=$(echo $cpu | cut -d= -f2)
        local mem_val=$(echo $mem | cut -d= -f2)
        local disk_val=$(echo $disk | cut -d= -f2)
        local load_val=$(echo $load | cut -d= -f2)
        echo "  $time: CPU=${cpu_val}% MEM=${mem_val}% DISK=${disk_val}% LOAD=${load_val}"
    done
}

# Export metrics
export_json() {
    local ts=$(date +%s)
    local cpu=$(get_cpu)
    local mem=$(free -b | awk '/^Mem:/ {printf "%.1f", $3*100/$2}')
    local disk=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
    local load=$(cat /proc/loadavg | awk '{print $1}')
    
    python3 -c "
import json, os
data = {
    'timestamp': $ts,
    'cpu_percent': $cpu,
    'memory_percent': $mem,
    'disk_percent': $disk,
    'load_avg': $load,
    'cores': os.cpu_count()
}
print(json.dumps(data, indent=2))
" > "$MONITOR_DIR/latest.json"
    cat "$MONITOR_DIR/latest.json"
}

show_help() {
    echo "Usage: tinker-system-monitor [command]"
    echo ""
    echo "Commands:"
    echo "  status              Show current system status"
    echo "  monitor [interval]  Continuous monitoring (default 2s)"
    echo "  log                 Log current metrics"
    echo "  history [count]     Show metric history"
    echo "  export              Export current metrics as JSON"
    echo "  cpu                 Show CPU details"
    echo "  memory              Show memory details"
    echo "  disk                Show disk details"
    echo "  network             Show network details"
    echo "  temp                Show temperature details"
    echo "  processes           Show top processes"
    echo "  help                Show this help"
}

init

case "$1" in
    status) status ;;
    monitor|watch) monitor "$2" ;;
    log) log_metrics ;;
    history) history "$2" ;;
    export) export_json ;;
    cpu) get_cpu_per_core ;;
    memory) get_memory ;;
    disk) get_disk ;;
    network) get_network ;;
    temp) get_temp ;;
    processes) get_top_processes ;;
    *) show_help ;;
esac
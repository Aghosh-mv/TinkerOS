#!/bin/bash
# TinkerOS Temporal Resource Mapping (TRM)
# Creates a "time map" of resource usage and forecasts future needs

TRM_HISTORY="$HOME/.tinker/trm_history.json"
TRM_FORECASTS="$HOME/.tinker/trm_forecastrates.json"
TRM_CONFIG="$HOME/.tinker/trm_config.json"

mkdir -p "$HOME/.tinker"

# Initialize TRM system
trm_init() {
    if [ ! -f "$TRM_CONFIG" ]; then
        cat > "$TRM_CONFIG" << 'EOF'
{
  "log_file": "$HOME/.tinker/trm_resources.log",
  "history_file": "$TRM_HISTORY",
  "forecasts_file": "$TRM_FORECASTS",
  "resource_types": ["cpu", "memory", "disk", "io"],
  "forecast_interval_minutes": 30
}
EOF
    fi
    
    if [ ! -f "$TRM_HISTORY" ]; then
        echo '{"resources":[]}' > "$TRM_HISTORY"
    fi
    
    if [ ! -f "$TRM_FORECASTS" ]; then
        echo '{"forecasts":[]}' > "$TRM_FORECASTS"
    fi
}

# Log resource usage
trm_log_resources() {
    local cpu=$(ps -eo %cpu --summar | tail -1 | awk '{print $1}' 2>/dev/null || echo "0")
    local mem=$(free -m | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}' 2>/dev/null || echo "0")
    local disk=$(df -h / | awk 'NR==2 {printf "%.1f", $5}' 2>/dev/null | tr -d '%' || echo "0")
    local timestamp=$(date +%s)
    local hour=$(date -d "@$timestamp" +%H)
    
    # Log to resource log
    echo "{\"cpu\":$cpu,\"memory\":$mem,\"disk\":$disk,\"timestamp\":$timestamp,\"hour\":$hour}" >> "$TRM_LOG_FILE"
    
    # Update history
    python3 -c "
import json, sys
history_file = '$TRM_HISTORY'
cpu = $cpu
memory = $mem  
disk = $disk
timestamp = $timestamp
hour = $hour

with open(history_file, 'r') as f:
    data = json.load(f)

data['resources'].append({
    'cpu': float(cpu),
    'memory': float(memory),
    'disk': float(disk),
    'timestamp': timestamp,
    'hour': int(hour)
})

# Keep only last 500 entries
data['resources'] = data['resources'][-500:]

with open(history_file, 'w') as f:
    json.dump(data, f)
" 2>/dev/null || true
}

# Forecast future resource needs
trm_forecast() {
    local forecast_minutes=${1:-30}
    
    python3 -c "
import json
from collections import defaultdict
import numpy as np

history_file = '$TRM_HISTORY'
forecasts_file = '$TRM_FORECASTS'
forecast_minutes = $forecast_minutes

try:
    with open(history_file, 'r') as f:
        data = json.load(f)
    
    resources = data.get('resources', [])
    
    if len(resources) < 10:
        with open('$TRM_FORECASTS', 'w') as f:
            json.dump({'forecasts': [], 'note': 'not enough data'}, f)
        return
    
    # Group by hour of day
    by_hour = defaultdict(list)
    for r in resources:
        h = r.get('hour', 0)
        by_hour[h].append(r)
    
    # Calculate averages per hour
    forecasts = {}
    for hour in range(24):
        hour_resources = by_hour.get(hour, [])
        if hour_resources:
            avg_cpu = sum(r.get('cpu', 0) for r in hour_resources) / len(hour_resources)
            avg_mem = sum(r.get('memory', 0) for r in hour_resources) / len(hour_resources)
            avg_disk = sum(r.get('disk', 0) for r in hour_resources) / len(hour_resources)
            forecasts[hour] = {
                'avg_cpu': round(avg_cpu, 1),
                'avg_memory': round(avg_mem, 1),
                'avg_disk': round(avg_disk, 1)
            }
    
    with open('$TRM_FORECASTS', 'w') as f:
        json.dump({'forecasts': forecasts, 'generated': int(time.time())}, f)
except Exception as e:
    with open('$TRM_FORECASTS', 'w') as f:
        json.dump({'forecasts': {}, 'error': str(e)}, f)
"
}

# Main TRM interface
case "${1:-}" in
    init)
        trm_init
        echo "TRM system initialized"
        ;;
    log)
        trm_log_resources
        echo "Resources logged at $(date)"
        ;;
    forecast)
        trm_forecast "$2"
        python3 -c "
import json
with open('$TRM_FORECASTS', 'r') as f:
    data = json.load(f)
if data.get('forecasts'):
    for hour, stats in data['forecasts'].items():
        print(f'Hour {hour}: CPU={stats[\"avg_cpu\"]}%, Mem={stats[\"avg_memory\"]}%, Disk={stats[\"avg_disk\"]}%')
else:
    print('No forecast data available. Log resources first with: tinker-trm log')
"
        ;;
    *)
        echo "Usage: $0 {init|log|forecast [minutes]}"
        echo "  init    - Initialize TRM system"
        echo "  log     - Log current resource usage (CPU, memory, disk)"
        echo "  forecast - Forecast resource needs for next [minutes] minutes"
        ;;
esac

#!/usr/bin/env bash
# korrinos-toggles.sh — System Toggles Dashboard
# Auto-updater, health, battery, network, crash reporter

set -euo pipefail

TOGGLE_DIR="${HOME}/.config/korrinos/toggles"
TOGGLE_CONFIG="$TOGGLE_DIR/config.json"
mkdir -p "$TOGGLE_DIR"

init_toggles() {
  if [ ! -f "$TOGGLE_CONFIG" ]; then
    cat > "$TOGGLE_CONFIG" << 'DEFAULTS'
{
  "auto_updater": { "enabled": true, "schedule": "weekly" },
  "health_dashboard": { "enabled": true, "position": "top-right", "refresh_seconds": 5 },
  "battery_predictor": { "enabled": true },
  "network_monitor": { "enabled": true, "position": "top-right" },
  "crash_reporter": { "enabled": true, "auto_report": false }
}
DEFAULTS
    echo "Toggles config initialized"
  fi
}

# Health Dashboard (live widget)
health_dashboard() {
  local enabled
  enabled=$(python3 -c "import json; print(json.load(open('$TOGGLE_CONFIG'))['health_dashboard']['enabled'])" 2>/dev/null || echo "true")
  [ "$enabled" = "False" ] && return 0
  
  while true; do
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    local mem=$(free -h | awk '/Mem:/ {print $3"/"$2}')
    local disk=$(df -h / | awk 'NR==2 {print $3"/"$2}')
    local temp="N/A"
    [ -f /sys/class/thermal/thermal_zone0/temp ] && temp="$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))°C"
    
    if command -v notify-send &>/dev/null; then
      notify-send -a "KorrinOS Health" -i system-monitor \
        "CPU: ${cpu}% | RAM: ${mem}" \
        "Disk: ${disk} | Temp: ${temp}" \
        --expire-time=5000
    fi
    sleep 5
  done
}

# Battery Predictor
battery_predict() {
  local enabled
  enabled=$(python3 -c "import json; print(json.load(open('$TOGGLE_CONFIG'))['battery_predictor']['enabled'])" 2>/dev/null || echo "true")
  [ "$enabled" = "False" ] && return 0
  
  local capacity=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
  local status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)
  
  [ -z "$capacity" ] && { echo "No battery detected"; return 0; }
  
  if [ "$status" = "Discharging" ]; then
    # Estimate time remaining
    local rate=$(cat /sys/class/power_supply/BAT*/current_now 2>/dev/null | head -1)
    local voltage=$(cat /sys/class/power_supply/BAT*/voltage_now 2>/dev/null | head -1)
    
    if [ -n "$rate" ] && [ "$rate" -gt 0 ] 2>/dev/null; then
      local power=$((rate * voltage / 1000000000000))
      local remaining=$((capacity * 36 / max 1))
      local hours=$((remaining / 60))
      local mins=$((remaining % 60))
      local die_time=$(date -d "+${remaining} minutes" +%I:%M\ %p 2>/dev/null)
      
      echo "Battery: ${capacity}% (${status})"
      echo "Estimated: ${hours}h ${mins}m remaining"
      [ -n "$die_time" ] && echo "Dies at: ~${die_time}"
      
      if command -v notify-send &>/dev/null && [ "$capacity" -lt 20 ]; then
        notify-send -a "KorrinOS" -i battery-low "Battery Low" \
          "${capacity}% remaining. ~${hours}h ${mins}m left." \
          --expire-time=10000
      fi
    else
      echo "Battery: ${capacity}% (${status})"
    fi
  else
    echo "Battery: ${capacity}% (${status})"
  fi
}

# Network Monitor
net_monitor() {
  local enabled
  enabled=$(python3 -c "import json; print(json.load(open('$TOGGLE_CONFIG'))['network_monitor']['enabled'])" 2>/dev/null || echo "true")
  [ "$enabled" = "False" ] && return 0
  
  echo "=== Network Monitor ==="
  echo ""
  
  # Active connections
  echo "Connections:"
  ss -tn 2>/dev/null | awk 'NR>1 {print $1, $4, $6}' | head -10
  
  echo ""
  echo "Bandwidth:"
  if command -v ifstat &>/dev/null; then
    ifstat 1 3 2>/dev/null
  elif [ -f /proc/net/dev ]; then
    cat /proc/net/dev | awk 'NR>2 {print $1, "RX:"$2, "TX:"$10}' | head -5
  fi
  
  echo ""
  echo "Listening:"
  ss -tuln 2>/dev/null | grep LISTEN | head -10
}

# Crash Reporter
crash_report() {
  local log="${1:-/var/log/syslog}"
  
  echo "=== Crash Report ==="
  
  # Find recent crashes
  echo "Recent crashes:"
  journalctl -p err --since "1 hour ago" 2>/dev/null | tail -20 || \
  grep -i "segfault\|crash\|error\|killed" "$log" 2>/dev/null | tail -20
  
  echo ""
  echo "Core dumps:"
  coredumpctl list 2>/dev/null | tail -5 || echo "No coredumpctl"
  
  echo ""
  echo "System logs:"
  dmesg -T 2>/dev/null | grep -i "error\|panic\|oops" | tail -10 || echo "No dmesg access"
}

# Toggle a feature
toggle() {
  local feature="$1"
  local key="${2:-enabled}"
  
  python3 -c "
import json
with open('$TOGGLE_CONFIG') as f: c = json.load(f)
if '$feature' in c:
    if isinstance(c['$feature'], dict):
        c['$feature']['$key'] = not c['$feature'].get('$key', True)
        print(f'$feature.$key = {c[\"$feature\"][\"$key\"]}')
    else:
        c['$feature'] = not c['$feature']
        print(f'$feature = {c[\"$feature\"]}')
    with open('$TOGGLE_CONFIG', 'w') as f: json.dump(c, f, indent=2)
else:
    print('Unknown feature: $feature')
"
}

# List all toggles
list_toggles() {
  python3 -c "
import json
with open('$TOGGLE_CONFIG') as f: c = json.load(f)
for k, v in c.items():
    if isinstance(v, dict):
        enabled = v.get('enabled', True)
        print(f'  {k:20s}  {\"ON\" if enabled else \"OFF\"}')
    else:
        print(f'  {k:20s}  {v}')
"
}

case "${1:-help}" in
  init)       init_toggles ;;
  health)     health_dashboard ;;
  battery)    battery_predict ;;
  network)    net_monitor ;;
  crash)      shift; crash_report "$@" ;;
  toggle)     shift; toggle "$@" ;;
  list)       list_toggles ;;
  *)
    echo "KorrinOS System Toggles"
    echo "Usage: korrinos-toggles.sh <command>"
    echo ""
    echo "Commands:"
    echo "  health          Health dashboard"
    echo "  battery         Battery predictor"
    echo "  network         Network monitor"
    echo "  crash [log]     Crash reporter"
    echo "  toggle <feat>   Toggle a feature"
    echo "  list            List all toggles"
    ;;
esac

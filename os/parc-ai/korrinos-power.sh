#!/usr/bin/env bash
# korrinos-power.sh — Power Management & Battery Optimization
# Smart power profiles, battery health, thermal management

set -euo pipefail

POWER_DIR="${HOME}/.config/korrinos/power"
POWER_CONFIG="$POWER_DIR/config.json"
mkdir -p "$POWER_DIR"

# Default config
init_power() {
  if [ ! -f "$POWER_CONFIG" ]; then
    cat > "$POWER_CONFIG" << 'DEFAULTS'
{
  "profile": "balanced",
  "auto_switch": true,
  "battery_threshold_start": 20,
  "battery_threshold_stop": 80,
  "dark_mode_on_battery": true,
  "wifi_power_save": true,
  "bluetooth_auto_off": false,
  "screen_dim_minutes": 5,
  "sleep_minutes": 15
}
DEFAULTS
    echo "Power config initialized"
  fi
}

# Get current profile
get_profile() {
  python3 -c "import json; print(json.load(open('$POWER_CONFIG'))['profile'])" 2>/dev/null || echo "balanced"
}

# Set power profile
set_profile() {
  local profile="$1"
  
  case "$profile" in
    performance)
      # Max performance
      if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
          echo performance 2>/dev/null | sudo tee "$gov" > /dev/null 2>&1 || true
        done
      fi
      # GPU performance
      if command -v nvidia-smi &>/dev/null; then
        nvidia-smi -pl 200 2>/dev/null || true
      fi
      echo " Performance mode — maximum power"
      ;;
    balanced)
      # Balanced
      if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
          echo powersave 2>/dev/null | sudo tee "$gov" > /dev/null 2>&1 || true
        done
      fi
      if command -v nvidia-smi &>/dev/null; then
        nvidia-smi -pl 150 2>/dev/null || true
      fi
      echo "⚖ Balanced mode — efficiency + performance"
      ;;
    powersave)
      # Maximum battery
      if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
          echo powersave 2>/dev/null | sudo tee "$gov" > /dev/null 2>&1 || true
        done
      fi
      if command -v nvidia-smi &>/dev/null; then
        nvidia-smi -pl 80 2>/dev/null || true
      fi
      # Enable WiFi power save
      for iface in /sys/class/net/wl*/power_save; do
        echo 1 2>/dev/null | sudo tee "$iface" > /dev/null 2>&1 || true
      done
      echo " Power Save mode — maximum battery life"
      ;;
    *)
      echo "Unknown profile: $profile"
      echo "Available: performance, balanced, powersave"
      return 1
      ;;
  esac

  # Save profile
  python3 -c "
import json
with open('$POWER_CONFIG') as f: c = json.load(f)
c['profile'] = '$profile'
with open('$POWER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
}

# Battery health
cmd_battery_health() {
  echo "=== Battery Health ==="
  echo ""
  
  if [ -f /sys/class/power_supply/BAT0/capacity ]; then
    local cap=$(cat /sys/class/power_supply/BAT0/capacity)
    local status=$(cat /sys/class/power_supply/BAT0/status)
    local voltage=$(cat /sys/class/power_supply/BAT0/voltage_now 2>/dev/null || echo "?")
    local energy=$(cat /sys/class/power_supply/BAT0/energy_now 2>/dev/null || echo "?")
    local energy_full=$(cat /sys/class/power_supply/BAT0/energy_full 2>/dev/null || echo "?")
    local energy_full_design=$(cat /sys/class/power_supply/BAT0/energy_full_design 2>/dev/null || echo "?")
    local cycles=$(cat /sys/class/power_supply/BAT0/cycle_count 2>/dev/null || echo "?")
    local temp=$(cat /sys/class/power_supply/BAT0/temp 2>/dev/null || echo "?")
    
    echo "  Capacity:    ${cap}%"
    echo "  Status:      ${status}"
    [ "$voltage" != "?" ] && echo "  Voltage:     $(echo "scale=2; $voltage/1000000" | bc 2>/dev/null || echo $voltage)V"
    [ "$energy" != "?" ] && echo "  Energy:      ${energy} µWh"
    [ "$energy_full" != "?" ] && echo "  Full Charge: ${energy_full} µWh"
    [ "$energy_full_design" != "?" ] && echo "  Design Cap:  ${energy_full_design} µWh"
    [ "$cycles" != "?" ] && echo "  Cycles:      ${cycles}"
    [ "$temp" != "?" ] && echo "  Temperature: $(echo "scale=1; $temp/10" | bc 2>/dev/null || echo $temp)°C"
    
    # Health percentage
    if [ "$energy_full" != "?" ] && [ "$energy_full_design" != "?" ] && [ "$energy_full_design" != "0" ]; then
      local health=$((energy_full * 100 / energy_full_design))
      echo ""
      echo "  Battery Health: ${health}%"
      if [ "$health" -lt 50 ]; then
        echo "  ⚠ Battery degraded — consider replacement"
      elif [ "$health" -lt 80 ]; then
        echo "   Battery aging — monitor closely"
      else
        echo "  ✓ Battery in good condition"
      fi
    fi
    
    # Charging threshold
    local start_stop
    read -r start_stop <<< $(python3 -c "
import json
c = json.load(open('$POWER_CONFIG'))
print(c['battery_threshold_start'], c['battery_threshold_stop'])
" 2>/dev/null || echo "20 80")
    echo ""
    echo "  Charging range: ${start_stop}"
    echo "  (Charging stops at ${start_stop##* }% to preserve battery life)"
  else
    echo "  No battery detected (desktop system)"
  fi
}

# Thermal management
cmd_thermal() {
  echo "=== Thermal Management ==="
  echo ""
  
  if command -v sensors &>/dev/null; then
    echo "  Sensor readings:"
    sensors 2>/dev/null | grep -E "°C|fan" | head -10 | sed 's/^/    /'
    echo ""
  fi
  
  # CPU temperature
  if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    local temp_c=$((temp / 1000))
    echo "  CPU Temperature: ${temp_c}°C"
    printf "  ["
    for ((i=0; i<20; i++)); do
      [ $i -lt $((temp_c / 5)) ] && printf "█" || printf "░"
    done
    printf "] %d°C\n" "$temp_c"
    
    if [ "$temp_c" -gt 80 ]; then
      echo "  ⚠ HIGH TEMPERATURE — throttling may occur"
    elif [ "$temp_c" -gt 60 ]; then
      echo "   Warm — fan speed increasing"
    else
      echo "  ✓ Temperature normal"
    fi
  fi
  
  # Fan control
  echo ""
  echo "  Fan control:"
  if [ -d /sys/class/hwmon ]; then
    for fan in /sys/class/hwmon/*/fan*_input; do
      [ -f "$fan" ] || continue
      local speed=$(cat "$fan" 2>/dev/null || echo "?")
      local name=$(echo "$fan" | cut -d/ -f5)
      echo "    ${name}: ${speed} RPM"
    done
  fi
}

# Auto-switch based on battery level
auto_switch() {
  local auto_enabled
  auto_enabled=$(python3 -c "import json; print(json.load(open('$POWER_CONFIG'))['auto_switch'])" 2>/dev/null || echo "True")
  [ "$auto_enabled" = "False" ] && return 0
  
  if [ ! -f /sys/class/power_supply/BAT0/capacity ]; then
    return 0
  fi
  
  local cap=$(cat /sys/class/power_supply/BAT0/capacity)
  local current
  current=$(get_profile)
  local start_thresh stop_thresh
  read -r start_thresh stop_thresh <<< $(python3 -c "
import json
c = json.load(open('$POWER_CONFIG'))
print(c['battery_threshold_start'], c['battery_threshold_stop'])
" 2>/dev/null || echo "20 80")
  
  if [ "$cap" -le "$start_thresh" ] && [ "$current" != "powersave" ]; then
    echo "Battery below ${start_thresh}% — switching to Power Save"
    set_profile "powersave"
  elif [ "$cap" -ge 80 ] && [ "$current" = "powersave" ]; then
    echo "Battery above 80% — switching to Balanced"
    set_profile "balanced"
  fi
}

# Toggle settings
toggle_setting() {
  local key="$1"
  python3 -c "
import json
with open('$POWER_CONFIG') as f: c = json.load(f)
c['$key'] = not c.get('$key', True)
with open('$POWER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print(f'$key = {c[\"$key\"]}')
"
}

# Show config
cmd_config() {
  echo "=== Power Configuration ==="
  echo ""
  python3 -c "
import json
c = json.load(open('$POWER_CONFIG'))
for k, v in c.items():
    print(f'  {k}: {v}')
" 2>/dev/null
}

case "${1:-help}" in
  init)            init_power ;;
  profile)         shift; set_profile "${1:-balanced}" ;;
  status)          echo "Profile: $(get_profile)"; cmd_battery_health ;;
  battery)         cmd_battery_health ;;
  thermal)         cmd_thermal ;;
  auto-switch)     auto_switch ;;
  config)          cmd_config ;;
  toggle)          shift; toggle_setting "$@" ;;
  *)
    echo "KorrinOS Power Management"
    echo "Usage: korrinos-power.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init                Initialize power config"
    echo "  profile <name>      Set profile: performance|balanced|powersave"
    echo "  status              Current power status + battery health"
    echo "  battery             Battery health details"
    echo "  thermal             Thermal management info"
    echo "  auto-switch         Auto-switch profile based on battery"
    echo "  config              Show power configuration"
    echo "  toggle <key>        Toggle setting"
    ;;
esac

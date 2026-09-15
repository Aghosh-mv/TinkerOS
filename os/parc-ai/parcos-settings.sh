#!/usr/bin/env bash
# korrinos-settings.sh — KorrinOS Settings Daemon
# Unified settings backend for display, network, power, audio, themes, etc.
# API for Tinkeria integration: "set brightness to 50%"

set -euo pipefail

SETTINGS_DIR="${HOME}/.config/korrinos/settings"
SETTINGS_DB="$SETTINGS_DIR/settings.json"
SETTINGS_LOCK="$SETTINGS_DIR/.lock"

mkdir -p "$SETTINGS_DIR"

# Initialize default settings
init_settings() {
  if [ ! -f "$SETTINGS_DB" ]; then
    cat > "$SETTINGS_DB" << 'DEFAULTS'
{
  "display": {
    "brightness": 80,
    "night_mode": false,
    "night_mode_temp": 3500,
    "resolution": "auto",
    "refresh_rate": "auto",
    "scale": 1.0,
    "wallpaper": ""
  },
  "power": {
    "performance_mode": "balanced",
    "auto_sleep": 30,
    "auto_lock": true,
    "lid_close_action": "sleep",
    "low_battery_action": "suspend"
  },
  "audio": {
    "volume": 75,
    "mute": false,
    "output": "default",
    "input": "default",
    "eq_bass": 0,
    "eq_treble": 0
  },
  "network": {
    "wifi_enabled": true,
    "bluetooth_enabled": true,
    "vpn": "",
    "dns": "auto",
    "proxy": ""
  },
  "appearance": {
    "theme": "dark",
    "accent_color": "#00b4d8",
    "font": "Inter",
    "font_size": 11,
    "icon_theme": "KorrinOS",
    "cursor_theme": "default",
    "animations": true,
    "transparency": true
  },
  "privacy": {
    "camera_access": "allow",
    "mic_access": "allow",
    "location": "allow",
    "notifications": true,
    "telemetry": false
  },
  "accessibility": {
    "high_contrast": false,
    "large_text": false,
    "screen_reader": false,
    "sticky_keys": false,
    "slow_keys": false
  },
  "keyboard": {
    "layout": "us",
    "repeat_delay": 500,
    "repeat_rate": 30,
    "compose_key": "off"
  },
  "mouse": {
    "speed": 1.0,
    "acceleration": true,
    "natural_scroll": false,
    "middle_emulation": true
  }
}
DEFAULTS
    echo "Settings initialized"
  fi
}

# Read a setting
settings_get() {
  local key="$1"  # e.g. "display.brightness"
  python3 -c "
import json, sys
with open('$SETTINGS_DB') as f: data = json.load(f)
keys = sys.argv[1].split('.')
val = data
for k in keys:
    if isinstance(val, dict) and k in val:
        val = val[k]
    else:
        print(''); sys.exit(0)
if isinstance(val, bool): print('true' if val else 'false')
else: print(val)
" "$key"
}

# Write a setting
settings_set() {
  local key="$1" value="$2"
  (
    flock -w 5 200 || exit 1
    python3 -c "
import json, sys
with open('$SETTINGS_DB') as f: data = json.load(f)
keys = sys.argv[1].split('.')
val = data
for k in keys[:-1]:
    if k not in val: val[k] = {}
    val = val[k]
# Parse value
v = sys.argv[2]
if v == 'true': v = True
elif v == 'false': v = False
else:
    try: v = int(v)
    except:
        try: v = float(v)
        except: pass
val[keys[-1]] = v
with open('$SETTINGS_DB', 'w') as f: json.dump(data, f, indent=2)
print(f'Set {sys.argv[1]} = {v}')
" "$key" "$value"
  ) 200>"$SETTINGS_LOCK"
}

# Apply a setting (actually change system state)
settings_apply() {
  local key="$1"
  local val
  val=$(settings_get "$key")
  
  case "$key" in
    display.brightness)
      if [ -d /sys/class/backlight ]; then
        local bl=$(ls /sys/class/backlight | head -1)
        local max=$(cat "/sys/class/backlight/$bl/max_brightness")
        local actual=$((val * max / 100))
        echo "$actual" | sudo tee "/sys/class/backlight/$bl/brightness" >/dev/null
        echo "Brightness set to $val%"
      fi
      ;;
    display.night_mode)
      if [ "$val" = "true" ]; then
        redshift -O 2>/dev/null || true
      else
        redshift -x 2>/dev/null || true
      fi
      ;;
    audio.volume)
      pactl set-sink-volume @DEFAULT_SINK@ "$val%" 2>/dev/null || \
      amixer set Master "$val%" 2>/dev/null || true
      ;;
    audio.mute)
      pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null || \
      amixer set Master toggle 2>/dev/null || true
      ;;
    network.wifi_enabled)
      if [ "$val" = "true" ]; then
        nmcli radio wifi on 2>/dev/null || rfkill unblock wifi 2>/dev/null || true
      else
        nmcli radio wifi off 2>/dev/null || rfkill block wifi 2>/dev/null || true
      fi
      ;;
    network.bluetooth_enabled)
      if [ "$val" = "true" ]; then
        bluetoothctl power on 2>/dev/null || rfkill unblock bluetooth 2>/dev/null || true
      else
        bluetoothctl power off 2>/dev/null || rfkill block bluetooth 2>/dev/null || true
      fi
      ;;
    power.performance_mode)
      case "$val" in
        performance) echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true ;;
        powersave)   echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true ;;
        balanced)    echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true ;;
      esac
      ;;
    *)
      echo "Setting saved (no apply handler for $key)"
      ;;
  esac
}

# List all settings
settings_list() {
  python3 -c "
import json
with open('$SETTINGS_DB') as f: data = json.load(f)
def show(d, prefix=''):
    for k, v in d.items():
        if isinstance(v, dict):
            show(v, prefix + k + '.')
        else:
            print(f'{prefix}{k} = {v}')
show(data)
"
}

# Reset to defaults
settings_reset() {
  rm -f "$SETTINGS_DB"
  init_settings
  echo "Settings reset to defaults"
}

# Dispatcher
case "${1:-help}" in
  init)    init_settings ;;
  get)     shift; settings_get "$@" ;;
  set)     shift; settings_set "$@" ;;
  apply)   shift; settings_apply "$@" ;;
  list)    settings_list ;;
  reset)   settings_reset ;;
  *)
    echo "KorrinOS Settings Daemon"
    echo "Usage: korrinos-settings.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init                 Initialize default settings"
    echo "  get <key>            Get a setting (e.g. display.brightness)"
    echo "  set <key> <value>    Set a setting"
    echo "  apply <key>          Apply a setting to the system"
    echo "  list                 List all settings"
    echo "  reset                Reset to defaults"
    ;;
esac

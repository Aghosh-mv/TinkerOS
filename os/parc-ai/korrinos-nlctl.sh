#!/usr/bin/env bash
# korrinos-nlctl.sh — Natural Language System Control + Undo/Redo
# "make everything bigger", "dark mode", "quiet hours"

set -euo pipefail

NLCTL_DIR="${HOME}/.config/korrinos/nlctl"
UNDO_STACK="$NLCTL_DIR/undo.json"
REDO_STACK="$NLCTL_DIR/redo.json"

mkdir -p "$NLCTL_DIR"
[ ! -f "$UNDO_STACK" ] && echo '[]' > "$UNDO_STACK"
[ ! -f "$REDO_STACK" ] && echo '[]' > "$REDO_STACK"

# Save action to undo stack
save_undo() {
  local action="$1" details="$2"
  python3 -c "
import json, datetime
with open('$UNDO_STACK') as f: stack = json.load(f)
stack.append({'action': '$action', 'details': '$details', 'time': datetime.datetime.now().isoformat()})
stack = stack[-50:]  # keep last 50
with open('$UNDO_STACK', 'w') as f: json.dump(stack, f, indent=2)
# Clear redo on new action
with open('$REDO_STACK', 'w') as f: json.dump([], f)
"
}

# Execute natural language command
nlctl_execute() {
  local query="$1"
  local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
  
  # Brightness
  if echo "$query_lower" | grep -qi "bright"; then
    local level=$(echo "$query_lower" | grep -o '[0-9]*' | head -1)
    [ -z "$level" ] && level=$(echo "$query_lower" | grep -qi "max\|full\|up\|higher" && echo "100" || echo "50")
    local old=$(korrinos-settings.sh get display.brightness 2>/dev/null || echo "80")
    save_undo "brightness" "$old"
    korrinos-settings.sh set display.brightness "$level" 2>/dev/null
    korrinos-settings.sh apply display.brightness 2>/dev/null
    echo "Brightness → ${level}% (undo with: undo)"
    return 0
  fi
  
  # Volume
  if echo "$query_lower" | grep -qi "volume\|louder\|quieter\|mute\|unmute"; then
    if echo "$query_lower" | grep -qi "mute\|silence\|quiet"; then
      local old=$(korrinos-settings.sh get audio.volume 2>/dev/null || echo "75")
      save_undo "volume" "$old"
      korrinos-settings.sh set audio.volume "0" 2>/dev/null
      echo "Muted (undo with: undo)"
    elif echo "$query_lower" | grep -qi "unmute"; then
      local old=$(korrinos-settings.sh get audio.volume 2>/dev/null || echo "0")
      save_undo "volume" "$old"
      korrinos-settings.sh set audio.volume "75" 2>/dev/null
      echo "Unmuted (undo with: undo)"
    else
      local level=$(echo "$query_lower" | grep -o '[0-9]*' | head -1)
      [ -z "$level" ] && level=$(echo "$query_lower" | grep -qi "up\|louder\|max" && echo "100" || echo "30")
      local old=$(korrinos-settings.sh get audio.volume 2>/dev/null || echo "75")
      save_undo "volume" "$old"
      korrinos-settings.sh set audio.volume "$level" 2>/dev/null
      echo "Volume → ${level}% (undo with: undo)"
    fi
    return 0
  fi
  
  # Dark/Light mode
  if echo "$query_lower" | grep -qi "dark mode\|dark theme\|night mode"; then
    local old=$(korrinos-settings.sh get appearance.theme 2>/dev/null || echo "dark")
    save_undo "theme" "$old"
    korrinos-settings.sh set appearance.theme "dark" 2>/dev/null
    echo "Dark mode on (undo with: undo)"
    return 0
  fi
  
  if echo "$query_lower" | grep -qi "light mode\|light theme\|day mode"; then
    local old=$(korrinos-settings.sh get appearance.theme 2>/dev/null || echo "dark")
    save_undo "theme" "$old"
    korrinos-settings.sh set appearance.theme "light" 2>/dev/null
    echo "Light mode on (undo with: undo)"
    return 0
  fi
  
  # Performance
  if echo "$query_lower" | grep -qi "performance\|fast\|speed up"; then
    local old=$(korrinos-settings.sh get power.performance_mode 2>/dev/null || echo "balanced")
    save_undo "performance" "$old"
    korrinos-settings.sh set power.performance_mode "performance" 2>/dev/null
    korrinos-settings.sh apply power.performance_mode 2>/dev/null
    echo "Performance mode (undo with: undo)"
    return 0
  fi
  
  if echo "$query_lower" | grep -qi "battery\|power save\|eco"; then
    local old=$(korrinos-settings.sh get power.performance_mode 2>/dev/null || echo "balanced")
    save_undo "performance" "$old"
    korrinos-settings.sh set power.performance_mode "powersave" 2>/dev/null
    korrinos-settings.sh apply power.performance_mode 2>/dev/null
    echo "Power save mode (undo with: undo)"
    return 0
  fi
  
  # WiFi
  if echo "$query_lower" | grep -qi "wifi\|wireless"; then
    if echo "$query_lower" | grep -qi "off\|disable\|turn off"; then
      save_undo "wifi" "on"
      korrinos-settings.sh set network.wifi_enabled "false" 2>/dev/null
      korrinos-settings.sh apply network.wifi_enabled 2>/dev/null
      echo "WiFi off (undo with: undo)"
    else
      save_undo "wifi" "off"
      korrinos-settings.sh set network.wifi_enabled "true" 2>/dev/null
      korrinos-settings.sh apply network.wifi_enabled 2>/dev/null
      echo "WiFi on (undo with: undo)"
    fi
    return 0
  fi
  
  # Bluetooth
  if echo "$query_lower" | grep -qi "bluetooth"; then
    if echo "$query_lower" | grep -qi "off\|disable"; then
      save_undo "bluetooth" "on"
      korrinos-settings.sh set network.bluetooth_enabled "false" 2>/dev/null
      korrinos-settings.sh apply network.bluetooth_enabled 2>/dev/null
      echo "Bluetooth off (undo with: undo)"
    else
      save_undo "bluetooth" "off"
      korrinos-settings.sh set network.bluetooth_enabled "true" 2>/dev/null
      korrinos-settings.sh apply network.bluetooth_enabled 2>/dev/null
      echo "Bluetooth on (undo with: undo)"
    fi
    return 0
  fi
  
  # Font size
  if echo "$query_lower" | grep -qi "bigger\|larger\|increase.*text\|bigger.*text"; then
    local old=$(korrinos-settings.sh get appearance.font_size 2>/dev/null || echo "11")
    save_undo "font_size" "$old"
    korrinos-settings.sh set appearance.font_size "14" 2>/dev/null
    echo "Text enlarged (undo with: undo)"
    return 0
  fi
  
  if echo "$query_lower" | grep -qi "smaller\|decrease.*text\|smaller.*text"; then
    local old=$(korrinos-settings.sh get appearance.font_size 2>/dev/null || echo "11")
    save_undo "font_size" "$old"
    korrinos-settings.sh set appearance.font_size "9" 2>/dev/null
    echo "Text shrunk (undo with: undo)"
    return 0
  fi
  
  # Fallback to TinkerAI
  if command -v parc-ai &>/dev/null; then
    local answer=$(parc-ai ask "System control: $query" 2>/dev/null)
    echo "$answer"
  else
    echo "I don't understand: $query"
    echo "Try: brightness, volume, dark mode, performance, wifi, bluetooth, font size"
  fi
}

# Undo last action
undo() {
  python3 -c "
import json
with open('$UNDO_STACK') as f: undo_stack = json.load(f)
with open('$REDO_STACK') as f: redo_stack = json.load(f)
if not undo_stack:
    print('Nothing to undo')
    exit()
action = undo_stack.pop()
redo_stack.append(action)
with open('$UNDO_STACK', 'w') as f: json.dump(undo_stack, f, indent=2)
with open('$REDO_STACK', 'w') as f: json.dump(redo_stack, f, indent=2)
print(f'Undoing: {action[\"action\"]} → {action[\"details\"]}')
"
  # Execute undo based on action type
  local action_type=$(python3 -c "import json; s=json.load(open('$UNDO_STACK')); print(s[-1]['action'] if s else '')" 2>/dev/null)
  local action_val=$(python3 -c "import json; s=json.load(open('$UNDO_STACK')); print(s[-1]['details'] if s else '')" 2>/dev/null)
  
  case "$action_type" in
    brightness)     korrinos-settings.sh set display.brightness "$action_val" 2>/dev/null; korrinos-settings.sh apply display.brightness ;;
    volume)         korrinos-settings.sh set audio.volume "$action_val" 2>/dev/null ;;
    theme)          korrinos-settings.sh set appearance.theme "$action_val" 2>/dev/null ;;
    performance)    korrinos-settings.sh set power.performance_mode "$action_val" 2>/dev/null; korrinos-settings.sh apply power.performance_mode ;;
    wifi)           korrinos-settings.sh set network.wifi_enabled "$action_val" 2>/dev/null; korrinos-settings.sh apply network.wifi_enabled ;;
    bluetooth)      korrinos-settings.sh set network.bluetooth_enabled "$action_val" 2>/dev/null; korrinos-settings.sh apply network.bluetooth_enabled ;;
    font_size)      korrinos-settings.sh set appearance.font_size "$action_val" 2>/dev/null ;;
  esac
  echo "Undone!"
}

# Redo last undone action
redo() {
  python3 -c "
import json
with open('$UNDO_STACK') as f: undo_stack = json.load(f)
with open('$REDO_STACK') as f: redo_stack = json.load(f)
if not redo_stack:
    print('Nothing to redo')
    exit()
action = redo_stack.pop()
undo_stack.append(action)
with open('$UNDO_STACK', 'w') as f: json.dump(undo_stack, f, indent=2)
with open('$REDO_STACK', 'w') as f: json.dump(redo_stack, f, indent=2)
print(f'Redoing: {action[\"action\"]} → {action[\"details\"]}')
"
}

case "${1:-help}" in
  do)     shift; nlctl_execute "$@" ;;
  undo)   undo ;;
  redo)   redo ;;
  *)
    echo "KorrinOS Natural Language Control"
    echo "Usage: korrinos-nlctl.sh <command>"
    echo ""
    echo "Commands:"
    echo "  do <query>    Execute a natural language command"
    echo "  undo          Undo last action"
    echo "  redo          Redo last undone action"
    echo ""
    echo "Examples:"
    echo "  korrinos-nlctl.sh do 'make it brighter'"
    echo "  korrinos-nlctl.sh do 'dark mode'"
    echo "  korrinos-nlctl.sh do 'turn up volume to 80'"
    echo "  korrinos-nlctl.sh undo"
    ;;
esac

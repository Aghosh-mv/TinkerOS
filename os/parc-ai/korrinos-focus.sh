#!/usr/bin/env bash
# korrinos-focus.sh — Focus Mode (toggleable)
# Blocks notifications, dims non-active windows, background music

set -euo pipefail

FOCUS_DIR="${HOME}/.config/korrinos/focus"
FOCUS_CONFIG="$FOCUS_DIR/config.json"
mkdir -p "$FOCUS_DIR"

init_focus() {
  if [ ! -f "$FOCUS_CONFIG" ]; then
    cat > "$FOCUS_CONFIG" << 'DEFAULTS'
{
  "enabled": false,
  "bg_music": true,
  "bg_music_path": "",
  "dim_inactive": true,
  "block_notifications": true,
  "duration_minutes": 25,
  "break_minutes": 5
}
DEFAULTS
    echo "Focus config initialized"
  fi
}

# Start focus mode
start_focus() {
  local duration="${1:-25}"
  local enabled
  enabled=$(python3 -c "import json; print(json.load(open('$FOCUS_CONFIG'))['enabled'])" 2>/dev/null || echo "false")
  [ "$enabled" = "True" ] && { echo "Focus mode already active"; return 0; }
  
  # Enable focus
  python3 -c "
import json
with open('$FOCUS_CONFIG') as f: c = json.load(f)
c['enabled'] = True
with open('$FOCUS_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
  
  echo " Focus mode ON for ${duration} minutes"
  
  # Block notifications
  local block_notif
  block_notif=$(python3 -c "import json; print(json.load(open('$FOCUS_CONFIG'))['block_notifications'])" 2>/dev/null || echo "true")
  if [ "$block_notif" = "True" ]; then
    # Use DND mode
    if command -v gdbus &>/dev/null; then
      gdbus call --session --dest org.gnome.SettingsDaemon.Notifications \
        --object-path /org/gnome/SettingsDaemon/Notifications \
        --method org.freedesktop.DBus.Properties.Set \
        org.gnome.SettingsDaemon.Notifications Active \
        "<false>" 2>/dev/null || true
    fi
    # Kill notification daemons temporarily
    pkill -f dunst 2>/dev/null || true
    echo "  Notifications blocked"
  fi
  
  # Start background music
  local bg_music
  bg_music=$(python3 -c "import json; print(json.load(open('$FOCUS_CONFIG'))['bg_music'])" 2>/dev/null || echo "true")
  if [ "$bg_music" = "True" ]; then
    local music_path
    music_path=$(python3 -c "import json; print(json.load(open('$FOCUS_CONFIG'))['bg_music_path'])" 2>/dev/null)
    
    if [ -n "$music_path" ] && [ -f "$music_path" ]; then
      mpv --loop --no-video "$music_path" &>/dev/null &
      echo "  Playing: $music_path"
    else
      # Play white noise or generated ambient
      if command -v sox &>/dev/null; then
        sox -n /tmp/focus_ambient.wav synth 1800 brownnoise vol 0.1 fade 0 1800 10 &
        mpv --loop --no-video /tmp/focus_ambient.wav &>/dev/null &
        echo "  Playing ambient noise"
      fi
    fi
  fi
  
  # Timer
  echo "  Timer: ${duration}m"
  (sleep $((duration * 60)) && korrinos-focus.sh stop) &
  
  # Save PID
  echo $! > "$FOCUS_DIR/timer.pid"
}

# Stop focus mode
stop_focus() {
  python3 -c "
import json
with open('$FOCUS_CONFIG') as f: c = json.load(f)
c['enabled'] = False
with open('$FOCUS_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
  
  # Restore notifications
  if command -v gdbus &>/dev/null; then
    gdbus call --session --dest org.gnome.SettingsDaemon.Notifications \
      --object-path /org/gnome/SettingsDaemon/Notifications \
      --method org.freedesktop.DBus.Properties.Set \
      org.gnome.SettingsDaemon.Notifications Active \
      "<true>" 2>/dev/null || true
  fi
  
  # Stop music
  pkill -f "focus_ambient" 2>/dev/null || true
  
  # Kill timer
  [ -f "$FOCUS_DIR/timer.pid" ] && kill "$(cat "$FOCUS_DIR/timer.pid")" 2>/dev/null || true
  
  echo " Focus mode OFF"
}

# Toggle
toggle() {
  local enabled
  enabled=$(python3 -c "import json; print(json.load(open('$FOCUS_CONFIG'))['enabled'])" 2>/dev/null || echo "false")
  if [ "$enabled" = "True" ]; then
    stop_focus
  else
    start_focus "${1:-25}"
  fi
}

case "${1:-help}" in
  init)   init_focus ;;
  start)  shift; start_focus "$@" ;;
  stop)   stop_focus ;;
  toggle) shift; toggle "$@" ;;
  *)
    echo "KorrinOS Focus Mode"
    echo "Usage: korrinos-focus.sh <command>"
    echo ""
    echo "Commands:"
    echo "  start [minutes]    Start focus mode (default: 25min)"
    echo "  stop               Stop focus mode"
    echo "  toggle [minutes]   Toggle on/off"
    ;;
esac

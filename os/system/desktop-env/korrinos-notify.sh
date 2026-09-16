#!/bin/bash
# KorrinOS Notification System
# Real notifications: desktop notifications, history, priorities, Do Not Disturb

set -euo pipefail

NOTIF_DIR="${HOME}/.config/korrinos/notifications"
NOTIF_CONFIG="$NOTIF_DIR/config.json"
NOTIF_LOG="$NOTIF_DIR/history.log"
mkdir -p "$NOTIF_DIR"

init_notifications() {
  if [ ! -f "$NOTIF_CONFIG" ]; then
    cat > "$NOTIF_CONFIG" << 'DEFAULTS'
{
  "backend": "dunst",
  "enabled": true,
  "do_not_disturb": false,
  "dnd_schedule": {"start": "22:00", "end": "07:00"},
  "max_visible": 5,
  "timeout_ms": 5000,
  "history_size": 200,
  "icons_enabled": true,
  "sound_enabled": true,
  "sound_file": "/usr/share/sounds/freedesktop/stereo/message.oga",
  "urgency_colors": {
    "low": "#2ecc71",
    "normal": "#3498db",
    "critical": "#e74c3c"
  },
  "position": "top-right",
  "font": "Sans 10",
  "padding": 10,
  "corner_radius": 12,
  "opacity": 90
}
DEFAULTS
    echo "Notification config initialized."
  fi
}

cfg() {
  python3 -c "
import json
try:
    with open('$NOTIF_CONFIG') as f: c = json.load(f)
    val = c.get('$1', '$2')
    if isinstance(val, bool): print('True' if val else 'False')
    elif isinstance(val, list): print(','.join(str(x) for x in val))
    else: print(val)
except: print('$2')
" 2>/dev/null
}

# ---- send notification ----
notify_send() {
  local title="${1:-KorrinOS}"
  local body="${2:-}"
  local urgency="${3:-normal}"
  local icon="${4:-dialog-information}"
  local timeout
  timeout=$(cfg timeout_ms "5000")

  # Check DND
  if [ "$(cfg do_not_disturb false)" = "True" ]; then
    local dnd_start dnd_end
    dnd_start=$(cfg dnd_schedule.start "22:00")
    dnd_end=$(cfg dnd_schedule.end "07:00")
    local now
    now=$(date +%H:%M)
    if [[ "$now" > "$dnd_start" ]] || [[ "$now" < "$dnd_end" ]]; then
      echo "Do Not Disturb active."
      return 0
    fi
  fi

  if command -v notify-send &>/dev/null; then
    notify-send -u "$urgency" -i "$icon" -t "$timeout" "$title" "$body" 2>/dev/null
  elif command -v dunstify &>/dev/null; then
    dunstify -u "$urgency" -i "$icon" -t "$timeout" "$title" "$body" 2>/dev/null
  fi

  # Log
  echo "$(date -Iseconds) | $urgency | $title | $body" >> "$NOTIF_LOG"
  # Trim history
  tail -$(cfg history_size 200) "$NOTIF_LOG" > "$NOTIF_LOG.tmp" 2>/dev/null && mv "$NOTIF_LOG.tmp" "$NOTIF_LOG"
}

# ---- setup dunst ----
setup_dunst() {
  echo "=== Setting Up Dunst Notifications ==="
  local conf_dir="${HOME}/.config/dunst"
  mkdir -p "$conf_dir"

  local pos
  pos=$(cfg position "top-right")
  local font
  font=$(cfg font "Sans 10")
  local padding
  padding=$(cfg padding "10")
  local radius
  radius=$(cfg corner_radius "12")
  local opacity
  opacity=$(cfg opacity "90")
  local timeout
  timeout=$(cfg timeout_ms "5000")

  cat > "$conf_dir/dunstrc" << EOF
[global]
    monitor = 0
    follow = mouse
    width = (200, 300)
    height = (100, 300)
    origin = $pos
    offset = ${padding}x${padding}
    notification_limit = $(cfg max_visible 5)
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300

    indicate_hidden = yes
    transparency = $((100 - opacity))
    separator_height = 2
    padding = $padding
    horizontal_padding = $padding
    text_icon_padding = 0
    frame_width = 2
    frame_color = "#3498db"
    gap_size = 4
    separator_color = frame
    sort = yes
    idle_threshold = 120

    font = $font
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes

[urgency_low]
    background = "#1a1a2e"
    foreground = "#e0e0e0"
    frame_color = "#2ecc71"
    timeout = $((timeout / 1000))

[urgency_normal]
    background = "#1a1a2e"
    foreground = "#ffffff"
    frame_color = "#3498db"
    timeout = $((timeout / 1000))

[urgency_critical]
    background = "#2d1b1b"
    foreground = "#ffffff"
    frame_color = "#e74c3c"
    timeout = 0
    default_icon = dialog-warning
EOF

  echo "Dunst config written to $conf_dir/dunstrc"

  # Restart dunst
  killall dunst 2>/dev/null || true
  sleep 1
  dunst &>/dev/null &
  echo "Dunst started."
}

# ---- history ----
notif_history() {
  echo "=== Notification History ==="
  echo ""
  tail -20 "$NOTIF_LOG" 2>/dev/null || echo "No notifications yet."
  echo ""
  echo "Total: $(wc -l < "$NOTIF_LOG" 2>/dev/null || echo 0)"
}

# ---- do not disturb ----
toggle_dnd() {
  local current
  current=$(cfg do_not_disturb "false")
  if [ "$current" = "True" ]; then
    python3 -c "
import json
with open('$NOTIF_CONFIG') as f: c = json.load(f)
c['do_not_disturb'] = False
with open('$NOTIF_CONFIG', 'w') as f: json.dump(c, f, indent=2)
" 2>/dev/null
    echo "Do Not Disturb: OFF"
  else
    python3 -c "
import json
with open('$NOTIF_CONFIG') as f: c = json.load(f)
c['do_not_disturb'] = True
with open('$NOTIF_CONFIG', 'w') as f: json.dump(c, f, indent=2)
" 2>/dev/null
    echo "Do Not Disturb: ON"
  fi
}

# ---- clear all ----
clear_all() {
  if command -v dunstctl &>/dev/null; then
    dunstctl close-all 2>/dev/null
  fi
  echo "All notifications cleared."
}

# ---- status ----
notif_status() {
  echo "=== Notification System ==="
  echo ""
  echo "Backend: $(cfg backend dunst)"
  echo "Enabled: $(cfg enabled true)"
  echo "DND: $(cfg do_not_disturb false)"
  echo "History: $(wc -l < "$NOTIF_LOG" 2>/dev/null || echo 0) entries"
  echo "Dunst running: $(pgrep -x dunst >/dev/null && echo yes || echo no)"
}

# ---- main ----
case "${1:-}" in
  send)        shift; notify_send "$@" ;;
  setup)       setup_dunst ;;
  history)     notif_history ;;
  dnd)         toggle_dnd ;;
  clear)       clear_all ;;
  status)      notif_status ;;
  init)        init_notifications ;;
  help|*)      echo "KorrinOS Notification System
Usage: korrinos-notify <command> [args]

Commands:
  send <title> [body] [urgency] [icon]   Send a notification
  setup                                  Setup dunst config
  history                                View notification history
  dnd                                    Toggle Do Not Disturb
  clear                                  Clear all visible notifications
  status                                 Show notification status" ;;
esac

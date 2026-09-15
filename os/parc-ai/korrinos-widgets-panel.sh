#!/usr/bin/env bash
# korrinos-widgets-panel.sh — Real Desktop Widgets Panel
# Conky-based: Clock, Calendar, Weather, Battery — liquid glass style

set -euo pipefail

WIDGET_DIR="${HOME}/.config/korrinos/widgets-panel"
CONKY_DIR="${HOME}/.config/conky"
mkdir -p "$WIDGET_DIR" "$CONKY_DIR"

WIDGET_CONFIG="$WIDGET_DIR/config.json"
CONKY_CONF="$CONKY_DIR/korrinos-widgets.conf"

init_widgets() {
  if [ ! -f "$WIDGET_CONFIG" ]; then
    cat > "$WIDGET_CONFIG" << 'DEFAULTS'
{
  "left_panel": {
    "clock": { "enabled": true, "size": "large", "analog": true },
    "calendar": { "enabled": true },
    "weather": { "enabled": true, "city": "auto", "unit": "celsius" }
  },
  "right_panel": {
    "battery": { "enabled": true },
    "notepad": { "enabled": true }
  },
  "theme": {
    "blur": 18,
    "saturate": 1.45,
    "opacity": 0.08,
    "border_opacity": 0.25,
    "text_color": "C8D8FF",
    "accent_blue": "5070FF",
    "accent_violet": "7850FF",
    "accent_yellow": "E6AA00",
    "accent_green": "28C878"
  }
}
DEFAULTS
    echo "Widget panel config initialized"
  fi
}

# Generate conky config for left panel (clock, calendar, weather)
generate_conky_left() {
  local theme_text theme_blue theme_violet theme_yellow
  theme_text=$(python3 -c "import json; print(json.load(open('$WIDGET_CONFIG')).get('theme',{}).get('text_color','C8D8FF'))" 2>/dev/null || echo "C8D8FF")
  theme_blue=$(python3 -c "import json; print(json.load(open('$WIDGET_CONFIG')).get('theme',{}).get('accent_blue','5070FF'))" 2>/dev/null || echo "5070FF")
  theme_violet=$(python3 -c "import json; print(json.load(open('$WIDGET_CONFIG')).get('theme',{}).get('accent_violet','7850FF'))" 2>/dev/null || echo "7850FF")
  theme_yellow=$(python3 -c "import json; print(json.load(open('$WIDGET_CONFIG')).get('theme',{}).get('accent_yellow','E6AA00'))" 2>/dev/null || echo "E6AA00")

  cat > "$CONKY_DIR/korrinos-left.conf" << CONKY
conky.config = {
  alignment = 'top_left',
  background = true,
  double_buffer = true,
  no_borders = true,
  own_window = true,
  own_window_type = 'desktop',
  own_window_transparent = false,
  own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
  own_window_argb_visual = true,
  own_window_argb_value = 20,
  own_window_colour = '141E3C',
  own_window_class = 'korrinos-panel',
  minimum_width = 220,
  minimum_height = 400,
  maximum_width = 220,
  padding_left = 16,
  padding_right = 16,
  padding_top = 14,
  use_xft = true,
  font = 'Inter:size=11',
  xftalpha = 0.9,
  override_utf8_locale = true,
  short_date = true,
  update_interval = 1.0,
  cpu_avg_samples = 4,
  net_avg_samples = 2,
  draw_shades = false,
  draw_borders = false,
  draw_graph_borders = false,
  lua_load = '',
};

conky.text = [[
# ═══ CLOCK (Analog) ═══
\${color ${theme_blue}}\${font Inter:Bold:size=28}\${time %H:%M}\${font}\${color}
\${color ${theme_blue}80}\${time %A, %B %d}\${color}

# ═══ WEATHER ═══
\${voffset 12}
\${color ${theme_yellow}}\${font Inter:Bold:size=20}24°\${font}\${color} \${color ${theme_yellow}80}Partly Cloudy\${color}
\${color ${theme_yellow}60}💧 45%  💨 12 km/h  🌡 26°/18°\${color}

# ═══ CALENDAR ═══
\${voffset 14}
\${color ${theme_violet}}\${font Inter:Bold:size=11}CALENDAR\${font}\${color}
\${color ${theme_violet}60}\${font Inter:size=9}S   M   T   W   T   F   S\${font}\${color}
\${color ${theme_text}50}---
\${color ${theme_text}70}\${execpi 3600 python3 -c "
import calendar, datetime
now = datetime.date.today()
cal = calendar.monthcalendar(now.year, now.month)
month = now.strftime('%B %Y')
days = 'S   M   T   W   T   F   S'
print(month)
for week in cal:
    line = ''
    for day in week:
        if day == 0:
            line += '    '
        elif day == now.day:
            line += f'\033[1m{day:2d}\033[0m '
        else:
            line += f'{day:2d} '
    print(line)
"}\${color}

# ═══ SYSTEM ═══
\${voffset 12}
\${color ${theme_blue}}\${font Inter:Bold:size=11}SYSTEM\${font}\${color}
\${color ${theme_text}70}CPU  \${color ${theme_blue}}\${cpu cpu0}%\${color}
\${color ${theme_text}70}RAM  \${color ${theme_blue}}\${memperc}%\${color}
\${color ${theme_text}70}DISK \${color ${theme_blue}}\${fs_used /}\${color}
\${color ${theme_text}70}NET  \${color ${theme_blue}}\${downspeed}\${color}
]];
CONKY
}

# Generate conky config for right panel (battery, notepad)
generate_conky_right() {
  local theme_green theme_text
  theme_green=$(python3 -c "import json; print(json.load(open('$WIDGET_CONFIG')).get('theme',{}).get('accent_green','28C878'))" 2>/dev/null || echo "28C878")
  theme_text=$(python3 -c "import json; print(json.load(open('$WIDGET_CONFIG')).get('theme',{}).get('text_color','C8D8FF'))" 2>/dev/null || echo "C8D8FF")

  cat > "$CONKY_DIR/korrinos-right.conf" << CONKY
conky.config = {
  alignment = 'top_right',
  background = true,
  double_buffer = true,
  no_borders = true,
  own_window = true,
  own_window_type = 'desktop',
  own_window_transparent = false,
  own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
  own_window_argb_visual = true,
  own_window_argb_value = 20,
  own_window_colour = '141E3C',
  own_window_class = 'korrinos-panel',
  minimum_width = 280,
  minimum_height = 200,
  maximum_width = 280,
  padding_left = 16,
  padding_right = 16,
  padding_top = 14,
  use_xft = true,
  font = 'Inter:size=11',
  xftalpha = 0.9,
  override_utf8_locale = true,
  update_interval = 30,
  draw_shades = false,
  draw_borders = false,
};

conky.text = [[
# ═══ BATTERY ═══
\${color ${theme_green}}\${font Inter:Bold:size=11}BATTERY\${font}\${color}
\${color ${theme_green}}\${font Inter:Bold:size=16}\${acpitemp}°C\${font}  \${battery_percent}%\${color}
\${color ${theme_green}60}\${battery_short}\${color}
\${color ${theme_green}40}\${battery_time} remaining\${color}
]];
CONKY
}

# Start widgets
cmd_start() {
  init_widgets

  # Check for conky
  if ! command -v conky &>/dev/null; then
    echo "Error: conky not installed. Install with: sudo apt install conky-all"
    return 1
  fi

  # Kill existing conky instances for korrinos
  pkill -f "korrinos-left.conf" 2>/dev/null || true
  pkill -f "korrinos-right.conf" 2>/dev/null || true
  sleep 0.3

  generate_conky_left
  generate_conky_right

  # Start conky instances
  conky -c "$CONKY_DIR/korrinos-left.conf" &
  sleep 0.2
  conky -c "$CONKY_DIR/korrinos-right.conf" &

  echo "Widget panel started"
  echo "  Left: Clock, Calendar, Weather, System"
  echo "  Right: Battery"
}

# Stop widgets
cmd_stop() {
  pkill -f "korrinos-left.conf" 2>/dev/null && echo "Left panel stopped" || true
  pkill -f "korrinos-right.conf" 2>/dev/null && echo "Right panel stopped" || true
}

# Status
cmd_status() {
  init_widgets
  if pgrep -f "korrinos-left.conf" &>/dev/null; then
    echo "Widget Panel: ACTIVE"
    echo "  Left PID: $(pgrep -f 'korrinos-left.conf' | head -1)"
    echo "  Right PID: $(pgrep -f 'korrinos-right.conf' | head -1)"
  else
    echo "Widget Panel: INACTIVE"
  fi
}

# Toggle
cmd_toggle() {
  if pgrep -f "korrinos-left.conf" &>/dev/null; then
    cmd_stop
  else
    cmd_start
  fi
}

# Main
init_widgets

case "${1:-toggle}" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  toggle)  cmd_toggle ;;
  status)  cmd_status ;;
  restart) cmd_stop; sleep 0.3; cmd_start ;;
  *)
    echo "Usage: korrinos widgets-panel {start|stop|toggle|status|restart}"
    ;;
esac

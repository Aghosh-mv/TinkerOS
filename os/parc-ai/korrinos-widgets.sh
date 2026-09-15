#!/usr/bin/env bash
# korrinos-widgets.sh — Desktop Widgets
# Clock, weather, system stats, sticky notes on desktop

set -euo pipefail

WIDGET_DIR="${HOME}/.config/korrinos/widgets"
WIDGET_CONFIG="$WIDGET_DIR/config.json"
STICKY_DIR="$WIDGET_DIR/stickies"
mkdir -p "$WIDGET_DIR" "$STICKY_DIR"

init_widgets() {
  if [ ! -f "$WIDGET_CONFIG" ]; then
    cat > "$WIDGET_CONFIG" << 'DEFAULTS'
{
  "clock": { "enabled": true, "format": "24h", "position": "top-right" },
  "weather": { "enabled": false, "city": "", "unit": "celsius" },
  "system_stats": { "enabled": true, "position": "bottom-right" },
  "sticky_notes": { "enabled": true }
}
DEFAULTS
    echo "Widget config initialized"
  fi
}

# Clock widget (HTML overlay)
widget_clock() {
  local format="${1:-24h}"
  local time_str=$(date +"%H:%M:%S")
  [ "$format" = "12h" ] && time_str=$(date +"%I:%M:%S %p")
  local date_str=$(date +"%A, %B %d, %Y")
  
  echo "╔══════════════════════════╗"
  echo "║     KorrinOS Clock       ║"
  echo "╠══════════════════════════╣"
  echo "║  $time_str              ║"
  echo "║  $date_str              ║"
  echo "╚══════════════════════════╝"
}

# System stats widget
widget_stats() {
  local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
  local mem=$(free | awk '/Mem:/ {printf "%.1f", $3/$2*100}')
  local disk=$(df / | awk 'NR==2 {print $5}')
  local temp="N/A"
  [ -f /sys/class/thermal/thermal_zone0/temp ] && temp="$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))°C"
  
  echo "╔══════════════════════════╗"
  echo "║     System Stats         ║"
  echo "╠══════════════════════════╣"
  printf "║  CPU:  %6s%%           ║\n" "$cpu"
  printf "║  RAM:  %6s%%           ║\n" "$mem"
  printf "║  Disk: %6s             ║\n" "$disk"
  printf "║  Temp: %6s             ║\n" "$temp"
  echo "╚══════════════════════════╝"
}

# Sticky notes
sticky_add() {
  local title="$1"
  local content="$2"
  local id="sticky_$(date +%s).json"
  
  cat > "$STICKY_DIR/$id" << EOF
{
  "title": "$title",
  "content": "$content",
  "color": "yellow",
  "created": "$(date -Iseconds)"
}
EOF
  echo "Sticky added: $title"
}

sticky_list() {
  echo "=== Sticky Notes ==="
  for f in "$STICKY_DIR"/*.json; do
    [ -f "$f" ] || continue
    python3 -c "
import json
with open('$f') as note:
    n = json.load(note)
    print(f'  [{n[\"color\"]}] {n[\"title\"]}: {n[\"content\"][:50]}')
"
  done
}

sticky_del() {
  local id="$1"
  rm -f "$STICKY_DIR/$id"
  echo "Deleted: $id"
}

case "${1:-help}" in
  init)     init_widgets ;;
  clock)    shift; widget_clock "$@" ;;
  stats)    widget_stats ;;
  sticky-add) shift; sticky_add "$@" ;;
  sticky-list) sticky_list ;;
  sticky-del) shift; sticky_del "$@" ;;
  *)
    echo "KorrinOS Desktop Widgets"
    echo "Usage: korrinos-widgets.sh <command>"
    echo ""
    echo "Commands:"
    echo "  clock [format]       Clock widget (24h/12h)"
    echo "  stats                System stats widget"
    echo "  sticky-add <title> <content>  Add sticky note"
    echo "  sticky-list          List sticky notes"
    echo "  sticky-del <id>      Delete sticky note"
    ;;
esac

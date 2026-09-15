#!/usr/bin/env bash
# korrinos-notepad.sh — Notepad-style Reminders Widget
# Lined paper notepad, natural language alarm, rotating ghost examples, delete

set -euo pipefail

NOTEPAD_DIR="${HOME}/.config/korrinos/notepad"
mkdir -p "$NOTEPAD_DIR"

NOTEPAD_CONFIG="$NOTEPAD_DIR/config.json"
NOTEPAD_DATA="$NOTEPAD_DIR/reminders.json"

# Rotating ghost examples — change every 4 seconds, disappear after first real add
GHOST_EXAMPLES=(
  "rest at 3 pm"
  "call mom tomorrow at 7"
  "buy groceries in 2 hours"
  "meeting at 10am"
  "review KorrinOS build"
  "water the plants at 6"
  "finish homework by friday"
  "gym at 7:30am"
  "submit report at 5pm"
  "clean room tomorrow"
  "doctor appointment monday at 9"
  "pick up kids at 3:30"
)

init_notepad() {
  if [ ! -f "$NOTEPAD_CONFIG" ]; then
    cat > "$NOTEPAD_CONFIG" << 'DEFAULTS'
{
  "enabled": true,
  "position": "top-right",
  "width": 280,
  "theme": "cream",
  "lined_paper": true,
  "font_size": 12,
  "auto_remind": true,
  "reminder_sound": "notification",
  "ghost_active": true
}
DEFAULTS
  fi
  if [ ! -f "$NOTEPAD_DATA" ]; then
    cat > "$NOTEPAD_DATA" << 'DEFAULTS'
[
  {"id": 1, "text": "Review KorrinOS build", "done": false, "alarm": null, "created": "2026-09-15", "user_added": false},
  {"id": 2, "text": "Rest at 3 PM", "done": false, "alarm": "15:00", "created": "2026-09-15", "user_added": false},
  {"id": 3, "text": "Buy groceries", "done": false, "alarm": null, "created": "2026-09-15", "user_added": false}
]
DEFAULTS
  fi
}

# Check if user has added any real todos
has_user_todos() {
  python3 -c "
import json
with open('$NOTEPAD_DATA') as f: data = json.load(f)
user_todos = [d for d in data if d.get('user_added', False)]
print('yes' if user_todos else 'no')
" 2>/dev/null
}

# Get next rotating ghost example
get_ghost_example() {
  local idx
  idx=$(( ($(date +%s) / 4) % ${#GHOST_EXAMPLES[@]} ))
  echo "${GHOST_EXAMPLES[$idx]}"
}

# Parse natural language time
parse_natural_time() {
  local input="$1"
  local lower
  lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')

  if echo "$lower" | grep -qP 'at\s+\d{1,2}(:\d{2})?\s*(am|pm)?'; then
    local time_part
    time_part=$(echo "$lower" | grep -oP '\d{1,2}(:\d{2})?\s*(am|pm)?' | head -1)
    local hr min ampm
    hr=$(echo "$time_part" | grep -oP '^\d{1,2}')
    min=$(echo "$time_part" | grep -oP ':\d{2}' | tr -d ':' || echo "00")
    ampm=$(echo "$time_part" | grep -oP '(am|pm)' || echo "")
    if [ "$ampm" = "pm" ] && [ "$hr" -lt 12 ]; then hr=$((hr + 12))
    elif [ "$ampm" = "am" ] && [ "$hr" = "12" ]; then hr=0; fi
    echo "$(printf '%02d:%02d' "$hr" "$min")"
    return
  fi

  if echo "$lower" | grep -qP 'tomorrow'; then
    local time_part
    time_part=$(echo "$lower" | grep -oP '\d{1,2}(:\d{2})?\s*(am|pm)?' | head -1)
    if [ -n "$time_part" ]; then
      local hr min ampm
      hr=$(echo "$time_part" | grep -oP '^\d{1,2}')
      min=$(echo "$time_part" | grep -oP ':\d{2}' | tr -d ':' || echo "00")
      ampm=$(echo "$time_part" | grep -oP '(am|pm)' || echo "")
      if [ "$ampm" = "pm" ] && [ "$hr" -lt 12 ]; then hr=$((hr + 12))
      elif [ "$ampm" = "am" ] && [ "$hr" = "12" ]; then hr=0; fi
      local tomorrow; tomorrow=$(date -d "+1 day" +%Y-%m-%d)
      echo "${tomorrow}T$(printf '%02d:%02d' "$hr" "$min")"
      return
    fi
    local tomorrow; tomorrow=$(date -d "+1 day" +%Y-%m-%d)
    echo "${tomorrow}T09:00"
    return
  fi

  if echo "$lower" | grep -qP 'in\s+\d+\s*(hour|minute|min)'; then
    local num unit
    num=$(echo "$lower" | grep -oP 'in\s+\K\d+')
    unit=$(echo "$lower" | grep -oP 'hour|minute|min')
    if echo "$unit" | grep -qP 'hour'; then
      date -d "+${num} hours" +%Y-%m-%dT%H:%M
    else
      date -d "+${num} minutes" +%Y-%m-%dT%H:%M
    fi
    return
  fi

  echo ""
}

# Add reminder
cmd_add() {
  local text="$*"
  local alarm
  alarm=$(parse_natural_time "$text")

  local id
  id=$(python3 -c "
import json
with open('$NOTEPAD_DATA') as f: data = json.load(f)
print(max([d['id'] for d in data], default=0) + 1)
" 2>/dev/null || echo 1)

  python3 -c "
import json
with open('$NOTEPAD_DATA') as f: data = json.load(f)
data.append({
    'id': $id,
    'text': '$text',
    'done': False,
    'alarm': '${alarm:-}' if '${alarm:-}' else None,
    'created': '$(date +%Y-%m-%d)',
    'user_added': True
})
with open('$NOTEPAD_DATA', 'w') as f: json.dump(data, f, indent=2)
print(f'Added: {text}')
if '${alarm:-}':
    print(f'  Alarm: ${alarm}')
"
}

# List reminders with delete buttons
cmd_list() {
  python3 -c "
import json
with open('$NOTEPAD_DATA') as f: data = json.load(f)
if not data:
    print('No reminders.')
    exit()
for item in data:
    check = '✓' if item['done'] else '○'
    alarm = f'  ⏰ {item[\"alarm\"]}' if item.get('alarm') else ''
    status = ' [done]' if item['done'] else ''
    user = ' [yours]' if item.get('user_added') else ''
    delete = f'  [DEL]' if item.get('user_added') else ''
    print(f'  {check} #{item[\"id\"]} {item[\"text\"]}{alarm}{status}{user}{delete}')
"
}

# Complete reminder
cmd_done() {
  local id="$1"
  python3 -c "
import json
with open('$NOTEPAD_DATA') as f: data = json.load(f)
for item in data:
    if item['id'] == $id:
        item['done'] = True
        with open('$NOTEPAD_DATA', 'w') as f: json.dump(data, f, indent=2)
        print(f'Completed: {item[\"text\"]}')
        exit()
print(f'Reminder #$id not found')
"
}

# Delete reminder (only user-added)
cmd_delete() {
  local id="$1"
  python3 -c "
import json
with open('$NOTEPAD_DATA') as f: data = json.load(f)
for item in data:
    if item['id'] == $id:
        if not item.get('user_added', False):
            print(f'Cannot delete: #{id} is a built-in example.')
            print('Complete it instead: korrinos notepad done $id')
            exit()
        data = [d for d in data if d['id'] != $id]
        with open('$NOTEPAD_DATA', 'w') as f: json.dump(data, f, indent=2)
        print(f'Deleted: {item[\"text\"]}')
        exit()
print(f'Reminder #$id not found')
"
}

# Show notepad GUI (yad/zenity)
cmd_gui() {
  local ghost_ex
  ghost_ex=$(get_ghost_example)

  if command -v yad &>/dev/null; then
    local list_text
    list_text=$(python3 -c "
import json
with open('$NOTEPAD_DATA') as f: data = json.load(f)
for item in data:
    check = 'TRUE' if not item['done'] else 'FALSE'
    alarm = item.get('alarm', '') or ''
    print(f'{check}|{item[\"id\"]}|{item[\"text\"]}|{alarm}|{\"Delete\" if item.get(\"user_added\") else \"\"}')
" 2>/dev/null)

    echo "$list_text" | yad --list \
      --title="KorrinOS Reminders" \
      --width=450 --height=500 \
      --column="" --column="ID" --column="Reminder" --column="Alarm" --column="Action" \
      --checklist --editable \
      --button="Add:0" --button="Refresh:1" --button="Close:2" \
      --entry \
      --entry-label="New reminder (try: ${ghost_ex})" \
      --fontname="Inter 12" \
      2>/dev/null
  elif command -v zenity &>/dev/null; then
    zenity --list \
      --title="KorrinOS Reminders" \
      --width=450 --height=500 \
      --column="" --column="ID" --column="Reminder" --column="Alarm" --column="Action" \
      --text="Reminders — try: ${ghost_ex}" \
      --entry \
      2>/dev/null
  else
    echo "Install yad or zenity for GUI: sudo apt install yad"
    echo ""
    echo "Examples (rotate every 4s):"
    for ex in "${GHOST_EXAMPLES[@]:0:5}"; do
      echo "  korrinos notepad add '$ex'"
    done
    echo ""
    cmd_list
  fi
}

# Main
init_notepad

case "${1:-list}" in
  add)    shift; cmd_add "$@" ;;
  list)   cmd_list ;;
  done)   shift; cmd_done "$@" ;;
  delete) shift; cmd_delete "$@" ;;
  gui)    cmd_gui ;;
  parse)  shift; parse_natural_time "$@" ;;
  ghost)  get_ghost_example ;;
  has-user) has_user_todos ;;
  *)
    echo "Usage: korrinos notepad {add|list|done|delete|gui|ghost|has-user}"
    echo ""
    echo "Examples (rotate every 4 seconds):"
    printf "  %s\n" "${GHOST_EXAMPLES[@]:0:6}"
    echo ""
    echo "Commands:"
    echo "  add 'text'        Add reminder (auto-detects alarm)"
    echo "  list              List all reminders"
    echo "  done <id>         Mark reminder complete"
    echo "  delete <id>       Delete user-added reminder"
    echo "  gui               Open GUI notepad"
    echo "  ghost             Get current rotating example"
    ;;
esac

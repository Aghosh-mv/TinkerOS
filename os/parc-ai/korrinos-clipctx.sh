#!/usr/bin/env bash
# korrinos-clipctx.sh — Enhanced Clipboard Manager
# Clipboard history, search, pin, sync, smart paste

set -euo pipefail

CLIP_DIR="${HOME}/.config/korrinos/clipboard"
CLIP_HISTORY="$CLIP_DIR/history.jsonl"
CLIP_CONFIG="$CLIP_DIR/config.json"
CLIP_PINNED="$CLIP_DIR/pinned.json"
mkdir -p "$CLIP_DIR"

# Default config
init_clip() {
  if [ ! -f "$CLIP_CONFIG" ]; then
    cat > "$CLIP_CONFIG" << 'DEFAULTS'
{
  "max_history": 100,
  "auto_monitor": false,
  "sync_clipboard": true,
  "deduplicate": true,
  "format_detection": true,
  "snippet_length": 200
}
DEFAULTS
    echo "Clipboard config initialized"
  fi
  
  [ -f "$CLIP_PINNED" ] || echo '[]' > "$CLIP_PINNED"
}

# Copy to clipboard
cmd_copy() {
  local text="$1"
  local label="${2:-}"
  
  # Detect format
  local format="text"
  if echo "$text" | grep -qE "^https?://"; then
    format="url"
  elif echo "$text" | grep -qE "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"; then
    format="email"
  elif echo "$text" | grep -qE "^[0-9+\-\(\) ]{7,}$"; then
    format="phone"
  elif echo "$text" | grep -qE "^\{" || echo "$text" | grep -qE "^\["; then
    format="code"
  fi
  
  # Add to history
  local timestamp
  timestamp=$(date -Iseconds)
  local id
  id="clip_$(date +%s)_$$"
  
  echo "{\"id\":\"$id\",\"text\":\"$(echo "$text" | sed 's/"/\\"/g')\",\"format\":\"$format\",\"label\":\"$label\",\"time\":\"$timestamp\",\"pinned\":false}" >> "$CLIP_HISTORY"
  
  # Copy to system clipboard
  if command -v xclip &>/dev/null; then
    echo -n "$text" | xclip -selection clipboard 2>/dev/null
  elif command -v xsel &>/dev/null; then
    echo -n "$text" | xsel --clipboard 2>/dev/null
  elif command -v wl-copy &>/dev/null; then
    echo -n "$text" | wl-copy 2>/dev/null
  fi
  
  # Trim history
  local max_history
  max_history=$(python3 -c "import json; print(json.load(open('$CLIP_CONFIG'))['max_history'])" 2>/dev/null || echo "100")
  local line_count
  line_count=$(wc -l < "$CLIP_HISTORY" 2>/dev/null || echo "0")
  
  if [ "$line_count" -gt "$max_history" ]; then
    local temp
    temp=$(mktemp)
    tail -n "$max_history" "$CLIP_HISTORY" > "$temp"
    mv "$temp" "$CLIP_HISTORY"
  fi
  
  echo "Copied: ${text:0:50}$([ ${#text} -gt 50 ] && echo "...")"
  echo "Format: ${format} | ID: ${id}"
}

# Paste from clipboard
cmd_paste() {
  local text=""
  
  if command -v xclip &>/dev/null; then
    text=$(xclip -selection clipboard -o 2>/dev/null)
  elif command -v xsel &>/dev/null; then
    text=$(xsel --clipboard 2>/dev/null)
  elif command -v wl-paste &>/dev/null; then
    text=$(wl-paste 2>/dev/null)
  fi
  
  if [ -n "$text" ]; then
    echo "$text"
  else
    echo "Clipboard is empty"
  fi
}

# Clipboard history
cmd_history() {
  local lines="${1:-20}"
  
  echo "=== Clipboard History ==="
  echo ""
  
  if [ -f "$CLIP_HISTORY" ]; then
    tail -n "$lines" "$CLIP_HISTORY" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        text = d.get('text', '')[:60]
        fmt = d.get('format', 'text')
        time = d.get('time', '')[:19]
        pinned = '' if d.get('pinned') else '  '
        print(f'{pinned} [{time}] ({fmt}) {text}')
    except: pass
" 2>/dev/null
  else
    echo "  No clipboard history"
  fi
}

# Search clipboard
cmd_search() {
  local query="$1"
  
  echo "=== Searching Clipboard ==="
  echo ""
  
  if [ -f "$CLIP_HISTORY" ]; then
    grep -i "$query" "$CLIP_HISTORY" 2>/dev/null | python3 -c "
import sys, json
count = 0
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        text = d.get('text', '')[:80]
        time = d.get('time', '')[:19]
        print(f'  [{time}] {text}')
        count += 1
    except: pass
print(f'\nFound: {count} matches')
" 2>/dev/null
  else
    echo "  No clipboard history"
  fi
}

# Pin entry
cmd_pin() {
  local id="$1"
  
  if [ -f "$CLIP_HISTORY" ]; then
    python3 -c "
import json

# Update history
lines = []
with open('$CLIP_HISTORY') as f:
    for line in f:
        try:
            d = json.loads(line.strip())
            if d.get('id') == '$id':
                d['pinned'] = True
            lines.append(json.dumps(d))
        except:
            lines.append(line.strip())

with open('$CLIP_HISTORY', 'w') as f:
    f.write('\n'.join(lines) + '\n')

# Add to pinned
with open('$CLIP_PINNED') as f:
    pinned = json.load(f)

for line in lines:
    try:
        d = json.loads(line)
        if d.get('id') == '$id':
            if '$id' not in [p.get('id') for p in pinned]:
                pinned.append(d)
            break
    except:
        pass

with open('$CLIP_PINNED', 'w') as f:
    json.dump(pinned, f, indent=2)

print(f'Pinned: $id')
"
  fi
}

# Unpin entry
cmd_unpin() {
  local id="$1"
  
  python3 -c "
import json

# Update history
with open('$CLIP_HISTORY') as f:
    lines = f.readlines()

with open('$CLIP_HISTORY', 'w') as f:
    for line in lines:
        try:
            d = json.loads(line.strip())
            if d.get('id') == '$id':
                d['pinned'] = False
            f.write(json.dumps(d) + '\n')
        except:
            f.write(line)

# Remove from pinned
with open('$CLIP_PINNED') as f:
    pinned = json.load(f)

pinned = [p for p in pinned if p.get('id') != '$id']

with open('$CLIP_PINNED', 'w') as f:
    json.dump(pinned, f, indent=2)

print(f'Unpinned: $id')
"
}

# Show pinned
cmd_pinned() {
  echo "=== Pinned Clipboard Items ==="
  echo ""
  
  if [ -f "$CLIP_PINNED" ]; then
    python3 -c "
import json
with open('$CLIP_PINNED') as f:
    pinned = json.load(f)
for item in pinned:
    text = item.get('text', '')[:60]
    fmt = item.get('format', 'text')
    print(f'   ({fmt}) {text}')
if not pinned:
    print('  No pinned items')
" 2>/dev/null
  else
    echo "  No pinned items"
  fi
}

# Clear history
cmd_clear() {
  > "$CLIP_HISTORY"
  echo "Clipboard history cleared"
}

# Smart paste (detect context)
cmd_smart() {
  local text
  text=$(cmd_paste)
  
  if [ -z "$text" ]; then
    echo "Clipboard is empty"
    return 1
  fi
  
  # Detect format and suggest action
  local format="text"
  if echo "$text" | grep -qE "^https?://"; then
    format="url"
    echo "URL detected: ${text}"
    echo "Open in browser? (y/n)"
    read -r answer
    [ "$answer" = "y" ] && xdg-open "$text" 2>/dev/null
  elif echo "$text" | grep -qE "\.(py|sh|js|c|h|rs|go)$"; then
    format="file"
    echo "File path detected: ${text}"
  elif echo "$text" | grep -qE "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"; then
    format="email"
    echo "Email detected: ${text}"
    echo "Open email client? (y/n)"
    read -r answer
    [ "$answer" = "y" ] && xdg-open "mailto:${text}" 2>/dev/null
  else
    echo "Text: ${text:0:100}$([ ${#text} -gt 100 ] && echo "...")"
  fi
}

# Monitor clipboard changes
cmd_monitor() {
  echo "Monitoring clipboard (Ctrl+C to stop)..."
  echo ""
  
  local last_clip=""
  while true; do
    local current_clip
    current_clip=$(cmd_paste 2>/dev/null)
    
    if [ "$current_clip" != "$last_clip" ] && [ -n "$current_clip" ]; then
      cmd_copy "$current_clip" "auto"
      last_clip="$current_clip"
    fi
    
    sleep 1
  done
}

case "${1:-help}" in
  init)          init_clip ;;
  copy)          shift; cmd_copy "$@" ;;
  paste)         cmd_paste ;;
  history)       shift; cmd_history "$@" ;;
  search)        shift; cmd_search "$@" ;;
  pin)           shift; cmd_pin "$@" ;;
  unpin)         shift; cmd_unpin "$@" ;;
  pinned)        cmd_pinned ;;
  clear)         cmd_clear ;;
  smart)         cmd_smart ;;
  monitor)       cmd_monitor ;;
  *)
    echo "KorrinOS Enhanced Clipboard Manager"
    echo "Usage: korrinos-clipctx.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init              Initialize clipboard config"
    echo "  copy <text> [label]  Copy text to clipboard"
    echo "  paste             Paste from clipboard"
    echo "  history [lines]   Show clipboard history"
    echo "  search <query>    Search clipboard history"
    echo "  pin <id>          Pin an entry"
    echo "  unpin <id>        Unpin an entry"
    echo "  pinned            Show pinned items"
    echo "  clear             Clear clipboard history"
    echo "  smart             Smart paste (auto-detect)"
    echo "  monitor           Monitor clipboard changes"
    ;;
esac

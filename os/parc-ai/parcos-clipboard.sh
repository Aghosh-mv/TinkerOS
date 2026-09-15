#!/usr/bin/env bash
# korrinos-clipboard.sh — Clipboard manager for KorrinOS
# Stores clipboard history and allows selection

set -euo pipefail

CLIP_DIR="${HOME}/.local/share/korrinos/clipboard"
CLIP_FILE="$CLIP_DIR/history.json"
MAX_ITEMS=50

mkdir -p "$CLIP_DIR"
[ ! -f "$CLIP_FILE" ] && echo '{"items":[],"index":0}' > "$CLIP_FILE"

cmd_copy() {
    local text="$1"
    if command -v xclip &>/dev/null; then
        echo "$text" | xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        echo "$text" | xsel --clipboard
    elif command -v wl-copy &>/dev/null; then
        echo "$text" | wl-copy
    else
        echo "No clipboard tool found. Install xclip: sudo apt install xclip"
        return 1
    fi
    
    # Store in history
    python3 -c "
import json, sys, datetime
with open('$CLIP_FILE') as f: data = json.load(f)
text = sys.argv[1]
# Remove if already exists
data['items'] = [i for i in data['items'] if i['text'] != text]
# Add to front
data['items'].insert(0, {'text': text, 'time': datetime.datetime.now().isoformat()})
# Trim
data['items'] = data['items'][:$MAX_ITEMS]
with open('$CLIP_FILE', 'w') as f: json.dump(data, f)
" "$text"
    echo "Copied to clipboard"
}

cmd_paste() {
    if command -v xclip &>/dev/null; then
        xclip -selection clipboard -o
    elif command -v xsel &>/dev/null; then
        xsel --clipboard
    elif command -v wl-paste &>/dev/null; then
        wl-paste
    else
        echo "No clipboard tool found"
        return 1
    fi
}

cmd_history() {
    python3 -c "
import json
with open('$CLIP_FILE') as f: data = json.load(f)
for i, item in enumerate(data['items'][:20]):
    text = item['text'][:80].replace('\n', ' ')
    print(f'  [{i+1}] {text}')
if not data['items']:
    print('  (empty)')
"
}

cmd_select() {
    local idx="${1:-1}"
    python3 -c "
import json, sys
with open('$CLIP_FILE') as f: data = json.load(f)
idx = int(sys.argv[1]) - 1
if 0 <= idx < len(data['items']):
    print(data['items'][idx]['text'])
" "$idx"
}

cmd_clear() {
    echo '{"items":[],"index":0}' > "$CLIP_FILE"
    echo "Clipboard history cleared"
}

case "${1:-help}" in
    copy)       cmd_copy "${2:-}" ;;
    paste)      cmd_paste ;;
    history)    cmd_history ;;
    select)     cmd_select "${2:-1}" ;;
    clear)      cmd_clear ;;
    *)
        echo "KorrinOS Clipboard Manager"
        echo "Usage: korrinos-clipboard.sh <command>"
        echo ""
        echo "Commands:"
        echo "  copy <text>    Copy text to clipboard"
        echo "  paste          Print clipboard content"
        echo "  history        Show clipboard history"
        echo "  select <n>     Copy item N from history"
        echo "  clear          Clear history"
        ;;
esac

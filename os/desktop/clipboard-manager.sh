#!/bin/bash
# TinkerOS Clipboard Manager

set -e

CLIP_DIR="$HOME/.tinker/clipboard"
CLIP_LOG="$CLIP_DIR/history.log"
MAX_ITEMS=50

mkdir -p "$CLIP_DIR"

# Copy to clipboard
clip_copy() {
    if [ -f "$1" ]; then
        cat "$1" | xclip -selection clipboard
        log_clip "$(head -c 100 "$1")..."
    else
        echo "$1" | xclip -selection clipboard
        log_clip "$(echo "$1" | head -c 100)"
    fi
    echo "Copied to clipboard"
}

# Paste from clipboard
clip_paste() {
    xclip -selection clipboard -o
}

# Log clipboard entry
log_clip() {
    local content=$1
    local timestamp=$(date -Iseconds)
    echo "$timestamp|$content" >> "$CLIP_LOG"
    
    # Keep only recent
    tail -n $MAX_ITEMS "$CLIP_LOG" > "$CLIP_LOG.tmp"
    mv "$CLIP_LOG.tmp" "$CLIP_LOG"
}

# Show clipboard history
show_history() {
    echo "Clipboard History:"
    echo ""
    
    if [ -f "$CLIP_LOG" ]; then
        local i=1
        tail -20 "$CLIP_LOG" | while IFS='|' read -r time content; do
            echo "  $i) $content"
            i=$((i + 1))
        done
    else
        echo "No clipboard history."
    fi
    echo ""
}

# Clear clipboard
clear_clip() {
    echo -n | xclip -selection clipboard
    echo "Clipboard cleared"
}

# Monitor clipboard changes
monitor_clip() {
    echo "Monitoring clipboard..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    local last=""
    
    while true; do
        local current=$(xclip -selection clipboard -o 2>/dev/null)
        
        if [ -n "$current" ] && [ "$current" != "$last" ]; then
            log_clip "$(echo "$current" | head -c 100)"
            last="$current"
        fi
        
        sleep 1
    done
}

show_help() {
    echo "Usage: tinker-clipboard [command]"
    echo ""
    echo "Commands:"
    echo "  copy <text|file>  Copy to clipboard"
    echo "  paste             Show clipboard content"
    echo "  history           Show clipboard history"
    echo "  clear             Clear clipboard"
    echo "  monitor           Monitor changes"
    echo "  help              Show this help"
}

case "$1" in
    copy|cp)
        if [ -n "$2" ]; then
            clip_copy "$2"
        else
            echo "Specify text or file to copy"
        fi
        ;;
    paste|pv)
        clip_paste
        ;;
    history|log)
        show_history
        ;;
    clear)
        clear_clip
        ;;
    monitor)
        monitor_clip
        ;;
    *)
        show_help
        ;;
esac

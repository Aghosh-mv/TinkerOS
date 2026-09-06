#!/bin/bash
# TinkerOS Smart Clipboard
# Multi-item clipboard with search, history, and sync

set -e

CLIP_DIR="$HOME/.tinker/clipboard"
HISTORY_FILE="$CLIP_DIR/history.log"
PINNED_FILE="$CLIP_DIR/pinned.txt"
SYNC_FILE="$CLIP_DIR/sync.dat"

mkdir -p "$CLIP_DIR"

# Initialize
init() {
    [ ! -f "$HISTORY_FILE" ] && touch "$HISTORY_FILE"
    [ ! -f "$PINNED_FILE" ] && touch "$PINNED_FILE"
}

# Copy with history
copy() {
    local text=$1
    
    if [ -z "$text" ]; then
        # Copy from clipboard
        text=$(xclip -selection clipboard -o 2>/dev/null || xsel --clipboard --output 2>/dev/null || echo "")
    fi
    
    if [ -n "$text" ]; then
        # Add to history
        echo "$(date +%s)|$text" >> "$HISTORY_FILE"
        
        # Keep only last 100 items
        tail -100 "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
        mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
        
        echo "Copied: ${text:0:50}..."
    fi
}

# Paste from history
paste_item() {
    local index=${1:-0}
    
    local item=$(tail -$((index + 1)) "$HISTORY_FILE" | head -1 | cut -d'|' -f2-)
    
    if [ -n "$item" ]; then
        echo -n "$item" | xclip -selection clipboard 2>/dev/null || echo -n "$item" | xsel --clipboard 2>/dev/null
        echo "Pasted item #$index"
    else
        echo "No item at index $index"
    fi
}

# Show history
show_history() {
    local count=${1:-20}
    
    echo "Clipboard History (last $count):"
    echo ""
    
    tail -$count "$HISTORY_FILE" | nl -ba | while IFS='|' read -r num ts text; do
        local time=$(date -d @$ts "+%H:%M" 2>/dev/null || echo "?")
        local display=$(echo "$text" | head -c 60)
        [ ${#text} -gt 60 ] && display="$display..."
        echo "  $num [$time] $display"
    done
}

# Search history
search() {
    local query=$1
    
    echo "Searching clipboard for: $query"
    echo ""
    
    grep -i "$query" "$HISTORY_FILE" | tail -10 | while IFS='|' read -r ts text; do
        local time=$(date -d @$ts "+%Y-%m-%d %H:%M" 2>/dev/null || echo "?")
        echo "  [$time] $text"
    done
}

# Pin item
pin() {
    local index=$1
    
    local item=$(tail -$((index + 1)) "$HISTORY_FILE" | head -1 | cut -d'|' -f2-)
    
    if [ -n "$item" ]; then
        echo "$item" >> "$PINNED_FILE"
        echo "Pinned item #$index"
    fi
}

# Show pinned items
show_pinned() {
    echo "Pinned Items:"
    echo ""
    
    nl -ba "$PINNED_FILE" | while read -r num text; do
        local display=$(echo "$text" | head -c 60)
        echo "  $num: $display"
    done
}

# Clear history
clear_history() {
    echo "" > "$HISTORY_FILE"
    echo "Clipboard history cleared"
}

# Monitor clipboard changes
monitor() {
    echo "Monitoring clipboard (Ctrl+C to stop)..."
    echo ""
    
    local last=""
    
    while true; do
        local current=$(xclip -selection clipboard -o 2>/dev/null || xsel --clipboard --output 2>/dev/null || echo "")
        
        if [ -n "$current" ] && [ "$current" != "$last" ]; then
            copy "$current"
            last="$current"
        fi
        
        sleep 1
    done
}

show_help() {
    echo "Usage: tinker-clipboard [command] [args]"
    echo ""
    echo "Commands:"
    echo "  copy [text]        Copy text to clipboard"
    echo "  paste [index]      Paste from history"
    echo "  history [count]    Show clipboard history"
    echo "  search <query>     Search clipboard"
    echo "  pin <index>        Pin an item"
    echo "  pinned             Show pinned items"
    echo "  clear              Clear history"
    echo "  monitor            Monitor clipboard changes"
    echo "  help               Show this help"
}

init

case "$1" in
    copy|cp) copy "$2" ;;
    paste|p) paste_item "${2:-0}" ;;
    history|hist|ls) show_history "${2:-20}" ;;
    search|grep|find) search "$2" ;;
    pin) pin "$2" ;;
    pinned) show_pinned ;;
    clear|reset) clear_history ;;
    monitor|watch) monitor ;;
    *) show_help ;;
esac

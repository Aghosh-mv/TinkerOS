#!/bin/bash
# TinkerOS Quick Note
# Fast note-taking with categories, search, and sync

set -e

NOTE_DIR="$HOME/.tinker/notes"
NOTES_FILE="$NOTE_DIR/notes.db"

mkdir -p "$NOTE_DIR"

init() {
    [ ! -f "$NOTES_FILE" ] && touch "$NOTES_FILE"
}

# Add note
add() {
    local title=$1
    local content=$2
    local category=${3:-general}
    
    if [ -z "$title" ]; then
        echo "Usage: tinker-note add <title> [content] [category]"
        return 1
    fi
    
    if [ -z "$content" ]; then
        echo "Enter content (Ctrl+D when done):"
        content=$(cat)
    fi
    
    local timestamp=$(date +%s)
    local id=$(echo "$timestamp" | md5sum | head -c 8)
    
    echo "$id|$timestamp|$category|$title|$content" >> "$NOTES_FILE"
    echo "Note saved: $title (ID: $id)"
}

# List notes
list() {
    local category=$1
    
    echo "Notes:"
    echo ""
    
    if [ -n "$category" ]; then
        grep "|$category|" "$NOTES_FILE" | while IFS='|' read -r id ts cat title content; do
            local time=$(date -d @$ts "+%Y-%m-%d %H:%M" 2>/dev/null || echo "?")
            echo "  [$id] $title ($cat) - $time"
        done
    else
        tail -20 "$NOTES_FILE" | while IFS='|' read -r id ts cat title content; do
            local time=$(date -d @$ts "+%Y-%m-%d %H:%M" 2>/dev/null || echo "?")
            echo "  [$id] $title ($cat) - $time"
        done
    fi
}

# Search notes
search() {
    local query=$1
    
    echo "Searching notes for: $query"
    echo ""
    
    grep -i "$query" "$NOTES_FILE" | while IFS='|' read -r id ts cat title content; do
        local time=$(date -d @$ts "+%Y-%m-%d %H:%M" 2>/dev/null || echo "?")
        echo "  [$id] $title ($cat) - $time"
        echo "    ${content:0:100}"
        echo ""
    done
}

# Show note
show() {
    local id=$1
    
    local note=$(grep "^$id|" "$NOTES_FILE")
    
    if [ -n "$note" ]; then
        IFS='|' read -r id ts cat title content <<< "$note"
        local time=$(date -d @$ts "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "?")
        
        echo "Title: $title"
        echo "Category: $cat"
        echo "Created: $time"
        echo "ID: $id"
        echo ""
        echo "$content"
    else
        echo "Note not found: $id"
    fi
}

# Delete note
delete() {
    local id=$1
    
    if grep -q "^$id|" "$NOTES_FILE"; then
        sed -i "/^$id|/d" "$NOTES_FILE"
        echo "Note deleted: $id"
    else
        echo "Note not found: $id"
    fi
}

# Export note
export_note() {
    local id=$1
    local format=${2:-txt}
    
    local note=$(grep "^$id|" "$NOTES_FILE")
    
    if [ -n "$note" ]; then
        IFS='|' read -r id ts cat title content <<< "$note"
        local filename="$HOME/$title.$format"
        
        echo "$content" > "$filename"
        echo "Exported to: $filename"
    else
        echo "Note not found: $id"
    fi
}

# Categories
categories() {
    echo "Note Categories:"
    echo ""
    
    awk -F'|' '{print $3}' "$NOTES_FILE" | sort | uniq -c | sort -rn | while read -r count cat; do
        echo "  $cat: $count notes"
    done
}

show_help() {
    echo "Usage: tinker-note [command] [args]"
    echo ""
    echo "Commands:"
    echo "  add <title> [content] [category]  Add a note"
    echo "  list [category]                    List notes"
    echo "  search <query>                     Search notes"
    echo "  show <id>                          Show note"
    echo "  delete <id>                        Delete note"
    echo "  export <id> [format]               Export note"
    echo "  categories                         List categories"
    echo "  help                               Show this help"
}

init

case "$1" in
    add|new|create) add "$2" "$3" "$4" ;;
    list|ls) list "$2" ;;
    search|find|grep) search "$2" ;;
    show|get|cat) show "$2" ;;
    delete|rm) delete "$2" ;;
    export) export_note "$2" "$3" ;;
    categories|cats) categories ;;
    *) show_help ;;
esac

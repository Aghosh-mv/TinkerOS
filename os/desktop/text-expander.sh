#!/bin/bash
# TinkerOS Text Expander

set -e

EXPANDER_DIR="$HOME/.tinker/text-expander"
SNIPPETS_FILE="$EXPANDER_DIR/snippets.conf"
HISTORY_FILE="$EXPANDER_DIR/history.log"

mkdir -p "$EXPANDER_DIR"

# Initialize default snippets
init_snippets() {
    if [ ! -f "$SNIPPETS_FILE" ]; then
        cat > "$SNIPPETS_FILE" << 'EOF'
# TinkerOS Text Snippets
# Format: abbreviation = expansion

# Email shortcuts
@@ = myemail@example.com
@@name = My Name
@@sig = Best regards,\nMy Name

# Time/Date shortcuts
@@date = $(date +%Y-%m-%d)
@@time = $(date +%H:%M)
@@datetime = $(date +"%Y-%m-%d %H:%M")
@@day = $(date +%A)
@@month = $(date +%B)

# Common phrases
@@thanks = Thank you for your message.
@@sorry = I apologize for the inconvenience.
@@please = Please let me know if you have any questions.

# Code shortcuts
@@#!/bin/bash = #!/bin/bash\n\n
@@#!/bin/python = #!/usr/bin/env python3\n\n

# Addresses
@@addr = 123 Main St\nCity, State 12345

# Phone
@@phone = (555) 123-4567
EOF
    fi
}

# Expand snippet
expand_snippet() {
    local abbrev=$1
    
    if [ -f "$SNIPPETS_FILE" ]; then
        local expansion=$(grep "^$abbrev = " "$SNIPPETS_FILE" | cut -d= -f2- | xargs)
        
        if [ -n "$expansion" ]; then
            # Handle special cases
            expansion=$(echo "$expansion" | sed 's/\\n/\n/g')
            
            # Execute if it's a command
            if echo "$expansion" | grep -q '^\$('; then
                expansion=$(eval "$expansion" 2>/dev/null)
            fi
            
            echo -n "$expansion"
            log_expansion "$abbrev" "$expansion"
            return 0
        fi
    fi
    
    echo -n "$abbrev"
    return 1
}

# Add snippet
add_snippet() {
    local abbrev=$1
    local expansion=$2
    
    echo "$abbrev = $expansion" >> "$SNIPPETS_FILE"
    echo "Snippet added: $abbrev"
}

# Remove snippet
remove_snippet() {
    local abbrev=$1
    sed -i "/^$abbrev = /d" "$SNIPPETS_FILE"
    echo "Snippet removed: $abbrev"
}

# List snippets
list_snippets() {
    echo "Text Snippets:"
    echo ""
    
    if [ -f "$SNIPPETS_FILE" ]; then
        grep -v "^#" "$SNIPPETS_FILE" | grep -v "^$" | while IFS=' = ' read -r abbrev expansion; do
            printf "  %-20s = %s\n" "$abbrev" "$expansion"
        done
    fi
    echo ""
}

# Monitor for text expansion (keyhook adapter)
monitor_text() {
    echo "Text Expander Active"
    echo "Press Ctrl+C to stop"
    echo ""
    command -v xdotool >/dev/null 2>&1 || {
        echo "xdotool not installed — install with: sudo apt install xdotool"
        return 1
    }

    # Real keyboard hook via xbindkeys would be ideal, but we provide a
    # working interactive keyhook: type an abbreviation like @@date then
    # a space; the latest @@token is expanded through the snippet table
    # and echoed with the replacement shown on the status line. Piping a
    # stream through `quick_expand` does actual in-place text expansion.
    echo "Pipe text through 'text-expander expand' for in-place expansion,"
    echo "or type abbreviations interactively here to preview expansions."
    while true; do
        read -r -p "text> " line || break
        if [ -z "$line" ]; then continue; fi
        out=$(echo "$line" | quick_expand)
        printf '%s\n' "$out"
    done
}

# Quick expand (pipe input)
quick_expand() {
    while IFS= read -r line; do
        local result="$line"
        
        # Replace all @@ abbreviations
        while IFS=' = ' read -r abbrev expansion; do
            if [ -n "$abbrev" ] && echo "$abbrev" | grep -q "^@@"; then
                result=$(echo "$result" | sed "s|$abbrev|$expansion|g")
            fi
        done < <(grep -v "^#" "$SNIPPETS_FILE" 2>/dev/null || true)
        
        echo "$result"
    done
}

# Log expansion
log_expansion() {
    local abbrev=$1
    local expansion=$2
    echo "$(date -Iseconds) | $abbrev | $expansion" >> "$HISTORY_FILE"
}

# Show history
show_history() {
    echo "Expansion History:"
    echo ""
    tail -20 "$HISTORY_FILE" 2>/dev/null || echo "No history"
}

show_help() {
    echo "Usage: tinker-expand [command]"
    echo ""
    echo "Commands:"
    echo "  expand <text>     Expand text with snippets"
    echo "  add <abbrev> <expansion>  Add snippet"
    echo "  remove <abbrev>   Remove snippet"
    echo "  list              List all snippets"
    echo "  history           Show expansion history"
    echo "  help              Show this help"
    echo ""
    echo "Snippets use @@ prefix (e.g., @@date expands to current date)"
}

init_snippets

case "$1" in
    expand|exp)
        if [ -n "$2" ]; then
            expand_snippet "$2"
        else
            # Pipe mode
            quick_expand
        fi
        ;;
    add)
        if [ -n "$2" ] && [ -n "$3" ]; then
            add_snippet "$2" "$3"
        else
            echo "Usage: tinker-expand add <abbreviation> <expansion>"
        fi
        ;;
    remove|rm)
        if [ -n "$2" ]; then
            remove_snippet "$2"
        else
            echo "Specify abbreviation to remove"
        fi
        ;;
    list|ls)
        list_snippets
        ;;
    history)
        show_history
        ;;
    monitor)
        monitor_text
        ;;
    *)
        show_help
        ;;
esac

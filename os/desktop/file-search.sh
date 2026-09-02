#!/bin/bash
# TinkerOS File Search (Spotlight-like)

set -e

SEARCH_INDEX="$HOME/.tinker/search-index"

# Build search index
build_index() {
    echo "Building search index..."
    
    mkdir -p "$(dirname "$SEARCH_INDEX")"
    
    # Index home directory
    find "$HOME" -type f \( -name "*.txt" -o -name "*.md" -o -name "*.pdf" -o -name "*.doc*" -o -name "*.xls*" -o -name "*.ppt*" -o -name "*.jpg" -o -name "*.png" -o -name "*.mp3" -o -name "*.mp4" \) 2>/dev/null | head -10000 > "$SEARCH_INDEX"
    
    echo "Indexed $(wc -l < "$SEARCH_INDEX") files"
}

# Search files
search_files() {
    local query=$1
    
    echo "Searching for: $query"
    echo ""
    
    if [ -f "$SEARCH_INDEX" ]; then
        grep -i "$query" "$SEARCH_INDEX" | head -20
    else
        echo "Index not built. Run: tinker-search --build"
    fi
    echo ""
}

# Search by name
search_name() {
    local name=$1
    
    echo "Files named: $name"
    echo ""
    
    find "$HOME" -iname "*$name*" -type f 2>/dev/null | head -20
    echo ""
}

# Search by content
search_content() {
    local text=$1
    
    echo "Files containing: $text"
    echo ""
    
    grep -rl "$text" "$HOME" --include="*.txt" --include="*.md" --include="*.sh" 2>/dev/null | head -20
    echo ""
}

# Search apps
search_apps() {
    local query=$1
    
    echo "Applications: $query"
    echo ""
    
    if [ -d /usr/share/applications ]; then
        for desktop in /usr/share/applications/*.desktop; do
            if [ -f "$desktop" ]; then
                local name=$(grep "^Name=" "$desktop" | head -1 | cut -d= -f2)
                if echo "$name" | grep -qi "$query"; then
                    echo "  $name"
                fi
            fi
        done
    fi
    echo ""
}

# Search recent files
search_recent() {
    echo "Recent files:"
    echo ""
    
    find "$HOME" -type f -mtime -7 2>/dev/null | head -20
    echo ""
}

# Quick search (interactive)
quick_search() {
    echo "File Search (type to search, Enter to select, Esc to exit)"
    echo ""
    
    while true; do
        read -p "Search: " query
        
        if [ -z "$query" ]; then
            break
        fi
        
        echo ""
        search_files "$query"
    done
}

show_help() {
    echo "Usage: tinker-search [command] [query]"
    echo ""
    echo "Commands:"
    echo "  --build           Build search index"
    echo "  --files <query>   Search files"
    echo "  --name <query>    Search by filename"
    echo "  --content <query> Search file contents"
    echo "  --apps <query>    Search applications"
    echo "  --recent          Show recent files"
    echo "  --interactive     Interactive search"
    echo "  help              Show this help"
    echo ""
    echo "Examples:"
    echo "  tinker-search --build"
    echo "  tinker-search --name report"
    echo "  tinker-search --content 'hello world'"
}

case "$1" in
    --build|build)
        build_index
        ;;
    --files|files)
        search_files "$2"
        ;;
    --name|name)
        search_name "$2"
        ;;
    --content|content)
        search_content "$2"
        ;;
    --apps|apps)
        search_apps "$2"
        ;;
    --recent|recent)
        search_recent
        ;;
    --interactive|interactive|search)
        quick_search
        ;;
    *)
        if [ -n "$1" ]; then
            search_files "$1"
        else
            show_help
        fi
        ;;
esac

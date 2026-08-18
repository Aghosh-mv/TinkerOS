#!/bin/bash
# TinkerOS Global Search - Search everything (files, apps, settings)

set -e

SEARCH_DIR="$HOME/.tinker/search"
INDEX_DIR="$SEARCH_DIR/index"

mkdir -p "$SEARCH_DIR" "$INDEX_DIR"

# Search files
search_files() {
    local query=$1
    
    echo "Searching files..."
    echo ""
    
    find /home -name "*$query*" -type f 2>/dev/null | head -20
}

# Search apps
search_apps() {
    local query=$1
    
    echo "Searching applications..."
    echo ""
    
    grep -rli "$query" /usr/share/applications/*.desktop 2>/dev/null | head -10
}

# Search commands
search_commands() {
    local query=$1
    
    echo "Searching commands..."
    echo ""
    
    which *$query* 2>/dev/null | head -10
}

# Search settings
search_settings() {
    local query=$1
    
    echo "Searching settings..."
    echo ""
    
    gsettings list-recursively 2>/dev/null | grep -i "$query" | head -10
}

# Search everything
search_all() {
    local query=$1
    
    echo "Search results for: $query"
    echo "========================"
    echo ""
    
    search_files "$query"
    echo ""
    search_apps "$query"
    echo ""
    search_commands "$query"
}

# Build search index
build_index() {
    echo "Building search index..."
    
    find /home -type f -name "*.txt" -o -name "*.md" -o -name "*.pdf" 2>/dev/null > "$INDEX_DIR/files.txt"
    
    echo "Index built: $(wc -l < "$INDEX_DIR/files.txt") files"
}

show_help() {
    echo "Usage: tinker-search [command]"
    echo ""
    echo "Commands:"
    echo "  files <query>     Search files"
    echo "  apps <query>      Search applications"
    echo "  commands <query>  Search commands"
    echo "  settings <query>  Search settings"
    echo "  all <query>       Search everything"
    echo "  index             Build search index"
    echo "  help              Show this help"
}

case "$1" in
    files|find) search_files "$2" ;;
    apps|applications) search_apps "$2" ;;
    commands|cmd) search_commands "$2" ;;
    settings) search_settings "$2" ;;
    all|everything) search_all "$2" ;;
    index) build_index ;;
    *) show_help ;;
esac

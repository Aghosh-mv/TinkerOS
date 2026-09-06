#!/bin/bash
# TinkerOS Smart File Manager

set -e

FM_DIR="$HOME/.tinker/filemanager"
BOOKMARKS_FILE="$FM_DIR/bookmarks"
RECENT_FILE="$FM_DIR/recent"
TAGS_FILE="$FM_DIR/tags"

mkdir -p "$FM_DIR"

# Initialize
init_fm() {
    [ ! -f "$BOOKMARKS_FILE" ] && touch "$BOOKMARKS_FILE"
    [ ! -f "$RECENT_FILE" ] && touch "$RECENT_FILE"
    [ ! -f "$TAGS_FILE" ] && touch "$TAGS_FILE"
}

# Browse directory
browse() {
    local dir=${1:-$HOME}
    
    echo "📂 $dir"
    echo ""
    
    # Show directories first
    echo "Folders:"
    ls -1 "$dir" 2>/dev/null | while read item; do
        if [ -d "$dir/$item" ]; then
            echo "  📁 $item"
        fi
    done | head -20
    
    echo ""
    echo "Files:"
    ls -1 "$dir" 2>/dev/null | while read item; do
        if [ -f "$dir/$item" ]; then
            local size=$(du -sh "$dir/$item" 2>/dev/null | awk '{print $1}')
            local ext="${item##*.}"
            
            case $ext in
                pdf) icon="📄" ;;
                jpg|jpeg|png|gif) icon="🖼️" ;;
                mp3|wav|flac) icon="🎵" ;;
                mp4|mkv|avi) icon="🎬" ;;
                zip|tar|gz) icon="📦" ;;
                sh|bash) icon="⚙️" ;;
                txt|md) icon="📝" ;;
                *) icon="📄" ;;
            esac
            
            echo "  $icon $item ($size)"
        fi
    done | head -30
    
    echo ""
}

# Search files
search() {
    local query=$1
    local dir=${2:-$HOME}
    
    echo "Searching for: $query"
    echo ""
    
    find "$dir" -iname "*$query*" -type f 2>/dev/null | head -20 | while read file; do
        echo "  $(basename "$file") - $(dirname "$file")"
    done
    echo ""
}

# Add bookmark
add_bookmark() {
    local name=$1
    local path=$2
    
    echo "$name|$path" >> "$BOOKMARKS_FILE"
    echo "Bookmarked: $name -> $path"
}

# List bookmarks
list_bookmarks() {
    echo "Bookmarks:"
    echo ""
    
    if [ -f "$BOOKMARKS_FILE" ]; then
        while IFS='|' read -r name path; do
            echo "  $name -> $path"
        done < "$BOOKMARKS_FILE"
    fi
    echo ""
}

# Recent files
add_recent() {
    local file=$1
    echo "$(date -Iseconds)|$file" >> "$RECENT_FILE"
    tail -50 "$RECENT_FILE" > "$RECENT_FILE.tmp"
    mv "$RECENT_FILE.tmp" "$RECENT_FILE"
}

show_recent() {
    echo "Recent Files:"
    echo ""
    
    if [ -f "$RECENT_FILE" ]; then
        tail -20 "$RECENT_FILE" | while IFS='|' read -r time file; do
            echo "  $(basename "$file")"
        done
    fi
    echo ""
}

# Tag files
tag_file() {
    local file=$1
    local tag=$2
    
    echo "$file|$tag" >> "$TAGS_FILE"
    echo "Tagged: $(basename "$file") as $tag"
}

# Search by tag
search_tag() {
    local tag=$1
    
    echo "Files tagged: $tag"
    echo ""
    
    grep "|$tag$" "$TAGS_FILE" | while IFS='|' read -r file tag; do
        echo "  $(basename "$file")"
    done
    echo ""
}

# File operations
copy_file() {
    local src=$1
    local dest=$2
    cp "$src" "$dest"
    echo "Copied: $(basename "$src")"
}

move_file() {
    local src=$1
    local dest=$2
    mv "$src" "$dest"
    echo "Moved: $(basename "$src")"
}

delete_file() {
    local file=$1
    echo "Delete: $(basename "$file")?"
    read -p "Confirm (y/N): " confirm
    [ "$confirm" = "y" ] && rm -rf "$file" && echo "Deleted"
}

# Quick actions
quick_actions() {
    local file=$1
    local ext="${file##*.}"
    
    echo "Quick actions for: $(basename "$file")"
    echo ""
    echo "  1) Open"
    echo "  2) Copy"
    echo "  3) Move"
    echo "  4) Delete"
    echo "  5) Tag"
    echo "  6) Properties"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1) xdg-open "$file" ;;
        2) read -p "Destination: " dest; copy_file "$file" "$dest" ;;
        3) read -p "Destination: " dest; move_file "$file" "$dest" ;;
        4) delete_file "$file" ;;
        5) read -p "Tag name: " tag; tag_file "$file" "$tag" ;;
        6) ls -lh "$file" ;;
    esac
}

# Disk usage
disk_usage() {
    echo "Disk Usage:"
    echo ""
    df -h | grep -v tmpfs | grep -v devtmpfs
    echo ""
    echo "Home directory usage:"
    du -sh "$HOME"/* 2>/dev/null | sort -hr | head -10
}

show_help() {
    echo "Usage: tinker-files [command]"
    echo ""
    echo "Commands:"
    echo "  browse [dir]        Browse directory"
    echo "  search <query>      Search files"
    echo "  bookmark <name> <path> Add bookmark"
    echo "  bookmarks           List bookmarks"
    echo "  recent              Show recent files"
    echo "  tag <file> <tag>    Tag file"
    echo "  tags <tag>          Search by tag"
    echo "  actions <file>      Quick actions"
    echo "  disk                Disk usage"
    echo "  help                Show this help"
}

init_fm

case "$1" in
    browse|ls) browse "$2" ;;
    search|find) search "$2" "$3" ;;
    bookmark|bm) add_bookmark "$2" "$3" ;;
    bookmarks|bml) list_bookmarks ;;
    recent) show_recent ;;
    tag) tag_file "$2" "$3" ;;
    tags) search_tag "$2" ;;
    actions|action) quick_actions "$2" ;;
    disk) disk_usage ;;
    *) show_help ;;
esac

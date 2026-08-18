#!/bin/bash
# TinkerOS Duplicate Finder - Find duplicate files

set -e

DUP_DIR="$HOME/.tinker/duplicates"

mkdir -p "$DUP_DIR"

# Find duplicates by name
find_by_name() {
    local dir=${1:-$HOME}
    
    echo "Finding duplicate files by name in $dir..."
    echo ""
    
    find "$dir" -type f -printf '%f\n' 2>/dev/null | sort | uniq -d | while read name; do
        echo "Duplicate: $name"
        find "$dir" -name "$name" -type f 2>/dev/null | while read f; do
            echo "  $f"
        done
        echo ""
    done
}

# Find duplicates by content (MD5)
find_by_content() {
    local dir=${1:-$HOME}
    
    echo "Finding duplicate files by content in $dir..."
    echo ""
    echo "This may take a while..."
    
    find "$dir" -type f -exec md5sum {} \; 2>/dev/null | sort | uniq -w32 -d | while read hash file; do
        echo "Duplicate (hash: ${hash:0:8}): $file"
    done
}

# Find duplicate images
find_images() {
    local dir=${1:-$HOME}
    
    echo "Finding duplicate images..."
    echo ""
    
    find "$dir" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.gif" \) -exec md5sum {} \; 2>/dev/null | sort | uniq -w32 -d
}

# Remove duplicates
remove_dups() {
    echo "Removing duplicates..."
    echo ""
    echo "CAUTION: This will delete duplicate files!"
    echo "Only keep one copy of each duplicate"
    echo ""
    echo "Not implemented - use with caution"
}

show_help() {
    echo "Usage: tinker-dedup [command]"
    echo ""
    echo "Commands:"
    echo "  name [dir]        Find duplicates by name"
    echo "  content [dir]     Find duplicates by content"
    echo "  images [dir]      Find duplicate images"
    echo "  remove            Remove duplicates (careful!)"
    echo "  help              Show this help"
}

case "$1" in
    name) find_by_name "$2" ;;
    content|md5) find_by_content "$2" ;;
    images|img) find_images "$2" ;;
    remove|delete) remove_dups ;;
    *) show_help ;;
esac

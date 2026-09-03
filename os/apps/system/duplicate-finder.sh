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

# Remove duplicates (real: keep first copy per content hash, trash the rest)
remove_dups() {
    local dir=${1:-$HOME}
    local dry=${2:-0}

    echo "Removing duplicates in $dir..."
    echo ""
    echo "CAUTION: This will delete duplicate files!"
    echo "Only one copy of each duplicate content hash is kept."
    echo ""

    local trash="$HOME/.local/share/Trash/files"
    mkdir -p "$trash"

    local seen="" removed=0 candidates=""

    while read -r hash file; do
        [ -z "$hash" ] && continue
        if echo "$seen" | grep -q "^$hash$"; then
            candidates="$candidates
$file"
        else
            seen="$seen
$hash"
        fi
    done < <(find "$dir" -type f -exec md5sum {} \; 2>/dev/null)

    if [ -z "$candidates" ]; then
        echo "No duplicate files found."
        return
    fi

    echo "Found duplicates (will remove):"
    echo "$candidates" | sed '/^$/d' | sed 's/^/  /'
    echo ""
    if [ "$dry" = "1" ]; then
        echo "DRY RUN: nothing deleted."
        return
    fi
    read -p "Move these to trash and continue? (y/N): " confirm
    [ "$confirm" != "y" ] && { echo "Aborted."; return; }

    echo "$candidates" | sed '/^$/d' | while read -r file; do
        if command -v trash-put >/dev/null 2>&1; then
            trash-put "$file" && echo "Trashed: $file"
        else
            mv "$file" "$trash/" 2>/dev/null && echo "Moved to trash: $file"
        fi
    done
    echo ""
    echo "Done. Restorable from $trash"
}

show_help() {
    echo "Usage: tinker-dedup [command]"
    echo ""
    echo "Commands:"
    echo "  name [dir]        Find duplicates by name"
    echo "  content [dir]     Find duplicates by content"
    echo "  images [dir]      Find duplicate images"
    echo "  remove [dir]      Remove duplicates (careful!)"
    echo "  dryrun [dir]      Show what would be removed without deleting"
    echo "  help              Show this help"
}

case "$1" in
    name) find_by_name "$2" ;;
    content|md5) find_by_content "$2" ;;
    images|img) find_images "$2" ;;
    remove|delete) remove_dups "$2" ;;
    dryrun|dry) remove_dups "$2" 1 ;;
    *) show_help ;;
esac

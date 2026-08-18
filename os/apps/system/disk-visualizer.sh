#!/bin/bash
# TinkerOS Disk Usage Visualizer - See what's using space

set -e

DISK_DIR="$HOME/.tinker/disk-viz"

mkdir -p "$DISK_DIR"

# Show disk usage
show_usage() {
    echo "Disk Usage Overview:"
    echo ""
    df -h | grep -E "^/dev|Filesystem"
}

# Show directory sizes
show_dirs() {
    local dir=${1:-$HOME}
    local depth=${2:-2}
    
    echo "Directory sizes in $dir:"
    echo ""
    
    du -h --max-depth=$depth "$dir" 2>/dev/null | sort -hr | head -20
}

# Find large files
find_large() {
    local size=${1:-100M}
    
    echo "Files larger than $size:"
    echo ""
    
    find / -type f -size +$size 2>/dev/null | head -20 | while read f; do
        ls -lh "$f" 2>/dev/null
    done
}

# Find old files
find_old() {
    local days=${1:-30}
    
    echo "Files older than $days days:"
    echo ""
    
    find /home -type f -mtime +$days 2>/dev/null | head -20 | while read f; do
        ls -lh "$f" 2>/dev/null
    done
}

# Treemap visualization
treemap() {
    local dir=${1:-$HOME}
    
    echo "Generating treemap..."
    
    if command -v ncdu >/dev/null 2>&1; then
        ncdu "$dir"
    else
        echo "Install ncdu for interactive visualization: sudo apt install ncdu"
        echo ""
        echo "Quick view:"
        du -h --max-depth=2 "$dir" 2>/dev/null | sort -hr | head -30
    fi
}

show_help() {
    echo "Usage: tinker-disk-viz [command]"
    echo ""
    echo "Commands:"
    echo "  overview          Show disk overview"
    echo "  dirs [dir]        Show directory sizes"
    echo "  large [size]      Find large files"
    echo "  old [days]        Find old files"
    echo "  treemap [dir]     Interactive visualization"
    echo "  help              Show this help"
}

case "$1" in
    overview|df) show_usage ;;
    dirs|du) show_dirs "$2" "$3" ;;
    large|big) find_large "${2:-100M}" ;;
    old) find_old "${2:-30}" ;;
    treemap|ncdu) treemap "$2" ;;
    *) show_help ;;
esac

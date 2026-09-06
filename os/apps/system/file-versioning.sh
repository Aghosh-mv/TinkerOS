#!/bin/bash
# TinkerOS File Versioning - Git-like file versions

set -e

VCS_DIR="$HOME/.tinker/vcs"
VERSIONS_DIR="$VCS_DIR/versions"

mkdir -p "$VCS_DIR" "$VERSIONS_DIR"

# Initialize versioning for file
init_file() {
    local file=$1
    
    local id=$(echo "$file" | md5sum | head -c 8)
    mkdir -p "$VERSIONS_DIR/$id"
    
    echo "Initialized versioning for: $file"
    echo "ID: $id"
}

# Save version
save() {
    local file=$1
    local message=${2:-"update"}
    
    local id=$(echo "$file" | md5sum | head -c 8)
    local timestamp=$(date +%s)
    
    mkdir -p "$VERSIONS_DIR/$id"
    
    if [ -f "$file" ]; then
        cp "$file" "$VERSIONS_DIR/$id/$timestamp"
        echo "$timestamp|$message" >> "$VERSIONS_DIR/$id/log.txt"
        echo "Version saved: $timestamp ($message)"
    else
        echo "File not found: $file"
    fi
}

# Show versions
log() {
    local file=$1
    
    local id=$(echo "$file" | md5sum | head -c 8)
    
    echo "Version history for: $file"
    echo ""
    
    if [ -f "$VERSIONS_DIR/$id/log.txt" ]; then
        cat "$VERSIONS_DIR/$id/log.txt" | while IFS='|' read -r ts msg; do
            local date=$(date -d @$ts "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "?")
            echo "  $date - $msg"
        done
    else
        echo "  No versions"
    fi
}

# Restore version
restore() {
    local file=$1
    local version=$2
    
    local id=$(echo "$file" | md5sum | head -c 8)
    
    if [ -f "$VERSIONS_DIR/$id/$version" ]; then
        cp "$VERSIONS_DIR/$id/$version" "$file"
        echo "Restored version: $version"
    else
        echo "Version not found: $version"
    fi
}

# Diff versions
diff_versions() {
    local file=$1
    local v1=$2
    local v2=$3
    
    local id=$(echo "$file" | md5sum | head -c 8)
    
    diff "$VERSIONS_DIR/$id/$v1" "$VERSIONS_DIR/$id/$v2" || true
}

show_help() {
    echo "Usage: tinker-vcs [command]"
    echo ""
    echo "Commands:"
    echo "  init <file>       Initialize versioning"
    echo "  save <file> [msg] Save version"
    echo "  log <file>        Show version history"
    echo "  restore <file> <ver> Restore version"
    echo "  diff <file> <v1> <v2> Compare versions"
    echo "  help              Show this help"
}

case "$1" in
    init) init_file "$2" ;;
    save|commit) save "$2" "$3" ;;
    log|history) log "$2" ;;
    restore|checkout) restore "$2" "$3" ;;
    diff) diff_versions "$2" "$3" "$4" ;;
    *) show_help ;;
esac

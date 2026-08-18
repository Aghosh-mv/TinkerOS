#!/bin/bash
# TinkerOS System Cleaner
# Deep clean system with safety checks

set -e

CLEAN_DIR="$HOME/.tinker/cleaner"
LOG_FILE="$CLEAN_DIR/clean.log"
BACKUP_DIR="$CLEAN_DIR/backups"

mkdir -p "$CLEAN_DIR" "$BACKUP_DIR"

# Quick clean
quick_clean() {
    echo "Quick Clean..."
    echo ""
    
    local freed=0
    
    # Clean package cache
    echo "Cleaning package cache..."
    local before=$(du -sm /var/cache/apt/archives 2>/dev/null | awk '{print $1}' || echo 0)
    sudo apt clean 2>/dev/null || sudo pacman -Sc --noconfirm 2>/dev/null || true
    local after=$(du -sm /var/cache/apt/archives 2>/dev/null | awk '{print $1}' || echo 0)
    freed=$((freed + before - after))
    echo "  Package cache: freed ${before-after}MB"
    
    # Clean temp files
    echo "Cleaning temp files..."
    local before=$(du -sm /tmp 2>/dev/null | awk '{print $1}' || echo 0)
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null || true
    local after=$(du -sm /tmp 2>/dev/null | awk '{print $1}' || echo 0)
    freed=$((freed + before - after))
    echo "  Temp files: freed ${before-after}MB"
    
    # Clean logs
    echo "Cleaning old logs..."
    sudo journalctl --vacuum-time=3d 2>/dev/null || true
    echo "  Logs cleaned"
    
    # Clean thumbnail cache
    echo "Cleaning thumbnails..."
    rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
    echo "  Thumbnails cleaned"
    
    echo ""
    echo "Quick clean complete! Freed ~${freed}MB"
}

# Deep clean
deep_clean() {
    echo "Deep Clean (with safety checks)..."
    echo ""
    
    # Create backup first
    echo "Creating safety backup..."
    backup_config
    
    # Clean browser cache
    echo "Cleaning browser cache..."
    rm -rf ~/.cache/google-chrome/Default/Cache/* 2>/dev/null || true
    rm -rf ~/.mozilla/firefox/*/Cache/* 2>/dev/null || true
    echo "  Browser cache cleaned"
    
    # Clean application cache
    echo "Cleaning application cache..."
    rm -rf ~/.cache/* 2>/dev/null || true
    echo "  App cache cleaned"
    
    # Clean old kernels (safe)
    echo "Cleaning old kernels..."
    sudo apt autoremove --purge -y 2>/dev/null || true
    echo "  Old packages removed"
    
    # Clean trash
    echo "Cleaning trash..."
    rm -rf ~/.local/share/Trash/* 2>/dev/null || true
    echo "  Trash emptied"
    
    # Clean old backups
    echo "Cleaning old backups..."
    find "$BACKUP_DIR" -type f -mtime +30 -delete 2>/dev/null || true
    echo "  Old backups cleaned"
    
    echo ""
    echo "Deep clean complete!"
}

# Backup config
backup_config() {
    local timestamp=$(date +%s)
    local backup="$BACKUP_DIR/backup_$timestamp"
    
    mkdir -p "$backup"
    
    # Backup important configs
    cp -r ~/.config "$backup/" 2>/dev/null || true
    cp -r ~/.tinker "$backup/" 2>/dev/null || true
    
    echo "Backup created: $backup"
}

# Show what can be cleaned
dry_run() {
    echo "Dry Run - What can be cleaned:"
    echo ""
    
    # Package cache
    local pkg_cache=$(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}' || echo "0")
    echo "  Package cache: $pkg_cache"
    
    # Temp files
    local temp=$(du -sh /tmp 2>/dev/null | awk '{print $1}' || echo "0")
    echo "  Temp files: $temp"
    
    # Browser cache
    local browser=$(du -sh ~/.cache/google-chrome 2>/dev/null | awk '{print $1}' || echo "0")
    echo "  Browser cache: $browser"
    
    # Thumbnails
    local thumbs=$(du -sh ~/.cache/thumbnails 2>/dev/null | awk '{print $1}' || echo "0")
    echo "  Thumbnails: $thumbs"
    
    # Trash
    local trash=$(du -sh ~/.local/share/Trash 2>/dev/null | awk '{print $1}' || echo "0")
    echo "  Trash: $trash"
    
    # Application cache
    local app_cache=$(du -sh ~/.cache 2>/dev/null | awk '{print $1}' || echo "0")
    echo "  App cache total: $app_cache"
    
    echo ""
    echo "Total potential space: Run 'tinker-clean quick' or 'tinker-clean deep'"
}

# Schedule auto-clean
schedule() {
    local frequency=${1:-weekly}
    
    echo "Setting up auto-clean ($frequency)..."
    
    case $frequency in
        daily)
            echo "0 3 * * * /usr/lib/tinker/system-cleaner.sh quick" | crontab -
            ;;
        weekly)
            echo "0 3 * * 0 /usr/lib/tinker/system-cleaner.sh quick" | crontab -
            ;;
        monthly)
            echo "0 3 1 * * /usr/lib/tinker/system-cleaner.sh deep" | crontab -
            ;;
    esac
    
    echo "Auto-clean scheduled: $frequency"
}

show_help() {
    echo "Usage: tinker-clean [command]"
    echo ""
    echo "Commands:"
    echo "  quick             Quick clean (cache, temp, logs)"
    echo "  deep              Deep clean (everything + backup)"
    echo "  dry-run           Show what can be cleaned"
    echo "  backup            Create config backup"
    echo "  schedule [freq]   Schedule auto-clean"
    echo "  help              Show this help"
    echo ""
    echo "Frequencies: daily, weekly, monthly"
}

case "$1" in
    quick|fast) quick_clean ;;
    deep|full) deep_clean ;;
    dry-run|preview|check) dry_run ;;
    backup) backup_config ;;
    schedule|auto) schedule "${2:-weekly}" ;;
    *) show_help ;;
esac

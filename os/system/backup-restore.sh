#!/bin/bash
# TinkerOS Backup & Restore System

set -e

BACKUP_DIR="$HOME/.tinker/backups"
BACKUP_CONFIG="$BACKUP_DIR/config.conf"
BACKUP_LOG="$BACKUP_DIR/log"

mkdir -p "$BACKUP_DIR"

init_config() {
    if [ ! -f "$BACKUP_CONFIG" ]; then
        cat > "$BACKUP_CONFIG" << 'EOF'
# TinkerOS Backup Configuration

# Backup location
BACKUP_LOCATION=local

# What to backup
BACKUP_HOME=true
BACKUP_CONFIGS=true
BACKUP_EMAILS=false
BACKUP_DATABASES=false

# Exclusions
EXCLUDE=.cache,.local/share/Trash,node_modules,.venv

# Retention (days)
RETENTION_DAYS=30

# Compression
COMPRESSION=gzip

# Encryption
ENCRYPTION=false
EOF
    fi
}

# Full backup
full_backup() {
    local backup_name="full-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    echo "Creating full backup: $backup_name"
    mkdir -p "$backup_path"
    
    # Backup home directory
    echo "Backing up home directory..."
    tar -czf "$backup_path/home.tar.gz" \
        --exclude="$HOME/.cache" \
        --exclude="$HOME/.local/share/Trash" \
        --exclude="$HOME/.tinker/backups" \
        -C "$HOME" . 2>/dev/null
    
    # Backup system configs
    echo "Backing up system configs..."
    sudo tar -czf "$backup_path/system-configs.tar.gz" \
        /etc/fstab \
        /etc/hostname \
        /etc/hosts \
        /etc/resolv.conf \
        /etc/network/interfaces \
        /etc/default/grub \
        /etc/sudoers \
        2>/dev/null || true
    
    # Save package list
    if command -v dpkg >/dev/null 2>&1; then
        dpkg --get-selections > "$backup_path/packages.list"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Q > "$backup_path/packages.list"
    fi
    
    # Save installed flatpaks
    if command -v flatpak >/dev/null 2>&1; then
        flatpak list --app --columns=application > "$backup_path/flatpaks.list" 2>/dev/null || true
    fi
    
    # Record system info
    uname -a > "$backup_path/system-info.txt"
    date -Iseconds > "$backup_path/created.txt"
    
    echo "Backup complete: $backup_path"
    log_backup "full" "Created: $backup_name"
}

# Incremental backup
incremental_backup() {
    local backup_name="incremental-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    echo "Creating incremental backup: $backup_name"
    mkdir -p "$backup_path"
    
    # Find modified files since last backup
    local last_backup=$(ls -1td "$BACKUP_DIR"/full-* "$BACKUP_DIR"/incremental-* 2>/dev/null | head -1)
    
    if [ -n "$last_backup" ]; then
        local last_date=$(cat "$last_backup/created.txt" 2>/dev/null)
        
        find "$HOME" -newer "$last_backup/created.txt" -type f \
            -not -path "*/.cache/*" \
            -not -path "*/Trash/*" \
            -not -path "*/.tinker/backups/*" \
            2>/dev/null | tar -czf "$backup_path/changes.tar.gz" -T -
    else
        full_backup
        return
    fi
    
    date -Iseconds > "$backup_path/created.txt"
    echo "Incremental backup complete"
    log_backup "incremental" "Created: $backup_name"
}

# Restore from backup
restore_backup() {
    local backup_name=$1
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [ ! -d "$backup_path" ]; then
        echo "Backup not found: $backup_name"
        return 1
    fi
    
    echo "Restoring from: $backup_name"
    echo "This will overwrite your current data."
    echo ""
    read -p "Continue? (y/N): " confirm
    [ "$confirm" != "y" ] && return
    
    # Restore home directory
    if [ -f "$backup_path/home.tar.gz" ]; then
        echo "Restoring home directory..."
        tar -xzf "$backup_path/home.tar.gz" -C "$HOME" 2>/dev/null
    fi
    
    # Restore system configs
    if [ -f "$backup_path/system-configs.tar.gz" ]; then
        echo "Restoring system configs..."
        sudo tar -xzf "$backup_path/system-configs.tar.gz" -C / 2>/dev/null
    fi
    
    # Restore packages
    if [ -f "$backup_path/packages.list" ]; then
        echo "Restoring packages..."
        if command -v dpkg >/dev/null 2>&1; then
            sudo dpkg --set-selections < "$backup_path/packages.list"
            sudo apt-get dselect-upgrade -y
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --needed --noconfirm $(awk '{print $1}' "$backup_path/packages.list")
        fi
    fi
    
    echo "Restore complete. Please reboot."
    log_backup "restore" "Restored: $backup_name"
}

# List backups
list_backups() {
    echo "Available Backups:"
    echo ""
    
    ls -1d "$BACKUP_DIR"/*/ 2>/dev/null | while read dir; do
        local name=$(basename "$dir")
        local created=$(cat "$dir/created.txt" 2>/dev/null || echo "Unknown")
        local size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
        echo "  $name ($size) - $created"
    done
    echo ""
}

# Delete backup
delete_backup() {
    local name=$1
    
    if [ -d "$BACKUP_DIR/$name" ]; then
        rm -rf "$BACKUP_DIR/$name"
        echo "Deleted: $name"
    else
        echo "Backup not found: $name"
    fi
}

# Auto backup
auto_backup() {
    echo "Running auto backup..."
    
    # Check retention
    local retention=$(grep "RETENTION_DAYS" "$BACKUP_CONFIG" | cut -d= -f2)
    retention=${retention:-30}
    
    # Delete old backups
    find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +$retention -exec rm -rf {} \; 2>/dev/null
    
    # Create backup
    incremental_backup
}

# Export backup
export_backup() {
    local backup_name=$1
    local export_path=${2:-"$HOME/backup-$backup_name.tar.gz"}
    
    tar -czf "$export_path" -C "$BACKUP_DIR" "$backup_name"
    echo "Exported to: $export_path"
}

# Import backup
import_backup() {
    local import_file=$1
    
    tar -xzf "$import_file" -C "$BACKUP_DIR"
    echo "Imported backup"
}

# Log backup actions
log_backup() {
    local action=$1
    local details=$2
    echo "$(date -Iseconds) | $action | $details" >> "$BACKUP_LOG"
}

show_help() {
    echo "Usage: tinker-backup [command]"
    echo ""
    echo "Commands:"
    echo "  full                Full backup"
    echo "  incremental         Incremental backup"
    echo "  restore <name>      Restore backup"
    echo "  list                List backups"
    echo "  delete <name>       Delete backup"
    echo "  auto                Auto backup (with retention)"
    echo "  export <name> [path] Export backup"
    echo "  import <file>       Import backup"
    echo "  log                 Show backup log"
    echo "  help                Show this help"
}

init_config

case "$1" in
    full) full_backup ;;
    incremental|incr) incremental_backup ;;
    restore) restore_backup "$2" ;;
    list|ls) list_backups ;;
    delete|rm) delete_backup "$2" ;;
    auto) auto_backup ;;
    export) export_backup "$2" "$3" ;;
    import) import_backup "$2" ;;
    log) cat "$BACKUP_LOG" 2>/dev/null || echo "No log" ;;
    *) show_help ;;
esac

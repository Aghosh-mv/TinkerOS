#!/bin/bash
# TinkerOS Backup & Restore - Full system backup with encryption and scheduling

set -e

BACKUP_DIR="$HOME/.tinker/backups"
CONFIG_FILE="$BACKUP_DIR/config.conf"
LOG_FILE="$BACKUP_DIR/backup.log"
EXCLUDE_FILE="$BACKUP_DIR/exclude.conf"

mkdir -p "$BACKUP_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Backup Configuration
DEFAULT_DESTINATION=local
ENCRYPTION=true
COMPRESSION=zstd
COMPRESSION_LEVEL=3
MAX_BACKUPS=10
AUTO_CLEANUP=true
VERIFY_BACKUPS=true
NOTIFICATIONS=true
EXCLUDE_CACHE=true
EXCLUDE_TRASH=true
EOF

    [ ! -f "$EXCLUDE_FILE" ] && cat > "$EXCLUDE_FILE" << 'EOF'
# Backup Exclude Patterns
.cache
.thumbnails
.Trash
Trash
*.tmp
*.log
node_modules
__pycache__
.git
.vscode
*.iso
*.img
VirtualBox VMs
VMware
EOF

    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Build tar command with excludes
build_tar_cmd() {
    local dest=$1
    local name=$2
    local src=${3:-$HOME}
    
    local excludes=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        [[ "$line" =~ ^#.* ]] && continue
        excludes="$excludes --exclude=$line"
    done < "$EXCLUDE_FILE"
    
    local encryption=""
    if grep -q "ENCRYPTION=true" "$CONFIG_FILE"; then
        encryption="| gpg --symmetric --cipher-algo AES256"
    fi
    
    local compression=""
    local comp=$(grep COMPRESSION "$CONFIG_FILE" | cut -d= -f2)
    local level=$(grep COMPRESSION_LEVEL "$CONFIG_FILE" | cut -d= -f2)
    
    case $comp in
        zstd) compression="zstd -$level" ;;
        gzip) compression="gzip -$level" ;;
        xz) compression="xz -$level" ;;
        none) compression="cat" ;;
    esac
    
    echo "tar $excludes -C $src -cf - . 2>/dev/null | $compression $encryption > $dest/$name"
}

# Create backup
create_backup() {
    local name=${1:-"backup-$(date +%Y%m%d-%H%M%S)"}
    local src=${2:-$HOME}
    local dest=$BACKUP_DIR
    
    echo "Creating backup: $name"
    echo "Source: $src"
    echo "Destination: $dest"
    echo ""
    
    local start=$(date +%s)
    local cmd=$(build_tar_cmd "$dest" "$name.tar" "$src")
    
    echo "Running backup..."
    if eval "$cmd"; then
        local end=$(date +%s)
        local duration=$((end - start))
        local size=$(du -h "$dest/$name.tar" 2>/dev/null | awk '{print $1}' || echo "unknown")
        
        echo "Backup completed in ${duration}s"
        echo "Size: $size"
        
        # Verify backup
        if grep -q "VERIFY_BACKUPS=true" "$CONFIG_FILE"; then
            echo "Verifying backup..."
            if tar -tf "$dest/$name.tar" >/dev/null 2>&1; then
                echo "Verification: OK"
            else
                echo "Verification: FAILED"
            fi
        fi
        
        # Log
        echo "$(date +%s)|create|$name|$size|${duration}s|success" >> "$LOG_FILE"
        
        # Cleanup old backups
        if grep -q "AUTO_CLEANUP=true" "$CONFIG_FILE"; then
            cleanup_old
        fi
        
        grep -q "NOTIFICATIONS=true" "$CONFIG_FILE" && notify-send "Backup Complete" "$name ($size)" 2>/dev/null || true
    else
        echo "Backup failed!"
        echo "$(date +%s)|create|$name|0|0|failed" >> "$LOG_FILE"
        return 1
    fi
}

# Restore backup
restore_backup() {
    local name=$1
    local dest=${2:-$HOME}
    local backup_file="$BACKUP_DIR/$name"
    
    [ ! -f "$backup_file" ] && backup_file="$BACKUP_DIR/$name.tar"
    [ ! -f "$backup_file" ] && echo "Backup not found: $name" && return 1
    
    echo "Restoring backup: $name"
    echo "Destination: $dest"
    echo ""
    echo "WARNING: This will overwrite existing files!"
    read -p "Continue? (y/N) " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Yy]$ ]] && echo "Aborted" && return 1
    
    local start=$(date +%s)
    
    local decryption=""
    if grep -q "ENCRYPTION=true" "$CONFIG_FILE"; then
        decryption="gpg --decrypt |"
    else
        decryption="cat |"
    fi
    
    local comp=$(grep COMPRESSION "$CONFIG_FILE" | cut -d= -f2)
    local decompression=""
    case $comp in
        zstd) decompression="zstd -d |" ;;
        gzip) decompression="gzip -d |" ;;
        xz) decompression="xz -d |" ;;
        none) decompression="cat |" ;;
    esac
    
    echo "Restoring..."
    if eval "$decryption < $backup_file | $decompression tar -C $dest -xf -"; then
        local end=$(date +%s)
        echo "Restore completed in $((end - start))s"
        echo "$(date +%s)|restore|$name|success" >> "$LOG_FILE"
    else
        echo "Restore failed!"
        echo "$(date +%s)|restore|$name|failed" >> "$LOG_FILE"
        return 1
    fi
}

# List backups
list_backups() {
    echo "Available Backups:"
    echo ""
    ls -lh "$BACKUP_DIR"/*.tar 2>/dev/null | while read line; do
        local name=$(echo "$line" | awk '{print $9}')
        local size=$(echo "$line" | awk '{print $5}')
        local date=$(echo "$line" | awk '{print $6, $7, $8}')
        local base=$(basename "$name" .tar)
        echo "  $base ($size) - $date"
    done || echo "  No backups found"
}

# Cleanup old backups
cleanup_old() {
    local max=$(grep MAX_BACKUPS "$CONFIG_FILE" | cut -d= -f2)
    max=${max:-10}
    
    local count=$(ls -1 "$BACKUP_DIR"/*.tar 2>/dev/null | wc -l)
    if [ $count -gt $max ]; then
        local to_remove=$((count - max))
        ls -t "$BACKUP_DIR"/*.tar | tail -$to_remove | while read f; do
            echo "Removing old backup: $(basename $f)"
            rm -f "$f"
        done
    fi
}

# Schedule backups
schedule() {
    local freq=${1:-daily}
    local time=${2:-02:00}
    local src=${3:-$HOME}
    
    echo "Scheduling backups: $freq at $time"
    
    cat > /etc/systemd/system/tinker-backup.service << EOF
[Unit]
Description=TinkerOS Backup
After=network-online.target

[Service]
Type=oneshot
ExecStart=/home/tinkerspace/linux-kernel/os/apps/system/backup-restore.sh create scheduled $src
Environment=HOME=/home/tinkerspace
EOF

    local timer_spec=""
    case $freq in
        hourly) timer_spec="OnCalendar=*:00" ;;
        daily) timer_spec="OnCalendar=*-*-* $time" ;;
        weekly) timer_spec="OnCalendar=Mon *-*-* $time" ;;
        monthly) timer_spec="OnCalendar=*-1 $time" ;;
    esac
    
    cat > /etc/systemd/system/tinker-backup.timer << EOF
[Unit]
Description=Run TinkerOS Backup $freq

[Timer]
$timer_spec
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable --now tinker-backup.timer 2>/dev/null || true
    
    echo "Backup timer created and enabled"
}

show_help() {
    echo "Usage: tinker-backup [command]"
    echo ""
    echo "Commands:"
    echo "  create [name] [src]   Create backup (default: timestamp, \$HOME)"
    echo "  restore <name> [dest] Restore backup (default: \$HOME)"
    echo "  list                  List available backups"
    echo "  cleanup               Remove old backups"
    echo "  schedule [freq] [time] [src]  Schedule automatic backups"
    echo "  verify <name>         Verify backup integrity"
    echo "  help                  Show this help"
    echo ""
    echo "Frequencies: hourly, daily, weekly, monthly"
}

init

case "$1" in
    create) create_backup "$2" "$3" ;;
    restore) restore_backup "$2" "$3" ;;
    list) list_backups ;;
    cleanup) cleanup_old ;;
    schedule) schedule "$2" "$3" "$4" ;;
    verify) tar -tf "$BACKUP_DIR/$2.tar" >/dev/null 2>&1 && echo "OK" || echo "FAILED" ;;
    *) show_help ;;
esac
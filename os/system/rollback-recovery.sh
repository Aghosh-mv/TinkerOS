#!/bin/bash
# TinkerOS Rollback & Recovery System

set -e

RECOVERY_DIR="$HOME/.tinker/recovery"
SNAPSHOTS_DIR="$RECOVERY_DIR/snapshots"
RECOVERY_LOG="$RECOVERY_DIR/log"

mkdir -p "$SNAPSHOTS_DIR"

# Create system snapshot
create_snapshot() {
    local name=${1:-"snapshot-$(date +%Y%m%d-%H%M%S)"}
    local snapshot_dir="$SNAPSHOTS_DIR/$name"
    
    echo "Creating snapshot: $name"
    mkdir -p "$snapshot_dir"
    
    # Save package list
    if command -v dpkg >/dev/null 2>&1; then
        dpkg --get-selections > "$snapshot_dir/packages.list"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Q > "$snapshot_dir/packages.list"
    fi
    
    # Save configs
    cp -r /etc/apt "$snapshot_dir/" 2>/dev/null || true
    cp /etc/fstab "$snapshot_dir/" 2>/dev/null || true
    cp /etc/hostname "$snapshot_dir/" 2>/dev/null || true
    
    # Save GRUB config
    cp /etc/default/grub "$snapshot_dir/" 2>/dev/null || true
    
    # Create backup of home directory (critical files only)
    mkdir -p "$snapshot_dir/home-backup"
    tar -czf "$snapshot_dir/home-backup/configs.tar.gz" \
        -C "$HOME" \
        .bashrc .profile .config 2>/dev/null || true
    
    # Record system state
    uname -a > "$snapshot_dir/system-info.txt"
    date -Iseconds > "$snapshot_dir/created.txt"
    
    echo "Snapshot created: $snapshot_dir"
    log_recovery "snapshot" "Created: $name"
}

# Restore from snapshot
restore_snapshot() {
    local name=$1
    local snapshot_dir="$SNAPSHOTS_DIR/$name"
    
    if [ ! -d "$snapshot_dir" ]; then
        echo "Snapshot not found: $name"
        return 1
    fi
    
    echo "Restoring snapshot: $name"
    echo "This may require a reboot."
    echo ""
    read -p "Continue? (y/N): " confirm
    [ "$confirm" != "y" ] && return
    
    # Restore package list
    if [ -f "$snapshot_dir/packages.list" ]; then
        if command -v dpkg >/dev/null 2>&1; then
            sudo dpkg --set-selections < "$snapshot_dir/packages.list"
            sudo apt-get dselect-upgrade -y
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --needed --noconfirm $(cat "$snapshot_dir/packages.list" | awk '{print $1}')
        fi
    fi
    
    # Restore configs
    [ -d "$snapshot_dir/apt" ] && sudo cp -r "$snapshot_dir/apt" /etc/
    [ -f "$snapshot_dir/fstab" ] && sudo cp "$snapshot_dir/fstab" /etc/
    [ -f "$snapshot_dir/grub" ] && sudo cp "$snapshot_dir/grub" /etc/default/
    
    # Restore home configs
    if [ -f "$snapshot_dir/home-backup/configs.tar.gz" ]; then
        tar -xzf "$snapshot_dir/home-backup/configs.tar.gz" -C "$HOME" 2>/dev/null || true
    fi
    
    echo "Snapshot restored. Please reboot."
    log_recovery "restore" "Restored: $name"
}

# List snapshots
list_snapshots() {
    echo "Available Snapshots:"
    echo ""
    
    if [ -d "$SNAPSHOTS_DIR" ]; then
        ls -1 "$SNAPSHOTS_DIR" | while read snap; do
            local created=$(cat "$SNAPSHOTS_DIR/$snap/created.txt" 2>/dev/null || echo "Unknown")
            echo "  $snap - $created"
        done
    else
        echo "  No snapshots found"
    fi
    echo ""
}

# Delete snapshot
delete_snapshot() {
    local name=$1
    
    if [ -d "$SNAPSHOTS_DIR/$name" ]; then
        rm -rf "$SNAPSHOTS_DIR/$name"
        echo "Deleted: $name"
    else
        echo "Snapshot not found: $name"
    fi
}

# Recovery mode boot
recovery_boot() {
    echo "Entering recovery mode..."
    echo ""
    echo "Available recovery options:"
    echo "  1) Restore latest snapshot"
    echo "  2) Repair GRUB"
    echo "  3) Reset passwords"
    echo "  4) Check filesystem"
    echo "  5) Drop to root shell"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1)
            local latest=$(ls -1t "$SNAPSHOTS_DIR" | head -1)
            if [ -n "$latest" ]; then
                restore_snapshot "$latest"
            fi
            ;;
        2)
            echo "Repairing GRUB..."
            sudo grub-install /dev/sda 2>/dev/null || true
            sudo update-grub 2>/dev/null || true
            ;;
        3)
            echo "Resetting user password..."
            sudo passwd "$USER"
            ;;
        4)
            echo "Checking filesystem..."
            sudo fsck -f /dev/sda1 2>/dev/null || true
            ;;
        5)
            sudo -i
            ;;
    esac
}

# Auto-snapshot before updates
auto_snapshot() {
    local count=$(ls -1 "$SNAPSHOTS_DIR" 2>/dev/null | wc -l)
    
    # Keep max 10 snapshots
    if [ $count -ge 10 ]; then
        local oldest=$(ls -1t "$SNAPSHOTS_DIR" | tail -1)
        delete_snapshot "$oldest"
    fi
    
    create_snapshot "pre-update-$(date +%Y%m%d)"
}

# Log recovery actions
log_recovery() {
    local action=$1
    local details=$2
    echo "$(date -Iseconds) | $action | $details" >> "$RECOVERY_LOG"
}

# Show recovery log
show_log() {
    echo "Recovery Log:"
    cat "$RECOVERY_LOG" 2>/dev/null || echo "No log entries"
}

show_help() {
    echo "Usage: tinker-recovery [command]"
    echo ""
    echo "Commands:"
    echo "  snapshot [name]      Create snapshot"
    echo "  restore <name>       Restore snapshot"
    echo "  list                 List snapshots"
    echo "  delete <name>        Delete snapshot"
    echo "  auto                 Auto-snapshot (pre-update)"
    echo "  recovery             Recovery mode"
    echo "  log                  Show recovery log"
    echo "  help                 Show this help"
}

case "$1" in
    snapshot|snap) create_snapshot "$2" ;;
    restore) restore_snapshot "$2" ;;
    list|ls) list_snapshots ;;
    delete|rm) delete_snapshot "$2" ;;
    auto) auto_snapshot ;;
    recovery) recovery_boot ;;
    log) show_log ;;
    *) show_help ;;
esac

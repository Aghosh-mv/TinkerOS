#!/bin/bash
# TinkerOS Automatic System Updates

set -e

UPDATE_DIR="$HOME/.tinker/updates"
UPDATE_LOG="$UPDATE_DIR/history.log"
UPDATE_CONFIG="$UPDATE_DIR/config.conf"

mkdir -p "$UPDATE_DIR"

# Initialize config
init_config() {
    if [ ! -f "$UPDATE_CONFIG" ]; then
        cat > "$UPDATE_CONFIG" << 'EOF'
# TinkerOS Auto-Update Configuration

# Enable automatic updates
AUTO_UPDATES=true

# Check interval (hours)
CHECK_INTERVAL=24

# Update types: all, security, system
UPDATE_TYPE=security

# Auto-reboot if required
AUTO_REBOOT=false

# Notify before updating
NOTIFY=true

# Quiet mode (no notifications)
QUIET=false
EOF
    fi
}

# Check for updates
check_updates() {
    echo "Checking for updates..."
    echo ""
    
    local updates=0
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt update -qq 2>/dev/null
        updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
    elif command -v dnf >/dev/null 2>&1; then
        updates=$(dnf check-update 2>/dev/null | grep -c "^\S")
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --quiet 2>/dev/null
        updates=$(pacman -Qu 2>/dev/null | wc -l)
    fi
    
    echo "Found $updates updates available"
    return $updates
}

# Apply updates
apply_updates() {
    echo "Applying updates..."
    
    # Create backup
    create_backup
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt upgrade -y -qq
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf upgrade -y -q
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Syu --noconfirm --quiet
    fi
    
    log_update "Updates applied"
    echo "Updates complete"
}

# Security updates only
apply_security_updates() {
    echo "Applying security updates..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt upgrade -y -qq -o Dir::Etc::SourceList=/etc/apt/sources.list.d/security.list
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf upgrade --security -y -q
    fi
    
    log_update "Security updates applied"
    echo "Security updates complete"
}

# Create backup before update
create_backup() {
    local backup_dir="$UPDATE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup package list
    if command -v apt >/dev/null 2>&1; then
        dpkg --get-selections > "$backup_dir/packages.list"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Q > "$backup_dir/packages.list"
    fi
    
    # Backup configs
    cp -r /etc/apt "$backup_dir/" 2>/dev/null || true
    
    echo "Backup created: $backup_dir"
}

# Check if reboot is needed
check_reboot_needed() {
    if [ -f /var/run/reboot-required ]; then
        return 0
    fi
    return 1
}

# Auto-update daemon
auto_update_daemon() {
    echo "Starting auto-update daemon..."
    
    while true; do
        # Check interval
        local interval=$(grep "CHECK_INTERVAL" "$UPDATE_CONFIG" | cut -d= -f2)
        interval=${interval:-24}
        
        sleep $((interval * 3600))
        
        # Check for updates
        if check_updates; then
            # Get update type
            local update_type=$(grep "UPDATE_TYPE" "$UPDATE_CONFIG" | cut -d= -f2)
            update_type=${update_type:-security}
            
            # Apply updates
            case $update_type in
                security) apply_security_updates ;;
                all) apply_updates ;;
            esac
            
            # Check if reboot needed
            if check_reboot_needed; then
                local auto_reboot=$(grep "AUTO_REBOOT" "$UPDATE_CONFIG" | cut -d= -f2)
                
                if [ "$auto_reboot" = "true" ]; then
                    log_update "Auto-rebooting"
                    sudo reboot
                else
                    log_update "Reboot required"
                fi
            fi
        fi
    done
}

# Log update
log_update() {
    local action=$1
    echo "$(date -Iseconds) | $action" >> "$UPDATE_LOG"
}

# Show update history
show_history() {
    echo "Update History:"
    echo ""
    
    if [ -f "$UPDATE_LOG" ]; then
        tail -20 "$UPDATE_LOG"
    else
        echo "No update history"
    fi
    echo ""
}

# Rollback updates
rollback() {
    echo "Rolling back updates..."
    
    local latest_backup=$(ls -td "$UPDATE_DIR/backups"/*/ 2>/dev/null | head -1)
    
    if [ -n "$latest_backup" ]; then
        echo "Restoring from: $latest_backup"
        
        # Restore package list
        if [ -f "$latest_backup/packages.list" ]; then
            if command -v apt >/dev/null 2>&1; then
                sudo dpkg --set-selections < "$latest_backup/packages.list"
                sudo apt-get dselect-upgrade -y
            fi
        fi
        
        log_update "Rollback completed"
    else
        echo "No backup found"
    fi
}

show_help() {
    echo "Usage: tinker-update [command]"
    echo ""
    echo "Commands:"
    echo "  check           Check for updates"
    echo "  apply           Apply all updates"
    echo "  security        Apply security updates"
    echo "  auto            Start auto-update daemon"
    echo "  history         Show update history"
    echo "  rollback        Rollback updates"
    echo "  reboot-check    Check if reboot needed"
    echo "  help            Show this help"
}

init_config

case "$1" in
    check)
        check_updates
        ;;
    apply|upgrade)
        apply_updates
        ;;
    security)
        apply_security_updates
        ;;
    auto|daemon)
        auto_update_daemon
        ;;
    history)
        show_history
        ;;
    rollback)
        rollback
        ;;
    reboot-check)
        if check_reboot_needed; then
            echo "Reboot required"
        else
            echo "No reboot needed"
        fi
        ;;
    *)
        show_help
        ;;
esac

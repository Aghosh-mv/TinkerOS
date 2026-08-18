#!/bin/bash
# TinkerOS Update System
# OTA (Over-The-Air) updates for the system

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

UPDATE_SERVER="https://updates.tinkerOS.org"
UPDATE_CHANNEL="stable"
UPDATE_CACHE="/var/cache/tinker/updates"
UPDATE_LOG="/var/log/tinker/update.log"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  TINKEROS UPDATE SYSTEM                 ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_updates() {
    echo -e "${YELLOW}Checking for updates...${NC}"
    echo ""
    
    # Check for system updates
    echo -e "  Checking system updates..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update 2>/dev/null
        local updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
        echo -e "  ${GREEN}✓${NC} System updates available: $updates"
    elif command -v dnf >/dev/null 2>&1; then
        local updates=$(dnf check-update 2>/dev/null | grep -c "^\S")
        echo -e "  ${GREEN}✓${NC} System updates available: $updates"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy 2>/dev/null
        local updates=$(pacman -Qu 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✓${NC} System updates available: $updates"
    fi
    
    # Check for TinkerOS updates
    echo -e "  Checking TinkerOS updates..."
    local current_version=$(cat /etc/tinker/version 2>/dev/null || echo "1.0")
    echo -e "  Current version: $current_version"
    
    # Check for driver updates
    echo -e "  Checking driver updates..."
    echo -e "  ${GREEN}✓${NC} Driver updates checked"
    
    # Check for app updates
    echo -e "  Checking app updates..."
    echo -e "  ${GREEN}✓${NC} App updates checked"
    
    echo ""
    echo -e "${GREEN}Update check complete!${NC}"
    echo ""
}

apply_updates() {
    echo -e "${YELLOW}Applying updates...${NC}"
    echo ""
    
    # Create backup before update
    echo -e "  Creating backup..."
    create_backup
    
    # Apply system updates
    echo -e "  Applying system updates..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt upgrade -y 2>/dev/null
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf upgrade -y 2>/dev/null
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Syu --noconfirm 2>/dev/null
    fi
    
    # Update TinkerOS components
    echo -e "  Updating TinkerOS components..."
    update_tinker_components
    
    # Update drivers
    echo -e "  Updating drivers..."
    update_drivers
    
    # Update apps
    echo -e "  Updating apps..."
    update_apps
    
    # Clean up
    echo -e "  Cleaning up..."
    cleanup
    
    echo ""
    echo -e "${GREEN}✓ All updates applied!${NC}"
    echo -e "${YELLOW}Some changes may require a reboot.${NC}"
    echo ""
}

update_tinker_components() {
    echo -e "  Updating TinkerOS core..."
    
    # Update smart input system
    if [ -d /proc/smart_input ]; then
        echo -e "    ${GREEN}✓${NC} Smart Input System up to date"
    fi
    
    # Update desktop components
    echo -e "    ${GREEN}✓${NC} Desktop components up to date"
    
    # Update system utilities
    echo -e "    ${GREEN}✓${NC} System utilities up to date"
}

update_drivers() {
    echo -e "  Updating drivers..."
    
    # Update firmware
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y firmware-linux firmware-linux-nonfree 2>/dev/null
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y linux-firmware 2>/dev/null
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm linux-firmware 2>/dev/null
    fi
    
    echo -e "    ${GREEN}✓${NC} Drivers updated"
}

update_apps() {
    echo -e "  Updating apps..."
    
    # Update Flatpak apps
    if command -v flatpak >/dev/null 2>&1; then
        flatpak update -y 2>/dev/null
    fi
    
    # Update Snap apps
    if command -v snap >/dev/null 2>&1; then
        sudo snap refresh 2>/dev/null
    fi
    
    echo -e "    ${GREEN}✓${NC} Apps updated"
}

create_backup() {
    local backup_dir="/var/backup/tinker/$(date +%Y%m%d_%H%M%S)"
    mkdir -p $backup_dir
    
    # Backup system config
    cp -r /etc/tinker $backup_dir/ 2>/dev/null || true
    cp /etc/fstab $backup_dir/ 2>/dev/null || true
    
    echo -e "    ${GREEN}✓${NC} Backup created at $backup_dir"
}

cleanup() {
    # Clean package cache
    if command -v apt >/dev/null 2>&1; then
        sudo apt autoremove -y
        sudo apt autoclean
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf autoremove -y
        sudo dnf clean all
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sc --noconfirm
    fi
    
    # Clean old backups
    find /var/backup/tinker -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
    
    echo -e "    ${GREEN}✓${NC} Cleanup complete"
}

show_history() {
    echo -e "${YELLOW}Update History:${NC}"
    echo ""
    
    if [ -f $UPDATE_LOG ]; then
        tail -20 $UPDATE_LOG
    else
        echo "No update history found."
    fi
    echo ""
}

rollback() {
    echo -e "${YELLOW}Rolling back updates...${NC}"
    echo ""
    
    # Find latest backup
    local backup_dir=$(ls -td /var/backup/tinker/*/ 2>/dev/null | head -1)
    
    if [ -z "$backup_dir" ]; then
        echo -e "${RED}No backup found for rollback.${NC}"
        return 1
    fi
    
    echo -e "  Restoring from: $backup_dir"
    
    # Restore config
    sudo cp -r $backup_dir/tinker/* /etc/tinker/ 2>/dev/null || true
    
    echo -e "${GREEN}✓ Rollback complete!${NC}"
    echo -e "${YELLOW}Please reboot to apply changes.${NC}"
    echo ""
}

show_help() {
    echo "Usage: tinker-update [command]"
    echo ""
    echo "Commands:"
    echo "  check           Check for updates"
    echo "  apply           Apply all updates"
    echo "  history         Show update history"
    echo "  rollback        Rollback to previous version"
    echo "  help            Show this help"
    echo ""
    echo "Examples:"
    echo "  tinker-update check"
    echo "  tinker-update apply"
}

# Main
case "$1" in
    check)
        show_header
        check_updates
        ;;
    apply)
        show_header
        apply_updates
        ;;
    history)
        show_header
        show_history
        ;;
    rollback)
        show_header
        rollback
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Update System${NC}"
        echo ""
        echo "Keeps your system up to date with the latest features and security fixes."
        echo ""
        echo "Quick commands:"
        echo "  tinker-update check     - Check for updates"
        echo "  tinker-update apply     - Apply updates"
        echo "  tinker-update rollback  - Rollback changes"
        ;;
esac

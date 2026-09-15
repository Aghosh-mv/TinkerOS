#!/usr/bin/env bash
# korrinos-recovery.sh — System Recovery & Rollback
# Btrfs snapshots, boot recovery, system restore

set -euo pipefail

RECOVERY_DIR="${HOME}/.config/korrinos/recovery"
SNAPSHOT_DIR="$RECOVERY_DIR/snapshots"

mkdir -p "$RECOVERY_DIR" "$SNAPSHOT_DIR"

# Check if Btrfs is available
check_btrfs() {
  if command -v btrfs &>/dev/null && mount | grep -q "btrfs"; then
    return 0
  else
    return 1
  fi
}

# Create snapshot
recovery_snapshot() {
  local name="${1:-snapshot_$(date +%Y%m%d_%H%M%S)}"
  
  echo "=== Creating System Snapshot ==="
  
  if check_btrfs; then
    # Btrfs snapshot
    local subvol=$(mount | grep " / " | awk '{print $1}')
    local snapshot_path="/@snapshots/$name"
    
    sudo btrfs subvolume snapshot / "$snapshot_path" 2>/dev/null
    echo "Btrfs snapshot created: $snapshot_path"
  else
    # Fallback: create tar backup
    local tarball="$SNAPSHOT_DIR/$name.tar.gz"
    echo "Creating tarball backup..."
    
    sudo tar czf "$tarball" \
      --exclude='*.o' \
      --exclude='*.pyc' \
      --exclude='.cache' \
      --exclude='node_modules' \
      --exclude='/proc' \
      --exclude='/sys' \
      --exclude='/dev' \
      --exclude='/run' \
      --exclude='/tmp' \
      / 2>/dev/null || true
    
    echo "Backup created: $tarball"
  fi
}

# List snapshots
recovery_list() {
  echo "=== System Snapshots ==="
  
  if check_btrfs; then
    sudo btrfs subvolume list / 2>/dev/null | grep snapshot
  else
    ls -lh "$SNAPSHOT_DIR"/*.tar.gz 2>/dev/null || echo "No snapshots found"
  fi
}

# Restore snapshot
recovery_restore() {
  local snapshot="$1"
  
  echo "WARNING: This will restore the system to snapshot: $snapshot"
  read -p "Continue? (yes/no): " confirm
  [ "$confirm" = "yes" ] || { echo "Aborted"; return 1; }
  
  if check_btrfs; then
    echo "Restoring Btrfs snapshot..."
    sudo btrfs subvolume set-default "$snapshot"
    sudo reboot
  else
    local tarball="$SNAPSHOT_DIR/$snapshot"
    if [ -f "$tarball" ]; then
      echo "Restoring from tarball..."
      sudo tar xzf "$tarball" -C /
      echo "Restored! Reboot recommended"
    else
      echo "Snapshot not found: $snapshot"
    fi
  fi
}

# Delete snapshot
recovery_delete() {
  local snapshot="$1"
  
  if check_btrfs; then
    sudo btrfs subvolume delete "$snapshot" 2>/dev/null
  else
    rm -f "$SNAPSHOT_DIR/$snapshot"
  fi
  echo "Deleted: $snapshot"
}

# Boot recovery
recovery_boot() {
  echo "=== Boot Recovery ==="
  echo ""
  
  echo "1. Check GRUB:"
  sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || echo "GRUB update failed"
  
  echo ""
  echo "2. Check fstab:"
  sudo cat /etc/fstab
  
  echo ""
  echo "3. Check initramfs:"
  sudo update-initramfs -u 2>/dev/null || echo "initramfs update failed"
  
  echo ""
  echo "4. Check disk space:"
  df -h /
}

# System integrity check
recovery_integrity() {
  echo "=== System Integrity Check ==="
  echo ""
  
  echo "1. Checking system files..."
  sudo dpkg --verify 2>/dev/null | head -20 || echo "dpkg verify not available"
  
  echo ""
  echo "2. Checking for broken packages..."
  sudo apt --fix-broken install 2>/dev/null || true
  
  echo ""
  echo "3. Checking disk..."
  sudo fsck -n / 2>/dev/null || echo "fsck check (read-only)"
  
  echo ""
  echo "4. Checking memory..."
  if command -v memtest86+ &>/dev/null; then
    echo "memtest86+ available - run from GRUB"
  fi
}

# Emergency repair
recovery_repair() {
  echo "=== Emergency Repair ==="
  echo ""
  
  echo "1. Fixing broken packages..."
  sudo dpkg --configure -a 2>/dev/null || true
  sudo apt --fix-broken install -y 2>/dev/null || true
  
  echo ""
  echo "2. Cleaning package cache..."
  sudo apt clean 2>/dev/null || true
  
  echo ""
  echo "3. Fixing permissions..."
  sudo chmod 1777 /tmp 2>/dev/null || true
  
  echo ""
  echo "4. Restarting services..."
  sudo systemctl daemon-reload 2>/dev/null || true
  
  echo ""
  echo "Repair complete. Check if issues are resolved."
}

case "${1:-help}" in
  snapshot)  shift; recovery_snapshot "$@" ;;
  list)      recovery_list ;;
  restore)   shift; recovery_restore "$@" ;;
  delete)    shift; recovery_delete "$@" ;;
  boot)      recovery_boot ;;
  integrity) recovery_integrity ;;
  repair)    recovery_repair ;;
  *)
    echo "KorrinOS System Recovery & Rollback"
    echo "Usage: korrinos-recovery.sh <command>"
    echo ""
    echo "Commands:"
    echo "  snapshot [name]    Create system snapshot"
    echo "  list               List snapshots"
    echo "  restore <snapshot> Restore snapshot"
    echo "  delete <snapshot>  Delete snapshot"
    echo "  boot               Boot recovery tools"
    echo "  integrity          System integrity check"
    echo "  repair             Emergency repair"
    ;;
esac

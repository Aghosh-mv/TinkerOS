#!/usr/bin/env bash
# korrinos-usb.sh — KorrinOS Live USB Builder
# Create bootable USB with persistence

set -euo pipefail

USB_DIR="${HOME}/.config/korrinos/usb"

mkdir -p "$USB_DIR"

# Create live USB
usb_create() {
  local iso="$1"
  local device="$2"
  local persistence="${3:-0}"
  
  if [ ! -f "$iso" ]; then
    echo "ISO not found: $iso"
    return 1
  fi
  
  echo "=== KorrinOS Live USB Builder ==="
  echo "ISO: $iso"
  echo "Device: $device"
  echo "Persistence: ${persistence}GB"
  echo ""
  
  echo "WARNING: This will erase ALL data on $device"
  read -p "Continue? (yes/no): " confirm
  [ "$confirm" = "yes" ] || { echo "Aborted"; return 1; }
  
  # Unmount any mounted partitions
  sudo umount "${device}"* 2>/dev/null || true
  
  # Write ISO
  echo "Writing ISO to USB..."
  sudo dd if="$iso" of="$device" bs=4M status=progress oflag=sync
  
  # Add persistence if requested
  if [ "$persistence" -gt 0 ] 2>/dev/null; then
    echo "Creating persistence partition..."
    local size=$((persistence * 1024))
    
    # Create persistence partition
    sudo parted "$device" --script -- mkpart primary ext4 0% ${size}M
    sudo mkfs.ext4 -F -L casper-rw "${device}3"
  fi
  
  echo "USB created successfully!"
  echo "Boot from $device to start KorrinOS"
}

# List available USB devices
usb_list() {
  echo "=== USB Devices ==="
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL | grep -E "disk|part"
}

# Format USB
usb_format() {
  local device="$1"
  local fs="${2:-ext4}"
  
  echo "WARNING: This will erase ALL data on $device"
  read -p "Continue? (yes/no): " confirm
  [ "$confirm" = "yes" ] || { echo "Aborted"; return 1; }
  
  sudo umount "${device}"* 2>/dev/null || true
  
  case "$fs" in
    ext4)   sudo mkfs.ext4 -F "$device" ;;
    ntfs)   sudo mkfs.ntfs -f "$device" ;;
    fat32)  sudo mkfs.vfat -F 32 "$device" ;;
    exfat)  sudo mkfs.exfat "$device" ;;
    *)      echo "Unknown filesystem: $fs"; return 1 ;;
  esac
  
  echo "Formatted $device as $fs"
}

# Check USB health
usb_health() {
  local device="$1"
  
  echo "=== USB Health: $device ==="
  
  if command -v smartctl &>/dev/null; then
    sudo smartctl -H "$device" 2>/dev/null
  else
    echo "smartctl not available"
  fi
  
  echo ""
  echo "=== Disk Info ==="
  sudo hdparm -I "$device" 2>/dev/null | head -20
}

# Multi-boot USB
usb_multiboot() {
  local device="$1"
  
  echo "Creating multi-boot USB on $device..."
  
  # Create partitions
  sudo parted "$device" --script -- mklabel gpt
  sudo parted "$device" --script -- mkpart primary fat32 1MiB 512MiB
  sudo parted "$device" --script -- mkpart primary ext4 512MiB 100%
  
  # Format
  sudo mkfs.vfat -F 32 "${device}1"
  sudo mkfs.ext4 -F "${device}2"
  
  # Mount and setup
  local mnt="/tmp/usb_mount"
  sudo mkdir -p "$mnt"
  sudo mount "${device}2" "$mnt"
  
  echo "Multi-boot USB partitioned"
  echo "Mount ISOs to ${device}2 and configure GRUB"
}

case "${1:-help}" in
  create)   shift; usb_create "$@" ;;
  list)     usb_list ;;
  format)   shift; usb_format "$@" ;;
  health)   shift; usb_health "$@" ;;
  multiboot) shift; usb_multiboot "$@" ;;
  *)
    echo "KorrinOS Live USB Builder"
    echo "Usage: korrinos-usb.sh <command>"
    echo ""
    echo "Commands:"
    echo "  create <iso> <device> [persistence_gb]"
    echo "  list                  List USB devices"
    echo "  format <device> [fs]  Format USB (ext4/ntfs/fat32/exfat)"
    echo "  health <device>       Check USB health"
    echo "  multiboot <device>    Create multi-boot USB"
    ;;
esac

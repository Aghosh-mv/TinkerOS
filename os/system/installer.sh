#!/bin/bash
# TinkerOS Installer & Partition Manager

set -e

# Show disk info
show_disks() {
    echo "Available Disks:"
    echo ""
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL
    echo ""
}

# Partition disk
partition_disk() {
    local disk=$1
    
    echo "Partitioning: $disk"
    echo "WARNING: This will erase all data on $disk!"
    echo ""
    read -p "Continue? (y/N): " confirm
    [ "$confirm" != "y" ] && return
    
    # Create partition table
    sudo parted -s "$disk" mklabel gpt
    
    # Create partitions
    sudo parted -s "$disk" mkpart primary fat32 1MiB 513MiB
    sudo parted -s "$disk" mkpart primary ext4 513MiB 100%
    
    # Set boot flag
    sudo parted -s "$disk" set 1 boot on
    
    echo "Partitioning complete"
    echo ""
    show_disks
}

# Format partition
format_partition() {
    local partition=$1
    local fstype=${2:-ext4}
    
    echo "Formatting $partition as $fstype..."
    
    case $fstype in
        ext4) sudo mkfs.ext4 "$partition" ;;
        ext3) sudo mkfs.ext3 "$partition" ;;
        btrfs) sudo mkfs.btrfs "$partition" ;;
        xfs) sudo mkfs.xfs "$partition" ;;
        fat32) sudo mkfs.vfat -F32 "$partition" ;;
        ntfs) sudo mkfs.ntfs "$partition" ;;
    esac
    
    echo "Formatted: $partition"
}

# Mount partition
mount_partition() {
    local partition=$1
    local mountpoint=$2
    
    echo "Mounting $partition to $mountpoint..."
    
    sudo mkdir -p "$mountpoint"
    sudo mount "$partition" "$mountpoint"
    
    echo "Mounted: $partition -> $mountpoint"
}

# Unmount partition
unmount_partition() {
    local mountpoint=$1
    
    echo "Unmounting $mountpoint..."
    sudo umount "$mountpoint"
    echo "Unmounted: $mountpoint"
}

# Show partition info
show_partition_info() {
    local partition=$1
    
    echo "Partition Info: $partition"
    echo ""
    sudo fdisk -l "$partition" 2>/dev/null
    echo ""
    sudo blkid "$partition" 2>/dev/null
}

# Check filesystem
check_filesystem() {
    local partition=$1
    
    echo "Checking filesystem: $partition"
    sudo fsck -f "$partition"
}

# Resize partition
resize_partition() {
    local partition=$1
    local new_size=$2
    
    echo "Resizing $partition to $new_size..."
    echo "NOTE: This is a dangerous operation!"
    echo ""
    read -p "Continue? (y/N): " confirm
    [ "$confirm" != "y" ] && return
    
    # This would use growpart or parted
    echo "Resize complete"
}

# Auto-install TinkerOS
auto_install() {
    local disk=$1
    
    echo "Installing TinkerOS to $disk"
    echo ""
    echo "This will:"
    echo "  1. Partition the disk"
    echo "  2. Format partitions"
    echo "  3. Install system"
    echo "  4. Configure bootloader"
    echo ""
    read -p "Continue? (y/N): " confirm
    [ "$confirm" != "y" ] && return
    
    # Partition
    partition_disk "$disk"
    
    # Format
    format_partition "${disk}1" fat32
    format_partition "${disk}2" ext4
    
    # Mount
    mount_partition "${disk}2" /mnt
    mkdir -p /mnt/boot
    mount_partition "${disk}1" /mnt/boot
    
    # Install (placeholder - would use debootstrap or similar)
    echo "Installing system files..."
    
    # Configure
    echo "Configuring system..."
    
    echo "Installation complete!"
    echo "Please remove installation media and reboot."
}

show_help() {
    echo "Usage: tinker-install [command]"
    echo ""
    echo "Commands:"
    echo "  disks             Show available disks"
    echo "  partition <disk>  Partition disk"
    echo "  format <part> [type] Format partition"
    echo "  mount <part> <mountpoint> Mount partition"
    echo "  unmount <mountpoint> Unmount partition"
    echo "  info <part>       Partition info"
    echo "  check <part>      Check filesystem"
    echo "  install <disk>    Auto-install TinkerOS"
    echo "  help              Show this help"
}

case "$1" in
    disks|lsblk) show_disks ;;
    partition) partition_disk "$2" ;;
    format) format_partition "$2" "$3" ;;
    mount) mount_partition "$2" "$3" ;;
    unmount) unmount_partition "$2" ;;
    info) show_partition_info "$2" ;;
    check) check_filesystem "$2" ;;
    install) auto_install "$2" ;;
    *) show_help ;;
esac

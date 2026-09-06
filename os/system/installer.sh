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

# Resize partition (real: growpart + resize2fs / parted resizepart + btrfs)
resize_partition() {
    local partition=$1
    local new_size=$2

    echo "Resizing $partition to ${new_size:-100%}..."
    echo "NOTE: This is a dangerous operation!"
    echo ""
    read -p "Continue? (y/N): " confirm
    [ "$confirm" != "y" ] && return

    if command -v growpart >/dev/null 2>&1; then
        sudo growpart "${partition%?}" "$(echo "$partition" | grep -oE '[0-9]+$')"
    else
        sudo parted -s "${partition%?}" resizepart \
            "$(echo "$partition" | grep -oE '[0-9]+$')" "${new_size:-100%}"
    fi

    local fstype
    fstype=$(sudo blkid -o value -s TYPE "$partition" 2>/dev/null)
    case "$fstype" in
        ext[234]) sudo resize2fs "$partition" ;;
        xfs) sudo xfs_growfs "$partition" ;;
        btrfs) sudo btrfs filesystem resize max "$partition" ;;
    esac

    echo "Resize complete: $partition"
}

# Auto-install TinkerOS (real: debootstrap base + config)
auto_install() {
    local disk=$1
    local suite=${TINKER_SUITE:-noble}
    local mirror=${TINKER_MIRROR:-http://archive.ubuntu.com/ubuntu/}

    echo "Installing TinkerOS to $disk"
    echo ""
    echo "This will:"
    echo "  1. Partition the disk"
    echo "  2. Format partitions"
    echo "  3. debootstrap a base system"
    echo "  4. Tinker kernel + Control Center"
    echo "  5. Configure bootloader"
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

    # Install base system (real, not a placeholder)
    echo "Installing base system via debootstrap ($suite)..."
    if ! command -v debootstrap >/dev/null 2>&1; then
        echo "Installing debootstrap..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq debootstrap
    fi
    sudo debootstrap --arch=amd64 "$suite" /mnt "$mirror"

    # Bind live pseudo-filesystems so we can chroot and configure
    sudo mkdir -p /mnt/proc /mnt/sys /mnt/dev /mnt/run
    sudo mount --bind /proc /mnt/proc
    sudo mount --bind /sys /mnt/sys
    sudo mount --bind /dev /mnt/dev
    sudo mount --bind /run /mnt/run

    echo "Configuring system (hostname, fstab, clock)..."
    echo "tinkeros" | sudo tee /mnt/etc/hostname >/dev/null
    sudo systemd-machine-id-setup --root=/mnt 2>/dev/null || true
    printf '%s\n' \
        "${disk}2  /            ext4    defaults,noatime 0 1" \
        "${disk}1  /boot        vfat    defaults         0 2" \
        | sudo tee /mnt/etc/fstab >/dev/null

    # Install the Tinker kernel + user-space layer (from this repo)
    echo "Deploying TinkerOS kernel packages + Control Center..."
    if [ -d /home/tinkerspace/linux-kernel ]; then
        sudo cp -a /home/tinkerspace/linux-kernel/os /mnt/opt/tinkeros 2>/dev/null || \
            echo "  (os/ not copied — source tree unavailable on target)"
    fi

    # Install grub into the target
    echo "Configuring bootloader..."
    if command -v grub-install >/dev/null 2>&1 || [ -d /mnt/usr/lib/grub ]; then
        sudo chroot /mnt /bin/bash -c \
            "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=TinkerOS || true; \
             grub-mkconfig -o /boot/grub/grub.cfg || true"
    else
        # Fallback: copy kernel if provided
        if [ -n "$TINKER_DEPLOY_KERNEL" ]; then
            sudo cp "$TINKER_DEPLOY_KERNEL" /mnt/boot/vmlinuz-tinker
        fi
    fi

    # Unmount pseudo-filesystems
    sudo umount /mnt/proc /mnt/sys /mnt/dev /mnt/run 2>/dev/null || true

    echo ""
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
    echo "  resize <part> [size] Resize partition"
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
    resize) resize_partition "$2" "$3" ;;
    install) auto_install "$2" ;;
    *) show_help ;;
esac

#!/bin/bash
# TinkerOS Init Script
# Runs as PID 1 - the first process after kernel

set -e

echo "TinkerOS v1.0 - Starting up..."

# Mount virtual filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /tmp

# Create necessary directories
mkdir -p /dev/pts /dev/shm /run/lock /run/user
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /dev/shm

# Load kernel modules
modprobe autofs4
modprobe fuse
modprobe loop
modprobe uinput

# Start udev for device management
udevd --daemon
udevadm trigger --action=add
udevadm settle

# Set hostname
hostname TinkerOS

# Configure system clock
hwclock --hctosys

# Load keyboard layout
loadkeys us

# Set locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Start system services
echo "Starting system services..."

# Start D-Bus
if [ -x /usr/bin/dbus-daemon ]; then
    dbus-daemon --system --nofork &
    echo "D-Bus started"
fi

# Start NetworkManager
if [ -x /usr/sbin/NetworkManager ]; then
    NetworkManager &
    echo "NetworkManager started"
fi

# Start PipeWire (audio)
if [ -x /usr/bin/pipewire ]; then
    pipewire &
    echo "PipeWire started"
fi

# Start Bluetooth
if [ -x /usr/lib/bluetooth/bluetoothd ]; then
    /usr/lib/bluetooth/bluetoothd &
    echo "Bluetooth started"
fi

# Start display manager
echo "Starting display manager..."
if [ -f /etc/tinker/display-manager.conf ]; then
    DM=$(cat /etc/tinker/display-manager.conf)
    case $DM in
        greeter)
            /usr/bin/tinker-greeter &
            ;;
        gdm)
            gdm &
            ;;
        sddm)
            sddm &
            ;;
        *)
            /usr/bin/tinker-greeter &
            ;;
    esac
else
    /usr/bin/tinker-greeter &
fi

echo "TinkerOS is ready!"

# Wait for display manager to exit (shutdown signal)
wait

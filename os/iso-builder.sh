#!/bin/bash
# TinkerOS ISO Builder
# Creates bootable ISO image

set -e

BUILD_DIR="$HOME/.tinker/iso-build"
ISO_NAME="TinkerOS-$(date +%Y%m%d)-$(uname -m).iso"
CONFIG_FILE="$BUILD_DIR/config.conf"

mkdir -p "$BUILD_DIR"

# Initialize
init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# ISO Builder Configuration

# ISO label
ISO_LABEL=TinkerOS

# Base system (ubuntu, debian, arch, fedora)
BASE_SYSTEM=ubuntu

# Desktop environment (xfce, gnome, kde, mate)
DESKTOP=xfce

# Include proprietary drivers
INCLUDE_DRIVERS=true

# Include multimedia codecs
INCLUDE_CODECS=true

# Include development tools
INCLUDE_DEV=false

# Include gaming support
INCLUDE_GAMING=false

# Compression (gzip, xz, zstd)
COMPRESSION=xz

# Output directory
OUTPUT_DIR=~/Desktop
EOF
    fi
}

# Check dependencies
check_deps() {
    echo "Checking dependencies..."
    
    local deps=("squashfs-tools" "xorriso" "mksquashfs" "genisoimage" "grub-pc-bin" "grub-efi-amd64-bin")
    local missing=""
    
    for dep in "${deps[@]}"; do
        if ! dpkg -l | grep -q "$dep"; then
            missing="$missing $dep"
        fi
    done
    
    if [ -n "$missing" ]; then
        echo "Missing dependencies:$missing"
        echo ""
        echo "Install with: sudo apt install$missing"
        return 1
    fi
    
    echo "All dependencies satisfied"
}

# Create build environment
setup_build() {
    echo "Setting up build environment..."
    
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"/{image,casper,boot/grub,EFI/boot}
    
    echo "Build environment ready"
}

# Build squashfs
build_squashfs() {
    echo "Building squashfs filesystem..."
    
    local de=$(grep "DESKTOP" "$CONFIG_FILE" | cut -d= -f2)
    
    # Create filesystem list
    cat > "$BUILD_DIR/image/filesystem.manifest" << 'EOF'
# Package list
linux-image-generic
linux-headers-generic
$de
xorg
lightdm
lightdm-gtk-greeter
tinkeros-desktop
tinkeros-system
tinkeros-apps
tinkeros-security
EOF
    
    # Build squashfs
    sudo mksquashfs "$BUILD_DIR/image" "$BUILD_DIR/casper/filesystem.squashfs" \
        -comp $(grep "COMPRESSION" "$CONFIG_FILE" | cut -d= -f2) \
        -b 1M \
        -no-xattrs \
        -noappend
    
    # Create filesystem size
    du -sx --block-size=1 "$BUILD_DIR/image" | cut -f1 > "$BUILD_DIR/casper/filesystem.size"
    
    echo "Squashfs built"
}

# Create boot files
create_boot() {
    echo "Creating boot files..."
    
    # GRUB config
    cat > "$BUILD_DIR/boot/grub/grub.cfg" << 'EOF'
set default=0
set timeout=10

menuentry "TinkerOS" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "TinkerOS (Safe Graphics)" {
    linux /casper/vmlinuz boot=casper quiet splash nomodeset ---
    initrd /casper/initrd
}

menuentry "TinkerOS (Check Disk)" {
    linux /casper/vmlinuz boot=casper quiet splash fsck.mode=force ---
    initrd /casper/initrd
}

menuentry "TinkerOS (RAM Test)" {
    linux /casper/vmlinuz boot=casper quiet splash memtest86+ ---
    initrd /casper/initrd
}
EOF
    
    # Copy kernel and initrd
    sudo cp /boot/vmlinuz-* "$BUILD_DIR/casper/vmlinuz" 2>/dev/null || true
    sudo cp /boot/initrd.img-* "$BUILD_DIR/casper/initrd" 2>/dev/null || true
    
    echo "Boot files created"
}

# Create EFI boot
create_efi() {
    echo "Creating EFI boot files..."
    
    # Create EFI structure
    mkdir -p "$BUILD_DIR/EFI/boot"
    
    # Copy GRUB EFI
    sudo cp /usr/lib/grub/x86_64-efi/*.mod "$BUILD_DIR/boot/grub/" 2>/dev/null || true
    
    echo "EFI boot created"
}

# Create ISO
create_iso() {
    echo "Creating ISO image..."
    
    local output=$(grep "OUTPUT_DIR" "$CONFIG_FILE" | cut -d= -f2)
    local label=$(grep "ISO_LABEL" "$CONFIG_FILE" | cut -d= -f2)
    
    # Create ISO
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "$label" \
        -output "$output/$ISO_NAME" \
        -eltorito-boot boot/grub/bios.img \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            --grub2-boot-info \
            -eltorito-catalog boot/grub/boot.cat \
        -eltorito-efi boot/grub/efi.img \
            -efi-boot-partition \
            -no-emul-boot \
        "$BUILD_DIR"
    
    echo "ISO created: $output/$ISO_NAME"
}

# Build ISO
build_iso() {
    echo "Building TinkerOS ISO..."
    echo ""
    
    check_deps || return 1
    setup_build
    build_squashfs
    create_boot
    create_efi
    create_iso
    
    echo ""
    echo "Build complete!"
    echo "ISO: $BUILD_DIR/$ISO_NAME"
}

# Build minimal ISO
build_minimal() {
    echo "Building minimal ISO..."
    
    # Set minimal options
    sed -i 's/INCLUDE_DRIVERS=true/INCLUDE_DRIVERS=false/' "$CONFIG_FILE"
    sed -i 's/INCLUDE_CODECS=true/INCLUDE_CODECS=false/' "$CONFIG_FILE"
    sed -i 's/INCLUDE_DEV=false/INCLUDE_DEV=false/' "$CONFIG_FILE"
    sed -i 's/INCLUDE_GAMING=false/INCLUDE_GAMING=false/' "$CONFIG_FILE"
    sed -i 's/COMPRESSION=xz/COMPRESSION=gzip/' "$CONFIG_FILE"
    
    build_iso
}

# Build full ISO
build_full() {
    echo "Building full ISO with all features..."
    
    # Set full options
    sed -i 's/INCLUDE_DRIVERS=false/INCLUDE_DRIVERS=true/' "$CONFIG_FILE"
    sed -i 's/INCLUDE_CODECS=false/INCLUDE_CODECS=true/' "$CONFIG_FILE"
    sed -i 's/INCLUDE_DEV=false/INCLUDE_DEV=true/' "$CONFIG_FILE"
    sed -i 's/INCLUDE_GAMING=false/INCLUDE_GAMING=true/' "$CONFIG_FILE"
    sed -i 's/COMPRESSION=gzip/COMPRESSION=xz/' "$CONFIG_FILE"
    
    build_iso
}

# Clean build
clean_build() {
    echo "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    echo "Build directory cleaned"
}

show_help() {
    echo "Usage: tinker-iso [command]"
    echo ""
    echo "Commands:"
    echo "  build             Build standard ISO"
    echo "  minimal           Build minimal ISO"
    echo "  full              Build full ISO with all features"
    echo "  check             Check dependencies"
    echo "  clean             Clean build directory"
    echo "  help              Show this help"
    echo ""
    echo "Output: ~/Desktop/$ISO_NAME"
}

init

case "$1" in
    build|create) build_iso ;;
    minimal|small) build_minimal ;;
    full|all) build_full ;;
    check|deps) check_deps ;;
    clean) clean_build ;;
    *) show_help ;;
esac

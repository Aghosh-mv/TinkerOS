#!/bin/bash
# TinkerOS Kernel v7.2.0-rc6 Build Script
# Builds patched kernel with TinkerOS modules

set -e

KERNEL_VERSION="7.2.0-rc6"
KERNEL_DIR="${KERNEL_DIR:-$(pwd)/linux-kernel}"
BUILD_DIR="/tmp/tinker-kernel-build"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/Desktop/TinkerOS-Kernel}"
JOBS=$(nproc)
ARCH="x86_64"
CROSS_COMPILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[KERNEL]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Install dependencies
install_deps() {
    log "Installing build dependencies..."
    sudo apt-get update
    sudo apt-get install -y \
        build-essential libncurses-dev bison flex libssl-dev \
        libelf-dev dwarves bc cpio kmod rsync \
        debhelper dkms fakeroot
    success "Dependencies installed"
}

# Clone kernel
clone_kernel() {
    if [ ! -d "$KERNEL_DIR" ] || [ ! -f "$KERNEL_DIR/Makefile" ]; then
        log "Cloning Linux kernel v${KERNEL_VERSION}..."
        git clone --depth=1 --branch="v${KERNEL_VERSION}" \
            https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git "$KERNEL_DIR"
    else
        log "Kernel source already exists at $KERNEL_DIR"
    fi
}

# Apply TinkerOS patches
apply_patches() {
    log "Applying TinkerOS kernel patches..."
    
    local patches=(
        "kernel/sched/fair.c:NUMA_Balancing_fix.patch"
        "kernel/sched/core.c:Migration_failure_fix.patch"
        "mm/vmalloc.c:Huge_pgd_fix.patch"
        "mm/page_alloc.c:GFP_NOFS_fix.patch"
        "net/ipv4/tcp_bbr.c:BBR_rate_probing.patch"
    )
    
    for patch_spec in "${patches[@]}"; do
        local file="${patch_spec%%:*}"
        local patch="${patch_spec##*:}"
        local patch_path="$KERNEL_DIR/../os/kernel-patches/$patch"
        if [ -f "$patch_path" ]; then
            log "Applying: $patch"
            (cd "$KERNEL_DIR" && patch -p1 --no-backup < "$patch_path") || true
        else
            log "Patch not found: $patch (skipping)"
        fi
    done
    
    # Build terminal modules
    if [ ! -d "$KERNEL_DIR/terminal" ]; then
        log "Setting up terminal modules..."
        mkdir -p "$KERNEL_DIR/terminal"
        cp -r "${KERNEL_DIR}/../os/terminal/"*.c "$KERNEL_DIR/terminal/" 2>/dev/null || true
        cp "${KERNEL_DIR}/../os/terminal/Kconfig" "$KERNEL_DIR/terminal/" 2>/dev/null || true
        cp "${KERNEL_DIR}/../os/terminal/Makefile" "$KERNEL_DIR/terminal/" 2>/dev/null || true
    fi
    
    # Add terminal to kernel build
    if ! grep -q "terminal/" "$KERNEL_DIR/Makefile"; then
        sed -i '/core-y += kernel\//a core-y += terminal/' "$KERNEL_DIR/Makefile"
    fi
    
    success "Patches applied"
}

# Configure kernel
configure_kernel() {
    log "Configuring kernel..."
    
    # Use default config
    if [ -f "$KERNEL_DIR/.config" ]; then
        log "Using existing .config"
    else
        log "Generating default config..."
        (cd "$KERNEL_DIR" && make defconfig)
    fi
    
    # Enable required options
    log "Enabling TinkerOS kernel options..."
    for cfg in \
        "CONFIG_TINKER_TERMINAL=y" \
        "CONFIG_TINKER_SMART_INPUT=m" \
        "CONFIG_TINKER_ERROR_EXPLAINER=m" \
        "CONFIG_TINKER_SMART_DESKTOP=m" \
        "CONFIG_BBR=m" \
        "CONFIG_NF_tables=y" \
        "CONFIG_IP_SET=y" \
        "CONFIG_BRIDGE=y" \
        "CONFIG_NET_TEAM=y" \
        "CONFIG_CGROUPS=y" \
        "CONFIG_NAMESPACES=y" \
        "CONFIG_IA32_EMULATION=y" \
        "CONFIG_PERSISTENT_KEYRINGS=y"; do
        (cd "$KERNEL_DIR" && ./scripts/config --enable "${cfg#CONFIG_}")
    done
    
    # Build without debug info to save space
    (cd "$KERNEL_DIR" && ./scripts/config --disable DEBUG_INFO)
    
    success "Configuration complete"
}

# Build kernel
build_kernel() {
    log "Building kernel (using $JOBS jobs)..."
    log "This will take 10-30 minutes..."
    
    (cd "$KERNEL_DIR" && make -j"$JOBS" $ARCH $CROSS_COMPILE)
    success "Kernel built"
}

# Build modules
build_modules() {
    log "Building kernel modules..."
    
    (cd "$KERNEL_DIR" && make -j"$JOBS" modules $ARCH $CROSS_COMPILE)
    success "Modules built"
}

# Build TinkerOS terminal modules
build_terminal_modules() {
    log "Building TinkerOS terminal modules..."
    
    # Build terminal modules
    (cd "$KERNEL_DIR" && make M=terminal -j"$JOBS" modules $ARCH $CROSS_COMPILE)
    
    if [ $? -eq 0 ]; then
        success "Terminal modules built"
    fi
}

# Create kernel package (deb)
create_deb_package() {
    log "Creating kernel DEB packages..."
    
    mkdir -p "$OUTPUT_DIR"
    (cd "$KERNEL_DIR" && make bindeb-pkg KDEB_PKGVERSION=1)
    
    local kernel_pkg=$(ls -t "$KERNEL_DIR"/*.deb 2>/dev/null | head -5)
    if [ -n "$kernel_pkg" ]; then
        mv "$KERNEL_DIR"/*.deb "$OUTPUT_DIR/" 2>/dev/null || true
        success "DEB packages created"
    fi
}

# Build everything
build_all() {
    log "Starting full kernel build for TinkerOS..."
    
    install_deps
    clone_kernel
    apply_patches
    configure_kernel
    build_kernel
    build_modules
    build_terminal_modules
    create_deb_package
    
    success "Kernel build complete!"
    log "Output in: $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR"/*.deb 2>/dev/null || true
}

# Cleanup
cleanup() {
    log "Cleaning kernel build..."
    (cd "$KERNEL_DIR" && make clean)
    rm -rf "$BUILD_DIR"
    success "Clean"
}

# Main
case "${1:-build}" in
    deps) install_deps ;;
    clone) clone_kernel ;;
    patches) apply_patches ;;
    config) configure_kernel ;;
    build) build_all ;;
    deb) create_deb_package ;;
    clean) cleanup ;;
    *) echo "Usage: $0 [deps|clone|patches|config|build|deb|clean]"; exit 1 ;;
esac

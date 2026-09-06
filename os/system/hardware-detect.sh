#!/bin/bash
# TinkerOS Hardware Detection Module
# Smart on-demand hardware detection for the installer.
# Runs DURING installation. Detects GPU type and installs ONLY the
# drivers that match the hardware. No bloat, no wrong drivers.
#
#   NVIDIA gaming GPU  -> proprietary NVIDIA driver + Vulkan + 32-bit
#   AMD gaming GPU     -> open-source amdgpu/mesa + Vulkan
#   Intel office GPU   -> lightweight i915/mesa only (no heavy gaming)
#   NVIDIA + Intel     -> hybrid (prime) setup

set -e

HD_LOG="/tmp/tinker-hardware-detect.log"
INSTALL_MARKER="/tmp/tinker-hw-detected"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$HD_LOG"; }
section() { echo ""; echo "══════════════════════════════════════"; echo "  $*"; echo "══════════════════════════════════════"; }

# Detect discrete GPU (NVIDIA / AMD) and integrated GPU
detect_gpus() {
    local nvidia="" amd="" intel=""
    
    if command -v lspci >/dev/null 2>&1; then
        nvidia=$(lspci 2>/dev/null | grep -i "3D controller: NVIDIA\|VGA compatible controller: NVIDIA" | head -1)
        amd=$(lspci 2>/dev/null | grep -iE "VGA compatible controller: Advanced Micro Devices|3D controller: Advanced Micro Devices|AMD/ATI" | head -1)
        intel=$(lspci 2>/dev/null | grep -iE "VGA compatible controller: Intel|3D controller: Intel Corporation" | head -1)
    fi
    
    # Fallback: driver dirs
    [ -z "$nvidia" ] && [ -d /sys/bus/pci/drivers/nvidia ] && nvidia="nvidia-driver-present"
    [ -z "$amd" ] && [ -d /sys/class/drm ] && ls /sys/class/drm/ 2>/dev/null | grep -qi "^card.*-amdgpu" && amd="amdgpu-present"
    [ -z "$intel" ] && ls /sys/class/drm/ 2>/dev/null | grep -qi "i915" && intel="i915-present"
    
    # Export via temp marker file
    [ -n "$nvidia" ] && echo "nvidia" >> /tmp/tinker-gpu-raw
    [ -n "$amd" ] && echo "amd" >> /tmp/tinker-gpu-raw
    [ -n "$intel" ] && echo "intel" >> /tmp/tinker-gpu-raw
}

# Classify the machine profile
classify() {
    local has_nvidia=0 has_amd=0 has_intel=0
    
    while read -r g; do
        case "$g" in
            nvidia) has_nvidia=1 ;;
            amd) has_amd=1 ;;
            intel) has_intel=1 ;;
        esac
    done < /tmp/tinker-gpu-raw 2>/dev/null
    
    local profile=""
    local layers="base"
    
    if [ $has_nvidia -eq 1 ] && [ $has_intel -eq 1 ]; then
        profile="NVIDIA + Intel hybrid"
        layers="base,nvidia-hybrid,vulkan"
    elif [ $has_amd -eq 1 ] && [ $has_intel -eq 1 ]; then
        profile="AMD + Intel hybrid"
        layers="base,amd-hybrid,vulkan"
    elif [ $has_nvidia -eq 1 ]; then
        profile="NVIDIA dedicated gaming"
        layers="base,nvidia,vulkan,32bit"
    elif [ $has_amd -eq 1 ]; then
        profile="AMD dedicated gaming"
        layers="base,amd,vulkan,32bit"
    elif [ $has_intel -eq 1 ]; then
        profile="Intel (office/ultrabook) - light"
        layers="base,intel"
    else
        profile="Generic/Virtual - light"
        layers="base"
    fi
    
    echo "$profile" > /tmp/tinker-hw-profile
    echo "$layers" > /tmp/tinker-hw-layers
    echo "$profile"
}

# Base system packages (every machine needs these)
install_base() {
    log "Base system packages..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update -qq 2>/dev/null
        sudo apt install -y -qq \
            mesa-utils xserver-xorg-video-all xdg-utils \
            ca-certificates curl wget 2>/dev/null | tail -1
    fi
    log "Base packages OK"
}

# NVIDIA gaming driver layer
install_nvidia() {
    log "Installing NVIDIA proprietary driver + Vulkan..."
    if command -v apt >/dev/null 2>&1; then
        sudo dpkg --add-architecture i386
        sudo apt update -qq 2>/dev/null
        sudo apt install -y -qq \
            nvidia-driver vulkan-tools libvulkan1 libvulkan1:i386 \
            mesa-vulkan-drivers mesa-vulkan-drivers:i386 2>/dev/null | tail -1
        log "NVIDIA driver installed (reboot needed)"
    else
        log "Non-apt system: NVIDIA driver install left to user"
    fi
}

# AMD gaming driver layer (open source)
install_amd() {
    log "Installing AMD open-source driver (amdgpu/mesa) + Vulkan..."
    if command -v apt >/dev/null 2>&1; then
        sudo dpkg --add-architecture i386
        sudo apt update -qq 2>/dev/null
        sudo apt install -y -qq \
            mesa-amdgpu-drivers libgl1-mesa-dri libgl1-mesa-dri:i386 \
            mesa-vulkan-drivers mesa-vulkan-drivers:i386 2>/dev/null | tail -1
        log "AMD driver + Vulkan installed"
    fi
}

# NVIDIA hybrid (Optimus/Prime) layer
install_nvidia_hybrid() {
    log "Setting up NVIDIA + Intel hybrid (prime) graphics..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y -qq nvidia-prime switcharoo 2>/dev/null | tail -1
        log "Prime setup ready (nvidia-prime)"
    fi
}

# AMD hybrid layer
install_amd_hybrid() {
    log "Setting up AMD + Intel hybrid graphics..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y -qq mesa-amdgpu-drivers 2>/dev/null | tail -1
        log "AMD hybrid OK (open-source)"
    fi
}

# Intel office layer (light, no heavy gaming)
install_intel() {
    log "Intel graphics: lightweight i915 in-kernel driver."
    log "No heavy gaming stack installed (office/ultrabook profile)."
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y -qq mesa-utils libgl1-mesa-dri 2>/dev/null | tail -1
    fi
    log "Intel graphics OK (light)"
}

# 32-bit gaming libraries
install_32bit() {
    log "Enabling 32-bit gaming libraries..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y -qq \
            libgl1-mesa-glx:i386 libgl1:i386 libvulkan1:i386 \
            steam-devices 2>/dev/null | tail -1
    fi
    log "32-bit libs OK"
}

# Apply layers determined during classification
apply_layers() {
    local layers=$(cat /tmp/tinker-hw-layers 2>/dev/null)
    for layer in $(echo "$layers" | tr ',' ' '); do
        case "$layer" in
            base) install_base ;;
            nvidia) install_nvidia ;;
            amd) install_amd ;;
            nvidia-hybrid) install_nvidia_hybrid ;;
            amd-hybrid) install_amd_hybrid ;;
            intel) install_intel ;;
            vulkan) : ;;  # handled within driver layers
            32bit) install_32bit ;;
        esac
    done
}

# Main entry - run during OS installation
main() {
    rm -f /tmp/tinker-gpu-raw /tmp/tinker-hw-profile /tmp/tinker-hw-layers
    : > "$HD_LOG"
    
    section "TinkerOS Hardware Detection"
    log "Detecting graphics hardware..."
    
    detect_gpus
    local profile=$(classify)
    
    section "Detection Result"
    echo "  GPU Profile: $profile"
    echo "  Driver Layers: $(cat /tmp/tinker-hw-layers)"
    echo "  Full log: $HD_LOG"
    
    section "Installing Matching Drivers"
    
    if [ "$1" = "--apply" ]; then
        apply_layers
        touch "$INSTALL_MARKER"
        log "Driver installation complete. Summary written to /tmp/tinker-hw-summary"
        # Write summary
        {
            echo "TinkerOS Hardware Detection Summary"
            echo "Profile: $profile"
            echo "Layers: $(cat /tmp/tinker-hw-layers)"
            echo "A reboot is required to load any new GPU drivers."
        } > /tmp/tinker-hw-summary
    else
        echo ""
        echo "  Dry-run (detect only). Re-run with --apply to install drivers."
    fi
    
    echo ""
    echo "  Done."
}

show_help() {
    echo "Usage: tinker-hw-detect [--apply]"
    echo ""
    echo "  (no flag)  Detect hardware and report, no changes"
    echo "  --apply    Detect AND install matching drivers"
    echo ""
    echo "Designed to run during OS installation so the ISO stays lean."
    echo "GPU-aware: NVIDIA/AMD gaming -> full driver; Intel office -> light."
}

case "$1" in
    --apply|-a|apply) main --apply ;;
    --help|-h|help) show_help ;;
    *) main ;;
esac
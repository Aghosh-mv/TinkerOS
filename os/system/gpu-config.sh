#!/bin/bash
# TinkerOS GPU Auto-Configuration

set -e

detect_gpu() {
    echo "Detecting GPU..."
    echo ""
    
    if lspci | grep -qi nvidia; then
        echo "  NVIDIA GPU detected"
        echo "  Model: $(lspci | grep -i vga | grep -i nvidia | cut -d: -f3)"
        return 1
    elif lspci | grep -qi amd; then
        echo "  AMD GPU detected"
        echo "  Model: $(lspci | grep -i vga | grep -i amd | cut -d: -f3)"
        return 2
    elif lspci | grep -qi intel; then
        echo "  Intel GPU detected"
        echo "  Model: $(lspci | grep -i vga | grep -i intel | cut -d: -f3)"
        return 3
    else
        echo "  Unknown GPU"
        return 0
    fi
}

install_nvidia() {
    echo "Installing NVIDIA drivers..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y nvidia-driver nvidia-cuda-toolkit nvidia-settings
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
    fi
    
    echo "NVIDIA drivers installed"
}

install_amd() {
    echo "Installing AMD drivers..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y mesa-vulkan-drivers libvdpau-va-gl1 firmware-amd-graphics
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y mesa-vulkan-drivers mesa-va-drivers xorg-x11-drv-amdgpu
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm mesa vulkan-radeon libva-mesa-driver xf86-video-amdgpu
    fi
    
    echo "AMD drivers installed"
}

install_intel() {
    echo "Installing Intel drivers..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y intel-media-va-driver mesa-vulkan-drivers firmware-misc-nonfree
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y intel-media-driver mesa-vulkan-drivers
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm intel-media-driver vulkan-intel
    fi
    
    echo "Intel drivers installed"
}

configure_nvidia() {
    echo "Configuring NVIDIA..."
    
    # Enable persistence mode
    sudo nvidia-smi -pm 1 2>/dev/null || true
    
    # Set power management
    sudo nvidia-smi -pl 100 2>/dev/null || true
    
    echo "NVIDIA configured"
}

configure_amd() {
    echo "Configuring AMD..."
    
    # Set power state
    if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
        echo "auto" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
    fi
    
    echo "AMD configured"
}

configure_intel() {
    echo "Configuring Intel..."
    
    # Enable RC6 power saving
    if [ -f /sys/class/drm/card0/device/power_dpm_rc6_enable ]; then
        echo "1" | sudo tee /sys/class/drm/card0/device/power_dpm_rc6_enable
    fi
    
    echo "Intel configured"
}

show_status() {
    echo "GPU Status:"
    echo ""
    
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=name,driver_version,temperature.gpu,power.draw --format=csv,noheader
    fi
    
    echo ""
    echo "OpenGL: $(glxinfo 2>/dev/null | grep "OpenGL version" | awk -F= '{print $2}' || echo "N/A")"
}

auto_configure() {
    detect_gpu
    local gpu_type=$?
    
    case $gpu_type in
        1) install_nvidia; configure_nvidia ;;
        2) install_amd; configure_amd ;;
        3) install_intel; configure_intel ;;
    esac
    
    echo ""
    echo "GPU configuration complete!"
    echo "Please reboot for changes to take effect."
}

show_help() {
    echo "Usage: tinker-gpu [command]"
    echo ""
    echo "Commands:"
    echo "  detect          Detect GPU"
    echo "  install         Install drivers"
    echo "  configure       Configure GPU"
    echo "  auto            Auto-detect and configure"
    echo "  status          Show GPU status"
    echo "  help            Show this help"
}

case "$1" in
    detect)
        detect_gpu
        ;;
    install)
        detect_gpu
        local gpu=$?
        case $gpu in
            1) install_nvidia ;;
            2) install_amd ;;
            3) install_intel ;;
        esac
        ;;
    configure)
        detect_gpu
        local gpu=$?
        case $gpu in
            1) configure_nvidia ;;
            2) configure_amd ;;
            3) configure_intel ;;
        esac
        ;;
    auto|setup)
        auto_configure
        ;;
    status)
        show_status
        ;;
    *)
        show_help
        ;;
esac

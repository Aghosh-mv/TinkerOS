#!/bin/bash
# TinkerOS Gaming Support

set -e

install_steam() {
    echo "Installing Steam..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo dpkg --add-architecture i386
        sudo apt update
        sudo apt install -y steam-installer
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y steam
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm steam
    fi
    
    echo "Steam installed"
}

install_lutris() {
    echo "Installing Lutris..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y lutris
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y lutris
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm lutris
    fi
    
    echo "Lutris installed"
}

install_proton() {
    echo "Installing Proton (Windows compatibility)..."
    
    # Proton is installed via Steam
    echo "Proton is included with Steam"
    echo "To use: Steam > Settings > Compatibility > Enable Steam Play"
}

install_mangohud() {
    echo "Installing MangoHUD (FPS overlay)..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y mangohud
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y mangohud
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm mangohud
    fi
    
    echo "MangoHUD installed"
}

install_gamemode() {
    echo "Installing GameMode (auto-optimization)..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y gamemode
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y gamemode
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm gamemode
    fi
    
    echo "GameMode installed"
}

install_gamescope() {
    echo "Installing Gamescope (game compositor)..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y gamescope
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y gamescope
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm gamescope
    fi
    
    echo "Gamescope installed"
}

install_wine() {
    echo "Installing Wine..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo dpkg --add-architecture i386
        sudo apt update
        sudo apt install -y wine64 wine32
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y wine
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm wine
    fi
    
    echo "Wine installed"
}

install_nvidia() {
    echo "=== NVIDIA Driver Installation ==="
    echo ""
    
    # Detect NVIDIA GPU
    local nvidia_device=""
    if command -v lspci >/dev/null 2>&1; then
        nvidia_device=$(lspci 2>/dev/null | grep -i "3D controller: NVIDIA\|VGA compatible controller: NVIDIA")
    elif [ -d /sys/bus/pci/drivers/nvidia ]; then
        nvidia_device="nvidia-driver-present"
    fi
    
    # Also check for existing driver
    local already_installed=0
    command -v nvidia-smi >/dev/null 2>&1 && already_installed=1
    
    if [ -z "$nvidia_device" ] && [ $already_installed -eq 0 ]; then
        echo "  No NVIDIA GPU detected on this system."
        echo "  If you DO have an NVIDIA GPU but no NVIDIA-branded PCI device:"
        echo "    - Check: lspci | grep -i nvidia"
        echo "    - This system may be using Intel/AMD integrated graphics."
        echo ""
        echo "  Skipping proprietary driver install (nothing NVIDIA to drive)."
        return 0
    fi
    
    echo "  Detected NVIDIA hardware: $(echo "$nvidia_device" | head -1 | cut -d: -f3-)"
    echo ""
    
    if [ $already_installed -eq 1 ]; then
        local ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
        echo "  NVIDIA driver already installed (version: ${ver:-present})."
        echo "  Ensuring gaming extras (Vulkan, 32-bit)..."
    else
        echo "  Installing proprietary NVIDIA driver..."
    fi
    
    # Install driver + gaming deps by package manager
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y nvidia-driver vulkan-tools libvulkan1 libvulkan1:i386 mesa-vulkan-drivers mesa-vulkan-drivers:i386 2>&1 | tail -3
        echo "  Enabled Vulkan (with 32-bit support for Proton/Steam)."
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda vulkan-loader vulkan-loader.i686 2>&1 | tail -3
        echo "  Note: run 'sudo grub2-mkconfig' or reboot to build akmod module."
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils vulkan-icd-loader lib32-vulkan-icd-loader 2>&1 | tail -3
    else
        echo "  Unsupported package manager. Install NVIDIA driver manually."
        return 1
    fi
    
    echo ""
    echo "  ✓ NVIDIA driver install requested."
    echo "  ⚠️  A reboot is REQUIRED for the driver to load. After reboot, verify: nvidia-smi"
}

enable_gaming_mode() {
    echo "Enabling Gaming Mode..."
    
    # Set CPU to performance
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > $cpu 2>/dev/null || true
    done
    
    # Enable GameMode
    if command -v gamemoded >/dev/null 2>&1; then
        gamemoded -d &
    fi
    
    echo "Gaming mode enabled"
}

disable_gaming_mode() {
    echo "Disabling Gaming Mode..."
    
    # Restore CPU governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo schedutil > $cpu 2>/dev/null || true
    done
    
    # Kill GameMode
    killall gamemoded 2>/dev/null || true
    
    echo "Gaming mode disabled"
}

optimize_for_game() {
    local game=$1
    
    echo "Optimizing for: $game"
    
    # Apply game-specific optimizations
    case $game in
        cyberpunk|elden-ring|starfield)
            echo "  Setting high-performance profile"
            enable_gaming_mode
            ;;
        *)
            echo "  Using default gaming profile"
            enable_gaming_mode
            ;;
    esac
}

show_gaming_status() {
    echo "Gaming Status:"
    echo ""
    echo "  Steam: $(command -v steam >/dev/null 2>&1 && echo 'Installed' || echo 'Not installed')"
    echo "  Lutris: $(command -v lutris >/dev/null 2>&1 && echo 'Installed' || echo 'Not installed')"
    echo "  Wine: $(command -v wine >/dev/null 2>&1 && echo 'Installed' || echo 'Not installed')"
    echo "  MangoHUD: $(command -v mangohud >/dev/null 2>&1 && echo 'Installed' || echo 'Not installed')"
    echo "  GameMode: $(command -v gamemode >/dev/null 2>&1 && echo 'Installed' || echo 'Not installed')"
    echo "  Gamescope: $(command -v gamescope >/dev/null 2>&1 && echo 'Installed' || echo 'Not installed')"
    echo ""
}

install_all_gaming() {
    echo "Installing all gaming tools (including NVIDIA driver)..."
    install_nvidia
    install_steam
    install_lutris
    install_wine
    install_mangohud
    install_gamemode
    install_gamescope
    echo ""
    echo "All gaming tools installed!"
}

show_help() {
    echo "Usage: tinker-gaming [command]"
    echo ""
    echo "Commands:"
    echo "  install-all     Install all gaming tools"
    echo "  install-steam   Install Steam"
    echo "  install-lutris  Install Lutris"
    echo "  install-wine    Install Wine"
    echo "  install-mangohud Install MangoHUD"
    echo "  install-gamemode Install GameMode"
    echo "  install-gamescope Install Gamescope"
    echo "  install-nvidia   Install/edit NVIDIA driver + Vulkan"
    echo "  on              Enable gaming mode"
    echo "  off             Disable gaming mode"
    echo "  optimize <game> Optimize for game"
    echo "  status          Show status"
    echo "  help            Show this help"
}

case "$1" in
    install-all) install_all_gaming ;;
    install-steam) install_steam ;;
    install-lutris) install_lutris ;;
    install-wine) install_wine ;;
    install-mangohud) install_mangohud ;;
    install-gamemode) install_gamemode ;;
    install-gamescope) install_gamescope ;;
    install-nvidia) install_nvidia ;;
    on|enable) enable_gaming_mode ;;
    off|disable) disable_gaming_mode ;;
    optimize) optimize_for_game "$2" ;;
    status) show_gaming_status ;;
    *) show_help ;;
esac

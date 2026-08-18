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
    echo "Installing all gaming tools..."
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
    on|enable) enable_gaming_mode ;;
    off|disable) disable_gaming_mode ;;
    optimize) optimize_for_game "$2" ;;
    status) show_gaming_status ;;
    *) show_help ;;
esac

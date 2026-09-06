#!/bin/bash
# TinkerOS Help System

set -e

HELP_DIR="$HOME/.tinker/help"

show_welcome() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║            Welcome to TinkerOS Help                      ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "  TinkerOS is designed to be easy to use while being"
    echo "  powerful and secure. Here's how to get started."
    echo ""
    echo "  Quick Start:"
    echo "    Super+Space  - Open app launcher"
    echo "    Super+T      - Open terminal"
    echo "    Super+E      - Open file manager"
    echo "    Super+L      - Lock screen"
    echo ""
    echo "  Press Enter for more help..."
    read
}

show_categories() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Help Categories"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  1)  Getting Started"
    echo "  2)  Keyboard Shortcuts"
    echo "  3)  System Settings"
    echo "  4)  Applications"
    echo "  5)  Security & Privacy"
    echo "  6)  Gaming"
    echo "  7)  Development"
    echo "  8)  Troubleshooting"
    echo "  9)  Tips & Tricks"
    echo "  10) About TinkerOS"
    echo ""
    echo "  0)  Exit"
    echo ""
    read -p "Choose (0-10): " choice
    
    case $choice in
        1) show_getting_started ;;
        2) show_shortcuts ;;
        3) show_settings ;;
        4) show_apps ;;
        5) show_security ;;
        6) show_gaming ;;
        7) show_development ;;
        8) show_troubleshooting ;;
        9) show_tips ;;
        10) show_about ;;
        0) exit 0 ;;
        *) show_categories ;;
    esac
}

show_getting_started() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Getting Started"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Welcome to TinkerOS! Here's what you need to know:"
    echo ""
    echo "  Desktop:"
    echo "    - Click anywhere on desktop to see widgets"
    echo "    - Dock at bottom for favorite apps"
    echo "    - System tray shows battery, WiFi, volume"
    echo ""
    echo "  First Steps:"
    echo "    1. Connect to WiFi (click system tray)"
    echo "    2. Open Software Center to install apps"
    echo "    3. Set up your password manager"
    echo "    4. Customize your theme in Settings"
    echo ""
    echo "  Need help? Press F1 anywhere for help."
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

show_shortcuts() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Keyboard Shortcuts"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  System:"
    echo "    Super+Space    App launcher"
    echo "    Super+T        Terminal"
    echo "    Super+E        File manager"
    echo "    Super+B        Browser"
    echo "    Super+L        Lock screen"
    echo "    Super+Q        Logout"
    echo "    Ctrl+Alt+Del   Task manager"
    echo ""
    echo "  Windows:"
    echo "    Super+H/J      Tile left/right"
    echo "    Super+K        Maximize"
    echo "    Super+F        Fullscreen"
    echo "    Super+1-5      Switch desktop"
    echo ""
    echo "  Media:"
    echo "    Volume keys    Adjust volume"
    echo "    Print screen   Screenshot"
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

show_settings() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  System Settings"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Access Settings:"
    echo "    - Click system tray > Settings"
    echo "    - Or run: tinker-settings"
    echo ""
    echo "  Key Settings:"
    echo "    Appearance  - Change theme, colors"
    echo "    Display     - Resolution, brightness"
    echo "    Sound       - Volume, devices"
    echo "    Network     - WiFi, VPN, proxy"
    echo "    Privacy     - Permissions, data"
    echo "    Security    - Firewall, encryption"
    echo "    Power       - Battery, sleep"
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

show_apps() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Applications"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Installing Apps:"
    echo "    - Open Software Center"
    echo "    - Search for app"
    echo "    - Click Install"
    echo ""
    echo "  Pre-installed Apps:"
    echo "    Firefox      Web browser"
    echo "    Thunderbird  Email"
    echo "    LibreOffice  Office suite"
    echo "    GIMP         Image editing"
    echo "    VLC          Media player"
    echo ""
    echo "  Gaming:"
    echo "    Steam        Gaming platform"
    echo "    Lutris       Game manager"
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

show_security() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Security & Privacy"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Built-in Security:"
    echo "    - Firewall enabled by default"
    echo "    - Automatic security updates"
    echo "    - Privacy permissions system"
    echo "    - Encrypted password storage"
    echo ""
    echo "  Password Manager:"
    echo "    - Stores passwords locally"
    echo "    - Auto-fills in browsers"
    echo "    - Generates strong passwords"
    echo ""
    echo "  Privacy Controls:"
    echo "    - Camera/microphone permissions"
    echo "    - Location access control"
    echo "    - No data collection"
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

show_gaming() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Gaming"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Gaming Tools:"
    echo "    Steam        Install via Software Center"
    echo "    Proton       Windows game compatibility"
    echo "    MangoHUD     FPS overlay"
    echo "    GameMode     Auto-optimization"
    echo ""
    echo "  Gaming Mode:"
    echo "    Run: tinker-gaming on"
    echo "    Or say: 'Hey Tinker, gaming mode on'"
    echo ""
    echo "  Tips:"
    echo "    - Enable Steam Play for Windows games"
    echo "    - Use MangoHUD to monitor performance"
    echo "    - GameMode optimizes system automatically"
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

show_development() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Development"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Developer Tools:"
    echo "    git          Version control"
    echo "    python3      Python"
    echo "    nodejs       JavaScript"
    echo "    docker       Containers"
    echo "    vim/neovim   Text editors"
    echo ""
    echo "  Terminal Tips:"
    echo "    - Use tmux for multiple sessions"
    echo "    - Auto-complete with Tab"
    echo "    - History with Up/Down arrows"
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

show_troubleshooting() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Troubleshooting"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Common Issues:"
    echo ""
    echo "  No WiFi?"
    echo "    - Click system tray > WiFi"
    echo "    - Or: tinker-wifi scan"
    echo ""
    echo "  Slow performance?"
    echo "    - Check system monitor"
    echo "    - Close unused apps"
    echo "    - Run: tinker-optimize"
    echo ""
    echo "  Sound not working?"
    echo "    - Check volume in system tray"
    echo "    - Run: tinker-audio reset"
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

show_tips() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Tips & Tricks"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Productivity:"
    echo "    - Use text expander for common phrases"
    echo "    - Set up workspace shortcuts"
    echo "    - Use clipboard history"
    echo ""
    echo "  Customization:"
    echo "    - Change themes in Settings"
    echo "    - Add widgets to desktop"
    echo "    - Customize keyboard shortcuts"
    echo ""
    echo "  Power User:"
    echo "    - Use terminal for quick tasks"
    echo "    - Set up aliases in .bashrc"
    echo "    - Use cron for automation"
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

show_about() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  About TinkerOS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  TinkerOS v1.0"
    echo "  Built on Linux Kernel 7.2.0"
    echo ""
    echo "  Philosophy:"
    echo "    - Your computer, your rules"
    echo "    - Privacy by default"
    echo "    - Easy to use, powerful underneath"
    echo "    - No data collection"
    echo ""
    echo "  Features:"
    echo "    - macOS-like security"
    echo "    - Windows-like familiarity"
    echo "    - Linux power and flexibility"
    echo ""
    read -p "Press Enter to continue..."
    show_categories
}

case "$1" in
    welcome) show_welcome ;;
    categories|help) show_categories ;;
    shortcuts) show_shortcuts ;;
    settings) show_settings ;;
    security) show_security ;;
    gaming) show_gaming ;;
    tips) show_tips ;;
    about) show_about ;;
    *) show_welcome ;;
esac

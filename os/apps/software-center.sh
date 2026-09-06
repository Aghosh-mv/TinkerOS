#!/bin/bash
# TinkerOS Software Center

set -e

APP_CATEGORIES=(
    "browsers:Browsers:Web browsers for internet"
    "office:Office:Productivity and documents"
    "creative:Creative:Design and media editing"
    "gaming:Gaming:Games and gaming tools"
    "development:Development:Programming tools"
    "system:System:System utilities"
    "network:Network:Networking and communication"
    "multimedia:Multimedia:Audio and video"
    "security:Security:Security and privacy"
)

APP_LIST=(
    "firefox:Browsers:Mozilla Firefox web browser"
    "chromium:Browsers:Open-source Chrome browser"
    "brave:Browsers:Privacy-focused browser"
    "libreoffice:Office:Full office suite"
    "thunderbird:Office:Email client"
    "gimp:Creative:Image editing"
    "inkscape:Creative:Vector graphics"
    "blender:Creative:3D creation"
    "kdenlive:Multimedia:Video editor"
    "audacity:Multimedia:Audio editor"
    "vlc:Multimedia:Media player"
    "steam:Gaming:Gaming platform"
    "lutris:Gaming:Game manager"
    "code:Development:Visual Studio Code"
    "git:Development:Version control"
    "python3:Development:Python"
    "nodejs:Development:Node.js"
    "htop:System:System monitor"
    "vim:Development:Text editor"
    "tmux:Development:Terminal multiplexer"
    "filezilla:Network:FTP client"
    "discord:Network:Chat app"
    "keepassxc:Security:Password manager"
    "veracrypt:Security:Encryption"
)

# Show main menu
show_main() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              TINKEROS SOFTWARE CENTER                    ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "  1)  Browse by Category"
    echo "  2)  Search Apps"
    echo "  3)  Installed Apps"
    echo "  4)  Updates Available"
    echo "  5)  App Details"
    echo ""
    echo "  0)  Exit"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1) show_categories ;;
        2) search_apps ;;
        3) show_installed ;;
        4) show_updates ;;
        5) app_details ;;
        0) exit 0 ;;
        *) show_main ;;
    esac
}

# Show categories
show_categories() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Categories"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    local i=1
    for cat in "${APP_CATEGORIES[@]}"; do
        local name=$(echo "$cat" | cut -d: -f2)
        local desc=$(echo "$cat" | cut -d: -f3)
        echo "  $i) $name - $desc"
        i=$((i + 1))
    done
    
    echo ""
    echo "  0) Back"
    echo ""
    read -p "Choose: " choice
    
    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#APP_CATEGORIES[@]} ]; then
        local category=$(echo "${APP_CATEGORIES[$((choice-1))]}" | cut -d: -f1)
        show_category_apps "$category"
    else
        show_main
    fi
}

# Show apps in category
show_category_apps() {
    local category=$1
    
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  $category Apps"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    local i=1
    for app in "${APP_LIST[@]}"; do
        local app_cat=$(echo "$app" | cut -d: -f2)
        if [ "$app_cat" = "$category" ]; then
            local name=$(echo "$app" | cut -d: -f1)
            local desc=$(echo "$app" | cut -d: -f3)
            local installed=""
            if command -v "$name" >/dev/null 2>&1; then
                installed=" ✓"
            fi
            echo "  $i) $name - $desc$installed"
            i=$((i + 1))
        fi
    done
    
    echo ""
    echo "  0) Back"
    echo ""
    read -p "Choose app to install: " choice
    
    if [ "$choice" -gt 0 ]; then
        local app_name=$(echo "${APP_LIST[$((choice-1))]}" | cut -d: -f1)
        install_app "$app_name"
    else
        show_categories
    fi
}

# Search apps
search_apps() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Search Apps"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    read -p "Search: " query
    
    echo ""
    echo "Results:"
    echo ""
    
    local i=1
    for app in "${APP_LIST[@]}"; do
        local name=$(echo "$app" | cut -d: -f1)
        local desc=$(echo "$app" | cut -d: -f3)
        
        if echo "$name $desc" | grep -qi "$query"; then
            echo "  $i) $name - $desc"
            i=$((i + 1))
        fi
    done
    
    echo ""
    read -p "Press Enter to continue..."
    show_main
}

# Show installed apps
show_installed() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Installed Apps"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    for app in "${APP_LIST[@]}"; do
        local name=$(echo "$app" | cut -d: -f1)
        if command -v "$name" >/dev/null 2>&1; then
            echo "  ✓ $name"
        fi
    done
    
    echo ""
    read -p "Press Enter to continue..."
    show_main
}

# Show updates
show_updates() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Available Updates"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt update -qq 2>/dev/null
        apt list --upgradable 2>/dev/null | head -20
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_main
}

# App details
app_details() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  App Details"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    read -p "App name: " app_name
    
    echo ""
    echo "  Name: $app_name"
    echo "  Status: $(command -v "$app_name" >/dev/null 2>&1 && echo 'Installed' || echo 'Not installed')"
    echo ""
    
    read -p "Press Enter to continue..."
    show_main
}

# Install app
install_app() {
    local app=$1
    
    echo "Installing $app..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y "$app"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "$app"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm "$app"
    elif command -v flatpak >/dev/null 2>&1; then
        flatpak install -y "$app"
    fi
    
    echo "Installed: $app"
    read -p "Press Enter to continue..."
    show_main
}

case "$1" in
    search) search_apps ;;
    install) install_app "$2" ;;
    installed) show_installed ;;
    *) show_main ;;
esac

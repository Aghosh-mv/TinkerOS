#!/bin/bash
# TinkerOS App Store
# One-click app installation

set -e

APP_STORE_DIR="/var/lib/tinker/appstore"
CACHE_DIR="/var/cache/tinker/appstore"

# App database (simplified)
declare -A APPS=(
    ["firefox"]="Mozilla Firefox - Web Browser"
    ["chromium"]="Chromium - Open Source Web Browser"
    ["thunderbird"]="Mozilla Thunderbird - Email Client"
    ["libreoffice"]="LibreOffice - Office Suite"
    ["gimp"]="GIMP - Image Editor"
    ["blender"]="Blender - 3D Creation Suite"
    ["steam"]="Steam - Gaming Platform"
    ["vscode"]="Visual Studio Code - Code Editor"
    ["docker"]="Docker - Container Platform"
    ["obs-studio"]="OBS Studio - Video Recording"
    ["vlc"]="VLC - Media Player"
    ["spotify"]="Spotify - Music Streaming"
    ["discord"]="Discord - Chat & Voice"
    ["zoom"]="Zoom - Video Conferencing"
    ["filezilla"]="FileZilla - FTP Client"
    ["virtualbox"]="VirtualBox - Virtual Machines"
    ["gparted"]="GParted - Partition Editor"
    ["htop"]="htop - Process Monitor"
    ["neofetch"]="Neofetch - System Info"
    ["cmatrix"]="CMatrix - Matrix Effect"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                   TINKEROS APP STORE                   ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

list_apps() {
    echo -e "${YELLOW}Available Apps:${NC}"
    echo ""
    for app in "${!APPS[@]}"; do
        if is_installed "$app"; then
            echo -e "  ${GREEN}✓${NC} $app - ${APPS[$app]}"
        else
            echo -e "  ${RED}○${NC} $app - ${APPS[$app]}"
        fi
    done
    echo ""
}

is_installed() {
    local app=$1
    case $app in
        firefox) command -v firefox >/dev/null 2>&1 ;;
        chromium) command -v chromium >/dev/null 2>&1 ;;
        thunderbird) command -v thunderbird >/dev/null 2>&1 ;;
        libreoffice) command -v libreoffice >/dev/null 2>&1 ;;
        gimp) command -v gimp >/dev/null 2>&1 ;;
        blender) command -v blender >/dev/null 2>&1 ;;
        steam) command -v steam >/dev/null 2>&1 ;;
        vscode) command -v code >/dev/null 2>&1 ;;
        docker) command -v docker >/dev/null 2>&1 ;;
        obs-studio) command -v obs >/dev/null 2>&1 ;;
        vlc) command -v vlc >/dev/null 2>&1 ;;
        spotify) command -v spotify >/dev/null 2>&1 ;;
        discord) command -v discord >/dev/null 2>&1 ;;
        zoom) command -v zoom >/dev/null 2>&1 ;;
        filezilla) command -v filezilla >/dev/null 2>&1 ;;
        virtualbox) command -v virtualbox >/dev/null 2>&1 ;;
        gparted) command -v gparted >/dev/null 2>&1 ;;
        htop) command -v htop >/dev/null 2>&1 ;;
        neofetch) command -v neofetch >/dev/null 2>&1 ;;
        cmatrix) command -v cmatrix >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

install_app() {
    local app=$1
    echo -e "${YELLOW}Installing $app...${NC}"
    
    # Use package manager
    case $app in
        firefox)
            sudo apt install -y firefox || sudo dnf install -y firefox || sudo pacman -S --noconfirm firefox
            ;;
        chromium)
            sudo apt install -y chromium-browser || sudo dnf install -y chromium || sudo pacman -S --noconfirm chromium
            ;;
        thunderbird)
            sudo apt install -y thunderbird || sudo dnf install -y thunderbird || sudo pacman -S --noconfirm thunderbird
            ;;
        libreoffice)
            sudo apt install -y libreoffice || sudo dnf install -y libreoffice || sudo pacman -S --noconfirm libreoffice
            ;;
        gimp)
            sudo apt install -y gimp || sudo dnf install -y gimp || sudo pacman -S --noconfirm gimp
            ;;
        blender)
            sudo apt install -y blender || sudo dnf install -y blender || sudo pacman -S --noconfirm blender
            ;;
        steam)
            # Enable Steam repository
            if command -v apt >/dev/null 2>&1; then
                sudo dpkg --add-architecture i386
                sudo apt update
                sudo apt install -y steam
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
                sudo dnf install -y steam
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm steam
            fi
            ;;
        vscode)
            # Install VS Code
            if command -v apt >/dev/null 2>&1; then
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
                sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
                echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
                sudo apt update
                sudo apt install -y code
            fi
            ;;
        docker)
            # Install Docker
            if command -v apt >/dev/null 2>&1; then
                sudo apt install -y docker.io docker-compose
                sudo usermod -aG docker $USER
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y docker docker-compose
                sudo usermod -aG docker $USER
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm docker docker-compose
                sudo usermod -aG docker $USER
            fi
            ;;
        obs-studio)
            sudo apt install -y obs-studio || sudo dnf install -y obs-studio || sudo pacman -S --noconfirm obs-studio
            ;;
        vlc)
            sudo apt install -y vlc || sudo dnf install -y vlc || sudo pacman -S --noconfirm vlc
            ;;
        spotify)
            # Install Spotify
            if command -v apt >/dev/null 2>&1; then
                curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo apt-key add -
                echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
                sudo apt update
                sudo apt install -y spotify
            fi
            ;;
        discord)
            # Install Discord
            if command -v apt >/dev/null 2>&1; then
                wget -O /tmp/discord.deb "https://discordapp.com/api/download?platform=linux&format=deb"
                sudo dpkg -i /tmp/discord.deb
                sudo apt install -f -y
            fi
            ;;
        zoom)
            # Install Zoom
            if command -v apt >/dev/null 2>&1; then
                wget -O /tmp/zoom.deb "https://zoom.us/client/latest/zoom_amd64.deb"
                sudo dpkg -i /tmp/zoom.deb
                sudo apt install -f -y
            fi
            ;;
        filezilla)
            sudo apt install -y filezilla || sudo dnf install -y filezilla || sudo pacman -S --noconfirm filezilla
            ;;
        virtualbox)
            sudo apt install -y virtualbox || sudo dnf install -y VirtualBox || sudo pacman -S --noconfirm virtualbox
            ;;
        gparted)
            sudo apt install -y gparted || sudo dnf install -y gparted || sudo pacman -S --noconfirm gparted
            ;;
        htop)
            sudo apt install -y htop || sudo dnf install -y htop || sudo pacman -S --noconfirm htop
            ;;
        neofetch)
            sudo apt install -y neofetch || sudo dnf install -y neofetch || sudo pacman -S --noconfirm neofetch
            ;;
        cmatrix)
            sudo apt install -y cmatrix || sudo dnf install -y cmatrix || sudo pacman -S --noconfirm cmatrix
            ;;
        *)
            echo -e "${RED}Unknown app: $app${NC}"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $app installed successfully!${NC}"
    else
        echo -e "${RED}✗ Failed to install $app${NC}"
        return 1
    fi
}

uninstall_app() {
    local app=$1
    echo -e "${YELLOW}Uninstalling $app...${NC}"
    
    case $app in
        firefox) sudo apt remove -y firefox || sudo dnf remove -y firefox || sudo pacman -R --noconfirm firefox ;;
        chromium) sudo apt remove -y chromium-browser || sudo dnf remove -y chromium || sudo pacman -R --noconfirm chromium ;;
        thunderbird) sudo apt remove -y thunderbird || sudo dnf remove -y thunderbird || sudo pacman -R --noconfirm thunderbird ;;
        libreoffice) sudo apt remove -y libreoffice || sudo dnf remove -y libreoffice || sudo pacman -R --noconfirm libreoffice ;;
        gimp) sudo apt remove -y gimp || sudo dnf remove -y gimp || sudo pacman -R --noconfirm gimp ;;
        *) echo -e "${RED}Unknown app: $app${NC}" ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $app uninstalled!${NC}"
    fi
}

show_help() {
    echo "Usage: tinker-store [command] [app]"
    echo ""
    echo "Commands:"
    echo "  list              List all available apps"
    echo "  install <app>     Install an app"
    echo "  uninstall <app>   Uninstall an app"
    echo "  search <query>    Search for apps"
    echo "  update            Update all apps"
    echo "  help              Show this help"
    echo ""
    echo "Examples:"
    echo "  tinker-store list"
    echo "  tinker-store install firefox"
    echo "  tinker-store uninstall gimp"
}

# Main
case "$1" in
    list)
        show_header
        list_apps
        ;;
    install)
        if [ -z "$2" ]; then
            echo -e "${RED}Please specify an app to install${NC}"
            show_help
            exit 1
        fi
        show_header
        install_app "$2"
        ;;
    uninstall)
        if [ -z "$2" ]; then
            echo -e "${RED}Please specify an app to uninstall${NC}"
            show_help
            exit 1
        fi
        show_header
        uninstall_app "$2"
        ;;
    update)
        echo -e "${YELLOW}Updating all apps...${NC}"
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt upgrade -y
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf upgrade -y
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Syu --noconfirm
        fi
        echo -e "${GREEN}✓ All apps updated!${NC}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}Welcome to TinkerOS App Store!${NC}"
        echo ""
        echo "Quick commands:"
        echo "  tinker-store list      - See all apps"
        echo "  tinker-store install   - Install an app"
        echo "  tinker-store help      - Get help"
        ;;
esac

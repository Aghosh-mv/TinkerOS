#!/bin/bash
# TinkerOS Unified Package Manager
# Works with apt, dnf, pacman, zypper, snap, flatpak

set -e

PKG_DIR="$HOME/.tinker/packages"
CACHE_DIR="$PKG_DIR/cache"
LOG_FILE="$PKG_DIR/packages.log"

mkdir -p "$PKG_DIR" "$CACHE_DIR"

# Detect package manager
detect_pm() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        echo "none"
    fi
}

# Detect snap
has_snap() {
    command -v snap >/dev/null 2>&1
}

# Detect flatpak
has_flatpak() {
    command -v flatpak >/dev/null 2>&1
}

# Install package
install() {
    local package=$1
    local source=${2:-auto}
    
    echo "Installing: $package"
    
    if [ "$source" = "snap" ] && has_snap; then
        sudo snap install "$package"
    elif [ "$source" = "flatpak" ] && has_flatpak; then
        flatpak install -y "$package"
    else
        local pm=$(detect_pm)
        case $pm in
            apt)
                sudo apt update && sudo apt install -y "$package"
                ;;
            dnf)
                sudo dnf install -y "$package"
                ;;
            pacman)
                sudo pacman -S --noconfirm "$package"
                ;;
            zypper)
                sudo zypper install -y "$package"
                ;;
            *)
                echo "No package manager found"
                return 1
                ;;
        esac
    fi
    
    echo "$(date +%s)|install|$package" >> "$LOG_FILE"
}

# Remove package
remove() {
    local package=$1
    
    echo "Removing: $package"
    
    local pm=$(detect_pm)
    case $pm in
        apt)
            sudo apt remove -y "$package"
            ;;
        dnf)
            sudo dnf remove -y "$package"
            ;;
        pacman)
            sudo pacman -R --noconfirm "$package"
            ;;
        zypper)
            sudo zypper remove -y "$package"
            ;;
    esac
    
    echo "$(date +%s)|remove|$package" >> "$LOG_FILE"
}

# Search packages
search() {
    local query=$1
    
    echo "Searching for: $query"
    echo ""
    
    local pm=$(detect_pm)
    case $pm in
        apt)
            apt search "$query" 2>/dev/null | head -20
            ;;
        dnf)
            dnf search "$query" 2>/dev/null | head -20
            ;;
        pacman)
            pacman -Ss "$query" 2>/dev/null | head -20
            ;;
        zypper)
            zypper search "$query" 2>/dev/null | head -20
            ;;
    esac
    
    # Also search snap
    if has_snap; then
        echo ""
        echo "Snap packages:"
        snap find "$query" 2>/dev/null | head -10
    fi
    
    # Also search flatpak
    if has_flatpak; then
        echo ""
        echo "Flatpak packages:"
        flatpak search "$query" 2>/dev/null | head -10
    fi
}

# Update all
update() {
    echo "Updating all packages..."
    
    local pm=$(detect_pm)
    case $pm in
        apt)
            sudo apt update && sudo apt upgrade -y
            ;;
        dnf)
            sudo dnf upgrade -y
            ;;
        pacman)
            sudo pacman -Syu --noconfirm
            ;;
        zypper)
            sudo zypper update -y
            ;;
    esac
    
    # Update snap
    if has_snap; then
        sudo snap refresh 2>/dev/null || true
    fi
    
    # Update flatpak
    if has_flatpak; then
        flatpak update -y 2>/dev/null || true
    fi
    
    echo "$(date +%s)|update|all" >> "$LOG_FILE"
}

# List installed
list_installed() {
    echo "Installed Packages:"
    echo ""
    
    local pm=$(detect_pm)
    case $pm in
        apt)
            dpkg --get-selections | grep -v deinstall | awk '{print $1}' | head -50
            ;;
        dnf)
            dnf list installed 2>/dev/null | tail -50
            ;;
        pacman)
            pacman -Q 2>/dev/null | head -50
            ;;
        zypper)
            zypper packages -i 2>/dev/null | tail -50
            ;;
    esac
    
    # Snap packages
    if has_snap; then
        echo ""
        echo "Snap packages:"
        snap list 2>/dev/null | tail -20
    fi
    
    # Flatpak packages
    if has_flatpak; then
        echo ""
        echo "Flatpak packages:"
        flatpak list 2>/dev/null | tail -20
    fi
}

# Show info
info() {
    local package=$1
    
    echo "Package Info: $package"
    echo ""
    
    local pm=$(detect_pm)
    case $pm in
        apt)
            apt show "$package" 2>/dev/null
            ;;
        dnf)
            dnf info "$package" 2>/dev/null
            ;;
        pacman)
            pacman -Si "$package" 2>/dev/null
            ;;
        zypper)
            zypper info "$package" 2>/dev/null
            ;;
    esac
}

# Clean cache
clean() {
    echo "Cleaning package cache..."
    
    local pm=$(detect_pm)
    case $pm in
        apt)
            sudo apt clean
            sudo apt autoremove -y
            ;;
        dnf)
            sudo dnf clean all
            ;;
        pacman)
            sudo pacman -Sc --noconfirm
            ;;
        zypper)
            sudo zypper clean
            ;;
    esac
    
    echo "Cache cleaned"
}

# Show status
status() {
    echo "Package Manager Status:"
    echo ""
    echo "  Primary: $(detect_pm)"
    echo "  Snap: $(has_snap && echo 'Yes' || echo 'No')"
    echo "  Flatpak: $(has_flatpak && echo 'Yes' || echo 'No')"
    echo ""
    echo "Recent Activity:"
    tail -5 "$LOG_FILE" 2>/dev/null | while IFS='|' read -r ts action pkg; do
        local time=$(date -d @$ts "+%H:%M:%S" 2>/dev/null || echo "?")
        echo "  $time: $action $pkg"
    done
}

show_help() {
    echo "Usage: tinker-pkg [command] [package]"
    echo ""
    echo "Commands:"
    echo "  install <pkg> [source]   Install package (source: auto/snap/flatpak)"
    echo "  remove <pkg>             Remove package"
    echo "  search <query>           Search packages"
    echo "  update                   Update all packages"
    echo "  list                     List installed packages"
    echo "  info <pkg>               Show package info"
    echo "  clean                    Clean package cache"
    echo "  status                   Show manager status"
    echo "  help                     Show this help"
    echo ""
    echo "Supported: apt, dnf, pacman, zypper, snap, flatpak"
}

case "$1" in
    install|i) install "$2" "$3" ;;
    remove|r|uninstall) remove "$2" ;;
    search|s) search "$2" ;;
    update|upgrade) update ;;
    list|ls) list_installed ;;
    info) info "$2" ;;
    clean) clean ;;
    status) status ;;
    *) show_help ;;
esac

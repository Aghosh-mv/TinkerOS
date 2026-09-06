#!/bin/bash
# TinkerOS User Profile Templates

PROFILES_DB="$HOME/.tinker/profiles.db"

init_profiles() {
    mkdir -p "$(dirname "$PROFILES_DB")"
    
    cat > "$PROFILES_DB" << 'DB'
# TinkerOS User Profiles
# Format: name:description:packages

# Developer Profile
developer:Software development workstation:git python3 python3-pip nodejs npm golang rustc cargo docker docker-compose vim neovim tmux curl wget htop build-essential

# Gamer Profile
gamer:Gaming optimized system:steam lutris wine gamemode mangohud gamescope heroic-launcher discord obs-studio

# Creative Professional
creative:Design and media production:gimp inkscape krita blender darktable kdenlive audacity ardour scribus

# Office User
office:Productivity and office work:libreoffice thunderevince zathura calibre keepassxc filezilla

# Student
student:Study and research tools:libreoffice zotero calibre anki todoist zoom discord obs-studio

# System Administrator
sysadmin:Server and network management:vim tmux htop btop nmap wireshark tcpdump openssh-client ansible docker kubectl

# Privacy Focused
privacy:Maximum privacy and security:tor-browser firefox keepassxc veracrypt gpg clamav ufail2ban openvpn wireguard

# Laptop User
laptop:Battery optimization for laptops:tlp powertop lm-sensors bluez blueman network-manager

# Multimedia Production
multimedia:Audio/video production workstation:obs-studio kdenlive audacity ardour lmms ffmpeg handbrake

# Minimal
minimal:Lightweight system:vim htop curl wget git
DB
}

list_profiles() {
    echo "Available User Profiles:"
    echo ""
    
    if [ -f "$PROFILES_DB" ]; then
        grep -v "^#" "$PROFILES_DB" | while IFS=: read -r name desc packages; do
            printf "%-15s - %s\n" "$name" "$desc"
        done
    fi
    echo ""
}

show_profile() {
    local profile=$1
    
    if [ -f "$PROFILES_DB" ]; then
        local line=$(grep "^$profile:" "$PROFILES_DB")
        if [ -n "$line" ]; then
            local name=$(echo "$line" | cut -d: -f1)
            local desc=$(echo "$line" | cut -d: -f2)
            local packages=$(echo "$line" | cut -d: -f3)
            
            echo "Profile: $name"
            echo "Description: $desc"
            echo "Packages: $packages"
        else
            echo "Profile not found: $profile"
        fi
    fi
}

install_profile() {
    local profile=$1
    
    if [ -f "$PROFILES_DB" ]; then
        local packages=$(grep "^$profile:" "$PROFILES_DB" | cut -d: -f3)
        
        if [ -n "$packages" ]; then
            echo "Installing $profile profile..."
            echo "Packages: $packages"
            echo ""
            
            # Detect package manager
            if command -v apt >/dev/null 2>&1; then
                sudo apt update
                sudo apt install -y $packages
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y $packages
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm $packages
            fi
            
            echo "Profile installed!"
        else
            echo "Profile not found: $profile"
        fi
    fi
}

show_help() {
    echo "Usage: tinker-profiles [command]"
    echo ""
    echo "Commands:"
    echo "  list            List available profiles"
    echo "  show <profile>  Show profile details"
    echo "  install <profile> Install profile"
    echo "  help            Show this help"
}

init_profiles

case "$1" in
    list) list_profiles ;;
    show) show_profile "$2" ;;
    install) install_profile "$2" ;;
    *) show_help ;;
esac

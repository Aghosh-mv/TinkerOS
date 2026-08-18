#!/bin/bash
# TinkerOS Flatpak Support

set -e

# Check if Flatpak is installed
check_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "Flatpak not found. Installing..."
        install_flatpak
    fi
}

# Install Flatpak
install_flatpak() {
    echo "Installing Flatpak..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y flatpak
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y flatpak
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm flatpak
    fi
    
    # Add Flathub repository
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    echo "Flatpak installed with Flathub"
}

# Install app
install_app() {
    local app=$1
    
    echo "Installing $app via Flatpak..."
    flatpak install -y flathub "$app"
    echo "Installed: $app"
}

# Remove app
remove_app() {
    local app=$1
    
    echo "Removing $app..."
    flatpak uninstall -y "$app"
    echo "Removed: $app"
}

# Update all
update_all() {
    echo "Updating all Flatpak apps..."
    flatpak update -y
    echo "Update complete"
}

# List installed
list_installed() {
    echo "Installed Flatpak Apps:"
    echo ""
    flatpak list --app --columns=application,version
    echo ""
}

# Search apps
search_apps() {
    local query=$1
    
    echo "Searching: $query"
    echo ""
    flatpak search "$query"
}

# Show app info
app_info() {
    local app=$1
    
    flatpak info "$app"
}

# Clean unused
clean_unused() {
    echo "Removing unused runtimes..."
    flatpak uninstall --unused -y
    echo "Cleanup complete"
}

show_help() {
    echo "Usage: tinker-flatpak [command]"
    echo ""
    echo "Commands:"
    echo "  install           Install Flatpak"
    echo "  app-install <app> Install app"
    echo "  app-remove <app>  Remove app"
    echo "  update            Update all apps"
    echo "  list              List installed"
    echo "  search <query>    Search apps"
    echo "  info <app>        App info"
    echo "  clean             Clean unused"
    echo "  help              Show this help"
}

check_flatpak

case "$1" in
    install) install_flatpak ;;
    app-install) install_app "$2" ;;
    app-remove) remove_app "$2" ;;
    update) update_all ;;
    list|ls) list_installed ;;
    search) search_apps "$2" ;;
    info) app_info "$2" ;;
    clean) clean_unused ;;
    *) show_help ;;
esac

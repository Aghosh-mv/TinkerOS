#!/bin/bash
# TinkerOS GRUB Theme - Boot screen themes

set -e

GRUB_DIR="$HOME/.tinker/grub-theme"
THEMES_DIR="$GRUB_DIR/themes"
CONFIG_FILE="$GRUB_DIR/config.conf"

mkdir -p "$GRUB_DIR" "$THEMES_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# GRUB Theme Configuration
ENABLED=true
DEFAULT_THEME=tinkeros
TIMEOUT=5
EOF
    fi
}

# List GRUB themes
list_themes() {
    echo "Available GRUB Themes:"
    echo ""
    
    ls /usr/share/grub/themes/ 2>/dev/null || echo "No themes found"
    
    echo ""
    echo "Popular themes to install:"
    echo "  - TinkerOS (default)"
    echo "  - Vimix"
    echo "  - Polydark"
    echo "  - Stylish"
}

# Set GRUB theme
set_theme() {
    local theme=$1
    
    echo "Setting GRUB theme: $theme"
    
    sudo sed -i "s/^GRUB_THEME=.*/GRUB_THEME=\"\/usr\/share\/grub\/themes\/$theme\/theme.txt\"/" /etc/default/grub
    
    sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg
    
    echo "GRUB theme set: $theme"
}

# Install GRUB theme
install_theme() {
    local name=$1
    local url=$2
    
    echo "Installing GRUB theme: $name"
    
    cd /tmp
    git clone "$url" 2>/dev/null || wget -q "$url" -O "$name.tar.gz" && tar xf "$name.tar.gz"
    
    cd "$name"
    sudo ./install.sh 2>/dev/null || sudo cp -r theme /usr/share/grub/themes/"$name"
    
    cd -
    echo "Installed: $name"
}

# Set timeout
set_timeout() {
    local timeout=${1:-5}
    
    echo "Setting GRUB timeout: $timeout seconds"
    
    sudo sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$timeout/" /etc/default/grub
    
    sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg
    
    echo "Timeout set: $timeout seconds"
}

show_help() {
    echo "Usage: tinker-grub-theme [command]"
    echo ""
    echo "Commands:"
    echo "  list              List GRUB themes"
    echo "  set <theme>       Set GRUB theme"
    echo "  install <name> <url> Install theme"
    echo "  timeout [seconds] Set GRUB timeout"
    echo "  help              Show this help"
}

init

case "$1" in
    list|ls) list_themes ;;
    set|apply) set_theme "$2" ;;
    install) install_theme "$2" "$3" ;;
    timeout) set_timeout "$2" ;;
    *) show_help ;;
esac

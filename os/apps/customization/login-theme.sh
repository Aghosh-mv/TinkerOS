#!/bin/bash
# TinkerOS Login Theme - Display manager themes

set -e

LOGIN_DIR="$HOME/.tinker/login-theme"
CONFIG_FILE="$LOGIN_DIR/config.conf"

mkdir -p "$LOGIN_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Login Theme Configuration
ENABLED=true
DEFAULT_THEME=tinkeros
EOF
    fi
}

# Check display manager
check_dm() {
    echo "Display Manager:"
    echo ""
    
    if [ -f /etc/X11/default-display-manager ]; then
        cat /etc/X11/default-display-manager
    elif command -v systemctl >/dev/null 2>&1; then
        systemctl status display-manager 2>/dev/null | head -3
    fi
}

# List login themes
list_themes() {
    echo "Available Login Themes:"
    echo ""
    
    # LightDM
    if [ -d /usr/share/lightdm/themes ]; then
        echo "LightDM themes:"
        ls /usr/share/lightdm/themes/ 2>/dev/null
    fi
    
    # GDM
    if [ -d /usr/share/gdm/themes ]; then
        echo "GDM themes:"
        ls /usr/share/gdm/themes/ 2>/dev/null
    fi
}

# Set LightDM theme
set_lightdm() {
    local theme=$1
    
    echo "Setting LightDM theme: $theme"
    
    sudo sed -i "s/^greeter-session=.*/greeter-session=$theme/" /etc/lightdm/lightdm.conf 2>/dev/null || true
    
    echo "Restart lightdm to apply"
}

show_help() {
    echo "Usage: tinker-login-theme [command]"
    echo ""
    echo "Commands:"
    echo "  check             Check display manager"
    echo "  list              List login themes"
    echo "  set <theme>       Set login theme"
    echo "  help              Show this help"
}

init

case "$1" in
    check|dm) check_dm ;;
    list|ls) list_themes ;;
    set|apply) set_lightdm "$2" ;;
    *) show_help ;;
esac

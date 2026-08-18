#!/bin/bash
# TinkerOS Command Palette - VS Code-like command palette

set -e

PALETTE_DIR="$HOME/.tinker/palette"
COMMANDS_FILE="$PALETTE_DIR/commands.txt"

mkdir -p "$PALETTE_DIR"

# Initialize commands
init_commands() {
    if [ ! -f "$COMMANDS_FILE" ]; then
        cat > "$COMMANDS_FILE" << 'EOF'
Settings:settings-gui.sh
Terminal:xdg-open xterm
File Manager:thunar
Screenshot:screenshot-tool.sh
System Monitor:gnome-system-monitor
Task Manager:htop
Network:nm-connection-editor
Bluetooth:blueman
Sound:pavucontrol
Display:gnome-display-properties
Power:gnome-power-statistics
Users:gnome-user-accounts-panel
Date:gnome-date-time-panel
Region:gnome-region-panel
Keyboard:gnome-keyboard-panel
Mouse:gnome-mouse-panel
Accessibility:gnome-accessibility-panel
Privacy:gnome-privacy-panel
Online Accounts:gnome-online-accounts-panel
Color:gnome-color-panel
Sound Settings:gnome-sound-panel
EOF
    fi
}

# Show palette
show_palette() {
    init_commands
    
    echo "Command Palette"
    echo ""
    
    if command -v fzf >/dev/null 2>&1; then
        cat "$COMMANDS_FILE" | fzf --prompt="Search: " | cut -d: -f2 | xargs -I {} bash -c '{}'
    else
        echo "Install fzf for interactive mode: sudo apt install fzf"
        echo ""
        echo "Available commands:"
        cat "$COMMANDS_FILE" | cut -d: -f1
    fi
}

# Add command
add_command() {
    local name=$1
    local cmd=$2
    
    echo "$name:$cmd" >> "$COMMANDS_FILE"
    echo "Added: $name"
}

# Remove command
remove_command() {
    local name=$1
    
    sed -i "/^$name:/d" "$COMMANDS_FILE"
    echo "Removed: $name"
}

# List commands
list_commands() {
    echo "Available Commands:"
    echo ""
    cat "$COMMANDS_FILE" | while IFS=: read -r name cmd; do
        echo "  $name"
    done
}

show_help() {
    echo "Usage: tinker-palette [command]"
    echo ""
    echo "Commands:"
    echo "  show              Show command palette"
    echo "  add <name> <cmd>  Add command"
    echo "  remove <name>     Remove command"
    echo "  list              List commands"
    echo "  help              Show this help"
}

case "$1" in
    show|open) show_palette ;;
    add) add_command "$2" "$3" ;;
    remove|rm) remove_command "$2" ;;
    list) list_commands ;;
    *) show_help ;;
esac

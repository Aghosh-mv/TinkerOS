#!/bin/bash
# TinkerOS Quick Actions - Custom quick actions

set -e

ACTIONS_DIR="$HOME/.tinker/quick-actions"
ACTIONS_FILE="$ACTIONS_DIR/actions.conf"

mkdir -p "$ACTIONS_DIR"

init() {
    if [ ! -f "$ACTIONS_FILE" ]; then
        cat > "$ACTIONS_FILE" << 'EOF'
# Quick Actions Configuration
# Format: name:command:icon

wifi-toggle:nmcli radio wifi toggle:network-wireless
bluetooth-toggle:bluetoothctl power toggle:bluetooth
night-mode:night-mode.sh toggle:night-light
dnd-toggle:notification-center.sh dnd:preferences-system-notifications
screenshot:screenshot-tool.sh full:camera-photo
terminal:xdg-open xterm:utilities-terminal
file-manager:thunar:system-file-manager
settings:gnome-control-center:preferences-system
lock:xdg-screensaver lock:system-lock-screen
logout:gnome-session-logout:system-log-out
reboot:systemctl reboot:system-reboot
shutdown:systemctl poweroff:system-shutdown
EOF
    fi
}

# Show actions
show_actions() {
    init
    
    echo "Quick Actions:"
    echo ""
    
    while IFS=: read -r name cmd icon; do
        [[ "$name" =~ ^# ]] && continue
        echo "  [$name] $cmd"
    done < "$ACTIONS_FILE"
}

# Run action
run_action() {
    local name=$1
    
    init
    
    local cmd=$(grep "^$name:" "$ACTIONS_FILE" | cut -d: -f2)
    
    if [ -n "$cmd" ]; then
        echo "Running: $name"
        eval "$cmd"
    else
        echo "Unknown action: $name"
    fi
}

# Add action
add_action() {
    local name=$1
    local cmd=$2
    local icon=${3:-applications-system}
    
    echo "$name:$cmd:$icon" >> "$ACTIONS_FILE"
    echo "Added action: $name"
}

# Remove action
remove_action() {
    local name=$1
    
    sed -i "/^$name:/d" "$ACTIONS_FILE"
    echo "Removed action: $name"
}

show_help() {
    echo "Usage: tinker-actions [command]"
    echo ""
    echo "Commands:"
    echo "  show              Show all actions"
    echo "  run <name>        Run action"
    echo "  add <name> <cmd> [icon] Add action"
    echo "  remove <name>     Remove action"
    echo "  help              Show this help"
}

case "$1" in
    show|list) show_actions ;;
    run|execute) run_action "$2" ;;
    add) add_action "$2" "$3" "$4" ;;
    remove|rm) remove_action "$2" ;;
    *) show_help ;;
esac

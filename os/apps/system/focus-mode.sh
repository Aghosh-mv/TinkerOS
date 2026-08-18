#!/bin/bash
# TinkerOS Focus Mode - Block distractions

set -e

FOCUS_DIR="$HOME/.tinker/focus"
CONFIG_FILE="$FOCUS_DIR/config.conf"
BLOCKED_FILE="$FOCUS_DIR/blocked.txt"

mkdir -p "$FOCUS_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Focus Mode Configuration
ENABLED=false
FOCUS_DURATION=25
BREAK_DURATION=5
BLOCK_NOTIFICATIONS=true
BLOCK_WEBSITES=true
EOF
    fi
    
    [ ! -f "$BLOCKED_FILE" ] && cat > "$BLOCKED_FILE" << 'EOF'
facebook.com
twitter.com
instagram.com
reddit.com
youtube.com
tiktok.com
EOF
}

# Start focus session
start() {
    local duration=${1:-25}
    
    echo "Starting focus session: ${duration} minutes"
    echo ""
    
    # Block notifications
    if [ "$(grep "BLOCK_NOTIFICATIONS" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
        gsettings set org.gnome.desktop.notifications show-banners false 2>/dev/null || true
        echo "Notifications blocked"
    fi
    
    # Block websites
    if [ "$(grep "BLOCK_WEBSITES" "$CONFIG_FILE" | cut -d= -f2)" = "true" ]; then
        echo "Websites blocked: facebook.com twitter.com instagram.com reddit.com youtube.com tiktok.com"
    fi
    
    echo "Focus session of ${duration} minutes started. Press Ctrl+C to end early."
    sleep $((duration * 60))
    echo "Focus session complete."
    
    # Reset settings
    gsettings set org.gnome.desktop.notifications show-banners true 2>/dev/null || true
}

# Main
if [ "${1:-}" = "start" ]; then
    init
    start "$2"
else
    echo "Usage: $0 start [duration_minutes]"
    echo "      $0 --help for more info"
fi

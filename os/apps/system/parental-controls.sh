#!/bin/bash
# TinkerOS Parental Controls - Content/time restrictions

set -e

PARENT_DIR="$HOME/.tinker/parental"
CONFIG_FILE="$PARENT_DIR/config.conf"
BLOCKED_FILE="$PARENT_DIR/blocked.txt"

mkdir -p "$PARENT_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Parental Controls Configuration
ENABLED=false
TIME_LIMIT=120
BEDTIME_START=22:00
BEDTIME_END=07:00
BLOCK_ADULT=true
EOF
    fi
    
    [ ! -f "$BLOCKED_FILE" ] && touch "$BLOCKED_FILE"
}

# Block website
block_site() {
    local site=$1
    
    echo "$site" >> "$BLOCKED_FILE"
    echo "Blocked: $site"
}

# Set time limit
set_time_limit() {
    local minutes=$1
    
    echo "$minutes" > "$PARENT_DIR/time-limit.txt"
    echo "Daily limit set: $minutes minutes"
}

# Set bedtime
set_bedtime() {
    local start=$1
    local end=$2
    
    echo "Bedtime: $start to $end"
    echo "$start" > "$PARENT_DIR/bedtime-start.txt"
    echo "$end" > "$PARENT_DIR/bedtime-end.txt"
}

# Check bedtime
check_bedtime() {
    if [ -f "$PARENT_DIR/bedtime-start.txt" ]; then
        local start=$(cat "$PARENT_DIR/bedtime-start.txt")
        local end=$(cat "$PARENT_DIR/bedtime-end.txt")
        local now=$(date +%H:%M)
        
        if [[ "$now" > "$start" ]] || [[ "$now" < "$end" ]]; then
            echo "BEDTIME ACTIVE - Computer should be off!"
            notify-send -u critical "Bedtime" "Computer should be off!" 2>/dev/null || true
        fi
    fi
}

# Enable/disable
enable() {
    echo "Parental Controls: ENABLED"
    echo "true" > "$PARENT_DIR/enabled.txt"
}

disable() {
    echo "Parental Controls: DISABLED"
    echo "false" > "$PARENT_DIR/enabled.txt"
}

show_help() {
    echo "Usage: tinker-parental [command]"
    echo ""
    echo "Commands:"
    echo "  block <site>      Block website"
    echo "  time-limit [min]  Set/check time limit"
    echo "  bedtime [start] [end] Set bedtime"
    echo "  check             Check bedtime"
    echo "  enable            Enable controls"
    echo "  disable           Disable controls"
    echo "  help              Show this help"
}

init

case "$1" in
    block) block_site "$2" ;;
    time-limit|time) 
        if [ -n "$2" ]; then
            set_time_limit "$2"
        else
            cat "$PARENT_DIR/time-limit.txt" 2>/dev/null || echo "No limit set"
        fi
        ;;
    bedtime) set_bedtime "$2" "$3" ;;
    check) check_bedtime ;;
    enable) enable ;;
    disable) disable ;;
    *) show_help ;;
esac

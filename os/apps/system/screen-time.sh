#!/bin/bash
# TinkerOS Screen Time - Usage statistics

set -e

SCREEN_DIR="$HOME/.tinker/screen-time"
LOG_FILE="$SCREEN_DIR/usage.log"

mkdir -p "$SCREEN_DIR"

init() {
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Log screen time
log_usage() {
    echo "$(date +%s)|active" >> "$LOG_FILE"
}

# Show today's usage
today() {
    local date=$(date +%Y-%m-%d)
    local minutes=$(grep "$date" "$LOG_FILE" | wc -l)
    
    echo "Screen Time Today: $minutes minutes"
}

# Show weekly usage
weekly() {
    echo "Weekly Screen Time:"
    echo ""
    
    for i in $(seq 6 -1 0); do
        local date=$(date -d "-$i days" +%Y-%m-%d)
        local minutes=$(grep "$date" "$LOG_FILE" | wc -l)
        local hours=$((minutes / 60))
        local mins=$((minutes % 60))
        echo "  $(date -d "-$i days" +%A): ${hours}h ${mins}m"
    done
}

# Set limit
set_limit() {
    local hours=$1
    
    echo "Setting daily limit: $hours hours"
    echo "$hours" > "$SCREEN_DIR/limit.txt"
}

# Check limit
check_limit() {
    if [ -f "$SCREEN_DIR/limit.txt" ]; then
        local limit=$(cat "$SCREEN_DIR/limit.txt")
        local today_min=$(grep "$(date +%Y-%m-%d)" "$LOG_FILE" | wc -l)
        local today_hours=$((today_min / 60))
        
        echo "Daily limit: $hours hours"
        echo "Today used: $today_hours hours"
        
        if [ $today_hours -ge $limit ]; then
            echo "LIMIT REACHED!"
        fi
    else
        echo "No limit set"
    fi
}

show_help() {
    echo "Usage: tinker-screen-time [command]"
    echo ""
    echo "Commands:"
    echo "  today             Show today's usage"
    echo "  weekly            Show weekly usage"
    echo "  limit [hours]     Set/check daily limit"
    echo "  help              Show this help"
}

init

case "$1" in
    today) today ;;
    weekly|week) weekly ;;
    limit) 
        if [ -n "$2" ]; then
            set_limit "$2"
        else
            check_limit
        fi
        ;;
    *) show_help ;;
esac

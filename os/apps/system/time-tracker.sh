#!/bin/bash
# TinkerOS Time Tracker - Track time per app

set -e

TRACK_DIR="$HOME/.tinker/time-tracker"
LOG_FILE="$TRACK_DIR/time.log"
CONFIG_FILE="$TRACK_DIR/config.conf"

mkdir -p "$TRACK_DIR"

init() {
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Time Tracker Configuration
ENABLED=true
AUTO_TRACK=true
REPORT_DAILY=true
EOF
    fi
}

# Start tracking
start_tracking() {
    local app=$1
    
    echo "Tracking: $app"
    
    while true; do
        echo "$(date +%s)|$app|$(xdotool getactivewindow getwindowname 2>/dev/null || echo unknown)" >> "$LOG_FILE"
        sleep 60
    done
}

# Show daily summary
daily() {
    local date=${1:-$(date +%Y-%m-%d)}
    
    echo "Time Summary for $date:"
    echo ""
    
    grep "$date" "$LOG_FILE" | awk -F'|' '{print $2}' | sort | uniq -c | sort -rn | head -20 | \
        awk '{printf "  %-20s %d minutes\n", $2, $1}'
}

# Show weekly summary
weekly() {
    echo "Weekly Summary:"
    echo ""
    
    for i in $(seq 6 -1 0); do
        local date=$(date -d "-$i days" +%Y-%m-%d)
        local total=$(grep "$date" "$LOG_FILE" | wc -l)
        echo "  $date: $total minutes tracked"
    done
}

# Export data
export_data() {
    local format=${1:-csv}
    
    case $format in
        csv)
            echo "Timestamp,Application,Window" > "$TRACK_DIR/export.csv"
            cat "$LOG_FILE" >> "$TRACK_DIR/export.csv"
            echo "Exported to: $TRACK_DIR/export.csv"
            ;;
        json)
            echo "[$(sed 's/|/","/g' "$LOG_FILE" | sed 's/^/{"ts":"/' | sed 's/$/"},/')]"> "$TRACK_DIR/export.json"
            echo "Exported to: $TRACK_DIR/export.json"
            ;;
    esac
}

show_help() {
    echo "Usage: tinker-time [command]"
    echo ""
    echo "Commands:"
    echo "  start             Start tracking"
    echo "  daily [date]      Show daily summary"
    echo "  weekly            Show weekly summary"
    echo "  export [format]   Export data (csv/json)"
    echo "  help              Show this help"
}

init

case "$1" in
    start|track) start_tracking "$2" ;;
    daily|today) daily "$2" ;;
    weekly|week) weekly ;;
    export) export_data "$2" ;;
    *) show_help ;;
esac

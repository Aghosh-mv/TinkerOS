#!/bin/bash
# TinkerOS Pomodoro Timer - Work/break timer

set -e

POMO_DIR="$HOME/.tinker/pomodoro"
CONFIG_FILE="$POMO_DIR/config.conf"

mkdir -p "$POMO_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Pomodoro Timer Configuration
WORK_DURATION=25
SHORT_BREAK=5
LONG_BREAK=15
SESSIONS_BEFORE_LONG=4
NOTIFICATIONS=true
EOF
    fi
}

# Start pomodoro
start() {
    local work=${1:-25}
    local short=${2:-5}
    local long=${3:-15}
    local sessions=${4:-4}
    
    echo "Starting Pomodoro Timer"
    echo ""
    
    local count=0
    
    while true; do
        count=$((count + 1))
        
        # Work session
        echo "Session $count: WORK for $work minutes"
        notify-send "Pomodoro" "Work session $count started!" 2>/dev/null || true
        sleep $((work * 60))
        notify-send "Pomodoro" "Work session complete!" 2>/dev/null || true
        
        # Break
        if [ $((count % sessions)) -eq 0 ]; then
            echo "LONG BREAK: $long minutes"
            notify-send "Pomodoro" "Long break time!" 2>/dev/null || true
            sleep $((long * 60))
        else
            echo "SHORT BREAK: $short minutes"
            notify-send "Pomodoro" "Short break time!" 2>/dev/null || true
            sleep $((short * 60))
        fi
        
        echo ""
        echo "Next session? (Ctrl+C to stop)"
    done
}

# Quick timer
quick() {
    local minutes=${1:-25}
    
    echo "Timer: $minutes minutes"
    echo ""
    
    notify-send "Timer" "Starting $minutes minute timer" 2>/dev/null || true
    sleep $((minutes * 60))
    notify-send "Timer" "Time's up!" 2>/dev/null || true
    echo "TIME'S UP!"
}

show_help() {
    echo "Usage: tinker-pomodoro [command]"
    echo ""
    echo "Commands:"
    echo "  start [work] [short] [long] [sessions]"
    echo "  quick [minutes]   Quick timer"
    echo "  help              Show this help"
}

init

case "$1" in
    start|work) start "$2" "$3" "$4" "$5" ;;
    quick|timer) quick "$2" ;;
    *) show_help ;;
esac

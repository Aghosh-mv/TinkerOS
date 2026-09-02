#!/bin/bash
# TinkerOS Voice Engine
# Hybrid: Rules + Fuzzy + Context

set -e

# Action definitions
declare -A ACTIONS=(
    ["open_browser"]="xdg-open https://www.google.com &"
    ["open_terminal"]="gnome-terminal &"
    ["open_files"]="xdg-open ~ &"
    ["open_settings"]="gnome-control-center &"
    ["screenshot"]="import -window root ~/Pictures/ss-\$(date +%s).png"
    ["lock_screen"]="i3lock -c 2e3440"
    ["volume_up"]="pactl set-sink-volume @DEFAULT_SINK@ +10%"
    ["volume_down"]="pactl set-sink-volume @DEFAULT_SINK@ -10%"
    ["volume_mute"]="pactl set-sink-mute @DEFAULT_SINK@ toggle"
    ["play_music"]="spotify &"
    ["pause_music"]="xdotool key space"
    ["next_track"]="xdotool key XF86AudioNext"
    ["prev_track"]="xdotool key XF86AudioPrev"
    ["gaming_on"]="/usr/lib/tinker/gaming-mode.sh enable"
    ["gaming_off"]="/usr/lib/tinker/gaming-mode.sh disable"
    ["shutdown"]="sudo shutdown -h 1"
    ["reboot"]="sudo reboot"
    ["lock"]="i3lock -c 2e3440"
    ["logout"]="gnome-session-quit"
    ["suspend"]="systemctl suspend"
)

# Patterns with weights (higher = more important)
declare -a PATTERNS=(
    # Browser (weight 10)
    "10:open.*browser|start.*browser|launch.*browser|firefox|chrome|chromium|browse.*web|internet|go.*online"
    # Terminal (weight 10)
    "10:open.*terminal|start.*terminal|terminal|command.*line|console|bash|shell|prompt"
    # Files (weight 10)
    "10:open.*file|file.*manager|my.*files|nautilus|thunar|dolphin|explorer|folder|documents"
    # Screenshot (weight 10)
    "10:screenshot|capture.*screen|take.*picture|screen.*capture|grab.*screen|snapshot"
    # Lock (weight 10)
    "10:lock.*screen|lock.*computer|lock.*machine|lock.*desktop|lock.*laptop|lock"
    # Volume up (weight 8)
    "8:volume.*up|turn.*up|louder|increase.*volume|more.*volume|sound.*up|boost"
    # Volume down (weight 8)
    "8:volume.*down|turn.*down|quieter|decrease.*volume|less.*volume|sound.*down|lower"
    # Mute (weight 8)
    "8:mute|silence|toggle.*sound|toggle.*mute|unmute|quiet"
    # Time (weight 9)
    "9:what.*time|current.*time|time.*is.*it|tell.*time|time.*please|clock|what.*hour"
    # Date (weight 9)
    "9:what.*date|today|what.*day|current.*date|what.*today|day.*is.*it"
    # Weather (weight 7)
    "7:weather|temperature|outside|forecast|raining|sunny|cold|hot|climate"
    # Music play (weight 8)
    "8:play.*music|start.*music|music.*please|listen|spotify|play.*song|play.*tune|music"
    # Music pause (weight 8)
    "8:pause|stop.*music|stop.*playing|pause.*music|hold.*music|stop"
    # Next track (weight 8)
    "8:next.*track|next.*song|skip|next.*please|skip.*track|next"
    # Prev track (weight 8)
    "8:previous.*track|previous.*song|go.*back|last.*track|previous|back"
    # Gaming on (weight 7)
    "7:gaming.*mode.*on|enable.*gaming|start.*gaming|game.*mode.*on|game|gaming"
    # Gaming off (weight 7)
    "7:gaming.*mode.*off|disable.*gaming|stop.*gaming|game.*mode.*off|done.*gaming|normal"
    # Password (weight 6)
    "6:generate.*password|create.*password|make.*password|need.*password|password|new.*pass"
    # Shutdown (weight 9)
    "9:shutdown|turn.*off|shut.*down|power.*off|leaving|bye|goodbye"
    # Reboot (weight 9)
    "9:reboot|restart|restart.*computer|reboot.*computer|reset"
    # Help (weight 5)
    "5:help|what.*can.*you.*do|commands|capabilities|how.*does.*this|info|manual"
)

ACTION_NAMES=(
    "open_browser"
    "open_terminal"
    "open_files"
    "open_settings"
    "screenshot"
    "lock_screen"
    "volume_up"
    "volume_down"
    "volume_mute"
    "what_time"
    "what_date"
    "weather"
    "play_music"
    "pause_music"
    "next_track"
    "prev_track"
    "gaming_on"
    "gaming_off"
    "generate_password"
    "shutdown"
    "reboot"
    "help"
)

# Fuzzy match score
fuzzy_score() {
    local input="$1"
    local pattern="$2"
    local score=0
    
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # Exact match
    if echo "$input" | grep -qE "$pattern"; then
        score=100
    fi
    
    # Word match
    for word in $input; do
        if echo "$word" | grep -qE "$pattern"; then
            score=$((score + 50))
        fi
    done
    
    # Partial match
    IFS='|' read -ra patterns <<< "$pattern"
    for p in "${patterns[@]}"; do
        if [[ "$input" == *"$p"* ]]; then
            score=$((score + 30))
        fi
    done
    
    echo $score
}

# Process command
process_command() {
    local input="$1"
    local best_score=0
    local best_action=""
    
    local i=0
    for pattern_entry in "${PATTERNS[@]}"; do
        local weight=$(echo "$pattern_entry" | cut -d: -f1)
        local pattern=$(echo "$pattern_entry" | cut -d: -f2-)
        
        local score=$(fuzzy_score "$input" "$pattern")
        local weighted_score=$((score * weight / 10))
        
        if [ $weighted_score -gt $best_score ]; then
            best_score=$weighted_score
            best_action="${ACTION_NAMES[$i]}"
        fi
        
        i=$((i + 1))
    done
    
    # Threshold
    if [ $best_score -lt 20 ]; then
        echo "I didn't understand. Say 'help' for commands."
        return 1
    fi
    
    # Execute
    case $best_action in
        "what_time")
            echo "$(date '+%I:%M %p')"
            ;;
        "what_date")
            echo "$(date '+%A, %B %d, %Y')"
            ;;
        "weather")
            curl -s "wttr.in?format=%C %t %h %w" 2>/dev/null
            ;;
        "generate_password")
            pass=$(tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 20)
            echo "$pass" | xclip -selection clipboard
            echo "Password copied to clipboard"
            ;;
        "help")
            echo "Commands: open browser/terminal/files, screenshot, lock, volume, time, date, weather, music, gaming, password, shutdown, reboot"
            ;;
        *)
            if [ -n "${ACTIONS[$best_action]}" ]; then
                eval "${ACTIONS[$best_action]}"
                echo "Done: $best_action"
            fi
            ;;
    esac
}

# Main
case "$1" in
    --text|-t)
        shift
        process_command "$*"
        ;;
    --interactive|-i)
        echo "TinkerOS Voice (say 'quit' to exit)"
        while true; do
            read -p "> " input
            [ "$input" = "quit" ] && break
            [ -n "$input" ] && process_command "$input"
        done
        ;;
    *)
        echo "Usage: voice-engine.sh --text 'command' | --interactive"
        ;;
esac

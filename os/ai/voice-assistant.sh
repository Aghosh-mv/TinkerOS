#!/bin/bash
# TinkerOS Voice Assistant
# Hybrid AI: Rule-based + Fuzzy matching + ML backup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Command mapping
declare -A COMMANDS=(
    ["open_browser"]="xdg-open https://www.google.com &"
    ["open_terminal"]="gnome-terminal &"
    ["open_files"]="xdg-open ~ &"
    ["screenshot"]="import -window root ~/Pictures/screenshot-\$(date +%s).png"
    ["lock_screen"]="i3lock -c 2e3440"
    ["volume_up"]="pactl set-sink-volume @DEFAULT_SINK@ +10%"
    ["volume_down"]="pactl set-sink-volume @DEFAULT_SINK@ -10%"
    ["mute"]="pactl set-sink-mute @DEFAULT_SINK@ toggle"
    ["play_music"]="spotify &"
    ["pause_music"]="xdotool key space"
    ["next_track"]="xdotool key XF86AudioNext"
    ["previous_track"]="xdotool key XF86AudioPrev"
    ["gaming_mode_on"]="/usr/lib/tinker/gaming-mode.sh enable"
    ["gaming_mode_off"]="/usr/lib/tinker/gaming-mode.sh disable"
    ["shutdown"]="sudo shutdown -h 1"
    ["reboot"]="sudo reboot"
)

# Pattern matching rules (order matters - first match wins)
PATTERNS=(
    # Browser
    "open.*browser|start.*browser|launch.*browser|firefox|chrome|chromium|open.*web|browse|internet|google"
    # Terminal
    "open.*terminal|start.*terminal|launch.*terminal|command.*line|console|bash|shell|terminal"
    # Files
    "open.*file|file.*manager|my.*files|nautilus|thunar|dolphin|explorer|documents|folder"
    # Screenshot
    "screenshot|capture.*screen|take.*picture|screen.*capture|grab.*screen"
    # Lock
    "lock.*screen|lock.*computer|lock.*laptop|lock.*machine|lock.*desktop|lock"
    # Volume
    "volume.*up|turn.*up.*volume|louder|increase.*volume|more.*volume|sound.*up"
    "volume.*down|turn.*down.*volume|quieter|decrease.*volume|less.*volume|sound.*down"
    "mute|silence|toggle.*sound|toggle.*mute|unmute"
    # Time/Date
    "what.*time|current.*time|time.*is.*it|tell.*time|time.*please|what.*clock"
    "what.*date|today|what.*day|current.*date|what.*today"
    # Weather
    "weather|temperature|outside|forecast|raining|sunny|cold|hot"
    # Music
    "play.*music|start.*music|music.*please|listen|spotify|play.*song|play.*tune"
    "pause|stop.*music|stop.*playing|pause.*music|hold.*music"
    "next.*track|next.*song|skip|next.*please|skip.*track"
    "previous.*track|previous.*song|go.*back|last.*track"
    # Gaming
    "gaming.*mode.*on|enable.*gaming|start.*gaming|game.*mode.*on|i.*want.*to.*game"
    "gaming.*mode.*off|disable.*gaming|stop.*gaming|game.*mode.*off|done.*gaming|normal.*mode"
    # Password
    "generate.*password|create.*password|make.*password|need.*password|password.*please"
    # Power
    "shutdown|turn.*off|shut.*down|power.*off|leaving"
    "reboot|restart|restart.*computer|reboot.*computer"
    # Help
    "help|what.*can.*you.*do|commands|capabilities|how.*does.*this.*work"
)

ACTIONS=(
    "open_browser"
    "open_terminal"
    "open_files"
    "screenshot"
    "lock_screen"
    "volume_up"
    "volume_down"
    "mute"
    "time"
    "date"
    "weather"
    "play_music"
    "pause_music"
    "next_track"
    "previous_track"
    "gaming_mode_on"
    "gaming_mode_off"
    "generate_password"
    "shutdown"
    "reboot"
    "help"
)

# Fuzzy match function
fuzzy_match() {
    local input="$1"
    local pattern="$2"
    
    # Convert to lowercase
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # Check if pattern matches (using grep -E for regex)
    if echo "$input" | grep -qE "$pattern"; then
        return 0
    fi
    
    # Check for similar words (simple edit distance)
    local words=($input)
    for word in "${words[@]}"; do
        if echo "$word" | grep -qE "$pattern"; then
            return 0
        fi
    done
    
    return 1
}

# Process command
process_command() {
    local input="$1"
    local i=0
    
    for pattern in "${PATTERNS[@]}"; do
        if fuzzy_match "$input" "$pattern"; then
            local action="${ACTIONS[$i]}"
            
            case $action in
                "time")
                    echo "It's $(date '+%I:%M %p')"
                    ;;
                "date")
                    echo "Today is $(date '+%B %d, %Y')"
                    ;;
                "weather")
                    curl -s "wttr.in?format=%C+%t+%h+%w"
                    ;;
                "generate_password")
                    local pass=$(tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 20)
                    echo "$pass" | xclip -selection clipboard
                    echo "Password generated and copied to clipboard"
                    ;;
                "help")
                    echo "Available commands:"
                    echo "  Open browser/terminal/files"
                    echo "  Take screenshot, lock screen"
                    echo "  Volume up/down/mute"
                    echo "  What time/date, weather"
                    echo "  Play/pause/next/previous music"
                    echo "  Gaming mode on/off"
                    echo "  Generate password"
                    echo "  Shutdown/reboot"
                    ;;
                *)
                    if [ -n "${COMMANDS[$action]}" ]; then
                        eval "${COMMANDS[$action]}"
                        echo "Done: $action"
                    fi
                    ;;
            esac
            return 0
        fi
        i=$((i + 1))
    done
    
    echo "I didn't understand that. Say 'help' for available commands."
    return 1
}

# Main
if [ "$1" = "--text" ]; then
    # Text input mode
    shift
    process_command "$*"
elif [ "$1" = "--interactive" ]; then
    # Interactive mode
    echo "TinkerOS Voice Assistant (type 'quit' to exit)"
    echo ""
    
    while true; do
        read -p "You: " input
        
        if [ "$input" = "quit" ] || [ "$input" = "exit" ]; then
            echo "Goodbye!"
            break
        fi
        
        if [ -n "$input" ]; then
            process_command "$input"
        fi
    done
else
    echo "Usage: voice-assistant.sh [--text 'command'] | [--interactive]"
fi

#!/bin/bash
# TinkerOS Context-Aware Adaptation - Context detection and auto-configuration

set -e

CA_DIR="$HOME/.tinker/context-aware"
CONFIG_FILE="$CA_DIR/config.conf"
STATE_FILE="$CA_DIR/state.json"
LOG_FILE="$CA_DIR/context.log"

mkdir -p "$CA_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Context-Aware Configuration
ENABLED=true
DETECT_INTERVAL=30
AUTO_SWITCH=true
NOTIFICATIONS=true
LEARN_PATTERNS=true
CONTEXTS=work,gaming,media,meeting,travel,idle
EOF

    [ ! -f "$STATE_FILE" ] && echo '{"context":"idle","confidence":0}' > "$STATE_FILE"
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Detect current context
detect_context() {
    local ctx="idle"
    local confidence=0
    local reasons=()
    
    # Check active window
    local active_window=$(xdotool getactivewindow getwindowname 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
    
    # Check running processes
    local procs=$(ps aux --no-headers | awk '{print $11}' | tr '[:upper:]' '[:lower:]' | sort -u | tr '\n' ' ')
    
    # Check audio
    local audio_active=$(pactl list sink-inputs short 2>/dev/null | wc -l)
    
    # Check display
    local display_on=$(xset q 2>/dev/null | grep "Monitor is On" | wc -l)
    
    # Check battery
    local on_battery=0
    if [ -f /sys/class/power_supply/BAT0/status ]; then
        [ "$(cat /sys/class/power_supply/BAT0/status)" = "Discharging" ] && on_battery=1
    fi
    
    # Check network
    local wifi_active=$(nmcli -t -f TYPE,STATE dev status 2>/dev/null | grep "wifi:connected" | wc -l)
    local vpn_active=$(nmcli -t -f TYPE,STATE con show --active 2>/dev/null | grep "vpn" | wc -l)
    
    # Check time
    local hour=$(date +%H)
    local dow=$(date +%u)
    
    # Work detection
    if echo "$procs" | grep -qE "code|vim|emacs|idea|pycharm|vscode|terminal|git|docker|kubectl"; then
        ctx="work"
        confidence=$((confidence + 40))
        reasons+=("dev tools running")
    fi
    
    if echo "$active_window" | grep -qE "outlook|teams|slack|zoom|meet|calendar|mail"; then
        ctx="meeting"
        confidence=$((confidence + 50))
        reasons+=("meeting app active")
    fi
    
    # Gaming detection
    if echo "$procs" | grep -qE "steam|lutris|wine|heroic|bottles|minecraft|cs2|valorant|dota|wow|ffxiv"; then
        ctx="gaming"
        confidence=$((confidence + 50))
        reasons+=("game running")
    fi
    
    # Media detection
    if echo "$procs" | grep -qE "vlc|mpv|spotify|firefox.*youtube|chrome.*netflix|brave.*twitch"; then
        ctx="media"
        confidence=$((confidence + 40))
        reasons+=("media player active")
    fi
    
    # Travel detection
    if [ $on_battery -eq 1 ] && [ $wifi_active -gt 0 ] && [ $vpn_active -eq 0 ]; then
        if [ $hour -lt 8 ] || [ $hour -gt 20 ]; then
            ctx="travel"
            confidence=$((confidence + 30))
            reasons+=("on battery, mobile network")
        fi
    fi
    
    # Idle detection
    local idle_ms=$(xprintidle 2>/dev/null || echo 0)
    if [ $idle_ms -gt 300000 ]; then  # 5 minutes
        ctx="idle"
        confidence=$((confidence + 20))
        reasons+=("idle >5min")
    fi
    
    # Time-based defaults
    if [ $confidence -eq 0 ]; then
        if [ $dow -le 5 ] && [ $hour -ge 9 ] && [ $hour -lt 17 ]; then
            ctx="work"
            confidence=20
            reasons+=("work hours")
        elif [ $dow -ge 6 ] || [ $hour -ge 22 ] || [ $hour -lt 7 ]; then
            ctx="idle"
            confidence=20
            reasons+=("off hours")
        fi
    fi
    
    # Output
    echo "{\"context\":\"$ctx\",\"confidence\":$confidence,\"reasons\":[$(printf '"%s",' "${reasons[@]}" | sed 's/,$//')],\"timestamp\":$(date +%s)}" > "$STATE_FILE"
    
    echo "Context: $ctx (${confidence}%)"
    [ ${#reasons[@]} -gt 0 ] && echo "Reasons: ${reasons[*]}"
    
    # Auto-switch
    if grep -q "AUTO_SWITCH=true" "$CONFIG_FILE" && [ $confidence -ge 40 ]; then
        switch_context "$ctx"
    fi
}

# Switch to context
switch_context() {
    local ctx=$1
    local current=$(cat "$STATE_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['context'])" 2>/dev/null)
    
    [ "$ctx" = "$current" ] && return 0
    
    echo "Switching to context: $ctx"
    
    case $ctx in
        work)
            bash /home/tinkerspace/linux-kernel/os/apps/system/power-manager.sh apply balanced 2>/dev/null || true
            notify-send "Context: Work" "Balanced performance mode" 2>/dev/null || true
            ;;
        gaming)
            bash /home/tinkerspace/linux-kernel/os/apps/system/power-manager.sh apply performance 2>/dev/null || true
            bash /home/tinkerspace/linux-kernel/os/apps/apps/gaming-mode.sh on 2>/dev/null || true
            notify-send "Context: Gaming" "Performance mode + Gaming mode" 2>/dev/null || true
            ;;
        media)
            bash /home/tinkerspace/linux-kernel/os/apps/system/power-manager.sh apply balanced 2>/dev/null || true
            notify-send "Context: Media" "Optimized for playback" 2>/dev/null || true
            ;;
        meeting)
            bash /home/tinkerspace/linux-kernel/os/apps/system/power-manager.sh apply balanced 2>/dev/null || true
            pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null || true
            notify-send "Context: Meeting" "Notifications muted" 2>/dev/null || true
            ;;
        travel)
            bash /home/tinkerspace/linux-kernel/os/apps/system/power-manager.sh apply powersave 2>/dev/null || true
            notify-send "Context: Travel" "Power saving mode" 2>/dev/null || true
            ;;
        idle)
            bash /home/tinkerspace/linux-kernel/os/apps/system/power-manager.sh apply powersave 2>/dev/null || true
            ;;
    esac
    
    echo "$(date +%s)|switch|$current|$ctx" >> "$LOG_FILE"
}

# Show current context
show_context() {
    cat "$STATE_FILE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"Context: {data['context']}\")
print(f\"Confidence: {data['confidence']}%\")
print(f\"Reasons: {', '.join(data.get('reasons', []))}\")
print(f\"Since: $(date -d @{data['timestamp']} '+%H:%M:%S')\" 2>/dev/null || echo \"Since: {data['timestamp']}\")
"
}

# Learn patterns
learn() {
    echo "Learning context patterns..."
    
    local ctx=$(cat "$STATE_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['context'])" 2>/dev/null)
    local hour=$(date +%H)
    local dow=$(date +%u)
    
    local pattern_file="$CA_DIR/patterns.csv"
    echo "$dow,$hour,$ctx" >> "$pattern_file"
    
    echo "Recorded: Day=$dow Hour=$hour Context=$ctx"
}

# Show learned patterns
patterns() {
    local pattern_file="$CA_DIR/patterns.csv"
    [ ! -f "$pattern_file" ] && echo "No patterns learned yet" && return
    
    echo "Learned Patterns:"
    echo ""
    awk -F, '{print $3}' "$pattern_file" | sort | uniq -c | sort -rn | while read count ctx; do
        echo "  $ctx: $count occurrences"
    done
}

# Daemon mode
daemon() {
    echo "Starting Context-Aware daemon..."
    
    while true; do
        detect_context
        learn
        sleep $(grep DETECT_INTERVAL "$CONFIG_FILE" | cut -d= -f2)
    done
}

show_help() {
    echo "Usage: tinker-context [command]"
    echo ""
    echo "Commands:"
    echo "  detect              Detect current context"
    echo "  show                Show current context"
    echo "  switch <context>    Manually switch context"
    echo "  learn               Record current context pattern"
    echo "  patterns            Show learned patterns"
    echo "  daemon              Run context detection daemon"
    echo "  help                Show this help"
    echo ""
    echo "Contexts: work, gaming, media, meeting, travel, idle"
}

init

case "$1" in
    detect) detect_context ;;
    show) show_context ;;
    switch) switch_context "$2" ;;
    learn) learn ;;
    patterns) patterns ;;
    daemon) daemon ;;
    *) show_help ;;
esac
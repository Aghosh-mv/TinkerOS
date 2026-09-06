#!/bin/bash
# TinkerOS FPS Monitor - Real-time frames-per-second and game performance tracking

set -e

FPS_DIR="$HOME/.tinker/fps"
CONFIG_FILE="$FPS_DIR/config.conf"
LOG_FILE="$FPS_DIR/fps.log"
mkdir -p "$FPS_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# FPS Monitor Configuration
SAMPLING_RATE=1
ENABLE_LOG=true
SHOW_CPU=true
SHOW_GPU=true
SHOW_TEMP=true
MONITOR_PROCESS=auto
EOF
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Run MangoHud monitor
mangohud() {
    echo "=== MangoHud FPS Monitor ==="
    echo ""
    if command -v mangohud &>/dev/null; then
        echo "  MangoHud installed. Configure in ~/.config/MangoHud/MangoHud.conf"
        echo "  Set fps_limit, vsync, and HUD layout there."
        echo "  Enable per-app: mangohud <game-command>"
    else
        echo "  MangoHud not installed."
        echo "  Install: sudo apt install mangohud"
    fi
    echo ""
    echo "  Config keys:"
    echo "    fps_limit=0            # 0 = uncapped"
    echo "    vsync=0                # 0 off / 1 on"
    echo "    hud_scale=1.0"
    echo "    [position] x=0 y=0"
}

# Monitor a running game process
monitor_process() {
    local process=${1:-$(pgrep -f -i "steam|wine|gamescope|hl2|csgo|dota" | head -1)}
    local interval=${2:-1}
    
    [ -z "$process" ] && { echo "No game process detected. Specify: $0 monitor <pid|name>"; return 1; }
    
    echo "=== Monitoring process: $process (Ctrl+C to stop) ==="
    echo ""
    
    local is_pid=0
    [[ "$process" =~ ^[0-9]+$ ]] && is_pid=1
    
    while true; do
        local pid=""
        if [ $is_pid -eq 1 ]; then pid=$process
        else pid=$(pgrep -x "$process" | head -1) || pid=$(pgrep -f "$process" | head -1)
        fi
        
        [ -z "$pid" ] && { echo "Process not found"; sleep $interval; continue; }
        
        local cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ')
        local mem=$(ps -p "$pid" -o %mem= 2>/dev/null | tr -d ' ')
        local threads=$(ls /proc/$pid/task 2>/dev/null | wc -l)
        local rss=$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ')
        local rss_mb=$((rss/1024))
        
        clear
        echo "=== Game Process Monitor $(date +%H:%M:%S) ==="
        echo ""
        printf "  CPU: %6s%%    Memory: %6s%%    Threads: %4d    RSS: %6d MB\n" "$cpu" "$mem" "$threads" "$rss_mb"
        
        # System load
        if grep -q SHOW_CPU "$CONFIG_FILE"; then
            local load=$(cat /proc/loadavg | awk '{print $1}')
            echo "  System load: $load"
        fi
        
        # Temperature
        if grep -q SHOW_TEMP "$CONFIG_FILE"; then
            local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
            [ "$temp" -gt 0 ] && echo "  CPU temp: $((temp/1000))°C"
        fi
        
        echo "$(date +%s)|$cpu|$mem|$threads" >> "$LOG_FILE" 2>/dev/null || true
        sleep $interval
    done
}

# Stress test FPS capability
stress_test() {
    local duration=${1:-30}
    echo "=== FPS Stress Test (${duration}s) ==="
    echo ""
    
    # Run a GPU stress test
    if command -v glmark2 &>/dev/null; then
        echo "Running glmark2 for $duration seconds..."
        glmark2 --run-forever 2>/dev/null &
        local gpid=$!
        sleep $duration
        kill $gpid 2>/dev/null
    elif command -v glxgears &>/dev/null; then
        echo "Running glxgears for $duration seconds..."
        glxgears -info 2>/dev/null &
        local gpid=$!
        sleep $duration
        local frames=$(kill $gpid 2>/dev/null; wait $gpid 2>/dev/null; echo 0)
    else
        echo "No GPU benchmark tool (install glmark2 or glxgears)"
        echo "  Try: sudo apt install glmark2"
    fi
    
    echo ""
    echo "Suggested tools for full testing:"
    echo "  glmark2  - full OpenGL benchmark"
    echo "  vkmark   - Vulkan benchmark"
    echo "  glxgears - OpenGL FPS counter"
}

# Compatibility check
compat() {
    echo "=== GPU Compatibility Check ==="
    echo ""
    echo "GPU Info:"
    lspci | grep -iE "vga|3d|display" | sed 's/^/  /' 2>/dev/null
    
    echo ""
    echo "Vulkan support:"
    if command -v vulkaninfo &>/dev/null; then
        vulkaninfo --summary 2>/dev/null | grep -iE "deviceName|apiVersion" | sed 's/^/  /' | head -5
    else
        echo "  vulkaninfo not installed (install vulkan-tools)"
    fi
    
    echo ""
    echo "OpenGL support:"
    if command -v glxinfo &>/dev/null; then
        glxinfo 2>/dev/null | grep -E "OpenGL version|OpenGL renderer" | sed 's/^/  /'
    else
        echo "  glxinfo not installed (install mesa-utils)"
    fi
}

# Log summary
summary() {
    echo "=== FPS/Performance Summary ==="
    echo ""
    if [ -s "$LOG_FILE" ]; then
        echo "  Records: $(wc -l < "$LOG_FILE")"
        echo "  Avg CPU: $(awk -F'|' '{s+=$2;n++} END {if(n) printf "%.1f%%", s/n}' "$LOG_FILE")"
        echo "  Max CPU: $(awk -F'|' '{if($2>m)m=$2} END {printf "%.1f%%", m}' "$LOG_FILE")"
    else
        echo "  No data yet. Run: $0 monitor"
    fi
}

show_help() {
    echo "Usage: tinker-fps [command]"
    echo ""
    echo "Commands:"
    echo "  mangohud            Configure MangoHud FPS overlay"
    echo "  monitor [proc]      Monitor game process performance"
    echo "  stress [sec]        Run GPU stress test"
    echo "  compat              Check GPU compatibility"
    echo "  summary             Show performance summary"
    echo "  help                Show this help"
}

init

case "$1" in
    mangohud) mangohud ;;
    monitor) monitor_process "$2" "$3" ;;
    stress) stress_test "$2" ;;
    compat) compat ;;
    summary) summary ;;
    *) show_help ;;
esac
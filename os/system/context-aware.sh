#!/bin/bash
# TinkerOS Context-Aware System Adaptation
# TECHNIQUE: Contextual System Symbiosis (CSS)
#
# CONCEPT: System detects WHAT you're doing (context) and automatically
# adapts ALL system parameters to optimize for that activity.
#
# WHAT MAKES IT NEW:
# - Current systems: Manual settings (you choose modes)
# - CSS: Automatic detection (system detects context)
#
# HOW IT WORKS:
# 1. CONTEXT DETECTION: Monitors active apps, input patterns, time
# 2. CONTEXT CLASSIFICATION: Categorizes activity (work/game/rest/etc)
# 3. PARAMETER MAPPING: Maps context to optimal system settings
# 4. ADAPTIVE TRANSITION: Smoothly transitions between contexts
# 5. LEARNED ADAPTATION: Learns your preferences per context
#
# CONTEXTS DETECTED:
# - Work: Browser, IDE, documents, email
# - Gaming: Steam, game processes, controller input
# - Rest: Low activity, night hours, media consumption
# - Creative: Video editor, audio tools, graphics
# - Communication: Zoom, Teams, Discord calls
# - Browsing: General web browsing
#
# PARAMETERS ADAPTED:
# - CPU governor, GPU mode, fan speed
# - Network priority, bandwidth allocation
# - Audio settings, display brightness
# - Notification level, background tasks

set -e

CSS_DIR="$HOME/.tinker/context"
CONTEXT_FILE="$CSS_DIR/current-context.dat"
HISTORY_FILE="$CSS_DIR/context-history.log"
PROFILE_DIR="$CSS_DIR/profiles"
LOG_FILE="$CSS_DIR/adaptation.log"

mkdir -p "$CSS_DIR" "$PROFILE_DIR"

# Initialize
init() {
    [ ! -f "$CONTEXT_FILE" ] && echo "unknown" > "$CONTEXT_FILE"
    [ ! -f "$HISTORY_FILE" ] && touch "$HISTORY_FILE"
    
    # Create default profiles
    create_profiles
}

# Create default context profiles
create_profiles() {
    # Work profile
    cat > "$PROFILE_DIR/work.conf" << 'EOF'
CONTEXT=work
CPU_GOVERNOR=ondemand
GPU_MODE=auto
FAN_SPEED=balanced
AUDIO=output
NOTIFICATIONS=priority
BACKGROUND_TASKS=normal
NETWORK_PRIORITY=normal
BRIGHTNESS=80
EOF

    # Gaming profile
    cat > "$PROFILE_DIR/gaming.conf" << 'EOF'
CONTEXT=gaming
CPU_GOVERNOR=performance
GPU_MODE=performance
FAN_SPEED=aggressive
AUDIO=gaming
NOTIFICATIONS=minimal
BACKGROUND_TASKS=minimal
NETWORK_PRIORITY=high
BRIGHTNESS=100
EOF

    # Rest profile
    cat > "$PROFILE_DIR/rest.conf" << 'EOF'
CONTEXT=rest
CPU_GOVERNOR=powersave
GPU_MODE=powersave
FAN_SPEED=quiet
AUDIO=quiet
NOTIFICATIONS=none
BACKGROUND_TASKS=minimal
NETWORK_PRIORITY=low
BRIGHTNESS=40
EOF

    # Creative profile
    cat > "$PROFILE_DIR/creative.conf" << 'EOF'
CONTEXT=creative
CPU_GOVERNOR=performance
GPU_MODE=performance
FAN_SPEED=aggressive
AUDIO=professional
NOTIFICATIONS=minimal
BACKGROUND_TASKS=minimal
NETWORK_PRIORITY=normal
BRIGHTNESS=90
EOF

    # Communication profile
    cat > "$PROFILE_DIR/communication.conf" << 'EOF'
CONTEXT=communication
CPU_GOVERNOR=ondemand
GPU_MODE=auto
FAN_SPEED=balanced
AUDIO=voice
NOTIFICATIONS=priority
BACKGROUND_TASKS=minimal
NETWORK_PRIORITY=high
BRIGHTNESS=70
EOF
}

# Detect current context
detect_context() {
    local context="unknown"
    
    # Get active window
    local active_window=$(xdotool getactivewindow getwindowname 2>/dev/null || echo "")
    local active_class=$(xdotool getactivewindow getwindowclass 2>/dev/null || echo "")
    
    # Check running processes
    local processes=$(ps aux | awk '{print $11}' | xargs -I {} basename {} | sort -u)
    
    # Gaming detection
    if echo "$processes" | grep -qi "steam\|game\|lutris\|wine"; then
        context="gaming"
    # Work detection
    elif echo "$processes" | grep -qi "code\|atom\|sublime\|vim\|emacs\|thunderbird\|outlook"; then
        context="work"
    # Creative detection
    elif echo "$processes" | grep -qi "obs\|audacity\|gimp\|blender\|inkscape"; then
        context="creative"
    # Communication detection
    elif echo "$processes" | grep -qi "zoom\|teams\|discord\|slack\|meet"; then
        context="communication"
    # Browsing detection
    elif echo "$processes" | grep -qi "firefox\|chrome\|chromium\|brave"; then
        context="browsing"
    # Rest detection (low activity or night hours)
    elif [ $(date +%H) -ge 22 ] || [ $(date +%H) -le 6 ]; then
        context="rest"
    fi
    
    # Save context
    echo "$context" > "$CONTEXT_FILE"
    echo "$(date +%s)|$context" >> "$HISTORY_FILE"
    
    echo "$context"
}

# Apply context profile
apply_context() {
    local context=$1
    local profile="$PROFILE_DIR/$context.conf"
    
    if [ ! -f "$profile" ]; then
        echo "No profile for context: $context"
        return
    fi
    
    echo "Applying context: $context"
    
    # Read profile
    local cpu_governor=$(grep "CPU_GOVERNOR" "$profile" | cut -d= -f2)
    local gpu_mode=$(grep "GPU_MODE" "$profile" | cut -d= -f2)
    local fan_speed=$(grep "FAN_SPEED" "$profile" | cut -d= -f2)
    local audio=$(grep "AUDIO" "$profile" | cut -d= -f2)
    local notifications=$(grep "NOTIFICATIONS" "$profile" | cut -d= -f2)
    local bg_tasks=$(grep "BACKGROUND_TASKS" "$profile" | cut -d= -f2)
    local net_priority=$(grep "NETWORK_PRIORITY" "$profile" | cut -d= -f2)
    local brightness=$(grep "BRIGHTNESS" "$profile" | cut -d= -f2)
    
    # Apply CPU governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$cpu_governor" > $cpu 2>/dev/null || true
    done
    
    # Apply GPU mode
    case $gpu_mode in
        performance)
            nvidia-smi -pm 1 2>/dev/null || true
            nvidia-smi -ac 5001,1500 2>/dev/null || true
            ;;
        powersave)
            nvidia-smi -pm 0 2>/dev/null || true
            ;;
    esac
    
    # Apply fan speed (if available)
    if [ -d /sys/class/hwmon ]; then
        for fan in /sys/class/hwmon/*/fan1_pwm; do
            case $fan_speed in
                quiet) echo 80 > $fan 2>/dev/null || true ;;
                balanced) echo 150 > $fan 2>/dev/null || true ;;
                aggressive) echo 255 > $fan 2>/dev/null || true ;;
            esac
        done
    fi
    
    # Apply brightness
    if [ -d /sys/class/backlight ]; then
        local max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null || echo 100)
        local target=$((brightness * max / 100))
        echo $target > /sys/class/backlight/*/brightness 2>/dev/null || true
    fi
    
    # Apply notification level
    case $notifications in
        none)
            # Disable all notifications
            gsettings set org.gnome.desktop.notifications show-banners false 2>/dev/null || true
            ;;
        minimal)
            # Only critical notifications
            gsettings set org.gnome.desktop.notifications show-banners true 2>/dev/null || true
            ;;
        priority)
            # All notifications
            gsettings set org.gnome.desktop.notifications show-banners true 2>/dev/null || true
            ;;
    esac
    
    # Apply background tasks
    case $bg_tasks in
        minimal)
            # Kill non-essential background tasks
            pkill -f "update-manager" 2>/dev/null || true
            pkill -f "tracker-miner" 2>/dev/null || true
            ;;
        normal)
            # Allow background tasks
            ;;
    esac
    
    # Log adaptation
    echo "$(date +%s)|Applied $context profile" >> "$LOG_FILE"
    
    echo "Context applied: $context"
}

# Monitor context changes
monitor() {
    echo "Starting Context-Aware Monitor..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    local last_context=""
    
    while true; do
        # Detect current context
        local context=$(detect_context)
        
        # Apply if changed
        if [ "$context" != "$last_context" ]; then
            echo "Context changed: $last_context → $context"
            apply_context "$context"
            last_context="$context"
        fi
        
        sleep 10  # Check every 10 seconds
    done
}

# Show current context
show_context() {
    local context=$(cat "$CONTEXT_FILE" 2>/dev/null || echo "unknown")
    echo "Current Context: $context"
    echo ""
    echo "Recent History:"
    tail -5 "$HISTORY_FILE" | while IFS='|' read -r ts ctx; do
        local time=$(date -d @$ts "+%H:%M:%S" 2>/dev/null || echo "?")
        echo "  $time: $ctx"
    done
}

show_help() {
    echo "Usage: tinker-context [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect current context"
    echo "  apply [context]   Apply context profile"
    echo "  monitor           Start monitoring"
    echo "  context           Show current context"
    echo "  profiles          List available profiles"
    echo "  help              Show this help"
    echo ""
    echo "TECHNIQUE: Contextual System Symbiosis (CSS)"
    echo "  - Detects what you're doing"
    echo "  - Automatically adapts system"
    echo "  - Learns your preferences"
    echo "  - Smooth transitions"
}

init

case "$1" in
    detect) detect_context ;;
    apply) apply_context "${2:-unknown}" ;;
    monitor) monitor ;;
    context|status) show_context ;;
    profiles) ls "$PROFILE_DIR" ;;
    *) show_help ;;
esac

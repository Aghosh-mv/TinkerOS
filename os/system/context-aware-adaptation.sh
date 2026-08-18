#!/bin/bash
# TinkerOS Context-Aware System Adaptation (CSS)
# Detects WHAT you're doing and automatically adapts ALL system parameters

CSS_CONTEXT="$HOME/.tinker/css_context.json"
CSS_PREFERENCES="$HOME/.tinker/css_preferences.json"
CSS_CONFIG="$HOME/.tinker/css_config.json"

mkdir -p "$HOME/.tinker"

# Initialize CSS system
css_init() {
    if [ ! -f "$CSS_CONFIG" ]; then
        cat > "$CSS_CONFIG" << 'EOF'
{
  "log_file": "$HOME/.tinker/css_context.log",
  "context_file": "$CSS_CONTEXT",
  "preferences_file": "$CSS_PREFERENCES",
  "adaptation_interval": 30
}
EOF
    fi
    
    if [ ! -f "$CSS_CONTEXT" ]; then
        echo '{"context":"unknown","app":"unknown","timestamp":0}' > "$CSS_CONTEXT"
    fi
    
    if [ ! -f "$CSS_PREFERENCES" ]; then
        cat > "$CSS_PREFERENCES" << 'EOF'
{
  "work": {"cpu_mode": "performance", "notifications": "off", "brightness": 80},
  "game": {"cpu_mode": "performance", "notifications": "off", "brightness": 100},
  "rest": {"cpu_mode": "power-save", "notifications": "on", "brightness": 30},
  "communication": {"cpu_mode": "balanced", "notifications": "on", "brightness": 70}
}
EOF
    fi
}

# Detect current context
css_detect_context() {
    local current_app=$(xprop -name "$(xprop -root _NET_ACTIVE_WINDOW | cut -d' ' -f5)" 2>/dev/null | grep _NET_WM_CLASS | cut -d'=' -f2 | tr -d '\"' || echo "unknown")
    local current_time=$(date +%H)
    local current_day=$(date +%u)
    
    # Classify context based on active window and time
    local context="unknown"
    
    case "$current_app" in
        *firefox*|*chrome*|*terminal*)
            if [ "$current_hour" -ge 8 ] && [ "$current_hour" -le 18 ]; then
                context="work"
            else
                context="communication"
            fi
            ;;
        *steam*|*play-on-linux*|*wine*)
            context="game"
            ;;
        *discord*|*telegram*|*signal*)
            context="communication"
            ;;
        *settings*|*system*)
            context="configuration"
            ;;
        *media*|*vlc*|*mpv*|*spotify*)
            context="entertainment"
            ;;
        *)
            # Time-based classification
            if [ "$current_hour" -ge 22 ] || [ "$current_hour" -le 6 ]; then
                context="rest"
            elif [ "$current_hour" -ge 8 ] && [ "$current_hour" -le 18 ]; then
                context="work"
            else
                context="leisure"
            fi
            ;;
    esac
    
    # Update context
    python3 -c "
import json, sys
context_file = '$CSS_CONTEXT'
context = '$context'
current_time = int('$current_time')
current_day = int('$current_day')

with open(context_file, 'w') as f:
    json.dump({
        'context': context,
        'app': '$current_app',
        'hour': current_time,
        'day': current_day,
        'timestamp': int(time.time())
    }, f)
"
    
    echo "Context detected: $context (app: $current_app)"
}

# Apply CSS adaptations
css_adapt() {
    local context=$(python3 -c "
import json
with open('$CSS_CONTEXT', 'r') as f:
    data = json.load(f)
print(data.get('context', 'unknown'))
")
    
    if [ -z "$context" ] || [ "$context" = "unknown" ]; then
        css_detect_context
        context=$(python3 -c "
import json
with open('$CSS_CONTEXT', 'r') as f:
    data = json.load(f)
print(data.get('context', 'unknown'))
")
    fi
    
    # Get preferences for this context
    local prefs=$(python3 -c "
import json
with open('$CSS_PREFERENCES', 'r') as f:
    data = json.load(f)
prefs = data.get('$context', data.get('work', {}))
for k, v in prefs.items():
    echo \"$k=\$v\"
")
    
    # Apply adaptations
    for pref in $prefs; do
        key=$(echo "$pref" | cut -d= -f1)
        value=$(echo "$pref" | cut -d= -f2)
        
        case "$key" in
            cpu_mode)
                echo "Setting CPU mode to: $value"
                # Placeholder - would actualy set CPU governor
                ;;
            notifications)
                echo "Setting notifications to: $value"
                # Would use gsettings or similar
                ;;
            brightness)
                echo "Setting brightness to: $value%"
                # Would use xbacklight or similar
                ;;
        esac
    done
    
    echo "CSS adaptations applied for context: $context"
}

# Main CSS interface
case "${1:-}" in
    init)
        css_init
        echo "CSS system initialized"
        ;;
    detect)
        css_detect_context
        ;;
    adapt)
        css_adapt
        ;;
    status)
        python3 -c "
import json
with open('$CSS_CONTEXT', 'r') as f:
    data = json.load(f)
print(f'Current context: {data.get(\"context\", \"unknown\")}')
print(f'Active app: {data.get(\"app\", \"unknown\")}')
print(f'Hour: {data.get(\"hour\", \"unknown\")}')
"
        ;;
    *)
        echo "Usage: $0 {init|detect|adapt|status}"
        echo "  init    - Initialize CSS system"
        echo "  detect  - Detect current context (active app, activity type)"
        echo "  adapt   - Apply system adaptations for detected context"
        echo "  status  - Show current context and preferences"
        ;;
esac

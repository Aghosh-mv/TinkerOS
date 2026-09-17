#!/bin/bash
# KorrinOS Battery Personality Bar
# Small top-bar indicator with witty messages
# Shows on mouseover or when battery < 10%

BAT_PERSONALITY_DIR="/opt/korrinos/os/system"
BAT_BAR_HTML="/tmp/korrinos-battery-bar.html"

# ============================================================
#  BATTERY PERSONALITY MESSAGES
# ============================================================
BAT_MESSAGES_100=(
    "Running on pure ambition."
    "Full charge. The world is our sandbox."
    "Battery at 100%. We're unstoppable. For now."
    "Maximum power. Minimum regrets."
    "Fully charged. Let's make questionable decisions."
)

BAT_MESSAGES_80=(
    "Still going strong. Like this project."
    "80%. We've got time."
    "Battery healthy. The hard part is just beginning."
    "Comfortable charge. Perfect for scope creep."
)

BAT_MESSAGES_50=(
    "Halfway there. Or halfway lost. Hard to tell."
    "50%. We're committed now."
    "Battery at 50%. The point of no return."
    "Half charge. Full ambition."
)

BAT_MESSAGES_30=(
    "Getting low. Like our patience."
    "30%. We should probably wrap up. We won't."
    "Battery warning: the project got bigger."
    "Time to find a charger. Or a better battery."
)

BAT_MESSAGES_20=(
    "Heart rate rising."
    "20%. The battery is getting nervous."
    "Low battery. The laptop is sweating."
    "We're in the danger zone. The fun one."
    "20%. This is fine. Everything is fine."
)

BAT_MESSAGES_10=(
    "Please. I'm dying. Connect me before I write my memoirs."
    "10%. The battery has accepted its fate."
    "Critical. The laptop is writing goodbye letters."
    "10%. We're one notification away from shutdown."
    "Battery at 10%. The end is near. Save your work."
)

BAT_MESSAGES_5=(
    "5%. I'm looking at the light."
    "The battery has left the building."
    "5%. This is not a drill. This is the end."
    "Last 5%. The laptop is whispering goodbye."
    "Critical battery. The system is writing its will."
)

BAT_MESSAGES_DEAD=(
    "The battery has ascended to a higher plane."
    "Battery: deceased. Cause: too much ambition."
    "RIP battery. It fought hard."
)

# ============================================================
#  BATTERY DETECTION
# ============================================================
get_battery_level() {
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        cat /sys/class/power_supply/BAT0/capacity
    elif [ -f /sys/class/power_supply/BAT1/capacity ]; then
        cat /sys/class/power_supply/BAT1/capacity
    else
        echo "100"  # Default: assume plugged in
    fi
}

get_battery_status() {
    if [ -f /sys/class/power_supply/BAT0/status ]; then
        cat /sys/class/power_supply/BAT0/status
    elif [ -f /sys/class/power_supply/BAT1/status ]; then
        cat /sys/class/power_supply/BAT1/status
    else
        echo "Charging"
    fi
}

get_battery_message() {
    local level=$1
    local messages=""
    
    if [ "$level" -ge 80 ]; then
        messages=("${BAT_MESSAGES_100[@]}" "${BAT_MESSAGES_80[@]}")
    elif [ "$level" -ge 50 ]; then
        messages=("${BAT_MESSAGES_80[@]}" "${BAT_MESSAGES_50[@]}")
    elif [ "$level" -ge 30 ]; then
        messages=("${BAT_MESSAGES_50[@]}" "${BAT_MESSAGES_30[@]}")
    elif [ "$level" -ge 20 ]; then
        messages=("${BAT_MESSAGES_30[@]}" "${BAT_MESSAGES_20[@]}")
    elif [ "$level" -ge 10 ]; then
        messages=("${BAT_MESSAGES_20[@]}" "${BAT_MESSAGES_10[@]}")
    elif [ "$level" -ge 5 ]; then
        messages=("${BAT_MESSAGES_10[@]}" "${BAT_MESSAGES_5[@]}")
    else
        messages=("${BAT_MESSAGES_5[@]}" "${BAT_MESSAGES_DEAD[@]}")
    fi
    
    local idx=$((RANDOM % ${#messages[@]}))
    echo "${messages[$idx]}"
}

# ============================================================
#  BATTERY BAR HTML — small, top-bar, mouseover or <10%
# ============================================================
generate_battery_bar() {
    local level
    level=$(get_battery_level)
    local status
    status=$(get_battery_status)
    local message
    message=$(get_battery_message "$level")
    
    local color=""
    local icon=""
    
    if [ "$level" -ge 50 ]; then
        color="#10b981"  # Green
        icon=""
    elif [ "$level" -ge 20 ]; then
        color="#f59e0b"  # Yellow
        icon=""
    elif [ "$level" -ge 10 ]; then
        color="#ef4444"  # Red
        icon="🪫"
    else
        color="#dc2626"  # Dark red
        icon="💀"
    fi
    
    cat > "$BAT_BAR_HTML" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: system-ui, -apple-system, sans-serif;
    background: transparent;
    overflow: hidden;
  }
  .bat-bar {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    height: 24px;
    background: rgba(0,0,0,0.8);
    display: flex;
    align-items: center;
    justify-content: flex-end;
    padding: 0 12px;
    font-size: 11px;
    color: #fff;
    z-index: 99999;
    opacity: 0;
    transition: opacity 0.3s ease;
    cursor: default;
  }
  .bat-bar:hover,
  .bat-bar.show {
    opacity: 1;
  }
  .bat-bar.critical {
    opacity: 1;
    animation: pulse 2s ease-in-out infinite;
  }
  @keyframes pulse {
    0%, 100% { background: rgba(0,0,0,0.8); }
    50% { background: rgba(220,38,38,0.9); }
  }
  .bat-icon { margin-right: 6px; }
  .bat-level { font-weight: 600; margin-right: 8px; color: ${color}; }
  .bat-msg { color: #aaa; font-style: italic; }
  .bat-bar.critical .bat-msg { color: #fca5a5; }
</style>
</head>
<body>
  <div class="bat-bar ${level}" id="batBar">
    <span class="bat-icon">${icon}</span>
    <span class="bat-level">${level}%</span>
    <span class="bat-msg">${message}</span>
  </div>
  <script>
    const bar = document.getElementById('batBar');
    // Show on hover
    bar.addEventListener('mouseenter', () => bar.classList.add('show'));
    bar.addEventListener('mouseleave', () => {
      if (!bar.classList.contains('critical')) bar.classList.remove('show');
    });
  </script>
</body>
</html>
HTMLEOF
    
    echo "$BAT_BAR_HTML"
}

# ============================================================
#  MAIN
# ============================================================
case "${1:-}" in
    status)
        local level=$(get_battery_level)
        local status=$(get_battery_status)
        local message=$(get_battery_message "$level")
        echo "Battery: ${level}% (${status})"
        echo "Message: ${message}"
        ;;
    show)
        generate_battery_bar
        echo "Battery bar generated: $BAT_BAR_HTML"
        ;;
    test)
        echo "=== Battery Personality Test ==="
        echo ""
        for level in 100 80 50 30 20 10 5 2; do
            echo "  ${level}%: $(get_battery_message $level)"
        done
        ;;
    *)
        echo "KorrinOS Battery Personality v1.0"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  status  Show current battery level + message"
        echo "  show    Generate battery bar HTML"
        echo "  test    Show sample messages for all levels"
        ;;
esac

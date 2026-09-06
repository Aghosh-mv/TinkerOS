#!/bin/bash
# TinkerOS Feature Manager
# Enable/disable optional technologies

CONFIG_FILE="$HOME/.tinker/optional-features.conf"

# Initialize config
init() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# TinkerOS Optional Features (All disabled by default)

DIGITAL_TWIN_ENABLED=false
SELF_HEALING_ENABLED=false
ADAPTIVE_POWER_GRID_ENABLED=false
PREDICTIVE_INTELLIGENCE_ENABLED=false
TEMPORAL_MAPPING_ENABLED=false
CONTEXT_AWARE_ENABLED=false
PREDICTIVE_CACHING_ENABLED=false
EOF
    fi
}

# Enable feature
enable() {
    local feature=$1
    
    case $feature in
        digital-twin|twin|neural)
            sed -i 's/DIGITAL_TWIN_ENABLED=false/DIGITAL_TWIN_ENABLED=true/' "$CONFIG_FILE"
            echo "Enabled: Digital Twin / Neural System Symbiosis"
            ;;
        self-healing|heal)
            sed -i 's/SELF_HEALING_ENABLED=false/SELF_HEALING_ENABLED=true/' "$CONFIG_FILE"
            echo "Enabled: Self-Healing System"
            ;;
        power-grid|power)
            sed -i 's/ADAPTIVE_POWER_GRID_ENABLED=false/ADAPTIVE_POWER_GRID_ENABLED=true/' "$CONFIG_FILE"
            echo "Enabled: Adaptive Power Grid"
            ;;
        predictive|predict)
            sed -i 's/PREDICTIVE_INTELLIGENCE_ENABLED=false/PREDICTIVE_INTELLIGENCE_ENABLED=true/' "$CONFIG_FILE"
            echo "Enabled: Predictive System Intelligence"
            ;;
        temporal|time)
            sed -i 's/TEMPORAL_MAPPING_ENABLED=false/TEMPORAL_MAPPING_ENABLED=true/' "$CONFIG_FILE"
            echo "Enabled: Temporal Resource Mapping"
            ;;
        context|adapt)
            sed -i 's/CONTEXT_AWARE_ENABLED=false/CONTEXT_AWARE_ENABLED=true/' "$CONFIG_FILE"
            echo "Enabled: Context-Aware Adaptation"
            ;;
        cache|precache)
            sed -i 's/PREDICTIVE_CACHING_ENABLED=false/PREDICTIVE_CACHING_ENABLED=true/' "$CONFIG_FILE"
            echo "Enabled: Predictive Pre-Caching"
            ;;
        all)
            sed -i 's/=false/=true/g' "$CONFIG_FILE"
            echo "Enabled ALL features"
            ;;
        *)
            echo "Unknown feature: $feature"
            return 1
            ;;
    esac
}

# Disable feature
disable() {
    local feature=$1
    
    case $feature in
        digital-twin|twin|neural)
            sed -i 's/DIGITAL_TWIN_ENABLED=true/DIGITAL_TWIN_ENABLED=false/' "$CONFIG_FILE"
            echo "Disabled: Digital Twin / Neural System Symbiosis"
            ;;
        self-healing|heal)
            sed -i 's/SELF_HEALING_ENABLED=true/SELF_HEALING_ENABLED=false/' "$CONFIG_FILE"
            echo "Disabled: Self-Healing System"
            ;;
        power-grid|power)
            sed -i 's/ADAPTIVE_POWER_GRID_ENABLED=true/ADAPTIVE_POWER_GRID_ENABLED=false/' "$CONFIG_FILE"
            echo "Disabled: Adaptive Power Grid"
            ;;
        predictive|predict)
            sed -i 's/PREDICTIVE_INTELLIGENCE_ENABLED=true/PREDICTIVE_INTELLIGENCE_ENABLED=false/' "$CONFIG_FILE"
            echo "Disabled: Predictive System Intelligence"
            ;;
        temporal|time)
            sed -i 's/TEMPORAL_MAPPING_ENABLED=true/TEMPORAL_MAPPING_ENABLED=false/' "$CONFIG_FILE"
            echo "Disabled: Temporal Resource Mapping"
            ;;
        context|adapt)
            sed -i 's/CONTEXT_AWARE_ENABLED=true/CONTEXT_AWARE_ENABLED=false/' "$CONFIG_FILE"
            echo "Disabled: Context-Aware Adaptation"
            ;;
        cache|precache)
            sed -i 's/PREDICTIVE_CACHING_ENABLED=true/PREDICTIVE_CACHING_ENABLED=false/' "$CONFIG_FILE"
            echo "Disabled: Predictive Pre-Caching"
            ;;
        all)
            sed -i 's/=true/=false/g' "$CONFIG_FILE"
            echo "Disabled ALL features"
            ;;
        *)
            echo "Unknown feature: $feature"
            return 1
            ;;
    esac
}

# Show status
status() {
    echo "TinkerOS Optional Features Status:"
    echo ""
    
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key value; do
            if [[ $key == *_ENABLED ]]; then
                local name=${key%_ENABLED}
                name=$(echo "$name" | tr '_' ' ')
                if [ "$value" = "true" ]; then
                    echo "  [ON]  $name"
                else
                    echo "  [OFF] $name"
                fi
            fi
        done < "$CONFIG_FILE"
    fi
}

show_help() {
    echo "Usage: tinker-feature [command] [feature]"
    echo ""
    echo "Commands:"
    echo "  enable <feature>    Enable a feature"
    echo "  disable <feature>   Disable a feature"
    echo "  status              Show all features status"
    echo "  help                Show this help"
    echo ""
    echo "Features:"
    echo "  digital-twin, twin, neural    Digital Twin / Neural Symbiosis"
    echo "  self-healing, heal            Self-Healing System"
    echo "  power-grid, power             Adaptive Power Grid"
    echo "  predictive, predict           Predictive Intelligence"
    echo "  temporal, time                Temporal Resource Mapping"
    echo "  context, adapt                Context-Aware Adaptation"
    echo "  cache, precache               Predictive Pre-Caching"
    echo "  all                           Enable/Disable ALL"
    echo ""
    echo "Examples:"
    echo "  tinker-feature enable self-healing"
    echo "  tinker-feature disable power-grid"
    echo "  tinker-feature status"
}

init

case "$1" in
    enable|on) enable "$2" ;;
    disable|off) disable "$2" ;;
    status) status ;;
    *) show_help ;;
esac

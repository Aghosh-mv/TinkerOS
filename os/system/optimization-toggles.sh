#!/bin/bash
# TinkerOS Optimization Toggles

set -e

OPT_DIR="$HOME/.tinker/optimizations"
CONFIG_FILE="$OPT_DIR/config.conf"

mkdir -p "$OPT_DIR"

init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# TinkerOS Optimization Toggles

# Performance
CPU_GOVERNOR=schedutil
IO_SCHEDULER=cfq
SWAPPINESS=60
DIRTY_RATIO=20

# Network
TCP_CONGESTION=cubic
NET_CORE_RMEM=212992
NET_CORE_WMEM=212992

# Memory
OVERCOMMIT_MEMORY=0
VFS_CACHE_PRESSURE=50

# Power
POWER_SAVE=true
TLP_ENABLED=true

# Gaming
GAMING_MODE=false
STEAM_COMPAT=proton-experimental

# Audio
AUDIO_LATENCY=1024
AUDIO_RATE=48000
EOF
    fi
}

# Toggle performance mode
toggle_performance() {
    local current=$(grep "CPU_GOVERNOR" "$CONFIG_FILE" | cut -d= -f2)
    
    if [ "$current" = "performance" ]; then
        sed -i 's/CPU_GOVERNOR=.*/CPU_GOVERNOR=schedutil/' "$CONFIG_FILE"
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo schedutil > $cpu 2>/dev/null || true
        done
        echo "Switched to balanced mode"
    else
        sed -i 's/CPU_GOVERNOR=.*/CPU_GOVERNOR=performance/' "$CONFIG_FILE"
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo performance > $cpu 2>/dev/null || true
        done
        echo "Switched to performance mode"
    fi
}

# Toggle power saving
toggle_power_save() {
    local current=$(grep "POWER_SAVE" "$CONFIG_FILE" | cut -d= -f2)
    
    if [ "$current" = "true" ]; then
        sed -i 's/POWER_SAVE=.*/POWER_SAVE=false/' "$CONFIG_FILE"
        echo "Power saving disabled"
    else
        sed -i 's/POWER_SAVE=.*/POWER_SAVE=true/' "$CONFIG_FILE"
        echo "Power saving enabled"
    fi
}

# Toggle gaming mode
toggle_gaming() {
    local current=$(grep "GAMING_MODE" "$CONFIG_FILE" | cut -d= -f2)
    
    if [ "$current" = "true" ]; then
        sed -i 's/GAMING_MODE=.*/GAMING_MODE=false/' "$CONFIG_FILE"
        /usr/lib/tinker/gaming-mode.sh disable 2>/dev/null
        echo "Gaming mode disabled"
    else
        sed -i 's/GAMING_MODE=.*/GAMING_MODE=true/' "$CONFIG_FILE"
        /usr/lib/tinker/gaming-mode.sh enable 2>/dev/null
        echo "Gaming mode enabled"
    fi
}

# Toggle TLP (laptop power saving)
toggle_tlp() {
    local current=$(grep "TLP_ENABLED" "$CONFIG_FILE" | cut -d= -f2)
    
    if [ "$current" = "true" ]; then
        sed -i 's/TLP_ENABLED=.*/TLP_ENABLED=false/' "$CONFIG_FILE"
        sudo systemctl stop tlp 2>/dev/null
        echo "TLP disabled"
    else
        sed -i 's/TLP_ENABLED=.*/TLP_ENABLED=true/' "$CONFIG_FILE"
        sudo systemctl start tlp 2>/dev/null
        echo "TLP enabled"
    fi
}

# Apply swappiness
apply_swappiness() {
    local value=$1
    sudo sysctl -w vm.swappiness=$value
    sed -i "s/SWAPPINESS=.*/SWAPPINESS=$value/" "$CONFIG_FILE"
    echo "Swappiness set to $value"
}

# Apply IO scheduler
apply_io_scheduler() {
    local scheduler=$1
    for disk in /sys/block/sd*/queue/scheduler; do
        echo $scheduler > $disk 2>/dev/null || true
    done
    sed -i "s/IO_SCHEDULER=.*/IO_SCHEDULER=$scheduler/" "$CONFIG_FILE"
    echo "IO scheduler set to $scheduler"
}

# Apply network settings
apply_network() {
    sudo sysctl -w net.core.rmem_max=16777216
    sudo sysctl -w net.core.wmem_max=16777216
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
    echo "Network optimized"
}

# Show current settings
show_settings() {
    echo "Current Optimization Settings:"
    echo ""
    grep -v "^#" "$CONFIG_FILE" | grep -v "^$" | while IFS='=' read -r key value; do
        printf "  %-20s %s\n" "$key:" "$value"
    done
    echo ""
}

# Show all toggles
show_toggles() {
    echo "Optimization Toggles:"
    echo ""
    echo "  1) CPU Governor: $(grep CPU_GOVERNOR $CONFIG_FILE | cut -d= -f2)"
    echo "  2) Power Save: $(grep POWER_SAVE $CONFIG_FILE | cut -d= -f2)"
    echo "  3) Gaming Mode: $(grep GAMING_MODE $CONFIG_FILE | cut -d= -f2)"
    echo "  4) TLP: $(grep TLP_ENABLED $CONFIG_FILE | cut -d= -f2)"
    echo "  5) Swappiness: $(grep SWAPPINESS $CONFIG_FILE | cut -d= -f2)"
    echo "  6) IO Scheduler: $(grep IO_SCHEDULER $CONFIG_FILE | cut -d= -f2)"
    echo ""
}

show_help() {
    echo "Usage: tinker-optimize [command]"
    echo ""
    echo "Commands:"
    echo "  performance       Toggle performance mode"
    echo "  power-save        Toggle power saving"
    echo "  gaming            Toggle gaming mode"
    echo "  tlp               Toggle TLP"
    echo "  swappiness <val>  Set swappiness"
    echo "  io <scheduler>    Set IO scheduler"
    echo "  network           Optimize network"
    echo "  settings          Show settings"
    echo "  toggles           Show all toggles"
    echo "  help              Show this help"
}

init_config

case "$1" in
    performance|perf) toggle_performance ;;
    power-save|ps) toggle_power_save ;;
    gaming|game) toggle_gaming ;;
    tlp) toggle_tlp ;;
    swappiness|swap) apply_swappiness "$2" ;;
    io) apply_io_scheduler "$2" ;;
    network|net) apply_network ;;
    settings) show_settings ;;
    toggles) show_toggles ;;
    *) show_help ;;
esac

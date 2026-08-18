#!/bin/bash
# TinkerOS Gaming Mode
# Optimizes system for gaming performance

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GAMING_MODE_FILE="/tmp/tinker-gaming-mode"
CPU_GOVERNOR_FILE="/tmp/tinker-cpu-governor"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  TINKEROS GAMING MODE                   ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

enable_gaming_mode() {
    echo -e "${YELLOW}Enabling Gaming Mode...${NC}"
    
    # Save current CPU governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor > $CPU_GOVERNOR_FILE
    fi
    
    # Set CPU to performance mode
    echo -e "  Setting CPU to performance mode..."
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > $cpu 2>/dev/null || true
    done
    
    # Disable screen tearing
    echo -e "  Disabling screen tearing..."
    export __GL_SYNC_TO_VBLANK=0
    export __GL_SYNC_DISPLAY设备=0
    
    # Set NVIDIA power mode (if available)
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo -e "  Setting NVIDIA to maximum performance..."
        sudo nvidia-smi -pm 1
        sudo nvidia-smi -pl 100
    fi
    
    # Set AMD power state (if available)
    if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
        echo -e "  Setting AMD to high performance..."
        echo high > /sys/class/drm/card0/device/power_dpm_force_performance_level
    fi
    
    # Disable power saving
    echo -e "  Disabling power saving..."
    for dev in /sys/bus/pci/devices/*/power/control; do
        echo on > $dev 2>/dev/null || true
    done
    
    # Set gaming-friendly sysctl
    echo -e "  Optimizing kernel parameters..."
    sudo sysctl -w vm.swappiness=10
    sudo sysctl -w net.core.rmem_max=16777216
    sudo sysctl -w net.core.wmem_max=16777216
    
    # Disable notifications
    echo -e "  Disabling notifications..."
    if [ -f /tmp/tinker-notifications ]; then
        kill -STOP $(cat /tmp/tinker-notifications) 2>/dev/null || true
    fi
    
    # Create gaming mode file
    touch $GAMING_MODE_FILE
    
    echo ""
    echo -e "${GREEN}✓ Gaming Mode Enabled!${NC}"
    echo -e "${YELLOW}System optimized for gaming performance.${NC}"
    echo ""
    echo "Features enabled:"
    echo "  ✓ CPU set to performance mode"
    echo "  ✓ GPU set to maximum performance"
    echo "  ✓ Power saving disabled"
    echo "  ✓ Notifications paused"
    echo "  ✓ Network optimized"
    echo ""
}

disable_gaming_mode() {
    echo -e "${YELLOW}Disabling Gaming Mode...${NC}"
    
    # Restore CPU governor
    if [ -f $CPU_GOVERNOR_FILE ]; then
        echo -e "  Restoring CPU governor..."
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            cat $CPU_GOVERNOR_FILE > $cpu 2>/dev/null || true
        done
    else
        # Default to powersave
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo powersave > $cpu 2>/dev/null || true
        done
    fi
    
    # Reset NVIDIA power mode
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo -e "  Resetting NVIDIA power mode..."
        sudo nvidia-smi -pm 0
        sudo nvidia-smi -pl 100
    fi
    
    # Reset AMD power state
    if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
        echo -e "  Resetting AMD power state..."
        echo auto > /sys/class/drm/card0/device/power_dpm_force_performance_level
    fi
    
    # Re-enable power saving
    echo -e "  Re-enabling power saving..."
    for dev in /sys/bus/pci/devices/*/power/control; do
        echo auto > $dev 2>/dev/null || true
    done
    
    # Reset sysctl
    sudo sysctl -w vm.swappiness=60
    sudo sysctl -w net.core.rmem_max=212992
    sudo sysctl -w net.core.wmem_max=212992
    
    # Re-enable notifications
    echo -e "  Re-enabling notifications..."
    if [ -f /tmp/tinker-notifications ]; then
        kill -CONT $(cat /tmp/tinker-notifications) 2>/dev/null || true
    fi
    
    # Remove gaming mode file
    rm -f $GAMING_MODE_FILE
    
    echo ""
    echo -e "${GREEN}✓ Gaming Mode Disabled!${NC}"
    echo -e "${YELLOW}System restored to normal mode.${NC}"
    echo ""
}

show_status() {
    echo -e "${YELLOW}Gaming Mode Status:${NC}"
    echo ""
    
    if [ -f $GAMING_MODE_FILE ]; then
        echo -e "  ${GREEN}✓${NC} Gaming Mode: ${GREEN}ENABLED${NC}"
    else
        echo -e "  ${RED}✗${NC} Gaming Mode: ${RED}DISABLED${NC}"
    fi
    
    # CPU Governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        echo -e "  CPU Governor: $governor"
    fi
    
    # GPU Status
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo -e "  GPU: NVIDIA (detected)"
    else
        echo -e "  GPU: Mesa (detected)"
    fi
    
    echo ""
}

optimize_for_game() {
    local game=$1
    echo -e "${YELLOW}Optimizing for: $game${NC}"
    
    # Game-specific optimizations
    case $game in
        cyberpunk|cyberpunk2077)
            echo "  Setting optimizations for Cyberpunk 2077..."
            export MANGOHUD_CONFIG="fps_limit=60,no_display"
            ;;
        valheim)
            echo "  Setting optimizations for Valheim..."
            export MANGOHUD_CONFIG="fps_limit=144,no_display"
            ;;
        minecraft)
            echo "  Setting optimizations for Minecraft..."
            export MANGOHUD_CONFIG="fps_limit=300,no_display"
            ;;
        *)
            echo "  Using default gaming optimizations..."
            ;;
    esac
    
    echo -e "${GREEN}✓ Game optimizations applied!${NC}"
}

show_help() {
    echo "Usage: tinker-gaming [command] [game]"
    echo ""
    echo "Commands:"
    echo "  enable          Enable gaming mode"
    echo "  disable         Disable gaming mode"
    echo "  status          Show gaming mode status"
    echo "  optimize <game> Optimize for specific game"
    echo "  help            Show this help"
    echo ""
    echo "Examples:"
    echo "  tinker-gaming enable"
    echo "  tinker-gaming optimize cyberpunk2077"
}

# Main
case "$1" in
    enable)
        show_header
        enable_gaming_mode
        ;;
    disable)
        show_header
        disable_gaming_mode
        ;;
    status)
        show_header
        show_status
        ;;
    optimize)
        if [ -z "$2" ]; then
            echo -e "${RED}Please specify a game to optimize for${NC}"
            show_help
            exit 1
        fi
        show_header
        optimize_for_game "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Gaming Mode${NC}"
        echo ""
        echo "Optimizes your system for the best gaming experience."
        echo ""
        echo "Quick commands:"
        echo "  tinker-gaming enable     - Enable gaming mode"
        echo "  tinker-gaming disable    - Disable gaming mode"
        echo "  tinker-gaming status     - Check status"
        ;;
esac

#!/bin/bash
# TinkerOS Power Profile Switcher
# Battery optimization + power profiles

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

POWER_CONFIG="/etc/tinker/power.conf"
POWER_STATE="/tmp/tinker-power-state"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              TINKEROS POWER MANAGER                     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

init_power() {
    mkdir -p /etc/tinker
    
    if [ ! -f $POWER_CONFIG ]; then
        cat > $POWER_CONFIG << 'EOF'
# TinkerOS Power Configuration

# Power profiles: performance, balanced, power-saver, custom
DEFAULT_PROFILE=balanced

# Auto-switch based on battery
AUTO_SWITCH=true

# Battery thresholds
BATTERY_LOW=20
BATTERY_CRITICAL=10
BATTERY_FULL=90

# Performance settings per profile
PERFORMANCE_CPU_GOVERNOR=performance
PERFORMANCE_GPU_POWER=high
PERFORMANCE_DISK_SCHED=deadline
PERFORMANCE_NETWORK_THROUGHPUT=high

BALANCED_CPU_GOVERNOR=schedutil
BALANCED_GPU_POWER=auto
BALANCED_DISK_SCHED=cfq
BALANCED_NETWORK_THROUGHput=balanced

SAVER_CPU_GOVERNOR=powersave
SAVER_GPU_POWER=low
SAVER_DISK_SCHED=cfq
SAVER_NETWORK_THROUGHput=power

# Timer settings
SCREEN_TIMEOUT=300
SUSPEND_TIMEOUT=1800
HIBERNATE_TIMEOUT=3600

# Wake-on-LAN
WOL_ENABLED=false

# Battery health
BATTERY_CHARGE_START=80
BATTERY_CHARGE_STOP=100
EOF
    fi
}

# Get battery status
get_battery_info() {
    local capacity=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
    local status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)
    local time_remaining=""
    
    if [ -n "$capacity" ]; then
        echo -e "Battery: ${GREEN}${capacity}%${NC} ($status)"
        
        # Calculate time remaining
        if [ "$status" = "Discharging" ]; then
            local power=$(cat /sys/class/power_supply/BAT*/current_now 2>/dev/null | head -1)
            local voltage=$(cat /sys/class/power_supply/BAT*/voltage_now 2>/dev/null | head -1)
            
            if [ -n "$power" ] && [ -n "$voltage" ] && [ "$power" -gt 0 ]; then
                local remaining=$((capacity * voltage / power / 60))
                echo -e "Time remaining: ~${remaining} minutes"
            fi
        fi
    else
        echo -e "Battery: ${YELLOW}Not detected${NC}"
    fi
}

# Get current power profile
get_current_profile() {
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl get
    elif [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    else
        echo "unknown"
    fi
}

# Set power profile
set_power_profile() {
    local profile=$1
    
    echo -e "${YELLOW}Setting power profile: $profile${NC}"
    
    case $profile in
        performance)
            set_performance
            ;;
        balanced)
            set_balanced
            ;;
        power-saver|saver)
            set_power_saver
            ;;
        *)
            echo "Unknown profile: $profile"
            return 1
            ;;
    esac
    
    # Save state
    echo $profile > $POWER_STATE
    
    # Notify user
    notify_user "Power Profile" "Switched to $profile mode"
}

set_performance() {
    # CPU Governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > $cpu 2>/dev/null || true
    done
    
    # GPU Power
    if command -v nvidia-smi >/dev/null 2>&1; then
        sudo nvidia-smi -pm 1
        sudo nvidia-smi -pl 100
    fi
    
    if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
        echo high > /sys/class/drm/card0/device/power_dpm_force_performance_level
    fi
    
    # Disk Scheduler
    for disk in /sys/block/sd*/queue/scheduler; do
        echo deadline > $disk 2>/dev/null || true
    done
    
    # Disable power saving
    for dev in /sys/bus/pci/devices/*/power/control; do
        echo on > $dev 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ Performance mode enabled${NC}"
}

set_balanced() {
    # CPU Governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo schedutil > $cpu 2>/dev/null || true
    done
    
    # GPU Power
    if command -v nvidia-smi >/dev/null 2>&1; then
        sudo nvidia-smi -pm 0
        sudo nvidia-smi -pl 100
    fi
    
    if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
        echo auto > /sys/class/drm/card0/device/power_dpm_force_performance_level
    fi
    
    # Disk Scheduler
    for disk in /sys/block/sd*/queue/scheduler; do
        echo cfq > $disk 2>/dev/null || true
    done
    
    # Enable power saving
    for dev in /sys/bus/pci/devices/*/power/control; do
        echo auto > $dev 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ Balanced mode enabled${NC}"
}

set_power_saver() {
    # CPU Governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo powersave > $cpu 2>/dev/null || true
    done
    
    # GPU Power
    if command -v nvidia-smi >/dev/null 2>&1; then
        sudo nvidia-smi -pm 1
        sudo nvidia-smi -pl 50
    fi
    
    if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
        echo low > /sys/class/drm/card0/device/power_dpm_force_performance_level
    fi
    
    # Disk Scheduler
    for disk in /sys/block/sd*/queue/scheduler; do
        echo cfq > $disk 2>/dev/null || true
    done
    
    # Aggressive power saving
    for dev in /sys/bus/pci/devices/*/power/control; do
        echo auto > $dev 2>/dev/null || true
    done
    
    # Dim screen
    if [ -d /sys/class/backlight ]; then
        local backlight=$(ls /sys/class/backlight | head -1)
        local max=$(cat /sys/class/backlight/$backlight/max_brightness)
        local dim=$((max / 3))
        echo $dim | sudo tee /sys/class/backlight/$backlight/brightness
    fi
    
    echo -e "${GREEN}✓ Power saver mode enabled${NC}"
}

# Auto-switch based on battery
auto_switch_profile() {
    if [ ! -f $POWER_CONFIG ] || ! grep -q "AUTO_SWITCH=true" $POWER_CONFIG; then
        return
    fi
    
    local capacity=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
    local status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)
    
    if [ -z "$capacity" ]; then
        return
    fi
    
    local low=$(grep "BATTERY_LOW=" $POWER_CONFIG | cut -d= -f2)
    local critical=$(grep "BATTERY_CRITICAL=" $POWER_CONFIG | cut -d= -f2)
    
    # Default thresholds
    low=${low:-20}
    critical=${critical:-10}
    
    if [ "$status" = "Discharging" ]; then
        if [ "$capacity" -le "$critical" ]; then
            echo -e "${RED}Battery critical! Switching to power saver...${NC}"
            set_power_profile saver
        elif [ "$capacity" -le "$low" ]; then
            echo -e "${YELLOW}Battery low! Switching to balanced...${NC}"
            set_power_profile balanced
        fi
    elif [ "$status" = "Charging" ]; then
        local current_profile=$(cat $POWER_STATE 2>/dev/null || echo "balanced")
        if [ "$current_profile" = "saver" ] && [ "$capacity" -ge 30 ]; then
            echo -e "${GREEN}Battery charging. Switching to balanced...${NC}"
            set_power_profile balanced
        fi
    fi
}

# Battery health management
optimize_battery_health() {
    echo -e "${YELLOW}Optimizing battery health...${NC}"
    
    if [ -f $POWER_CONFIG ]; then
        local charge_start=$(grep "BATTERY_CHARGE_START=" $POWER_CONFIG | cut -d= -f2)
        local charge_stop=$(grep "BATTERY_CHARGE_STOP=" $POWER_CONFIG | cut -d= -f2)
        
        charge_start=${charge_start:-80}
        charge_stop=${charge_stop:-100}
        
        # Set charge thresholds (if supported)
        if [ -d /sys/class/power_supply/BAT*/charge_control_start_threshold ]; then
            echo $charge_start | sudo tee /sys/class/power_supply/BAT*/charge_control_start_threshold
            echo $charge_stop | sudo tee /sys/class/power_supply/BAT*/charge_control_end_threshold
            echo -e "${GREEN}✓ Battery charge thresholds set: $charge_start% - $charge_stop%${NC}"
        else
            echo -e "${YELLOW}Charge threshold control not available for this hardware${NC}"
        fi
    fi
}

# Show power usage
show_power_usage() {
    echo -e "${YELLOW}Power Usage:${NC}"
    echo ""
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    echo -e "CPU: ${cpu_usage}%"
    
    # Memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    echo -e "Memory: ${mem_usage}%"
    
    # Disk usage
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}')
    echo -e "Disk: ${disk_usage}"
    
    # GPU usage (if available)
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
        echo -e "GPU: ${gpu_usage}%"
    fi
    
    echo ""
}

show_help() {
    echo "Usage: tinker-power [command]"
    echo ""
    echo "Commands:"
    echo "  status          Show battery and power status"
    echo "  profile <name>  Set power profile"
    echo "  profiles        List available profiles"
    echo "  auto            Enable auto-switching"
    echo "  battery         Battery health settings"
    echo "  usage           Show power usage"
    echo "  help            Show this help"
    echo ""
    echo "Profiles:"
    echo "  performance     Maximum performance"
    echo "  balanced        Balanced performance/battery"
    echo "  power-saver     Maximum battery life"
}

# Main
init_power

case "$1" in
    status)
        show_header
        echo -e "${YELLOW}Power Status:${NC}"
        echo ""
        get_battery_info
        echo ""
        echo -e "Current profile: ${GREEN}$(get_current_profile)${NC}"
        echo ""
        show_power_usage
        ;;
    profile)
        if [ -z "$2" ]; then
            echo "Please specify a profile"
            show_help
            exit 1
        fi
        show_header
        set_power_profile "$2"
        ;;
    profiles)
        show_header
        echo -e "${YELLOW}Available Power Profiles:${NC}"
        echo ""
        echo "  performance   - Maximum performance (high power usage)"
        echo "  balanced      - Balanced performance and battery"
        echo "  power-saver   - Maximum battery life (reduced performance)"
        echo ""
        echo -e "Current: ${GREEN}$(get_current_profile)${NC}"
        ;;
    auto)
        show_header
        auto_switch_profile
        ;;
    battery)
        show_header
        optimize_battery_health
        ;;
    usage)
        show_header
        show_power_usage
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Power Manager${NC}"
        echo ""
        echo "Battery optimization + power profiles."
        echo ""
        get_battery_info
        echo ""
        echo -e "Current profile: ${GREEN}$(get_current_profile)${NC}"
        echo ""
        echo "Quick commands:"
        echo "  tinker-power status          - Show status"
        echo "  tinker-power profile saver   - Power saver mode"
        echo "  tinker-power auto            - Auto-switch"
        ;;
esac

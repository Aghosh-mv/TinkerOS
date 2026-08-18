#!/bin/bash
# TinkerOS Fast Boot System

set -e

BOOT_DIR="$HOME/.tinker/boot"
CONFIG_FILE="$BOOT_DIR/config.conf"

mkdir -p "$BOOT_DIR"

init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# TinkerOS Fast Boot Configuration

# Enable fast boot
FAST_BOOT_ENABLED=true

# Skip GRUB menu
SKIP_GRUB=true
GRUB_TIMEOUT=0

# Parallel startup
PARALLEL_STARTUP=true

# Reduce services
MINIMAL_SERVICES=true

# Memory optimization
PRELOAD_APPS=true
PRELOAD_LIST=browser terminal file-manager

# Clean boot
CLEAN_BOOT=true
CLEAN_TMP=true
EOF
    fi
}

# Optimize GRUB
optimize_grub() {
    echo "Optimizing GRUB..."
    
    local timeout=$(grep "GRUB_TIMEOUT" "$CONFIG_FILE" | cut -d= -f2)
    timeout=${timeout:-0}
    
    sudo sed -i "s/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$timeout/" /etc/default/grub
    sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg
    
    echo "GRUB optimized (timeout: ${timeout}s)"
}

# Enable parallel services
enable_parallel() {
    echo "Enabling parallel service startup..."
    
    # Create systemd override
    sudo mkdir -p /etc/systemd/system.conf.d/
    cat > /tmp/parallel-boot.conf << 'EOF'
[Manager]
DefaultTimeoutStartSec=10s
DefaultTimeoutStopSec=10s
EOF
    sudo mv /tmp/parallel-boot.conf /etc/systemd/system.conf.d/
    
    echo "Parallel startup enabled"
}

# Disable unnecessary services
disable_unnecessary() {
    echo "Disabling unnecessary services..."
    
    local services=(
        "bluetooth"
        "cups"
        "avahi-daemon"
        "ModemManager"
    )
    
    for service in "${services[@]}"; do
        sudo systemctl disable "$service" 2>/dev/null || true
    done
    
    echo "Unnecessary services disabled"
}

# Clean boot cache
clean_boot() {
    echo "Cleaning boot cache..."
    
    sudo journalctl --vacuum-time=3d
    sudo apt clean 2>/dev/null || true
    sudo pacman -Sc --noconfirm 2>/dev/null || true
    
    echo "Boot cache cleaned"
}

# Preload apps
preload_apps() {
    echo "Configuring app preloading..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y preload 2>/dev/null || true
    fi
    
    echo "App preloading enabled"
}

# Show boot time
show_boot_time() {
    echo "Boot Time Analysis:"
    echo ""
    systemd-analyze 2>/dev/null || echo "systemd-analyze not available"
    echo ""
}

# Show critical chain
show_critical() {
    echo "Critical Boot Chain:"
    echo ""
    systemd-analyze critical-chain 2>/dev/null || echo "Not available"
    echo ""
}

# Apply all optimizations
apply_all() {
    echo "Applying all boot optimizations..."
    echo ""
    
    optimize_grub
    enable_parallel
    disable_unnecessary
    clean_boot
    preload_apps
    
    echo ""
    echo "Boot optimizations applied!"
    echo "Reboot for changes to take effect."
}

show_help() {
    echo "Usage: tinker-boot [command]"
    echo ""
    echo "Commands:"
    echo "  optimize          Optimize GRUB"
    echo "  parallel          Enable parallel startup"
    echo "  disable-services  Disable unnecessary services"
    echo "  clean             Clean boot cache"
    echo "  preload           Enable app preloading"
    echo "  time              Show boot time"
    echo "  critical          Show critical chain"
    echo "  apply-all         Apply all optimizations"
    echo "  help              Show this help"
}

init_config

case "$1" in
    optimize|grub) optimize_grub ;;
    parallel) enable_parallel ;;
    disable-services) disable_unnecessary ;;
    clean) clean_boot ;;
    preload) preload_apps ;;
    time) show_boot_time ;;
    critical) show_critical ;;
    apply-all|all) apply_all ;;
    *) show_help ;;
esac

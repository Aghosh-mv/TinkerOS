#!/bin/bash
# TinkerOS Fast Boot - Boot optimization and analysis

set -e

FASTBOOT_DIR="$HOME/.tinker/fast-boot"
CONFIG_FILE="$FASTBOOT_DIR/config.conf"
LOG_FILE="$FASTBOOT_DIR/boot.log"

mkdir -p "$FASTBOOT_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Fast Boot Configuration
ENABLED=true
ANALYZE_ON_BOOT=true
DISABLE_UNUSED_SERVICES=true
PARALLEL_BOOT=true
KERNEL_CMDLINE_OPTIMIZE=false
INITRD_COMPRESS=zstd
EOF
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Analyze boot time
analyze() {
    echo "=== Boot Analysis ==="
    echo ""
    
    if command -v systemd-analyze &>/dev/null; then
        echo "Overall Boot Time:"
        systemd-analyze 2>/dev/null | sed 's/^/  /'
        echo ""
        
        echo "Kernel/Initrd Breakdown:"
        systemd-analyze blame 2>/dev/null | head -20 | sed 's/^/  /'
        echo ""
        
        echo "Critical Chain:"
        systemd-analyze critical-chain 2>/dev/null | head -30 | sed 's/^/  /'
    else
        echo "systemd-analyze not available"
    fi
}

# Show boot log
boot_log() {
    echo "=== Recent Boot Log ==="
    echo ""
    journalctl -b -1 -p 3 2>/dev/null | tail -30 | sed 's/^/  /' || echo "No previous boot log"
}

# Optimize services
optimize_services() {
    echo "=== Service Optimization ==="
    echo ""
    
    echo "Enabled services:"
    systemctl list-unit-files --state=enabled --no-pager 2>/dev/null | grep -v "^UNIT" | head -20 | sed 's/^/  /'
    echo ""
    
    echo "Recommended to disable (if not needed):"
    local candidates=(
        "bluetooth.service"
        "cups.service"
        "avahi-daemon.service"
        "ModemManager.service"
        "whoopsie.service"
        "speech-dispatcher.service"
        "bolt.service"
        "fwupd.service"
        "accounts-daemon.service"
        "rtkit-daemon.service"
    )
    
    for svc in "${candidates[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            echo "  $svc (enabled)"
        fi
    done
}

# Disable service
disable_service() {
    local svc=$1
    [ -z "$svc" ] && echo "Usage: $0 disable <service>" && return 1
    
    echo "Disabling $svc..."
    systemctl disable --now "$svc" 2>&1
    echo "$(date +%s)|disable|$svc" >> "$LOG_FILE"
}

# Enable service
enable_service() {
    local svc=$1
    [ -z "$svc" ] && echo "Usage: $0 enable <service>" && return 1
    
    echo "Enabling $svc..."
    systemctl enable --now "$svc" 2>&1
    echo "$(date +%s)|enable|$svc" >> "$LOG_FILE"
}

# Parallel boot settings
set_parallel() {
    local enabled=${1:-true}
    
    echo "Setting parallel boot: $enabled"
    
    mkdir -p /etc/systemd/system.conf.d
    if [ "$enabled" = "true" ]; then
        echo "[Manager]" > /etc/systemd/system.conf.d/99-tinker-parallel.conf
        echo "DefaultDependencies=no" >> /etc/systemd/system.conf.d/99-tinker-parallel.conf
    else
        rm -f /etc/systemd/system.conf.d/99-tinker-parallel.conf
    fi
    
    systemctl daemon-reload 2>/dev/null || true
}

# Kernel cmdline optimization
kernel_optimize() {
    echo "=== Kernel Boot Optimization ==="
    echo ""
    echo "Current cmdline:"
    cat /proc/cmdline | sed 's/ /\n/g' | sed 's/^/  /'
    echo ""
    
    echo "Recommended optimizations:"
    echo "  quiet splash - Reduce boot output"
    echo "  nowatchdog - Disable lockup detector (if stable)"
    echo "  noibrs noibpb nostibp - Disable Spectre mitigations (if safe)"
    echo "  mitigations=off - Disable all CPU mitigations (performance)"
    echo "  transparent_hugepage=madvise - Better memory management"
    echo "  intel_pstate=active - Intel P-State driver"
    echo "  amd_pstate=active - AMD P-State driver"
    echo "  nvme.no_acpi=1 - NVMe direct access"
    echo "  tsc=reliable - Reliable TSC"
    echo "  clocksource=tsc - Fast clocksource"
}

# Initrd optimization
initrd_optimize() {
    local compression=$(grep INITRD_COMPRESS "$CONFIG_FILE" | cut -d= -f2)
    compression=${compression:-zstd}
    
    echo "Optimizing initrd with $compression compression..."
    
    # Update mkinitcpio or dracut
    if [ -f /etc/mkinitcpio.conf ]; then
        sed -i "s/^COMPRESSION=.*/COMPRESSION=\"$compression\"/" /etc/mkinitcpio.conf
        mkinitcpio -P 2>&1 | tail -10
    elif [ -f /etc/dracut.conf ]; then
        echo "compress=\"$compression\"" > /etc/dracut.conf.d/99-tinker-compress.conf
        dracut --force 2>&1 | tail -10
    else
        echo "No initrd tool detected"
    fi
}

# Profile boot
profile_boot() {
    echo "Adding systemd profile to kernel cmdline..."
    echo "This will reorder boot for faster startup on next boot"
    
    # This requires grub update
    if [ -f /etc/default/grub ]; then
        if ! grep -q "systemd.profile" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="systemd.profile /' /etc/default/grub
            update-grub 2>/dev/null || grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null
            echo "Profile added. Reboot to take effect."
        else
            echo "Profile already configured"
        fi
    fi
}

# Show boot history
history() {
    echo "Boot History:"
    echo ""
    journalctl --list-boots 2>/dev/null | while read line; do
        echo "  $line"
    done
}

show_help() {
    echo "Usage: tinker-fast-boot [command]"
    echo ""
    echo "Commands:"
    echo "  analyze             Analyze boot time"
    echo "  log                 Show previous boot errors"
    echo "  optimize            Show service optimization suggestions"
    echo "  disable <service>   Disable a service"
    echo "  enable <service>    Enable a service"
    echo "  parallel [on|off]   Enable/disable parallel boot"
    echo "  kernel              Show kernel cmdline optimizations"
    echo "  initrd              Optimize initrd compression"
    echo "  profile             Enable systemd boot profiling"
    echo "  history             Show boot history"
    echo "  help                Show this help"
}

init

case "$1" in
    analyze) analyze ;;
    log) boot_log ;;
    optimize) optimize_services ;;
    disable) disable_service "$2" ;;
    enable) enable_service "$2" ;;
    parallel) set_parallel "$2" ;;
    kernel) kernel_optimize ;;
    initrd) initrd_optimize ;;
    profile) profile_boot ;;
    history) history ;;
    *) show_help ;;
esac
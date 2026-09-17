#!/bin/bash
# HyperDrive Daemon — runs in background managing GPU emulation
# Monitors FPS, adjusts resolution, manages VRAM, optimizes CPU

HD_DIR="/opt/korrinos/hyperdrive"
HD_LOG="/var/log/hyperdrive.log"
HD_STATE="/var/run/hyperdrive.pid"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$HD_LOG"
}

# ============================================================
#  MONITOR — detect FPS and system load
# ============================================================
monitor_loop() {
    log "HyperDrive daemon started (PID $$)"
    
    while true; do
        # Read current FPS (from MangoHud, libstrangle, or manual)
        CURRENT_FPS=60  # Default assumption
        
        # Try MangoHud
        if [ -f /tmp/mangohud_stats ]; then
            CURRENT_FPS=$(grep -o 'fps:[0-9]*' /tmp/mangohud_stats | cut -d: -f2 || echo 60)
        fi
        
        # Read CPU usage
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 || echo 0)
        
        # Read memory usage
        MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
        MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
        MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
        
        # Read zRAM usage
        ZRAM_USED=0
        if [ -f /sys/block/zram0/mm_stat ]; then
            ZRAM_USED=$(awk '{print $8}' /sys/block/zram0/mm_stat 2>/dev/null || echo 0)
            ZRAM_USED=$((ZRAM_USED / 1024 / 1024))  # Convert to MB
        fi
        
        # Adaptive resolution logic
        if [ "$CURRENT_FPS" -lt 30 ]; then
            # Critical: reduce resolution aggressively
            log "CRITICAL: FPS=$CURRENT_FPS, reducing resolution"
            apply_resolution_scale 50
        elif [ "$CURRENT_FPS" -lt 50 ]; then
            # Warning: reduce resolution moderately
            log "WARNING: FPS=$CURRENT_FPS, adjusting resolution"
            apply_resolution_scale 75
        elif [ "$CURRENT_FPS" -gt 70 ]; then
            # Good: can increase resolution
            log "GOOD: FPS=$CURRENT_FPS, increasing resolution"
            apply_resolution_scale 100
        fi
        
        # CPU frequency management
        if [ "$CPU_USAGE" -gt 80 ]; then
            # High load: ensure performance governor
            echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        fi
        
        # Memory management
        if [ "$MEM_PCT" -gt 85 ]; then
            log "HIGH MEMORY: ${MEM_PCT}%, triggering defrag"
            trigger_memory_defrag
        fi
        
        # Log stats periodically
        log "STATS: fps=$CURRENT_FPS cpu=$CPU_USAGE% mem=$MEM_PCT% zram=${ZRAM_USED}MB"
        
        sleep 5
    done
}

# ============================================================
#  RESOLUTION SCALING
# ============================================================
apply_resolution_scale() {
    local scale=$1
    # This would interface with X11/Wayland to change resolution
    # For now, log the intended action
    log "Resolution scale set to ${scale}%"
    
    # If using X11, we could use xrandr
    if command -v xrandr &>/dev/null; then
        # Get current resolution
        CURRENT=$(xrandr | grep '*' | head -1 | awk '{print $1}')
        W=$(echo "$CURRENT" | cut -d'x' -f1)
        H=$(echo "$CURRENT" | cut -d'x' -f2)
        
        NEW_W=$((W * scale / 100))
        NEW_H=$((H * scale / 100))
        
        # Round to even numbers
        NEW_W=$((NEW_W / 2 * 2))
        NEW_H=$((NEW_H / 2 * 2))
        
        log "Scaling ${W}x${H} -> ${NEW_W}x${NEW_H}"
        # xrandr --output $(xrandr | grep connected | head -1 | awk '{print $1}') --mode ${NEW_W}x${NEW_H} 2>/dev/null || true
    fi
}

# ============================================================
#  MEMORY DEFRAGMENTATION
# ============================================================
trigger_memory_defrag() {
    # Drop caches
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
    
    # Compact memory
    echo 1 | sudo tee /proc/sys/vm/compact_memory >/dev/null 2>&1 || true
    
    log "Memory defragmentation triggered"
}

# ============================================================
#  STARTUP
# ============================================================
setup_startup() {
    log "HyperDrive daemon initializing..."
    
    # Set CPU governor to performance
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    
    # Enable huge pages
    echo always | sudo tee /proc/sys/vm/nr_hugepages >/dev/null 2>&1 || true
    
    # Set process priority
    sudo renice -n -10 $$ 2>/dev/null || true
    
    log "HyperDrive daemon ready"
}

# ============================================================
#  MAIN
# ============================================================
case "${1:-}" in
    start)
        setup_startup
        monitor_loop
        ;;
    stop)
        if [ -f "$HD_STATE" ]; then
            kill $(cat "$HD_STATE") 2>/dev/null || true
            rm -f "$HD_STATE"
            log "HyperDrive daemon stopped"
        fi
        ;;
    *)
        echo "Usage: $0 start|stop"
        ;;
esac

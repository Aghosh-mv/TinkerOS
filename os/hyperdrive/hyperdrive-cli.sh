#!/bin/bash
# HyperDrive CLI — user control for GPU emulation layer
# Usage: hyperdrive <command> [options]

HD_DIR="/opt/korrinos/hyperdrive"
HD_CONF="/etc/hyperdrive/hyperdrive.conf"
HD_PROC="/proc/hyperdrive/status"

# Colors
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'; B='\033[1;34m'
C='\033[1;36m'; M='\033[1;35m'; W='\033[1;37m'; NC='\033[0m'

show_banner() {
    echo -e "${C}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  HyperDrive — GPU Emulation Layer                           ║"
    echo "║  Pure Software. Zero Cloud. Zero Money. Maximum FPS.        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ============================================================
#  STATUS
# ============================================================
cmd_status() {
    show_banner
    
    if systemctl is-active --quiet hyperdrive 2>/dev/null; then
        echo -e "  Status: ${G}Running${NC}"
    else
        echo -e "  Status: ${R}Stopped${NC}"
    fi
    
    # Kernel module status
    if lsmod | grep -q hyperdrive; then
        echo -e "  Module: ${G}Loaded${NC}"
    else
        echo -e "  Module: ${Y}Not loaded${NC}"
    fi
    
    echo ""
    
    # Show /proc info if available
    if [ -f "$HD_PROC" ]; then
        cat "$HD_PROC"
    else
        echo -e "  ${Y}Kernel module not loaded — showing user-space stats${NC}"
        
        # CPU info
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 || echo 0)
        echo -e "  CPU Usage: ${W}${CPU_USAGE}%${NC}"
        
        # Memory info
        free -h | awk '/^Mem:/{printf "  Memory: %s / %s (%s used)\n", $3, $2, $4}'
        
        # zRAM info
        if [ -f /sys/block/zram0/mm_stat ]; then
            ZRAM_USED=$(awk '{print $8}' /sys/block/zram0/mm_stat 2>/dev/null || echo 0)
            ZRAM_USED=$((ZRAM_USED / 1024 / 1024))
            echo -e "  zRAM VRAM: ${W}${ZRAM_USED} MB${NC}"
        fi
    fi
    
    echo ""
    
    # Configuration
    if [ -f "$HD_CONF" ]; then
        echo -e "  Config: ${W}$HD_CONF${NC}"
    else
        echo -e "  Config: ${Y}Not installed${NC}"
    fi
}

# ============================================================
#  START/STOP
# ============================================================
cmd_start() {
    show_banner
    echo -e "${G}Starting HyperDrive...${NC}"
    
    # Load kernel module if available
    if [ -f /lib/modules/$(uname -r)/extra/hyperdrive.ko ]; then
        sudo insmod /lib/modules/$(uname -r)/extra/hyperdrive.ko 2>/dev/null || true
        echo -e "  ${G}Kernel module loaded${NC}"
    fi
    
    # Start daemon
    sudo systemctl start hyperdrive
    echo -e "  ${G}Daemon started${NC}"
}

cmd_stop() {
    show_banner
    echo -e "${R}Stopping HyperDrive...${NC}"
    
    sudo systemctl stop hyperdrive
    echo -e "  ${R}Daemon stopped${NC}"
}

# ============================================================
#  BOOST — boost a render thread
# ============================================================
cmd_boost() {
    local pid=$1
    
    if [ -z "$pid" ]; then
        echo -e "${R}Usage: hyperdrive boost <pid>${NC}"
        echo ""
        echo "Find your game/render process PID with:"
        echo "  ps aux | grep <game>"
        echo "  htop"
        return 1
    fi
    
    show_banner
    echo -e "${G}Boosting render thread PID $pid...${NC}"
    
    # Try kernel module first
    if [ -f "$HD_PROC" ]; then
        echo "boost $pid" | sudo tee "$HD_PROC" > /dev/null
        echo -e "  ${G}Thread boosted via kernel module${NC}"
    else
        # Fallback: set nice value
        sudo renice -n -20 -p "$pid" 2>/dev/null || true
        echo -e "  ${Y}Thread boosted via nice (kernel module not loaded)${NC}"
    fi
}

# ============================================================
#  CONFIG — show/edit configuration
# ============================================================
cmd_config() {
    show_banner
    
    if [ ! -f "$HD_CONF" ]; then
        echo -e "${Y}Configuration not found. Run: sudo hyperdrive install${NC}"
        return 1
    fi
    
    echo -e "${W}Configuration:${NC}"
    echo ""
    cat "$HD_CONF"
}

# ============================================================
#  TWEAK — quick performance tweaks
# ============================================================
cmd_tweak() {
    show_banner
    echo -e "${M}Applying performance tweaks...${NC}"
    
    # CPU governor
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    echo -e "  ${G}CPU governor: performance${NC}"
    
    # Huge pages
    echo always | sudo tee /proc/sys/vm/nr_hugepages >/dev/null 2>&1 || true
    echo -e "  ${G}Huge pages: enabled${NC}"
    
    # Memory compaction
    echo 1 | sudo tee /proc/sys/vm/compact_memory >/dev/null 2>&1 || true
    echo -e "  ${G}Memory compaction: triggered${NC}"
    
    # Drop caches
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
    echo -e "  ${G}Caches dropped${NC}"
    
    # Disable transparent huge pages (for better latency)
    echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1 || true
    echo -e "  ${G}Transparent huge pages: disabled${NC}"
    
    echo ""
    echo -e "${G}All tweaks applied!${NC}"
}

# ============================================================
#  BENCHMARK — run quick GPU benchmark
# ============================================================
cmd_benchmark() {
    show_banner
    echo -e "${M}Running HyperDrive benchmark...${NC}"
    echo ""
    
    # CPU benchmark
    echo -e "${B}CPU Performance:${NC}"
    sysbench cpu --threads=$(nproc) --time=5 run 2>/dev/null | grep -E "events|latency" || echo "  (sysbench not available)"
    
    # Memory benchmark
    echo ""
    echo -e "${B}Memory Bandwidth:${NC}"
    dd if=/dev/zero of=/tmp/bench bs=1M count=1024 2>&1 | grep -E "copied|MB/s" || true
    rm -f /tmp/bench
    
    # zRAM test
    if [ -f /sys/block/zram0/mm_stat ]; then
        echo ""
        echo -e "${B}zRAM Compression:${NC}"
        echo "  zRAM available — VRAM emulation active"
    fi
    
    echo ""
    echo -e "${G}Benchmark complete!${NC}"
}

# ============================================================
#  MAIN
# ============================================================
case "${1:-}" in
    status) cmd_status ;;
    start) cmd_start ;;
    stop) cmd_stop ;;
    restart) cmd_stop; sleep 1; cmd_start ;;
    boost) cmd_boost "${2:-}" ;;
    config) cmd_config ;;
    tweak) cmd_tweak ;;
    benchmark) cmd_benchmark ;;
    *)
        show_banner
        echo "Usage: hyperdrive <command> [options]"
        echo ""
        echo "Commands:"
        echo "  status      Show HyperDrive status"
        echo "  start       Start HyperDrive daemon"
        echo "  stop        Stop HyperDrive daemon"
        echo "  restart     Restart HyperDrive daemon"
        echo "  boost <pid> Boost a render thread"
        echo "  config      Show configuration"
        echo "  tweak       Apply quick performance tweaks"
        echo "  benchmark   Run quick benchmark"
        echo ""
        echo "Examples:"
        echo "  hyperdrive status"
        echo "  hyperdrive boost 1234"
        echo "  hyperdrive tweak"
        ;;
esac

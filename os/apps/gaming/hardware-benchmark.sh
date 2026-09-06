#!/bin/bash
# TinkerOS Hardware Benchmark - Measure CPU, GPU, memory, and disk performance

set -e

HB_DIR="$HOME/.tinker/benchmark"
RESULTS_FILE="$HB_DIR/results.log"
mkdir -p "$HB_DIR"

# CPU benchmark
bench_cpu() {
    echo "=== CPU Benchmark ==="
    echo ""
    local cores=$(nproc)
    echo "  Cores: $cores"
    
    # Use sysbench if available
    if command -v sysbench &>/dev/null; then
        echo "  Running CPU test (prime numbers, 10s)..."
        local out=$(sysbench cpu --cpu-max-prime=20000 --threads=$cores run 2>/dev/null)
        local events=$(echo "$out" | grep "total number of events" | awk '{print $NF}')
        local eps=$(echo "$out" | grep "events per second" | awk '{print $NF}')
        echo "  Events: $events ($eps events/s)"
        echo "$(date +%s)|cpu|events_per_s|$eps" >> "$RESULTS_FILE"
    else
        echo "  sysbench not installed. Running native test..."
        # Native test: calculate large prime count
        local start=$(date +%s%N)
        local count=0
        for ((i=2; i<=200000; i+=1)); do
            local is_prime=1
            for ((j=2; j*j<=i; j+=1)); do
                if [ $((i%j)) -eq 0 ]; then is_prime=0; break; fi
            done
            [ $is_prime -eq 1 ] && count=$((count+1))
        done
        local end=$(date +%s%N)
        local dur=$(( (end-start)/1000000 ))
        echo "  Primes to 200000: $count in ${dur}ms"
        echo "$(date +%s)|cpu|primes|$count|${dur}ms" >> "$RESULTS_FILE"
    fi
}

# Memory benchmark
bench_mem() {
    echo "=== Memory Benchmark ==="
    echo ""
    local mem=$(free -h | awk '/Mem:/ {print $2}')
    echo "  Total memory: $mem"
    
    if command -v sysbench &>/dev/null; then
        echo "  Running memory test (10s)..."
        local out=$(sysbench memory --memory-block-size=8K --memory-total-size=1G run 2>/dev/null)
        local ops=$(echo "$out" | grep "Total operations" | awk '{print $NF}')
        local transfer=$(echo "$out" | grep "transferred" | awk '{print $4, $5}')
        echo "  Operations: $ops"
        echo "  Transfer: $transfer"
        echo "$(date +%s)|mem|ops|$ops|$transfer" >> "$RESULTS_FILE"
    else
        echo "  sysbench not installed (sudo apt install sysbench)"
    fi
}

# Disk benchmark
bench_disk() {
    echo "=== Disk Benchmark ==="
    echo ""
    
    # Read test
    echo "  Sequential read test (1GB)..."
    local start=$(date +%s%N)
    dd if=/ of=/dev/null bs=1M count=1024 2>/dev/null
    local end=$(date +%s%N)
    local dur=$(( (end-start)/1000000000 ))
    [ $dur -lt 1 ] && dur=1
    local read_speed=$((1024/dur))
    echo "  Read speed: ~${read_speed} MB/s"
    
    # Write test
    echo "  Write test (512MB)..."
    local tmpfile=$(mktemp)
    sync
    start=$(date +%s%N)
    dd if=/dev/zero of="$tmpfile" bs=1M count=512 oflag=sync 2>/dev/null
    end=$(date +%s%N)
    dur=$(( (end-start)/1000000000 ))
    [ $dur -lt 1 ] && dur=1
    local write_speed=$((512/dur))
    echo "  Write speed: ~${write_speed} MB/s"
    rm -f "$tmpfile"
    
    echo "$(date +%s)|disk|read|${read_speed}|write|${write_speed}" >> "$RESULTS_FILE"
    
    # Sequential dd precision
    if command -v fio &>/dev/null; then
        echo ""
        echo "  fio detailed results not run (manual op)"
    fi
}

# GPU benchmark
bench_gpu() {
    echo "=== GPU Benchmark ==="
    echo ""
    echo "GPU: $(lspci | grep -iE 'vga|3d' | head -1 | cut -d: -f3- | xargs)"
    echo ""
    
    if command -v glmark2 &>/dev/null; then
        echo "  glmark2 (OpenGL 2.0)..."
        local score=$(glmark2 --run-forever 2>/dev/null | grep "glmark2 Score" | awk '{print $NF}' | head -1)
        echo "  Score: ${score:-not captured}"
        [ -n "$score" ] && echo "$(date +%s)|gpu|glmark2|$score" >> "$RESULTS_FILE"
    elif command -v vkmark &>/dev/null; then
        echo "  vkmark (Vulkan)..."
        vkmark --defaults 2>/dev/null | grep -E "Score|scene" | head -5 | sed 's/^/    /'
    else
        echo "  No GPU benchmark tool (install glmark2 or vkmark)"
    fi
}

# Network benchmark
bench_network() {
    echo "=== Network Benchmark ==="
    echo ""
    [ -n "$(command -v iperf3)" ] && echo "  iperf3 available for LAN tests: iperf3 -c <server>" || echo "  iperf3 not installed"
    echo "  Internet test:"
    timeout 5 curl -s -o /dev/null -w "  Download speed: %{speed_download} bytes/s\n" https://example.com 2>/dev/null || echo "  Offline"
}

# Overall benchmark
bench_all() {
    echo "=== TinkerOS Full Hardware Benchmark ==="
    echo ""
    bench_cpu
    echo ""
    bench_mem
    echo ""
    bench_disk
    echo ""
    bench_gpu
    echo ""
    bench_network
    echo ""
    echo "Results saved to: $RESULTS_FILE"
}

# Show history
history() {
    echo "=== Benchmark History ==="
    echo ""
    [ -f "$RESULTS_FILE" ] && tail -30 "$RESULTS_FILE" | sed 's/^/  /' || echo "  No results yet"
}

show_help() {
    echo "Usage: tinker-benchmark [command]"
    echo ""
    echo "Commands:"
    echo "  all         Run all benchmarks"
    echo "  cpu         CPU benchmark"
    echo "  mem         Memory benchmark"
    echo "  disk        Disk benchmark"
    echo "  gpu         GPU benchmark"
    echo "  network     Network benchmark"
    echo "  history     Show benchmark history"
    echo "  help        Show this help"
}

case "$1" in
    all) bench_all ;;
    cpu) bench_cpu ;;
    mem) bench_mem ;;
    disk) bench_disk ;;
    gpu) bench_gpu ;;
    network) bench_network ;;
    history) history ;;
    *) show_help ;;
esac
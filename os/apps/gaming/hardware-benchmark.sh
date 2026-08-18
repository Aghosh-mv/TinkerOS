#!/bin/bash
# TinkerOS Hardware Benchmark
echo "=== TinkerOS Hardware Benchmark ==="
echo ""
echo "CPU single-thread test:"
timeout 5 bash -c 'a=0; for i in $(seq 1 1000000); do a=$((a+i)); done; echo "  completed 1M ops"' 2>/dev/null || echo "  (skipped)"
echo ""
echo "Memory bandwidth (dd):"
dd if=/dev/zero of=/dev/null bs=1M count=200 2>&1 | tail -1 | sed 's/^/  /'
echo ""
echo "Disk write speed:"
dd if=/dev/zero of=/tmp/tinker-bench bs=1M count=200 2>&1 | tail -1 | sed 's/^/  /' && rm -f /tmp/tinker-bench

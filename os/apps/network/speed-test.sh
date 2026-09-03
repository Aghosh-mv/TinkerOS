#!/bin/bash
# TinkerOS Speed Test - Internet bandwidth measurement and analysis

set -e

ST_DIR="$HOME/.tinker/speedtest"
RESULTS_FILE="$ST_DIR/results.log"
mkdir -p "$ST_DIR"

# Measure download speed by fetching a known file
test_download() {
    local url=$1
    local label=$2
    local bytes=0
    local seconds=0
    
    echo -n "  $label: "
    if command -v curl &>/dev/null; then
        local out=$(curl -s -o /dev/null -w "%{speed_download} %{time_total}" --max-time 10 "$url" 2>/dev/null)
        printf "%.2f MB/s\n" "$(echo "$out" | awk '{print $1/1048576}')"
        echo "$out" | awk '{print $1}' 
    elif command -v wget &>/dev/null; then
        local out=$(wget -O /dev/null --timeout=10 "$url" 2>&1 | grep "(" | tail -1)
        echo "$out" | sed 's/^/  /'
        echo "0"
    else
        echo "no download tool (curl/wget)"
        echo "0"
    fi
}

# Measure upload speed using curl
test_upload() {
    local size=${1:-10}  # MB
    echo -n "  Upload ($size MB): "
    if command -v curl &>/dev/null; then
        local tmp=$(mktemp)
        dd if=/dev/urandom of="$tmp" bs=1M count=$size 2>/dev/null
        local out=$(curl -s -o /dev/null -w "%{speed_upload} %{time_total}" --max-time 20 -F "file=@$tmp" https://httpbin.org/post 2>/dev/null)
        printf "%.2f MB/s\n" "$(echo "$out" | awk '{print $1/1048576}')"
        rm -f "$tmp"
    else
        echo "no curl"
    fi
}

# Ping/latency test
test_ping() {
    echo "  Ping (ms):"
    for host in 1.1.1.1 8.8.8.8 google.com; do
        local t=$(ping -c 3 -W 2 "$host" 2>/dev/null | grep "min/avg/max" | awk -F= '{print $2}' | cut -d/ -f2)
        printf "    %-12s avg: %s ms\n" "$host" "${t:-N/A}"
    done
}

# Measure jitter and packet loss
test_quality() {
    echo "  Quality (jitter/loss):"
    for host in 8.8.8.8 1.1.1.1; do
        local result=$(ping -c 10 -W 2 "$host" 2>/dev/null)
        local loss=$(echo "$result" | tail -1 | grep -o "[0-9]*% packet loss")
        local jitter=$(echo "$result" | grep "min/avg/max" | awk -F= '{print $2}' | cut -d/ -f3 2>/dev/null)
        printf "    %-12s loss: %s\n" "$host" "${loss:-100% packet loss}"
    done
}

# Run full test
run_test() {
    local ts=$(date +%H:%M:%S)
    echo "=== TinkerOS Speed Test ($ts) ==="
    echo ""
    
    echo "Download tests:"
    d1=$(test_download "https://proof.ovh.net/files/10Mb.dat" "10MB (OVH)")
    d2=$(test_download "https://cloudflare.com/cdn-cgi/trace" "CF trace")
    
    echo ""
    test_upload 10
    
    echo ""
    test_ping
    echo ""
    test_quality
    
    echo ""
    echo "Saving result..."
    echo "$(date +%s)|${d1}" >> "$RESULTS_FILE" 2>/dev/null || true
    echo "Done."
}

# Show history
history() {
    echo "=== Speed Test History ==="
    echo ""
    if [ -f "$RESULTS_FILE" ]; then
        tail -20 "$RESULTS_FILE" | while read line; do
            local ts=$(echo $line | cut -d'|' -f1)
            local speed=$(echo $line | cut -d'|' -f2)
            echo "  $(date -d @$ts '+%Y-%m-%d %H:%M' 2>/dev/null || echo $ts)  ${speed} bytes/s"
        done
    else
        echo "  No results yet"
    fi
}

show_help() {
    echo "Usage: tinker-speedtest [command]"
    echo ""
    echo "Commands:"
    echo "  run|test            Run full speed test"
    echo "  download            Test download speed"
    echo "  upload              Test upload speed"
    echo "  ping                Test latency"
    echo "  quality             Test jitter/loss"
    echo "  history             Show test history"
    echo "  help                Show this help"
}

case "$1" in
    run|test) run_test ;;
    download) test_download "https://proof.ovh.net/files/10Mb.dat" "10MB" ;;
    upload) test_upload "${2:-10}" ;;
    ping) test_ping ;;
    quality) test_quality ;;
    history) history ;;
    *) show_help ;;
esac
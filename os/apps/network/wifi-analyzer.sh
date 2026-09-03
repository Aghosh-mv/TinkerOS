#!/bin/bash
# TinkerOS Wi-Fi Analyzer - Signal strength, channel analysis, and optimization

set -e

WA_DIR="$HOME/.tinker/wifi"
mkdir -p "$WA_DIR"

# Scan networks
scan() {
    echo "=== Wi-Fi Networks ==="
    echo ""
    
    if command -v nmcli &>/dev/null; then
        nmcli -f "SSID,SIGNAL,CHAN,SECURITY,FREQ,RATE" device wifi list 2>/dev/null | sed 's/^/  /'
    elif command -v iw &>/dev/null; then
        local iface=$(iw dev 2>/dev/null | awk '/Interface/ {print $2}' | head -1)
        [ -z "$iface" ] && iface=$(ls /sys/class/net 2>/dev/null | grep -i wl | head -1)
        if [ -n "$iface" ]; then
            echo "  Scanning on $iface..."
            sudo iw "$iface" scan 2>/dev/null | grep -E "SSID|signal|freq|channel" | sed 's/^/  /'
        fi
    else
        echo "  No Wi-Fi tool (nmcli or iw)"
    fi
}

# Signal strength
signal() {
    echo "=== Wi-Fi Signal ==="
    echo ""
    
    local iface=$(ls /sys/class/net 2>/dev/null | grep -iE "wlan|wlp|wlx" | head -1)
    [ -z "$iface" ] && { echo "  No Wi-Fi interface"; return 1; }
    
    local ssid=""
    local signal=""
    
    if command -v nmcli &>/dev/null; then
        ssid=$(nmcli -t -f ACTIVE,SSID device wifi list 2>/dev/null | grep "^yes" | cut -d: -f2)
        signal=$(nmcli -t -f ACTIVE,SIGNAL device wifi list 2>/dev/null | grep "^yes" | cut -d: -f2)
    fi
    
    echo "  Interface: $iface"
    echo "  Connected SSID: ${ssid:-unknown}"
    echo "  Signal: ${signal:-N/A}"
    echo ""
    
    # Read signal from sysfs/iw
    if command -v iw &>/dev/null; then
        local iwlink=$(iw "$iface" link 2>/dev/null)
        echo "$iwlink" | grep -E "signal|SSID|freq|tx bitrate" | sed 's/^/  /'
    fi
}

# Channel analysis
channels() {
    echo "=== Channel Analysis ==="
    echo ""
    
    # 2.4 GHz channels: 1-11/13
    echo "2.4 GHz channels and congestion:"
    echo "  Ch 1, 6, 11 are non-overlapping (recommended)"
    echo ""
    
    # Analyze current channel usage
    if command -v nmcli &>/dev/null; then
        echo "Current channel distribution:"
        nmcli -f CHAN device wifi list 2>/dev/null | tail -n +2 | grep -oP '\d+' | sort -n | uniq -c | sed 's/^/  /'
    fi
    
    echo ""
    echo "Recommendation logic:"
    echo "  - 2.4GHz: prefer channel 1, 6, or 11 (least congested)"
    echo "  - 5GHz: prefer higher channels (avoid DFS channels)"
    echo "  - Check for co-channel interference (same channel as neighbors)"
}

# Measure throughput
throughput() {
    echo "=== Throughput Test ==="
    echo ""
    
    local iface=$(ls /sys/class/net 2>/dev/null | grep -iE "wlan|wlp|wlx" | head -1)
    [ -z "$iface" ] && { echo "  No Wi-Fi interface"; return 1; }
    
    # Interface throughput stats
    local rx=$(cat /sys/class/net/$iface/statistics/rx_bytes)
    local tx=$(cat /sys/class/net/$iface/statistics/tx_bytes)
    sleep 1
    local rx2=$(cat /sys/class/net/$iface/statistics/rx_bytes)
    local tx2=$(cat /sys/class/net/$iface/statistics/tx_bytes)
    
    echo "  Interface: $iface"
    echo "  Download rate: $(( (rx2-rx) / 1024 )) KB/s"
    echo "  Upload rate: $(( (tx2-tx) / 1024 )) KB/s"
    echo ""
    echo "  Max link rate:"
    iw "$iface" link 2>/dev/null | grep "tx bitrate" | sed 's/^/    /'
}

# Quality report
quality() {
    echo "=== Wi-Fi Quality Report ==="
    echo ""
    
    local iface=$(ls /sys/class/net 2>/dev/null | grep -iE "wlan|wlp|wlx" | head -1)
    [ -z "$iface" ] && { echo "  No Wi-Fi interface"; return 1; }
    
    local signal=$(iw "$iface" link 2>/dev/null | grep -oP 'signal: -\d+' | grep -oP '\d+')
    local nm_signal=""
    command -v nmcli &>/dev/null && nm_signal=$(nmcli -t -f ACTIVE,SIGNAL device wifi list 2>/dev/null | grep "^yes" | cut -d: -f2)
    
    if [ -n "$signal" ]; then
        echo "  Raw signal: -${signal} dBm"
        if [ "$signal" -lt 50 ]; then echo "  Quality: EXCELLENT"
        elif [ "$signal" -lt 60 ]; then echo "  Quality: GOOD"
        elif [ "$signal" -lt 70 ]; then echo "  Quality: FAIR"
        elif [ "$signal" -lt 80 ]; then echo "  Quality: POOR"
        else echo "  Quality: VERY POOR"
        fi
    elif [ -n "$nm_signal" ]; then
        echo "  Signal: ${nm_signal}%"
        if [ "$nm_signal" -gt 80 ]; then echo "  Quality: EXCELLENT"
        elif [ "$nm_signal" -gt 60 ]; then echo "  Quality: GOOD"
        elif [ "$nm_signal" -gt 40 ]; then echo "  Quality: FAIR"
        else echo "  Quality: POOR"
        fi
    fi
    
    echo ""
    echo "  5GHz vs 2.4GHz:"
    local freq=$(iw "$iface" link 2>/dev/null | grep -oP 'freq: \d+' | grep -oP '\d+')
    if [ -n "$freq" ] && [ "$freq" -gt 4000 ]; then
        echo "    Connected on 5GHz (higher bandwidth, lower range)"
    else
        echo "    Connected on 2.4GHz (lower bandwidth, higher range)"
    fi
}

optimize() {
    echo "=== Wi-Fi Optimization ==="
    echo ""
    echo "Recommendations:"
    echo ""
    
    local iface=$(ls /sys/class/net 2>/dev/null | grep -iE "wlan|wlp|wlx" | head -1)
    local freq=$(iw "$iface" link 2>/dev/null | grep -oP 'freq: \d+' | grep -oP '\d+' 2>/dev/null)
    
    if [ -n "$freq" ] && [ "$freq" -lt 2500 ]; then
        echo "  ⚠️  Connected to 2.4GHz - switch to 5GHz for better speed"
    fi
    
    # Power saving check
    local ps=$(iw "$iface" get power_save 2>/dev/null)
    echo "$ps" | grep -qi "on" && echo "  ⚠️  Power save is ON - disable for lower latency:"
    echo "      sudo iw dev $iface set power_save off"
    
    echo "  ✓ Ensure router antenna is positioned well"
    echo "  ✓ Use channel 1, 6, or 11 on 2.4GHz"
    echo "  ✓ Enable WPA3 if supported"
}

show_help() {
    echo "Usage: tinker-wifi [command]"
    echo ""
    echo "Commands:"
    echo "  scan                Scan available networks"
    echo "  signal              Show signal strength"
    echo "  channels            Channel analysis"
    echo "  throughput          Measure throughput"
    echo "  quality             Quality report"
    echo "  optimize            Optimization tips"
    echo "  help                Show this help"
}

case "$1" in
    scan) scan ;;
    signal) signal ;;
    channels) channels ;;
    throughput) throughput ;;
    quality) quality ;;
    optimize) optimize ;;
    *) show_help ;;
esac
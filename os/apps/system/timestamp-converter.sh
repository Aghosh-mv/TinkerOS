#!/bin/bash
# TinkerOS Timestamp Converter
# Convert between epoch seconds and human dates, both directions.

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

to_human() {
    date -d "@$1" 2>/dev/null || echo "invalid epoch"
}

to_epoch() {
    date -d "$1" +%s 2>/dev/null || echo "invalid date"
}

now() {
    echo "now epoch: $(date +%s)  human: $(date)"
}

echo -e "${BLUE}── TinkerOS Timestamp Converter ──${NC}"
if [ $# -eq 1 ]; then
    # if it looks like a number, treat as epoch -> human
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "epoch $1 -> $(to_human "$1")"
    else
        echo "human '$1' -> epoch $(to_epoch "$1")"
    fi
    exit 0
fi

now
echo "Usage:"
echo "  timestamp-converter 1735689600   (epoch -> human)"
echo "  timestamp-converter '2026-01-01 00:00:00'   (human -> epoch)"
echo ""
read -r -p "timestamp: " input
if [[ "$input" =~ ^[0-9]+$ ]]; then
    echo "epoch $input -> $(to_human "$input")"
else
    echo "human '$input' -> epoch $(to_epoch "$input")"
fi

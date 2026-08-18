#!/bin/bash
# TinkerOS Speed Test
echo "=== TinkerOS Speed Test ==="
echo ""
echo "Testing download (100MB from cachefly)..."
timeout 20 curl -s -o /dev/null -w "  Download: %{speed_download} bytes/s (%{time_total}s)\n" --max-time 15 http://cachefly.cachefly.net/100mb.test 2>/dev/null || echo "  (test skipped - no network or curl)"

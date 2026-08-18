#!/bin/bash
# TinkerOS System Monitor - Real-time resource monitoring
echo "=== TinkerOS System Monitor ==="
echo ""
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print "  " $2 "% user, " $4 "% system"}' 2>/dev/null || echo "  (top unavailable)"
echo ""
echo "Memory:"
free -h 2>/dev/null | grep -E "Mem|Swap" | sed 's/^/  /' || echo "  (free unavailable)"
echo ""
echo "Disk:"
df -h / 2>/dev/null | awk 'NR==2 {print "  / " $5 " used (" $3 "/" $2 ")"}'
echo ""
echo "Load Average: $(cat /proc/loadavg 2>/dev/null | awk '{print $1", "$2", "$3}')"
echo "Uptime: $(uptime -p 2>/dev/null || echo unknown)"

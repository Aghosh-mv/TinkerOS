#!/bin/bash
# TinkerOS Thermal Tuning - fan curves, thermal zones, throttling
case "${1:-status}" in
  status)
    echo "=== Thermal Status ==="
    for z in /sys/class/thermal/thermal_zone*/; do
      t=$(cat ${z}type 2>/dev/null); temp=$(cat ${z}temp 2>/dev/null)
      [ -n "$temp" ] && echo "  $t: $(echo "scale=1; $temp/1000" | bc 2>/dev/null || echo "$temp")°C"
    done
    ;;
  curve) echo "Fan curve: 30°C→800rpm | 50°C→1500rpm | 70°C→2500rpm | 85°C→4000rpm" ;;
  *) echo "Usage: $0 {status|curve}";;
esac

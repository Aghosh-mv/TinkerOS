#!/bin/bash
# TinkerOS Thermal Tuning - fan curves, thermal zones, throttling
BHELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/backend-helper.sh"
if [[ -f "$BHELPER" ]]; then source "$BHELPER"; fi

case "${1:-status}" in
  status)
    echo "=== Thermal Status ==="
    # Preferred: compiled thermal_control C backend (MSR heat map, /sys fallback)
    if backend_available "thermal_control"; then
      tsum="$(backend_run thermal_control probe 2>/dev/null | grep -oP 'mean_c=\K[0-9.]+')"
      if [[ -n "$tsum" ]]; then
        echo "  Mean package temp: ${tsum}°C (thermal_control C backend)"
      fi
    fi
    for z in /sys/class/thermal/thermal_zone*/; do
      t=$(cat ${z}type 2>/dev/null); temp=$(cat ${z}temp 2>/dev/null)
      [ -n "$temp" ] && echo "  $t: $(echo "scale=1; $temp/1000" | bc 2>/dev/null || echo "$temp")°C"
    done
    ;;
  curve) echo "Fan curve: 30°C→800rpm | 50°C→1500rpm | 70°C→2500rpm | 85°C→4000rpm" ;;
  *) echo "Usage: $0 {status|curve}";;
esac

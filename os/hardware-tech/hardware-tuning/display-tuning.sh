#!/bin/bash
# TinkerOS Display Tuning - brightness, color profiles, gamma, VRR, EDID
BHELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/backend-helper.sh"
if [[ -f "$BHELPER" ]]; then source "$BHELPER"; fi

case "${1:-status}" in
  status)
    echo "=== Display Status ==="
    xrandr 2>/dev/null | grep -E " connected|Screen" | head -3 | sed 's/^/  /'
    if backend_run display_control probe 2>/dev/null | grep -q 'backlights=[1-9]'; then
      backend_run display_control read 2>/dev/null | sed 's/^/  /'
    else
      echo "  Brightness: $(cat /sys/class/backlight/*/brightness 2>/dev/null || echo N/A)"
    fi
    echo "  Night light: $(gsettings get org.gnome.settings-daemon.plugins.color night-light-enabled 2>/dev/null || echo N/A)"
    ;;
  brightness)
    VAL="${2:-80}"
    # Preferred: compiled display_control C backend (max-scaled, safe envelope)
    if backend_available "display_control"; then
      out="$(backend_run display_control brightness "$VAL" 2>/dev/null)"
      if [[ "$out" == *"ok=backlight"* ]]; then
        echo "Brightness: $VAL (display_control C backend)"
        exit 0
      fi
    fi
    # Fallback: raw sysfs, then xrandr
    echo "$VAL" | sudo tee /sys/class/backlight/*/brightness > /dev/null 2>&1 && echo "Brightness: $VAL" || xrandr --brightness ${2:-0.8} 2>/dev/null && echo "Brightness: ${2:-0.8}" || echo "Need root or xrandr"
    ;;
  gamma) xrandr --gamma ${2:-1.0}:${2:-1.0}:${2:-1.0} 2>/dev/null && echo "Gamma: ${2:-1.0}" || echo "xrandr unavailable" ;;
  night) gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled ${2:-true} 2>/dev/null && echo "Night light: ${2:-true}" || echo "Need gnome-settings" ;;
  *) echo "Usage: $0 {status|brightness <0-100>|gamma <val>|night [on|off]}";;
esac

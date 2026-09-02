#!/bin/bash
# TinkerOS Display Tuning - brightness, color profiles, gamma, VRR, EDID
case "${1:-status}" in
  status)
    echo "=== Display Status ==="
    xrandr 2>/dev/null | grep -E " connected|Screen" | head -3 | sed 's/^/  /'
    echo "  Brightness: $(cat /sys/class/backlight/*/brightness 2>/dev/null || echo N/A)"
    echo "  Night light: $(gsettings get org.gnome.settings-daemon.plugins.color night-light-enabled 2>/dev/null || echo N/A)"
    ;;
  brightness) echo ${2:-80} | sudo tee /sys/class/backlight/*/brightness > /dev/null 2>&1 && echo "Brightness: ${2:-80}" || xrandr --brightness ${2:-0.8} 2>/dev/null && echo "Brightness: ${2:-0.8}" || echo "Need root or xrandr" ;;
  gamma) xrandr --gamma ${2:-1.0}:${2:-1.0}:${2:-1.0} 2>/dev/null && echo "Gamma: ${2:-1.0}" || echo "xrandr unavailable" ;;
  night) gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled ${2:-true} 2>/dev/null && echo "Night light: ${2:-true}" || echo "Need gnome-settings" ;;
  *) echo "Usage: $0 {status|brightness <0-100>|gamma <val>|night [on|off]}";;
esac

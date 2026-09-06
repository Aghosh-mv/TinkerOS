#!/bin/bash
# TinkerOS Input Tuning - keyboard repeat, mouse accel, touchpad, gestures, Wacom
case "${1:-status}" in
  status)
    echo "=== Input Devices ==="
    for d in /dev/input/event*; do name=$(cat /sys/class/input/$(basename $d)/device/name 2>/dev/null); [ -n "$name" ] && echo "  $d: $name"; done 2>/dev/null | head -10
    echo "  Repeat: $(xset q 2>/dev/null | grep 'repeat' | head -1 || echo N/A)"
    ;;
  repeat) xset r rate ${2:-300} ${3:-30} 2>/dev/null && echo "Repeat: ${2:-300}ms delay, ${3:-30}/s" || echo "xset unavailable" ;;
  mouse) xset m ${2:-1} 2>/dev/null && echo "Mouse accel: ${2:-1}" || echo "xset unavailable" ;;
  touchpad) synclient TouchpadOff=${2:-0} 2>/dev/null && echo "Touchpad: ${2:-0}" || echo "synclient unavailable" ;;
  *) echo "Usage: $0 {status|repeat <delay> <rate>|mouse <accel>|touchpad <0|1>}";;
esac

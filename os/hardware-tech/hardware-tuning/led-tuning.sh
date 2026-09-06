#!/bin/bash
# TinkerOS LED Tuning - keyboard backlight, RGB, hardware LEDs, OpenRazer
case "${1:-status}" in
  status)
    echo "=== LED Status ==="
    for led in /sys/class/leds/*/; do
      [ -d "$led" ] || continue
      name=$(basename $led)
      brightness=$(cat ${led}brightness 2>/dev/null)
      max=$(cat ${led}max_brightness 2>/dev/null)
      echo "  $name: brightness=$brightness/$max"
    done
    ;;
  set) led=${2:-kbd_backlight}; val=${3:-1}
    echo $val | sudo tee /sys/class/leds/$led/brightness > /dev/null 2>&1 && echo "LED $led: $val" || echo "LED not found" ;;
  rgb) echo "RGB mode: ${2:-static} color=${3:-ffffff}"
    [ -f "/sys/devices/platform/leds/leds/rgb:kbd/mode" ] && echo ${2:-static} | sudo tee /sys/devices/platform/leds/leds/rgb:kbd/mode > /dev/null 2>&1 ;;
  *) echo "Usage: $0 {status|set <led> <brightness>|rgb <mode> <color>}";;
esac

#!/usr/bin/env bash
# korrinos-splitscreen.sh — Split Screen Manager
# Drag windows to edges → auto-snap to half/quarter

set -euo pipefail

# Get screen geometry
get_screen() {
  if command -v xdotool &>/dev/null; then
    xdotool getdisplaygeometry 2>/dev/null
  else
    echo "1920 1080"
  fi
}

# Snap window to left half
snap_left() {
  local win="${1:-$(xdotool getactivewindow 2>/dev/null)}"
  local geo=$(get_screen)
  local w=$(echo "$geo" | awk '{print $1}')
  local h=$(echo "$geo" | awk '{print $2}')
  
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,0,0,$((w/2)),$h" 2>/dev/null
  elif command -v xdotool &>/dev/null; then
    xdotool windowsize "$win" "$((w/2))" "$h" && xdotool windowmove "$win" 0 0
  fi
  echo "→ Left half"
}

# Snap window to right half
snap_right() {
  local win="${1:-$(xdotool getactivewindow 2>/dev/null)}"
  local geo=$(get_screen)
  local w=$(echo "$geo" | awk '{print $1}')
  local h=$(echo "$geo" | awk '{print $2}')
  
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,$((w/2)),0,$((w/2)),$h" 2>/dev/null
  elif command -v xdotool &>/dev/null; then
    xdotool windowsize "$win" "$((w/2))" "$h" && xdotool windowmove "$win" "$((w/2))" 0
  fi
  echo "→ Right half"
}

# Snap to top-left quarter
snap_topleft() {
  local win="${1:-$(xdotool getactivewindow 2>/dev/null)}"
  local geo=$(get_screen)
  local w=$(echo "$geo" | awk '{print $1}')
  local h=$(echo "$geo" | awk '{print $2}')
  
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,0,0,$((w/2)),$((h/2))" 2>/dev/null
  fi
  echo "→ Top-left quarter"
}

# Snap to top-right quarter
snap_topright() {
  local win="${1:-$(xdotool getactivewindow 2>/dev/null)}"
  local geo=$(get_screen)
  local w=$(echo "$geo" | awk '{print $1}')
  local h=$(echo "$geo" | awk '{print $2}')
  
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,$((w/2)),0,$((w/2)),$((h/2))" 2>/dev/null
  fi
  echo "→ Top-right quarter"
}

# Snap to bottom-left quarter
snap_bottomleft() {
  local win="${1:-$(xdotool getactivewindow 2>/dev/null)}"
  local geo=$(get_screen)
  local w=$(echo "$geo" | awk '{print $1}')
  local h=$(echo "$geo" | awk '{print $2}')
  
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,0,$((h/2)),$((w/2)),$((h/2))" 2>/dev/null
  fi
  echo "→ Bottom-left quarter"
}

# Snap to bottom-right quarter
snap_bottomright() {
  local win="${1:-$(xdotool getactivewindow 2>/dev/null)}"
  local geo=$(get_screen)
  local w=$(echo "$geo" | awk '{print $1}')
  local h=$(echo "$geo" | awk '{print $2}')
  
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,$((w/2)),$((h/2)),$((w/2)),$((h/2))" 2>/dev/null
  fi
  echo "→ Bottom-right quarter"
}

# Maximize
snap_maximize() {
  local win="${1:-$(xdotool getactivewindow 2>/dev/null)}"
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -b add,maximized_vert,maximized_horz 2>/dev/null
  fi
  echo "→ Maximized"
}

# Center
snap_center() {
  local win="${1:-$(xdotool getactivewindow 2>/dev/null)}"
  local geo=$(get_screen)
  local w=$(echo "$geo" | awk '{print $1}')
  local h=$(echo "$geo" | awk '{print $2}')
  local ww=800 wh=600
  
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,$(( (w-ww)/2 )),$(( (h-wh)/2 )),$ww,$wh" 2>/dev/null
  fi
  echo "→ Centered"
}

# List windows
list_windows() {
  echo "=== Windows ==="
  if command -v wmctrl &>/dev/null; then
    wmctrl -l 2>/dev/null | while read -r line; do
      local id=$(echo "$line" | awk '{print $1}')
      local title=$(echo "$line" | cut -d' ' -f4-)
      echo "  $id  ${title:0:60}"
    done
  fi
}

case "${1:-help}" in
  left)       shift; snap_left "$@" ;;
  right)      shift; snap_right "$@" ;;
  topleft)    shift; snap_topleft "$@" ;;
  topright)   shift; snap_topright "$@" ;;
  bottomleft) shift; snap_bottomleft "$@" ;;
  bottomright) shift; snap_bottomright "$@" ;;
  maximize)   shift; snap_maximize "$@" ;;
  center)     shift; snap_center "$@" ;;
  windows)    list_windows ;;
  *)
    echo "KorrinOS Split Screen Manager"
    echo "Usage: korrinos-splitscreen.sh <command>"
    echo ""
    echo "Commands:"
    echo "  left            Snap to left half"
    echo "  right           Snap to right half"
    echo "  topleft         Snap to top-left quarter"
    echo "  topright        Snap to top-right quarter"
    echo "  bottomleft      Snap to bottom-left quarter"
    echo "  bottomright     Snap to bottom-right quarter"
    echo "  maximize        Maximize window"
    echo "  center          Center window"
    echo "  windows         List windows"
    ;;
esac

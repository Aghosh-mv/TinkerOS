#!/usr/bin/env bash
# korrinos-desktop.sh — Virtual Desktops & Workspace Manager
# Window tiling, workspaces, overview mode

set -euo pipefail

# Get current workspace
desktop_current() {
  if command -v wmctrl &>/dev/null; then
    wmctrl -d 2>/dev/null | awk '/\*/ {print $1}'
  elif command -v xdotool &>/dev/null; then
    xdotool get_desktop 2>/dev/null
  else
    echo "0"
  fi
}

# Get total workspaces
desktop_total() {
  if command -v wmctrl &>/dev/null; then
    wmctrl -d 2>/dev/null | wc -l
  else
    echo "4"
  fi
}

# Switch to workspace
desktop_switch() {
  local num="$1"
  if command -v wmctrl &>/dev/null; then
    wmctrl -s "$num" 2>/dev/null
  elif command -v xdotool &>/dev/null; then
    xdotool set_desktop "$num" 2>/dev/null
  fi
  echo "Switched to workspace $num"
}

# Create workspace
desktop_create() {
  local count="${1:-$(($(desktop_total) + 1))}"
  if command -v wmctrl &>/dev/null; then
    wmctrl -n "$count" 2>/dev/null
  fi
  echo "Workspaces: $count"
}

# Move window to workspace
desktop_move_window() {
  local win="${1:-$(desktop_active_window)}"
  local ws="$2"
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -t "$ws" 2>/dev/null
  elif command -v xdotool &>/dev/null; then
    xdotool windowactivate "$win" 2>/dev/null
    xdotool key "ctrl+alt+shift+${ws}" 2>/dev/null
  fi
  echo "Window moved to workspace $ws"
}

# Get active window ID
desktop_active_window() {
  if command -v wmctrl &>/dev/null; then
    wmctrl -l 2>/dev/null | awk '{print $1}' | head -1
  elif command -v xdotool &>/dev/null; then
    xdotool getactivewindow 2>/dev/null
  fi
}

# List windows
desktop_list_windows() {
  echo "=== Active Windows ==="
  if command -v wmctrl -l &>/dev/null; then
    wmctrl -l 2>/dev/null | while read -r line; do
      local id=$(echo "$line" | awk '{print $1}')
      local ws=$(echo "$line" | awk '{print $2}')
      local title=$(echo "$line" | cut -d' ' -f4-)
      echo "  [$ws] $title (ID: $id)"
    done
  else
    xdotool search --name "" getwindowname 2>/dev/null | head -20
  fi
}

# Tile window (left half)
desktop_tile_left() {
  local win="${1:-$(desktop_active_window)}"
  local screen_w=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $1}')
  local screen_h=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $2}')
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,0,0,$((screen_w/2)),$screen_h" 2>/dev/null
  fi
}

# Tile window (right half)
desktop_tile_right() {
  local win="${1:-$(desktop_active_window)}"
  local screen_w=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $1}')
  local screen_h=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $2}')
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,$((screen_w/2)),0,$((screen_w/2)),$screen_h" 2>/dev/null
  fi
}

# Tile window (top half)
desktop_tile_top() {
  local win="${1:-$(desktop_active_window)}"
  local screen_w=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $1}')
  local screen_h=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $2}')
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,0,0,$screen_w,$((screen_h/2))" 2>/dev/null
  fi
}

# Tile window (bottom half)
desktop_tile_bottom() {
  local win="${1:-$(desktop_active_window)}"
  local screen_w=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $1}')
  local screen_h=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $2}')
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -e "0,0,$((screen_h/2)),$screen_w,$((screen_h/2))" 2>/dev/null
  fi
}

# Maximize window
desktop_maximize() {
  local win="${1:-$(desktop_active_window)}"
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -b add,maximized_vert,maximized_horz 2>/dev/null
  fi
}

# Minimize window
desktop_minimize() {
  local win="${1:-$(desktop_active_window)}"
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -b add,hidden 2>/dev/null
  fi
}

# Close window
desktop_close() {
  local win="${1:-$(desktop_active_window)}"
  if command -v wmctrl &>/dev/null; then
    wmctrl -i -r "$win" -c 2>/dev/null
  elif command -v xdotool &>/dev/null; then
    xdotool windowclose "$win" 2>/dev/null
  fi
}

# Overview mode (show all windows)
desktop_overview() {
  echo "=== Workspace Overview ==="
  local current=$(desktop_current)
  local total=$(desktop_total)
  echo "Workspace: $current / $total"
  echo ""
  desktop_list_windows
}

case "${1:-help}" in
  current)    desktop_current ;;
  total)      desktop_total ;;
  switch)     shift; desktop_switch "$@" ;;
  create)     shift; desktop_create "$@" ;;
  move)       shift; desktop_move_window "$@" ;;
  windows)    desktop_list_windows ;;
  tile-left)  shift; desktop_tile_left "$@" ;;
  tile-right) shift; desktop_tile_right "$@" ;;
  tile-top)   shift; desktop_tile_top "$@" ;;
  tile-bottom) shift; desktop_tile_bottom "$@" ;;
  maximize)   shift; desktop_maximize "$@" ;;
  minimize)   shift; desktop_minimize "$@" ;;
  close)      shift; desktop_close "$@" ;;
  overview)   desktop_overview ;;
  *)
    echo "KorrinOS Virtual Desktops & Workspace Manager"
    echo "Usage: korrinos-desktop.sh <command>"
    echo ""
    echo "Commands:"
    echo "  current           Show current workspace"
    echo "  total             Show total workspaces"
    echo "  switch <n>        Switch to workspace N"
    echo "  create [n]        Create N workspaces"
    echo "  move <win> <ws>   Move window to workspace"
    echo "  windows           List all windows"
    echo "  tile-left         Tile window to left half"
    echo "  tile-right        Tile window to right half"
    echo "  tile-top          Tile window to top half"
    echo "  tile-bottom       Tile window to bottom half"
    echo "  maximize          Maximize window"
    echo "  minimize          Minimize window"
    echo "  close             Close window"
    echo "  overview          Show workspace overview"
    ;;
esac

#!/usr/bin/env bash
# agent-system.sh — system-level control agent: execute commands, manage apps, control desktop

TINKER_AI_HOME="${TINKER_AI_HOME:-$HOME/.config/tinker-ai}"
AGENT_DIR="$TINKER_AI_HOME/agent"
mkdir -p "$AGENT_DIR/logs" "$AGENT_DIR/screenshots" "$AGENT_DIR/schedules"

# Execute a terminal command and return output
agent_exec() {
  local cmd="$1" timeout="${2:-30}"
  local log="$AGENT_DIR/logs/exec_$(date +%s).log"
  echo "[$(date -Iseconds)] EXEC: $cmd" >> "$log"
  
  local output
  output=$(timeout "$timeout" bash -c "$cmd" 2>&1)
  local rc=$?
  
  echo "[$(date -Iseconds)] EXIT: $rc" >> "$log"
  echo "$output" >> "$log"
  
  if [ $rc -eq 0 ]; then
    echo "$output"
  else
    echo "Command failed (exit $rc): $output"
  fi
  return $rc
}

# Execute with sudo
agent_exec_sudo() {
  local cmd="$1"
  echo "$cmd" | sudo -S bash 2>/dev/null || echo "Sudo failed or not available"
}

# Open any application by name
agent_open_app() {
  local app="$1"
  local logfile="$AGENT_DIR/logs/apps.log"
  
  # Try known apps first
  case "${app,,}" in
    *browser*|*firefox*|*chrome*|*chromium*|*brave*)
      for b in brave-browser vivaldi chromium-browser google-chrome firefox; do
        if command -v "$b" &>/dev/null; then
          nohup "$b" &>/dev/null &
          echo "[$(date)] Opened $b" >> "$logfile"
          echo "Opened $b"; return 0
        fi
      done
      ;;
    *terminal*|*konsole*|*alacritty*|*kitty*)
      for t in alacritty kitty wezterm konsole gnome-terminal; do
        if command -v "$t" &>/dev/null; then
          nohup "$t" &>/dev/null &
          echo "Opened $t"; return 0
        fi
      done
      ;;
    *editor*|*code*|*vscode*)
      for e in code codium vim nano emacs; do
        if command -v "$e" &>/dev/null; then
          nohup "$e" &>/dev/null &
          echo "Opened $e"; return 0
        fi
      done
      ;;
    *files*|*finder*|*nautilus*|*dolphin*)
      for f in nautilus dolphin thunar pcmanfm nemo; do
        if command -v "$f" &>/dev/null; then
          nohup "$f" &>/dev/null &
          echo "Opened $f"; return 0
        fi
      done
      ;;
    *settings*|*preferences*)
      nohup gnome-control-center &>/dev/null &
      echo "Opened Settings"; return 0
      ;;
    *spotify*|*music*)
      for m in spotify rhythmbox vlc Clementine; do
        if command -v "$m" &>/dev/null; then
          nohup "$m" &>/dev/null &
          echo "Opened $m"; return 0
        fi
      done
      ;;
    *mail*|*email*|*thunderbird*)
      nohup thunderbird &>/dev/null &
      echo "Opened Thunderbird"; return 0
      ;;
    *calc*)
      nohup gnome-calculator &>/dev/null || nohup qalculate-gtk &>/dev/null
      echo "Opened Calculator"; return 0
      ;;
  esac
  
  # Generic: try xdg-open
  if command -v "$app" &>/dev/null; then
    nohup "$app" &>/dev/null &
    echo "Opened $app"; return 0
  fi
  
  echo "App not found: $app"
  return 1
}

# Take a screenshot
agent_screenshot() {
  local output="${1:-$AGENT_DIR/screenshots/snap_$(date +%s).png}"
  if command -v scrot &>/dev/null; then
    scrot -o "$output" 2>/dev/null
  elif command -v maim &>/dev/null; then
    maim "$output" 2>/dev/null
  elif python3 -c "import pyautogui" 2>/dev/null; then
    python3 -c "
import pyautogui
img = pyautogui.screenshot()
img.save('$output')
print('Screenshot saved: $output')
" 2>/dev/null
  else
    echo "No screenshot tool available"; return 1
  fi
  echo "$output"
}

# Read screen text using OCR
agent_read_screen() {
  local screenshot="${1:-}"
  if [ -z "$screenshot" ]; then
    screenshot=$(agent_screenshot)
  fi
  if [ ! -f "$screenshot" ]; then
    echo "Screenshot not found: $screenshot"; return 1
  fi
  tesseract "$screenshot" - 2>/dev/null
}

# Get current window info
agent_get_window() {
  xdotool getactivewindow getwindowname 2>/dev/null || echo "Unknown window"
}

# List all open windows
agent_list_windows() {
  wmctrl -l 2>/dev/null || xdotool search --name "" 2>/dev/null | while read wid; do
    local name=$(xdotool getwindowname "$wid" 2>/dev/null)
    [ -n "$name" ] && echo "  $wid: $name"
  done
}

# Focus a window by name
agent_focus_window() {
  local name="$1"
  local wid=$(wmctrl -l 2>/dev/null | grep -i "$name" | awk '{print $1}' | head -1)
  if [ -n "$wid" ]; then
    wmctrl -i -a "$wid" 2>/dev/null
    echo "Focused: $name"
  else
    # Try xdotool
    wid=$(xdotool search --name "$name" 2>/dev/null | head -1)
    if [ -n "$wid" ]; then
      xdotool windowactivate "$wid" 2>/dev/null
      echo "Focused: $name"
    else
      echo "Window not found: $name"
    fi
  fi
}

# Type text (optionally into specific window — no focus steal)
agent_type() {
  local text="$1"
  local window_title="$2"
  
  if [ -n "$window_title" ]; then
    # Type into specific window — no focus steal
    local wid=$(xdotool search --name "$window_title" 2>/dev/null | head -1)
    if [ -n "$wid" ]; then
      xdotool type --window "$wid" --clearmodifiers "$text" 2>/dev/null
      echo "Typed into '$window_title'"
    else
      echo "Window not found: $window_title"
      return 1
    fi
  else
    # Type into focused window (last resort)
    xdotool type --clearmodifiers "$text" 2>/dev/null || echo "Type failed"
  fi
}

# Press a key (optionally into specific window — no focus steal)
agent_key() {
  local key="$1"
  local window_title="$2"
  
  if [ -n "$window_title" ]; then
    # Press key in specific window — no focus steal
    local wid=$(xdotool search --name "$window_title" 2>/dev/null | head -1)
    if [ -n "$wid" ]; then
      xdotool key --window "$wid" "$key" 2>/dev/null
      echo "Pressed $key in '$window_title'"
    else
      echo "Window not found: $window_title"
      return 1
    fi
  else
    # Press key in focused window (last resort)
    xdotool key --clearmodifiers "$key" 2>/dev/null || echo "Key failed"
  fi
}

# Mouse click at coordinates
agent_click() {
  local x="$1" y="$2" button="${3:-1}"
  xdotool mousemove --sync "$x" "$y" 2>/dev/null
  xdotool click --button "$button" 2>/dev/null
  echo "Clicked ($x, $y)"
}

# Mouse move
agent_move() {
  local x="$1" y="$2"
  xdotool mousemove --sync "$x" "$y" 2>/dev/null
}

# Scroll
agent_scroll() {
  local direction="${1:-down}" amount="${2:-3}"
  if [ "$direction" = "up" ]; then
    xdotool click --button 4 "$amount" 2>/dev/null
  else
    xdotool click --button 5 "$amount" 2>/dev/null
  fi
}

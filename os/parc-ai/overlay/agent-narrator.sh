#!/usr/bin/env bash
# agent-narrator.sh — narration functions for VOKK v4 agents

NARRATOR_SCRIPT="$(dirname "$0")/narrator.py"

# Show narration popup
ai_narrate() {
  local message="$1"
  local duration="${2:-3000}"
  
  # Show popup
  DISPLAY=:1 python3 "$NARRATOR_SCRIPT" "$message" "$duration" &>/dev/null &
}

# Narrate and execute (shows popup while running)
ai_narrate_exec() {
  local message="$1"
  local cmd="$2"
  
  # Show "doing" narration
  ai_narrate "$message" 2000
  
  # Run command
  local output
  output=$(eval "$cmd" 2>&1)
  local rc=$?
  
  # Show result narration
  if [ $rc -eq 0 ]; then
    ai_narrate "Done! $message" 2000
  else
    ai_narrate "Something went wrong..." 2000
  fi
  
  echo "$output"
  return $rc
}

# Search narration
ai_narrate_search() {
  local query="$1"
  ai_narrate "Searching for $query..." 2000
}

# Play music narration
ai_narrate_play() {
  local song="$1"
  ai_narrate "Playing $song..." 2000
}

# App open narration
ai_narrate_open() {
  local app="$1"
  ai_narrate "Opening $app..." 2000
}

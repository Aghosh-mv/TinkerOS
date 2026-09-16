#!/usr/bin/env bash
# narrator.sh — TinkerAI narration system
# Usage: narrator.sh "message" [duration_ms]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OVERLAY_DIR="$SCRIPT_DIR"

message="${1:-}"
duration="${2:-3000}"

if [ -z "$message" ]; then
  echo "Usage: narrator.sh <message> [duration_ms]"
  exit 1
fi

# Show narration via Python
DISPLAY=:1 python3 "$OVERLAY_DIR/narrator.py" "$message" "$duration" &>/dev/null &
echo "Narrated: $message"

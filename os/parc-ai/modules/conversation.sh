#!/usr/bin/env bash
# conversation.sh — manages conversation history, context, multi-turn
# Stores last N turns in ~/.config/tinker-ai/conversations/

TINKER_AI_HOME="${TINKER_AI_HOME:-$HOME/.config/tinker-ai}"
CONV_DIR="$TINKER_AI_HOME/conversations"
MAX_HISTORY=50

mkdir -p "$CONV_DIR"

# Save a turn to history
# ai_conv_save <session_id> <role: user|assistant> <text>
ai_conv_save() {
  local sid="$1" role="$2" text="$3"
  local file="$CONV_DIR/${sid}.jsonl"
  local ts=$(date -Iseconds)
  echo "{\"ts\":\"$ts\",\"role\":\"$role\",\"text\":\"$(echo "$text" | sed 's/"/\\"/g')\"}" >> "$file"
  # Trim to last MAX_HISTORY lines (only if file exists and has content)
  if [ -f "$file" ]; then
    local lines=$(wc -l < "$file" 2>/dev/null || echo 0)
    if [ "$lines" -gt "$MAX_HISTORY" ]; then
      tail -n "$MAX_HISTORY" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    fi
  fi
}

# Get recent conversation context
# ai_conv_context <session_id> [num_turns]
ai_conv_context() {
  local sid="$1" n="${2:-10}"
  local file="$CONV_DIR/${sid}.jsonl"
  [ -f "$file" ] || return
  tail -n "$n" "$file" | python3 -c "
import sys,json
for line in sys.stdin:
    try:
        d=json.loads(line.strip())
        print(f\"{d['role']}: {d['text']}\")
    except: pass
" 2>/dev/null
}

# Generate a session ID from user+timestamp
ai_conv_session() {
  echo "s_$(date +%s)_$$"
}

# Get the "topic" of conversation (most mentioned noun/entity)
ai_conv_topic() {
  local sid="$1"
  local file="$CONV_DIR/${sid}.jsonl"
  [ -f "$file" ] || { echo "general"; return; }
  tail -n 20 "$file" | grep '"role":"user"' | sed 's/.*"text":"\([^"]*\)".*/\1/' | \
    tr ' ' '\n' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'
}

# Detect follow-up questions (references to previous context)
ai_conv_is_followup() {
  local text
  text=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  [[ "$text" =~ (it|this|that|those|them|they|the\s+same|also|more|again|another|other|else|continue|keep|next) ]] && return 0
  return 1
}

# Clear old conversations (older than 7 days)
ai_conv_cleanup() {
  find "$CONV_DIR" -name "*.jsonl" -mtime +7 -delete 2>/dev/null
}

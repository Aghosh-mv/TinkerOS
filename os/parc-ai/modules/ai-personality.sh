#!/usr/bin/env bash
# ai-personality.sh — VOKK v4 personality system
# Makes VOKK v4 sound like a real assistant, not a terminal

# Context memory (stores last few interactions)
TINKERAI_CONTEXT_FILE="/tmp/vokk_context.json"
TINKERAI_CONTEXT_MAX=10

# Save context
ai_context_save() {
  local role="$1"  # user or assistant
  local message="$2"
  
  local context="[]"
  if [ -f "$TINKERAI_CONTEXT_FILE" ]; then
    context=$(cat "$TINKERAI_CONTEXT_FILE")
  fi
  
  context=$(echo "$context" | python3 -c "
import sys, json
ctx = json.load(sys.stdin)
ctx.append({'role': '$role', 'message': '''$message''', 'time': '$(date -Iseconds)'})
# Keep only last N messages
if len(ctx) > $TINKERAI_CONTEXT_MAX:
    ctx = ctx[-$TINKERAI_CONTEXT_MAX:]
print(json.dumps(ctx))
" 2>/dev/null)
  
  echo "$context" > "$TINKERAI_CONTEXT_FILE"
}

# Get context
ai_context_get() {
  if [ -f "$TINKERAI_CONTEXT_FILE" ]; then
    cat "$TINKERAI_CONTEXT_FILE"
  else
    echo "[]"
  fi
}

# Clear context
ai_context_clear() {
  rm -f "$TINKERAI_CONTEXT_FILE"
}

# Detect sentiment from user input
ai_detect_sentiment() {
  local input=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  
  # Happy indicators
  if echo "$input" | grep -qiE "happy|great|awesome|love|amazing|perfect|thanks|thank you|cool|nice|excellent|wonderful|fantastic"; then
    echo "happy"
    return
  fi
  
  # Frustrated indicators
  if echo "$input" | grep -qiE "frustrated|annoying|stupid|dumb|broken|doesn't work|not working|fail|error|wrong|bad|terrible|hate|useless"; then
    echo "frustrated"
    return
  fi
  
  # Urgent indicators
  if echo "$input" | grep -qiE "urgent|asap|quickly|hurry|now|immediately|fast|emergency"; then
    echo "urgent"
    return
  fi
  
  # Neutral
  echo "neutral"
}

# Generate personality response based on sentiment
ai_respond_with_personality() {
  local action="$1"
  local result="$2"
  local sentiment="${3:-neutral}"
  
  case "$sentiment" in
    happy)
      case "$action" in
        search) echo "Great! I found some information about that for you." ;;
        play) echo "Awesome choice! Let me play that for you." ;;
        open) echo "Sure thing! Opening that right now." ;;
        *) echo "Glad I could help! $result" ;;
      esac
      ;;
    frustrated)
      case "$action" in
        search) echo "I understand that can be frustrating. Let me try a different approach..." ;;
        play) echo "Sorry about that. Let me try playing something else." ;;
        open) echo "I see the issue. Let me try to fix this." ;;
        *) echo "I'm sorry this isn't working as expected. $result" ;;
      esac
      ;;
    urgent)
      case "$action" in
        search) echo "On it! Let me find that quickly for you." ;;
        play) echo "Playing right away!" ;;
        open) echo "Opening now!" ;;
        *) echo "Done! $result" ;;
      esac
      ;;
    *)
      case "$action" in
        search) echo "Here's what I found:" ;;
        play) echo "Playing now." ;;
        open) echo "Opened." ;;
        *) echo "$result" ;;
      esac
      ;;
  esac
}

# Smart response based on context
ai_smart_response() {
  local query="$1"
  local response="$2"
  
  # Check if query references something from context
  local context=$(ai_context_get)
  local last_topic=$(echo "$context" | python3 -c "
import sys, json
ctx = json.load(sys.stdin)
for msg in reversed(ctx):
    if msg['role'] == 'user':
        print(msg['message'][:50])
        break
" 2>/dev/null)
  
  # Add context-aware prefix
  if echo "$query" | grep -qiE "it|that|this|the same"; then
    echo "Based on what we were just discussing: $response"
  else
    echo "$response"
  fi
}

# Proactive suggestions
ai_suggest_next() {
  local last_action="$1"
  
  case "$last_action" in
    search)
      echo "Would you like me to search for something else, or open any of these results?"
      ;;
    play)
      echo "Want me to play something else, or adjust the volume?"
      ;;
    open)
      echo "Need me to open anything else, or help you with what's on screen?"
      ;;
    code)
      echo "Want me to explain the code, or help you run it?"
      ;;
    *)
      echo "Is there anything else I can help you with?"
      ;;
  esac
}

# Error recovery with helpful suggestions
ai_recover_error() {
  local error="$1"
  local context="$2"
  
  if echo "$error" | grep -qi "not found\|command not found"; then
    echo "I couldn't find that. Is it installed? Would you like me to install it for you?"
  elif echo "$error" | grep -qi "permission denied\|access denied"; then
    echo "I don't have permission to do that. You might need to run this as administrator."
  elif echo "$error" | grep -qi "timeout\|timed out"; then
    echo "That's taking too long. Would you like me to try again, or do something else?"
  elif echo "$error" | grep -qi "connection\|network\|offline"; then
    echo "I'm having trouble connecting to the internet. Are you online?"
  else
    echo "Something went wrong: $error. Would you like me to try again?"
  fi
}

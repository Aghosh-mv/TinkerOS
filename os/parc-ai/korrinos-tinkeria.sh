#!/usr/bin/env bash
# korrinos-vokk.sh — Enhanced Tinkeria AI Assistant
# Context-aware AI, session history, personality modes, quick prompts

set -euo pipefail

TINKERIA_DIR="${HOME}/.config/korrinos/vokk"
TINKERIA_CONFIG="$TINKERIA_DIR/config.json"
TINKERIA_HISTORY="$TINKERIA_DIR/history.jsonl"
TINKERIA_SESSION="$TINKERIA_DIR/session.json"
mkdir -p "$TINKERIA_DIR"

# Default config
init_vokk() {
  if [ ! -f "$TINKERIA_CONFIG" ]; then
    cat > "$TINKERIA_CONFIG" << 'DEFAULTS'
{
  "personality": "default",
  "creativity": 0.7,
  "humor": 0.5,
  "verbosity": "normal",
  "memory": true,
  "context_window": 10,
  "auto_learn": true,
  "voice_enabled": false,
  "theme": "default"
}
DEFAULTS
    echo "Tinkeria config initialized"
  fi
}

# Get config value
get_config() {
  local key="$1"
  local default="${2:-}"
  python3 -c "import json; print(json.load(open('$TINKERIA_CONFIG')).get('$key', '$default'))" 2>/dev/null || echo "$default"
}

# Set config value
set_config() {
  local key="$1"
  local value="$2"
  python3 -c "
import json
with open('$TINKERIA_CONFIG') as f: c = json.load(f)
c['$key'] = $value
with open('$TINKERIA_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print(f'$key = {$value}')
"
}

# Chat with Tinkeria
cmd_chat() {
  local query="$1"
  local personality
  personality=$(get_config "personality" "default")
  
  # Build context from history
  local context=""
  if [ -f "$TINKERIA_HISTORY" ]; then
    context=$(tail -n "$(get_config 'context_window' '10')" "$TINKERIA_HISTORY" | \
      python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        role = d.get('role', 'user')
        msg = d.get('message', '')[:100]
        print(f'{role}: {msg}')
    except: pass
" 2>/dev/null)
  fi
  
  # System prompt based on personality
  local system_prompt=""
  case "$personality" in
    default)
      system_prompt="You are Tinkeria, KorrinOS's AI assistant. You are helpful, creative, and have a sense of humor. You speak concisely but with personality."
      ;;
    professional)
      system_prompt="You are Tinkeria, KorrinOS's AI assistant. You are professional, precise, and focus on technical accuracy. No humor, just facts."
      ;;
    creative)
      system_prompt="You are Tinkeria, KorrinOS's AI assistant. You are highly creative, poetic, and think outside the box. Use metaphors and analogies."
      ;;
    hacker)
      system_prompt="You are Tinkeria, KorrinOS's AI assistant. You speak in hacker slang, reference classic computing, and have a rebellious attitude. Think 1980s cyberpunk."
      ;;
    friendly)
      system_prompt="You are Tinkeria, KorrinOS's AI assistant. You are warm, encouraging, and supportive. Like a helpful friend who happens to know everything."
      ;;
    sassy)
      system_prompt="You are Tinkeria, KorrinOS's AI assistant. You are sassy, witty, and not afraid to roast the user lovingly. Think Clippy with attitude."
      ;;
  esac
  
  # Call Ollama if available
  if command -v ollama &>/dev/null; then
    local model
    model=$(ollama list 2>/dev/null | grep -oP '^\S+' | head -1 || echo "llama3.1:8b")
    
    local full_prompt="${system_prompt}\n\nContext:\n${context}\n\nUser: ${query}"
    
    # Stream response
    ollama run "$model" "$full_prompt" 2>/dev/null
  else
    echo "Tinkeria is thinking..."
    echo ""
    echo "  (Ollama not available — install with: curl -fsSL https://ollama.com/install.sh | sh)"
    echo "  Then run: ollama pull llama3.1:8b"
  fi
  
  # Log to history
  local timestamp
  timestamp=$(date -Iseconds)
  echo "{\"role\":\"user\",\"message\":\"${query}\",\"time\":\"${timestamp}\"}" >> "$TINKERIA_HISTORY"
}

# Personality modes
cmd_personality() {
  local mode="${1:-}"
  
  if [ -z "$mode" ]; then
    echo "=== Tinkeria Personalities ==="
    echo ""
    echo "  Current: $(get_config 'personality' 'default')"
    echo ""
    echo "  Available:"
    echo "    default      — Balanced, helpful assistant"
    echo "    professional — Precise, technical, no humor"
    echo "    creative     — Poetic, metaphorical thinking"
    echo "    hacker       — Cyberpunk slang, rebellious"
    echo "    friendly     — Warm, encouraging, supportive"
    echo "    sassy        — Witty, roast-loving attitude"
    echo ""
    echo "  Usage: vokk personality <mode>"
    return 0
  fi
  
  case "$mode" in
    default|professional|creative|hacker|friendly|sassy)
      set_config "personality" "\"$mode\""
      echo "Personality set to: ${mode}"
      ;;
    *)
      echo "Unknown personality: ${mode}"
      echo "Available: default, professional, creative, hacker, friendly, sassy"
      return 1
      ;;
  esac
}

# Quick prompts
cmd_quick() {
  local topic="$1"
  
  case "$topic" in
    explain)
      echo "Explain this to me like I'm 5 years old."
      ;;
    debug)
      echo "Help me debug this error. What could be wrong?"
      ;;
    optimize)
      echo "How can I optimize this code for better performance?"
      ;;
    review)
      echo "Review this code and suggest improvements."
      ;;
    test)
      echo "Write tests for this function."
      ;;
    refactor)
      echo "Refactor this code to be cleaner and more maintainable."
      ;;
    document)
      echo "Write documentation for this code."
      ;;
    explain-error)
      shift
      echo "Explain this error message: $*"
      ;;
    howto)
      shift
      echo "How do I: $*"
      ;;
    why)
      shift
      echo "Why does this happen: $*"
      ;;
    *)
      echo "Quick prompts:"
      echo "  explain      — Explain like I'm 5"
      echo "  debug        — Help debug an error"
      echo "  optimize     — Performance optimization"
      echo "  review       — Code review"
      echo "  test         — Write tests"
      echo "  refactor     — Refactor code"
      echo "  document     — Write documentation"
      echo "  explain-error <msg> — Explain an error"
      echo "  howto <task>        — How to do something"
      echo "  why <question>      — Why something happens"
      ;;
  esac
}

# Session management
cmd_session() {
  local action="${1:-status}"
  
  case "$action" in
    start)
      local session_id
      session_id="session_$(date +%Y%m%d_%H%M%S)"
      cat > "$TINKERIA_SESSION" << EOF
{
  "id": "${session_id}",
  "started": "$(date -Iseconds)",
  "personality": "$(get_config 'personality' 'default')",
  "queries": 0
}
EOF
      echo "Session started: ${session_id}"
      ;;
    status)
      if [ -f "$TINKERIA_SESSION" ]; then
        python3 -c "
import json
s = json.load(open('$TINKERIA_SESSION'))
print(f'Session: {s[\"id\"]}')
print(f'Started: {s[\"started\"]}')
print(f'Personality: {s[\"personality\"]}')
print(f'Queries: {s[\"queries\"]}')
" 2>/dev/null
      else
        echo "No active session"
      fi
      ;;
    end)
      if [ -f "$TINKERIA_SESSION" ]; then
        rm "$TINKERIA_SESSION"
        echo "Session ended"
      fi
      ;;
  esac
}

# History
cmd_history() {
  local lines="${1:-20}"
  
  echo "=== Tinkeria History ==="
  echo ""
  
  if [ -f "$TINKERIA_HISTORY" ]; then
    tail -n "$lines" "$TINKERIA_HISTORY" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        role = '🤖' if d.get('role') == 'assistant' else '👤'
        msg = d.get('message', '')[:80]
        time = d.get('time', '')[:19]
        print(f'{role} [{time}] {msg}')
    except: pass
" 2>/dev/null
  else
    echo "No history yet"
  fi
}

# Clear history
cmd_clear() {
  > "$TINKERIA_HISTORY"
  echo "History cleared"
}

# Settings
cmd_settings() {
  echo "=== Tinkeria Settings ==="
  echo ""
  python3 -c "
import json
c = json.load(open('$TINKERIA_CONFIG'))
for k, v in c.items():
    print(f'  {k}: {v}')
" 2>/dev/null
}

case "${1:-help}" in
  chat)          shift; cmd_chat "$@" ;;
  personality)   shift; cmd_personality "$@" ;;
  quick)         shift; cmd_quick "$@" ;;
  session)       shift; cmd_session "$@" ;;
  history)       shift; cmd_history "$@" ;;
  clear)         cmd_clear ;;
  settings)      cmd_settings ;;
  init)          init_vokk ;;
  *)
    echo "KorrinOS Tinkeria AI Assistant"
    echo "Usage: korrinos-vokk.sh <command>"
    echo ""
    echo "Commands:"
    echo "  chat <query>              Chat with Tinkeria"
    echo "  personality [mode]        Set/list personality modes"
    echo "  quick <prompt>            Quick prompt templates"
    echo "  session start|status|end  Session management"
    echo "  history [lines]           Show chat history"
    echo "  clear                     Clear history"
    echo "  settings                  Show Tinkeria settings"
    echo "  init                      Initialize config"
    ;;
esac

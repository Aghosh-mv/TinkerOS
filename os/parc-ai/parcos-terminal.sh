#!/usr/bin/env bash
# korrinos-terminal.sh — Built-in Terminal with AI Integration
# Split panes, tabs, AI command suggestions, session recording

set -euo pipefail

TERM_DIR="${HOME}/.config/korrinos/terminal"
TERM_SESSIONS="$TERM_DIR/sessions"
TERM_CONFIG="$TERM_DIR/config.json"

mkdir -p "$TERM_DIR" "$TERM_SESSIONS"

# Initialize terminal config
term_init() {
  if [ ! -f "$TERM_CONFIG" ]; then
    cat > "$TERM_CONFIG" << 'DEFAULTS'
{
  "theme": "dark",
  "font": "JetBrains Mono",
  "font_size": 12,
  "opacity": 0.95,
  "scrollback": 10000,
  "bell": "visual",
  "cursor_shape": "block",
  "cursor_blink": true
}
DEFAULTS
    echo "Terminal config initialized"
  fi
}

# AI command suggestion
term_ai_suggest() {
  local description="$1"
  
  echo "AI suggests command for: $description"
  echo ""
  
  # Use Tinkeria for command suggestion
  if command -v parc-ai &>/dev/null; then
    parc-ai ask "What is the Linux command to: $description? Give me just the command, no explanation." 2>/dev/null
  else
    echo "Tinkeria not available for suggestions"
  fi
}

# AI explain command
term_ai_explain() {
  local cmd="$1"
  
  echo "Explaining: $cmd"
  echo ""
  
  if command -v parc-ai &>/dev/null; then
    parc-ai ask "Explain this Linux command in detail: $cmd" 2>/dev/null
  else
    man "$cmd" 2>/dev/null || echo "No manual available"
  fi
}

# AI fix error
term_ai_fix() {
  local error="$1"
  
  echo "Analyzing error..."
  echo ""
  
  if command -v parc-ai &>/dev/null; then
    parc-ai ask "How to fix this Linux error: $error" 2>/dev/null
  else
    echo "Tinkeria not available for error analysis"
  fi
}

# Record session
term_record_start() {
  local name="${1:-session_$(date +%Y%m%d_%H%M%S)}"
  local file="$TERM_SESSIONS/$name.log"
  
  script -f "$file"
  echo "Recording saved: $file"
}

# Replay session
term_replay() {
  local name="$1"
  local file="$TERM_SESSIONS/$name.log"
  
  if [ ! -f "$file" ]; then
    echo "Session not found: $name"
    return 1
  fi
  
  cat "$file"
}

# List sessions
term_sessions() {
  echo "=== Recorded Sessions ==="
  ls -lh "$TERM_SESSIONS"/*.log 2>/dev/null | awk '{print $NF, $5}' || echo "No sessions"
}

# Search history
term_history_search() {
  local query="$1"
  
  if [ -f "$HOME/.bash_history" ]; then
    grep -i "$query" "$HOME/.bash_history" | tail -20
  fi
}

# Quick command shortcuts
term_shortcuts() {
  echo "=== Terminal Shortcuts ==="
  echo ""
  echo "Navigation:"
  echo "  cd -              Previous directory"
  echo "  cd ~              Home directory"
  echo "  pushd <dir>       Push directory"
  echo "  popd              Pop directory"
  echo ""
  echo "File Operations:"
  echo "  ls -la            List all files"
  echo "  find . -name '*.py'  Find files"
  echo "  grep -r 'text' .  Search in files"
  echo "  cp -r src/ dst/   Copy directory"
  echo ""
  echo "Process Management:"
  echo "  ps aux | grep <name>  Find process"
  echo "  kill -9 <pid>     Kill process"
  echo "  top               Process monitor"
  echo "  htop              Better process monitor"
  echo ""
  echo "Disk:"
  echo "  df -h             Disk usage"
  echo "  du -sh *          Directory sizes"
  echo "  ncdu .            Interactive disk usage"
  echo ""
  echo "Network:"
  echo "  curl <url>        HTTP request"
  echo "  wget <url>        Download file"
  echo "  ssh user@host     Remote login"
  echo "  scp file host:    Copy to remote"
  echo ""
  echo "AI Integration:"
  echo "  tinker ask '...'  Ask Tinkeria"
  echo "  tinker fix '...'  Fix error with AI"
  echo "  tinker suggest '...'  Get command suggestion"
}

case "${1:-help}" in
  init)       term_init ;;
  suggest)    shift; term_ai_suggest "$@" ;;
  explain)    shift; term_ai_explain "$@" ;;
  fix)        shift; term_ai_fix "$@" ;;
  record)     term_record_start "${2:-}" ;;
  replay)     shift; term_replay "$@" ;;
  sessions)   term_sessions ;;
  history)    shift; term_history_search "$@" ;;
  shortcuts)  term_shortcuts ;;
  *)
    echo "KorrinOS Terminal with AI Integration"
    echo "Usage: korrinos-terminal.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init                  Initialize terminal config"
    echo "  suggest <description> Get AI command suggestion"
    echo "  explain <command>     Explain a command with AI"
    echo "  fix <error>           Fix error with AI"
    echo "  record [name]         Record terminal session"
    echo "  replay <name>         Replay a session"
    echo "  sessions              List recorded sessions"
    echo "  history <query>       Search command history"
    echo "  shortcuts             Show terminal shortcuts"
    ;;
esac

#!/usr/bin/env bash
# korrinos-shell-ai.sh — AI Shell Companion (small popup)
# Explains commands before running, small VOKK v4 integration

set -euo pipefail

# Explain a command before running
explain_cmd() {
  local cmd="$1"
  
  if command -v parc-ai &>/dev/null; then
    # Get brief explanation
    local explanation=$(parc-ai ask "Explain this command in 1 sentence: $cmd" 2>/dev/null)
    
    # Show small popup
    if command -v notify-send &>/dev/null; then
      notify-send -a "VOKK v4" -i terminal "$cmd" "$explanation" --expire-time=8000
    fi
    
    # Also print to terminal
    echo "💡 $explanation"
  fi
}

# Suggest command from description
suggest_cmd() {
  local description="$1"
  
  if command -v parc-ai &>/dev/null; then
    local suggestion=$(parc-ai ask "What Linux command does this: $description? Reply with ONLY the command, no explanation." 2>/dev/null)
    echo "$suggestion"
  fi
}

# Explain last error
explain_error() {
  local error="${1:-$(dmesg | tail -5)}"
  
  if command -v parc-ai &>/dev/null; then
    local explanation=$(parc-ai ask "Explain this error briefly: $error" 2>/dev/null)
    
    if command -v notify-send &>/dev/null; then
      notify-send -a "VOKK v4" -i dialog-error "Error" "$explanation" --expire-time=10000
    fi
    
    echo "🔍 $explanation"
  fi
}

case "${1:-help}" in
  explain)  shift; explain_cmd "$@" ;;
  suggest)  shift; suggest_cmd "$@" ;;
  error)    shift; explain_error "$@" ;;
  *)
    echo "KorrinOS AI Shell Companion"
    echo "Usage: korrinos-shell-ai.sh <command>"
    echo ""
    echo "Commands:"
    echo "  explain <cmd>       Explain a command"
    echo "  suggest <desc>      Suggest a command"
    echo "  error [text]        Explain last error"
    ;;
esac

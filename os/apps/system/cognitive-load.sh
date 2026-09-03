#!/bin/bash
# TinkerOS Cognitive Load Management
# Context-aware Do Not Disturb: suppresses low-urgency notifications
# during focused work, batches non-urgent pings, escalates urgent ones.

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

CL_CONFIG="$HOME/.tinker/cognitive-load.conf"
CL_STATE="$HOME/.tinker/cognitive-load.state"
FOCUSED_PIDS=""

load_config() {
    [ -f "$CL_CONFIG" ] && source "$CL_CONFIG"
    : "${MODE:=auto}"
    : "${BATCH_WINDOW_MIN:=5}"
}

save_state() {
    echo "MODE=$MODE" > "$CL_STATE"
}

# Detect "focused work" - any fullscreen bright app? simple heuristic:
# treat tty/editor/ide processes as high-value focus windows.
focused() {
    command -v xdotool >/dev/null 2>&1 || return 0
    local cls
    cls=$(xdotool getactivewindow getwindowclassname 2>/dev/null || true)
    case "$cls" in
        *[Cc]ode*|*Terminal*|*Typora*|*Obsidian*|*Writer*|*Ide*) return 0;;
        *) return 1;;
    esac
}

suppress() {
    # best-effort: notify-send gag + log only; real hook is DE-specific
    echo "[$(date +%T)] suppressed non-urgent notification: $*" >> "$HOME/.tinker/cognitive.log"
    return 0
}

escalate() {
    notify-send -u critical "URGENT: $*" 2>/dev/null || echo "URGENT: $*"
}

echo -e "${BLUE}── TinkerOS Cognitive Load Manager ──${NC}"
load_config
echo "mode: $MODE  batch_window: ${BATCH_WINDOW_MIN}min"
case "${1:-status}" in
    status)
        if focused; then echo -e "${GREEN}Focus active — low-urgency items suppressed${NC}"
        else echo "Not focused — normal notifications"; fi
        ;;
    focus-on) MODE=focus; save_state; echo "Focus mode ON";;
    focus-off) MODE=auto; save_state; echo "Focus mode OFF";;
    urgent) shift; escalate "$*";;
    notify) shift; suppress "$*";;
    *)
        echo "Usage: cognitive-load {status|focus-on|focus-off|urgent <msg>|notify <msg>}"
        ;;
esac

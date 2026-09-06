#!/bin/bash
# TinkerOS Intent-Driven Launcher
# "Type or say what you're doing" — assembles the right tools onto a
# unified canvas based on intent, then hands a working context to the
# target apps. Approximates the intent-driven OS architecture idea while
# remaining a safe user-space launcher.

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

launch_intent() {
    local intent="$1" low
    low=$(echo "$intent" | tr '[:upper:]' '[:lower:]')
    echo -e "${BLUE}── Intent: $intent ──${NC}"
    case "$low" in
        *"write"*|*"document"*|*"contract"*)
            echo "Assembling: text editor + templates + recent notes"
            command -v gedit >/dev/null 2>&1 && gedit >/dev/null 2>&1 &
            command -v typora >/dev/null 2>&1 && typora >/dev/null 2>&1 & ;;
        *"code"*|*"develop"*|*"program"*)
            echo "Assembling: editor + terminal + git"
            command -v code >/dev/null 2>&1 && code >/dev/null 2>&1 &
            x-terminal-emulator >/dev/null 2>&1 & ;;
        *"plan"*|*"trip"*|*"travel"*)
            echo "Assembling: browser + calendar + notes"
            xdg-open https://www.google.com/travel >/dev/null 2>&1 & ;;
        *"email"*|*"mail"*)
            echo "Assembling: mail client + address book"
            command -v thunderbird >/dev/null 2>&1 && thunderbird >/dev/null 2>&1 & ;;
        *"call"*|*"meeting"*|*"video"*)
            echo "Assembling: video conference"
            command -v zoom >/dev/null 2>&1 && zoom >/dev/null 2>&1 & ;;
        *)
            echo -e "${YELLOW}No prebuilt canvas for '$intent'${NC}"
            echo "  Try: write document, develop code, plan trip, email, meeting.";;
    esac
}

echo -e "${BLUE}── TinkerOS Intent Launcher ──${NC}"
if [ $# -ge 1 ]; then
    launch_intent "$*"
else
    read -r -p "what do you want to do? " intent
    launch_intent "$intent"
fi

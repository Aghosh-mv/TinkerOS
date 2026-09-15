#!/usr/bin/env bash
# korrinos-ascii.sh — ASCII Art Generator (part of TinkerAI)
# Text → ASCII art banners

set -euo pipefail

# Generate ASCII art using figlet
ascii_figlet() {
  local text="$1"
  local font="${2:-standard}"
  
  if command -v figlet &>/dev/null; then
    figlet -f "$font" "$text" 2>/dev/null || figlet "$text" 2>/dev/null
  else
    echo "Install figlet: sudo apt install figlet"
    echo "Available fonts: $(ls /usr/share/figlet/*.flf 2>/dev/null | xargs -I{} basename {} .flf | tr '\n' ', ')"
  fi
}

# Generate ASCII art using TinkerAI
ascii_ai() {
  local text="$1"
  local style="${2:-block}"
  
  if command -v parc-ai &>/dev/null; then
    parc-ai ask "Create ASCII art for '$text' in $style style. Only output the art, no explanation." 2>/dev/null
  else
    ascii_figlet "$text"
  fi
}

# List available fonts
list_fonts() {
  if command -v figlet &>/dev/null; then
    echo "=== Figlet Fonts ==="
    ls /usr/share/figlet/*.flf 2>/dev/null | xargs -I{} basename {} .flf
  else
    echo "Install figlet for font support"
  fi
}

# Generate a banner
banner() {
  local text="$1"
  local width="${2:-60}"
  
  local border=$(printf '═%.0s' $(seq 1 $width))
  local padding=$(( (width - ${#text} - 2) / 2 ))
  local padded=$(printf "%${padding}s" "")$text$(printf "%$((width - ${#text} - padding - 2))s" "")
  
  echo "╔${border}╗"
  echo "║${padded}║"
  echo "╚${border}╝"
}

case "${1:-help}" in
  figlet) shift; ascii_figlet "$@" ;;
  ai)     shift; ascii_ai "$@" ;;
  fonts)  list_fonts ;;
  banner) shift; banner "$@" ;;
  *)
    echo "KorrinOS ASCII Art Generator"
    echo "Usage: korrinos-ascii.sh <command>"
    echo ""
    echo "Commands:"
    echo "  figlet <text> [font]   Generate with figlet"
    echo "  ai <text> [style]      Generate with TinkerAI"
    echo "  fonts                  List available fonts"
    echo "  banner <text> [width]  Generate bordered banner"
    ;;
esac

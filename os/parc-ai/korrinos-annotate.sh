#!/usr/bin/env bash
# korrinos-annotate.sh — Screenshot Annotator
# Screenshot → draw arrows/text/highlights → share

set -euo pipefail

ANNOTATE_DIR="${HOME}/.local/share/korrinos/annotations"
mkdir -p "$ANNOTATE_DIR"

# Take screenshot
take_screenshot() {
  local output="$ANNOTATE_DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"
  
  if command -v scrot &>/dev/null; then
    scrot -s "$output" 2>/dev/null
  elif command -v gnome-screenshot &>/dev/null; then
    gnome-screenshot -a -f "$output" 2>/dev/null
  elif command -v import &>/dev/null; then
    import -window root "$output" 2>/dev/null
  elif command -v maim &>/dev/null; then
    maim -s "$output" 2>/dev/null
  else
    echo "No screenshot tool. Install: sudo apt install scrot"
    return 1
  fi
  
  [ -f "$output" ] && echo "$output" || echo "Screenshot failed"
}

# Annotate using ImageMagick
annotate() {
  local image="$1"
  shift
  
  if [ ! -f "$image" ]; then
    echo "Image not found: $image"
    return 1
  fi
  
  if ! command -v convert &>/dev/null; then
    echo "Install ImageMagick: sudo apt install imagemagick"
    return 1
  fi
  
  local output="${image%.*}_annotated.${image##*.}"
  cp "$image" "$output"
  
  # Parse annotations from args
  while [ $# -gt 0 ]; do
    case "$1" in
      arrow)
        local x1="$2" y1="$3" x2="$4" y2="$5"
        convert "$output" -stroke red -strokewidth 3 \
          -draw "line $x1,$y1 $x2,$y2" \
          -draw "polygon $((x2-10)),$((y2-5)) $((x2-10)),$((y2+5)) $x2,$y2" \
          "$output"
        shift 5
        ;;
      text)
        local x="$2" y="$3" msg="$4"
        convert "$output" -fill white -stroke black -strokewidth 1 \
          -font Helvetica -pointsize 20 \
          -annotate +${x}+${y} "$msg" \
          "$output"
        shift 4
        ;;
      highlight)
        local x="$2" y="$3" w="$4" h="$5"
        convert "$output" \
          -fill "rgba(255,255,0,0.3)" -stroke yellow -strokewidth 2 \
          -draw "rectangle $x,$y $((x+w)),$((y+h))" \
          "$output"
        shift 5
        ;;
      blur)
        local x="$2" y="$3" w="$4" h="$5"
        convert "$output" -region ${w}x${h}+${x}+${y} -blur 0x10 "$output"
        shift 5
        ;;
      circle)
        local x="$2" y="$3" r="$4"
        convert "$output" -stroke red -strokewidth 3 -fill none \
          -draw "circle $x,$y $((x+r)),$y" \
          "$output"
        shift 4
        ;;
      *)
        shift
        ;;
    esac
  done
  
  echo "Annotated: $output"
}

# Quick annotate with presets
quick_annotate() {
  local image="$1"
  local preset="$2"
  
  case "$preset" in
    redact)
    # Blur sensitive areas
    local w=$(identify -format "%w" "$image" 2>/dev/null)
    local h=$(identify -format "%h" "$image" 2>/dev/null)
    annotate "$image" blur 10 10 $((w/4)) $((h/4))
    ;;
    highlight)
      annotate "$image" highlight 50 50 200 30
      ;;
    *)
      echo "Presets: redact, highlight"
      ;;
  esac
}

# Share annotated image
share() {
  local image="$1"
  
  # Copy to clipboard
  if command -v xclip &>/dev/null; then
    xclip -selection clipboard -t image/png -i "$image" 2>/dev/null
    echo "Copied to clipboard"
  fi
  
  # Open sharing dialog
  if command -v gnome-screenshot &>/dev/null; then
    gnome-screenshot -f "$image" 2>/dev/null
  fi
  
  echo "Image: $image"
}

case "${1:-help}" in
  screenshot) take_screenshot ;;
  annotate)   shift; annotate "$@" ;;
  quick)      shift; quick_annotate "$@" ;;
  share)      shift; share "$@" ;;
  *)
    echo "KorrinOS Screenshot Annotator"
    echo "Usage: korrinos-annotate.sh <command>"
    echo ""
    echo "Commands:"
    echo "  screenshot              Take a screenshot"
    echo "  annotate <img> [ops]    Annotate image"
    echo "  quick <img> <preset>    Quick annotate (redact/highlight)"
    echo "  share <img>             Share/clipboard"
    echo ""
    echo "Annotation ops:"
    echo "  arrow x1 y1 x2 y2      Draw arrow"
    echo "  text x y \"message\"      Add text"
    echo "  highlight x y w h      Highlight area"
    echo "  blur x y w h           Blur area"
    echo "  circle x y r           Draw circle"
    ;;
esac

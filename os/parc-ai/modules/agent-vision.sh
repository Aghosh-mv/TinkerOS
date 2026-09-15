#!/usr/bin/env bash
# agent-vision.sh — computer vision: read screen, find elements, visual understanding

AGENT_DIR="${TINKER_AI_HOME:-$HOME/.config/tinker-ai}/agent"
mkdir -p "$AGENT_DIR/screenshots"

# Take screenshot and read all text
agent_vision_read() {
  local screenshot="${1:-}"
  if [ -z "$screenshot" ]; then
    screenshot="$AGENT_DIR/screenshots/vision_$(date +%s).png"
    scrot -o "$screenshot" 2>/dev/null
  fi
  
  if [ ! -f "$screenshot" ]; then
    echo "Screenshot failed"; return 1
  fi
  
  # Get image info
  local info
  info=$(python3 -c "
from PIL import Image
img = Image.open('$screenshot')
print(f'Size: {img.size[0]}x{img.size[1]}')
" 2>/dev/null)
  
  # OCR all text
  local text
  text=$(tesseract "$screenshot" - 2>/dev/null)
  
  echo "=== Screen Analysis ==="
  echo "$info"
  echo ""
  echo "Text on screen:"
  echo "$text"
}

# Find where something is on screen (returns coordinates)
agent_vision_find() {
  local target="$1"
  local screenshot="$AGENT_DIR/screenshots/find_$(date +%s).png"
  scrot -o "$screenshot" 2>/dev/null
  
  python3 -c "
from PIL import Image
import subprocess, re

img = Image.open('$screenshot')
w, h = img.size

# OCR with coordinates
result = subprocess.run(['tesseract', '$screenshot', '-', '--dpi', '96', 'tsv'], capture_output=True, text=True)
lines = result.stdout.strip().split('\n')

# Parse TSV for word positions
header = lines[0].split('\t')
target = '$target'.lower()
found_words = []

for line in lines[1:]:
    parts = line.split('\t')
    if len(parts) >= 12:
        word = parts[11].strip()
        if word and target in word.lower():
            x = int(parts[6])
            y = int(parts[7])
            w = int(parts[8])
            h = int(parts[9])
            cx = x + w // 2
            cy = y + h // 2
            found_words.append((word, cx, cy))

if found_words:
    for word, cx, cy in found_words:
        print(f'Found \"{word}\" at ({cx}, {cy})')
    # Return center of all matches
    avg_x = sum(w[1] for w in found_words) // len(found_words)
    avg_y = sum(w[2] for w in found_words) // len(found_words)
    print(f'Click target: ({avg_x}, {avg_y})')
else:
    print(f'\"$target\" not found on screen')
" 2>/dev/null
}

# Click on text found on screen
agent_vision_click() {
  local target="$1"
  local coords
  coords=$(agent_vision_find "$target" 2>/dev/null | grep "Click target:" | grep -oP '\(\d+, \d+\)' | tail -1)
  
  if [ -n "$coords" ]; then
    local x=$(echo "$coords" | grep -oP '\d+' | head -1)
    local y=$(echo "$coords" | grep -oP '\d+' | tail -1)
    xdotool mousemove --sync "$x" "$y" 2>/dev/null
    sleep 0.2
    xdotool click 1 2>/dev/null
    echo "Clicked on \"$target\" at ($x, $y)"
  else
    echo "Could not find \"$target\" on screen"
  fi
}

# Describe what's on screen (uses LLM for vision)
agent_vision_describe() {
  local screenshot="${1:-}"
  if [ -z "$screenshot" ]; then
    screenshot="$AGENT_DIR/screenshots/describe_$(date +%s).png"
    scrot -o "$screenshot" 2>/dev/null
  fi
  
  # Get text content
  local text
  text=$(tesseract "$screenshot" - 2>/dev/null)
  
  # Get image properties
  local props
  props=$(python3 -c "
from PIL import Image
img = Image.open('$screenshot')
w, h = img.size
# Color analysis
pixels = list(img.getdata())[:10000]
r_avg = sum(p[0] for p in pixels) // len(pixels)
g_avg = sum(p[1] for p in pixels) // len(pixels)
b_avg = sum(p[2] for p in pixels) // len(pixels)
brightness = (r_avg + g_avg + b_avg) / 3
print(f'Dimensions: {w}x{h}')
print(f'Brightness: {brightness:.0f}/255 ({\"bright\" if brightness > 128 else \"dark\"})')
" 2>/dev/null)
  
  echo "=== Screen Description ==="
  echo "$props"
  echo ""
  echo "Visible text:"
  echo "$text"
  
  # If ollama available, ask for visual description
  if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo ""
    echo "AI Analysis:"
    curl -s http://localhost:11434/api/generate \
      -d "{\"model\":\"llama3.1:8b\",\"prompt\":\"Describe what you see on this computer screen based on the following text extracted via OCR. Be concise and note any buttons, menus, input fields, or important UI elements:\\n\\n$text\",\"stream\":false}" 2>/dev/null | \
      python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null
  fi
}

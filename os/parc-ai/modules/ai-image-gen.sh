#!/usr/bin/env bash
# ai-image-gen.sh — Image generation for TinkerAI cards and visual content
# Uses Pillow/ImageMagick for dynamic UI cards

# Generate a gradient background card
ai_gen_gradient_card() {
  local title="$1" subtitle="$2" color1="${3:-#1a1e2e}" color2="${4:-#2d1b69}"
  local output="${5:-/tmp/tinkerai_card_$(date +%s).png}"

  # Strip # from colors for Python
  local c1="${color1//#/}"
  local c2="${color2//#/}"

  python3 << PYEOF
from PIL import Image, ImageDraw, ImageFont
import os

w, h = 800, 400
img = Image.new('RGB', (w, h))
draw = ImageDraw.Draw(img)

# Gradient
for y in range(h):
    r = int("$c1"[0:2], 16) + (int("$c2"[0:2], 16) - int("$c1"[0:2], 16)) * y // h
    g = int("$c1"[2:4], 16) + (int("$c2"[2:4], 16) - int("$c1"[2:4], 16)) * y // h
    b = int("$c1"[4:6], 16) + (int("$c2"[4:6], 16) - int("$c1"[4:6], 16)) * y // h
    draw.line([(0, y), (w, y)], fill=(r, g, b))

# Rounded rectangle overlay
draw.rounded_rectangle([20, 20, w-20, h-20], radius=20, fill=(26, 30, 42, 180))

# Title
try:
    font_title = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/Ubuntu-Bold.ttf", 36)
    font_sub = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/Ubuntu.ttf", 20)
except:
    font_title = ImageFont.load_default()
    font_sub = ImageFont.load_default()

draw.text((w//2, h//2 - 40), "$title", fill=(200, 215, 255), font=font_title, anchor="mm")
draw.text((w//2, h//2 + 20), "$subtitle", fill=(150, 165, 200), font=font_sub, anchor="mm")

img.save("$output")
print("$output")
PYEOF
}

# Generate a code card with syntax highlighting
ai_gen_code_card() {
  local code="$1" lang="${2:-python}"
  local output="${3:-/tmp/tinkerai_code_$(date +%s).png}"

  python3 << PYEOF
from PIL import Image, ImageDraw, ImageFont
import textwrap

code_text = """$code"""
lines = code_text.strip().split('\n')

w = 700
h = max(200, len(lines) * 22 + 80)
img = Image.new('RGB', (w, h), (13, 17, 23))
draw = ImageDraw.Draw(img)

# Title bar
draw.rectangle([0, 0, w, 35], fill=(33, 38, 45))
draw.ellipse([12, 12, 22, 22], fill=(255, 95, 86))
draw.ellipse([30, 12, 40, 22], fill=(255, 189, 46))
draw.ellipse([48, 12, 58, 22], fill=(39, 201, 63))

try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 14)
    font_title = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/Ubuntu.ttf", 12)
except:
    font = ImageFont.load_default()
    font_title = font

draw.text((w//2, 18), "$lang", fill=(139, 148, 158), font=font_title, anchor="mm")

# Code content
y = 50
colors = {
    'def': (198, 120, 221), 'class': (198, 120, 221),
    'import': (198, 120, 221), 'from': (198, 120, 221),
    'return': (255, 123, 114), 'if': (255, 123, 114),
    'else': (255, 123, 114), 'elif': (255, 123, 114),
    'for': (255, 123, 114), 'while': (255, 123, 114),
    '#': (106, 115, 125), '"""': (106, 115, 125),
    'print': (121, 192, 255), 'self': (255, 123, 114),
    'True': (255, 123, 114), 'False': (255, 123, 114),
    'None': (255, 123, 114),
}

for line in lines:
    # Line number
    draw.text((10, y), f"{lines.index(line)+1:3d}", fill=(106, 115, 125), font=font)
    # Syntax highlight
    x = 45
    for word in line.split():
        color = (201, 209, 217)
        for kw, c in colors.items():
            if word.startswith(kw):
                color = c
                break
        draw.text((x, y), word + " ", fill=color, font=font)
        x += font.getlength(word + " ")
    y += 22

img.save("$output")
print("$output")
PYEOF
}

# Generate a flowchart card
ai_gen_flowchart() {
  local steps="$1" title="$2"
  local output="${3:-/tmp/tinkerai_flow_$(date +%s).png}"

  python3 << PYEOF
from PIL import Image, ImageDraw, ImageFont

steps = "$steps".split(',')
title = "$title"

w = 800
h = max(300, len(steps) * 80 + 100)
img = Image.new('RGB', (w, h), (26, 30, 42))
draw = ImageDraw.Draw(img)

try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/Ubuntu-Bold.ttf", 18)
    font_sm = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/Ubuntu.ttf", 14)
except:
    font = ImageFont.load_default()
    font_sm = font

# Title
draw.text((w//2, 30), title, fill=(200, 215, 255), font=font, anchor="mm")

# Steps
colors = [(108, 99, 255), (0, 200, 150), (255, 159, 67), (255, 99, 132), (54, 162, 235)]
for i, step in enumerate(steps):
    y = 80 + i * 70
    color = colors[i % len(colors)]
    # Box
    draw.rounded_rectangle([100, y, w-100, y+50], radius=10, fill=(45, 55, 72), outline=color, width=2)
    # Text
    draw.text((w//2, y+25), step.strip(), fill=(220, 230, 255), font=font_sm, anchor="mm")
    # Arrow
    if i < len(steps) - 1:
        draw.line([(w//2, y+50), (w//2, y+70)], fill=(100, 120, 160), width=2)
        draw.polygon([(w//2-5, y+65), (w//2+5, y+65), (w//2, y+75)], fill=(100, 120, 160))

img.save("$output")
print("$output")
PYEOF
}

# Generate a data visualization card
ai_gen_chart() {
  local data="$1" title="$2" chart_type="${3:-bar}"
  local output="${4:-/tmp/tinkerai_chart_$(date +%s).png}"

  python3 << PYEOF
from PIL import Image, ImageDraw, ImageFont
import math

data = "$data".split(',')
title = "$title"
values = [float(x.strip()) for x in data]

w, h = 700, 400
img = Image.new('RGB', (w, h), (26, 30, 42))
draw = ImageDraw.Draw(img)

try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/Ubuntu-Bold.ttf", 20)
    font_sm = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/Ubuntu.ttf", 12)
except:
    font = ImageFont.load_default()
    font_sm = font

# Title
draw.text((w//2, 30), title, fill=(200, 215, 255), font=font, anchor="mm")

# Bar chart
max_val = max(values) if values else 1
bar_w = (w - 100) // len(values) if values else 50
colors = [(108, 99, 255), (0, 200, 150), (255, 159, 67), (255, 99, 132),
          (54, 162, 235), (255, 206, 86), (153, 102, 255), (255, 159, 67)]

for i, val in enumerate(values):
    x = 50 + i * bar_w
    bar_h = int((val / max_val) * 250)
    color = colors[i % len(colors)]
    draw.rounded_rectangle([x+5, h-50-bar_h, x+bar_w-5, h-50], radius=5, fill=color)
    draw.text((x + bar_w//2, h-30), f"{val:.0f}", fill=(200, 215, 255), font=font_sm, anchor="mm")
    draw.text((x + bar_w//2, h-55-bar_h), f"{val:.0f}", fill=(200, 215, 255), font=font_sm, anchor="mm")

img.save("$output")
print("$output")
PYEOF
}

# Generate a notification/alert card
ai_gen_alert() {
  local message="$1" alert_type="${2:-info}"
  local output="${3:-/tmp/tinkerai_alert_$(date +%s).png}"

  python3 << PYEOF
from PIL import Image, ImageDraw, ImageFont

msg = "$message"
alert_type = "$alert_type"

colors = {
    'info': (54, 162, 235),
    'success': (0, 200, 150),
    'warning': (255, 159, 67),
    'error': (255, 99, 132),
}
color = colors.get(alert_type, colors['info'])

icons = {'info': 'ℹ️', 'success': '✅', 'warning': '⚠️', 'error': '❌'}

w, h = 600, 120
img = Image.new('RGB', (w, h), (26, 30, 42))
draw = ImageDraw.Draw(img)

# Left accent
draw.rectangle([0, 0, 6, h], fill=color)

# Message
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/Ubuntu.ttf", 18)
except:
    font = ImageFont.load_default()

draw.text((30, h//2), msg, fill=(220, 230, 255), font=font, anchor="lm")

img.save("$output")
print("$output")
PYEOF
}

# Generate a progress card
ai_gen_progress() {
  local percent="$1" label="$2"
  local output="${3:-/tmp/tinkerai_progress_$(date +%s).png}"

  python3 << PYEOF
from PIL import Image, ImageDraw, ImageFont

pct = int("$percent")
label = "$label"

w, h = 500, 100
img = Image.new('RGB', (w, h), (26, 30, 42))
draw = ImageDraw.Draw(img)

try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/ubuntu/Ubuntu.ttf", 14)
except:
    font = ImageFont.load_default()

# Background bar
draw.rounded_rectangle([20, 40, w-20, 60], radius=10, fill=(45, 55, 72))

# Progress bar
bar_w = int((w-40) * pct / 100)
if bar_w > 0:
    draw.rounded_rectangle([20, 40, 20+bar_w, 60], radius=10, fill=(108, 99, 255))

# Label
draw.text((20, 25), label, fill=(200, 215, 255), font=font)
draw.text((w-20, 25), f"{pct}%", fill=(150, 165, 200), font=font, anchor="rm")

img.save("$output")
print("$output")
PYEOF
}

echo "[ai-image-gen] loaded — gradient, code, flowchart, chart, alert, progress cards"

#!/usr/bin/env bash
# parcos-features.sh — New ParcOS features

# Feature 1: System Health Dashboard
tk_health_dashboard() {
  echo "=== ParcOS Health Dashboard ==="
  echo ""

  # CPU
  local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
  local cpu_cores=$(nproc)
  echo "CPU: ${cpu_usage}% used (${cpu_cores} cores)"

  # Memory
  local mem_info=$(free -m | awk 'NR==2{printf "Memory: %s/%s MB (%.1f%%)", $3, $2, $3*100/$2}')
  echo "$mem_info"

  # Disk
  local disk_info=$(df -h / | awk 'NR==2{printf "Disk: %s/%s (%s used)", $3, $2, $5}')
  echo "$disk_info"

  # Network
  local net_up=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo 0)
  local net_down=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo 0)
  echo "Network: ↑$(numfmt --to=iec $net_up) ↓$(numfmt --to=iec $net_down)"

  # Temperature
  local temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1)
  if [ -n "$temp" ]; then
    echo "Temperature: $((temp/1000))°C"
  fi

  # Uptime
  echo "Uptime: $(uptime -p)"

  # Battery (if laptop)
  if [ -f /sys/class/power_supply/BAT0/capacity ]; then
    local bat=$(cat /sys/class/power_supply/BAT0/capacity)
    local bat_status=$(cat /sys/class/power_supply/BAT0/status)
    echo "Battery: ${bat}% (${bat_status})"
  fi
}

# Feature 2: Quick Actions
tk_quick_action() {
  local action="$1"
  case "$action" in
    clean-cache)
      echo "Cleaning package cache..."
      sudo apt-get clean 2>/dev/null
      echo "Cleaning thumbnail cache..."
      rm -rf ~/.cache/thumbnails/*
      echo "Cache cleaned!"
      ;;
    update-system)
      echo "Updating system..."
      sudo apt-get update && sudo apt-get upgrade -y
      echo "System updated!"
      ;;
    find-large)
      echo "Large files (>100MB):"
      find / -type f -size +100M 2>/dev/null | head -20
      ;;
    top-processes)
      echo "Top 10 processes by CPU:"
      ps aux --sort=-%cpu | head -11
      echo ""
      echo "Top 10 processes by Memory:"
      ps aux --sort=-%mem | head -11
      ;;
    disk-usage)
      echo "Disk usage by directory:"
      du -sh /* 2>/dev/null | sort -rh | head -15
      ;;
    open-ports)
      echo "Open ports:"
      ss -tuln 2>/dev/null | head -20
      ;;
    *) echo "Unknown action. Use: clean-cache, update-system, find-large, top-processes, disk-usage, open-ports" ;;
  esac
}

# Feature 3: Project Templates
tk_project_template() {
  local type="$1"
  local name="${2:-my_project}"

  case "$type" in
    python)
      mkdir -p "$name"/{src,tests,docs}
      cat > "$name"/src/main.py << 'EOF'
#!/usr/bin/env python3
"""Main module."""
import sys

def main():
    print("Hello from ParcOS!")

if __name__ == "__main__":
    main()
EOF
      cat > "$name"/setup.py << 'EOF'
from setuptools import setup, find_packages

setup(
    name="my_project",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[],
)
EOF
      cat > "$name"/requirements.txt << 'EOF'
# Add dependencies here
EOF
      cat > "$name"/README.md << EOF
# $name

A Python project created with ParcOS.

## Installation
\`\`\`bash
pip install -e .
\`\`\`

## Usage
\`\`\`bash
python src/main.py
\`\`\`
EOF
      echo "Python project created: $name/"
      ;;
    node)
      mkdir -p "$name"/{src,public}
      cat > "$name"/package.json << EOF
{
  "name": "$name",
  "version": "1.0.0",
  "description": "A Node.js project",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest"
  }
}
EOF
      cat > "$name"/src/index.js << 'EOF'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Hello from ParcOS!');
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF
      echo "Node.js project created: $name/"
      ;;
    rust)
      mkdir -p "$name"/src
      cat > "$name"/Cargo.toml << EOF
[package]
name = "$name"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF
      cat > "$name"/src/main.rs << 'EOF'
fn main() {
    println!("Hello from ParcOS!");
}
EOF
      echo "Rust project created: $name/"
      ;;
    bash)
      mkdir -p "$name"
      cat > "$name"/main.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

main() {
  echo "Hello from ParcOS!"
}

main "$@"
EOF
      chmod +x "$name"/main.sh
      echo "Bash project created: $name/"
      ;;
    *) echo "Unknown type. Use: python, node, rust, bash" ;;
  esac
}

# Feature 4: System Monitor (live)
tk_system_monitor() {
  local duration="${1:-10}"
  echo "System monitor (Ctrl+C to stop)..."
  for i in $(seq 1 "$duration"); do
    clear
    echo "=== ParcOS Monitor (update $i/$duration) ==="
    echo "Time: $(date)"
    echo ""
    echo "CPU:"
    mpstat 1 1 2>/dev/null | tail -1 || top -bn1 | head -5
    echo ""
    echo "Memory:"
    free -m | head -2
    echo ""
    echo "Disk I/O:"
    iostat 1 1 2>/dev/null | tail -3 || echo "iostat not available"
    echo ""
    echo "Network:"
    cat /proc/net/dev | head -5
    sleep 1
  done
}

# Feature 5: Backup Tool
tk_backup() {
  local src="$1"
  local dest="${2:-$HOME/backups}"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_name="backup_${timestamp}.tar.gz"

  mkdir -p "$dest"

  echo "Backing up $src to $dest/$backup_name..."
  tar -czf "$dest/$backup_name" "$src" 2>/dev/null
  local size=$(du -sh "$dest/$backup_name" | cut -f1)
  echo "Backup complete: $dest/$backup_name ($size)"
}

# Feature 6: Quick Notes
tk_notes_dir="$HOME/.parcos/notes"
tk_notes_init() { mkdir -p "$tk_notes_dir"; }

tk_notes_add() {
  tk_notes_init
  local note="$*"
  local timestamp=$(date '+%Y-%m-%d %H:%M')
  echo "[$timestamp] $note" >> "$tk_notes_dir/notes.txt"
  echo "Note added!"
}

tk_notes_list() {
  tk_notes_init
  if [ -f "$tk_notes_dir/notes.txt" ]; then
    cat -n "$tk_notes_dir/notes.txt"
  else
    echo "No notes yet."
  fi
}

tk_notes_clear() {
  tk_notes_init
  rm -f "$tk_notes_dir/notes.txt"
  echo "Notes cleared!"
}

# Feature 7: Color Theme Generator
tk_color_theme() {
  local base_color="${1:-#6C63FF}"
  python3 << PYEOF
import colorsys

base = "$base_color"
r = int(base[1:3], 16) / 255
g = int(base[3:5], 16) / 255
b = int(base[5:7], 16) / 255

h, s, v = colorsys.rgb_to_hsv(r, g, b)

print(f"Base: {base}")
print(f"HSV: H={h*360:.0f} S={s*100:.0f}% V={v*100:.0f}%")
print()
print("Generated palette:")

for i in range(8):
    new_h = (h + i * 0.125) % 1.0
    nr, ng, nb = colorsys.hsv_to_rgb(new_h, s, v)
    hex_color = f"#{int(nr*255):02x}{int(ng*255):02x}{int(nb*255):02x}"
    print(f"  {hex_color}")

print()
print("Complementary:")
comp_h = (h + 0.5) % 1.0
cr, cg, cb = colorsys.hsv_to_rgb(comp_h, s, v)
print(f"  #{int(cr*255):02x}{int(cg*255):02x}{int(cb*255):02x}")

print()
print("Analogous:")
for i in [-1, 1]:
    an_h = (h + i * 0.083) % 1.0
    ar, ag, ab = colorsys.hsv_to_rgb(an_h, s, v)
    print(f"  #{int(ar*255):02x}{int(ag*255):02x}{int(ab*255):02x}")
PYEOF
}

# Feature 8: Clipboard Manager
tk_clipboard_history="/tmp/parcos_clipboard.txt"

tk_clip_save() {
  local text="${*:-$(xclip -o 2>/dev/null)}"
  echo "$text" >> "$tk_clipboard_history"
  echo "Saved to clipboard history"
}

tk_clip_list() {
  if [ -f "$tk_clipboard_history" ]; then
    cat -n "$tk_clipboard_history" | tail -20
  else
    echo "No clipboard history"
  fi
}

tk_clip_clear() {
  rm -f "$tk_clipboard_history"
  echo "Clipboard history cleared"
}

echo "[parcos-features] loaded — health dashboard, quick actions, project templates, monitor, backup, notes, themes, clipboard"

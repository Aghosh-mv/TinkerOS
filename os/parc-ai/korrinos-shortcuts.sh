#!/usr/bin/env bash
# korrinos-shortcuts.sh — Keyboard Shortcuts Manager
# Global hotkeys, custom shortcuts, shortcut presets

set -euo pipefail

SHORTCUTS_DIR="${HOME}/.config/korrinos/shortcuts"
SHORTCUTS_CONFIG="$SHORTCUTS_DIR/config.json"
SHORTCUTS_CUSTOM="$SHORTCUTS_DIR/custom.json"
mkdir -p "$SHORTCUTS_DIR"

# Default shortcuts
declare -A DEFAULT_SHORTCUTS=(
  # System
  ["super+l"]="lock-screen"
  ["super+shift+q"]="logout"
  ["ctrl+alt+delete"]="shutdown-menu"
  ["super+d"]="show-desktop"
  ["super+space"]="application-menu"
  ["alt+tab"]="switch-windows"
  ["alt+shift+tab"]="switch-windows-reverse"
  ["super+tab"]="switch-applications"
  
  # Window management
  ["super+left"]="snap-left"
  ["super+right"]="snap-right"
  ["super+up"]="maximize"
  ["super+down"]="minimize"
  ["super+h"]="hide-window"
  ["super+q"]="close-window"
  ["super+n"]="minimize"
  
  # Workspaces
  ["super+1"]="workspace-1"
  ["super+2"]="workspace-2"
  ["super+3"]="workspace-3"
  ["super+4"]="workspace-4"
  ["super+5"]="workspace-5"
  ["ctrl+super+left"]="workspace-prev"
  ["ctrl+super+right"]="workspace-next"
  
  # Screenshots
  ["print"]="screenshot-full"
  ["ctrl+print"]="screenshot-area"
  ["alt+print"]="screenshot-window"
  ["shift+print"]="screenshot-clipboard"
  
  # Media
  ["ctrl+alt+m"]="mute"
  ["ctrl+alt+up"]="volume-up"
  ["ctrl+alt+down"]="volume-down"
  ["ctrl+alt+p"]="play-pause"
  ["ctrl+alt+right"]="next-track"
  ["ctrl+alt+left"]="prev-track"
  
  # Tinkeria AI
  ["super+space+space"]="vokk-quick"
  ["ctrl+shift+space"]="vokk-chat"
  
  # KorrinOS specific
  ["super+k"]="korrinos-dashboard"
  ["super+shift+c"]="korrinos-cleanup"
  ["super+shift+b"]="korrinos-backup"
  ["super+shift+m"]="korrinos-monitor"
)

# Initialize shortcuts config
init_shortcuts() {
  if [ ! -f "$SHORTCUTS_CONFIG" ]; then
    python3 -c "
import json
shortcuts = {
    'super+l': 'lock-screen',
    'super+shift+q': 'logout',
    'ctrl+alt+delete': 'shutdown-menu',
    'super+d': 'show-desktop',
    'super+space': 'application-menu',
    'alt+tab': 'switch-windows',
    'super+left': 'snap-left',
    'super+right': 'snap-right',
    'super+up': 'maximize',
    'super+down': 'minimize',
    'super+q': 'close-window',
    'super+1': 'workspace-1',
    'super+2': 'workspace-2',
    'super+3': 'workspace-3',
    'super+4': 'workspace-4',
    'super+5': 'workspace-5',
    'print': 'screenshot-full',
    'ctrl+print': 'screenshot-area',
    'ctrl+alt+m': 'mute',
    'ctrl+alt+up': 'volume-up',
    'ctrl+alt+down': 'volume-down',
    'super+k': 'korrinos-dashboard',
    'super+shift+c': 'korrinos-cleanup',
    'super+shift+b': 'korrinos-backup'
}
with open('$SHORTCUTS_CONFIG', 'w') as f:
    json.dump({'shortcuts': shortcuts, 'presets': {}}, f, indent=2)
print('Shortcuts config initialized')
"
  fi
}

# List shortcuts
cmd_list() {
  echo "=== KorrinOS Keyboard Shortcuts ==="
  echo ""
  
  python3 -c "
import json
with open('$SHORTCUTS_CONFIG') as f:
    c = json.load(f)
shortcuts = c.get('shortcuts', {})

# Group by category
categories = {
    'System': ['lock-screen', 'logout', 'shutdown-menu', 'show-desktop', 'application-menu', 'switch-windows'],
    'Window Management': ['snap-left', 'snap-right', 'maximize', 'minimize', 'hide-window', 'close-window'],
    'Workspaces': ['workspace-1', 'workspace-2', 'workspace-3', 'workspace-4', 'workspace-5', 'workspace-prev', 'workspace-next'],
    'Screenshots': ['screenshot-full', 'screenshot-area', 'screenshot-window', 'screenshot-clipboard'],
    'Media': ['mute', 'volume-up', 'volume-down', 'play-pause', 'next-track', 'prev-track'],
    'Tinkeria AI': ['vokk-quick', 'vokk-chat'],
    'KorrinOS': ['korrinos-dashboard', 'korrinos-cleanup', 'korrinos-backup', 'korrinos-monitor']
}

# Reverse map: action -> key
action_to_key = {v: k for k, v in shortcuts.items()}

for cat, actions in categories.items():
    print(f'  {cat}:')
    for action in actions:
        key = action_to_key.get(action, 'not set')
        print(f'    {key:25} → {action}')
    print()
" 2>/dev/null
}

# Set shortcut
cmd_set() {
  local key="$1"
  local action="$2"
  
  python3 -c "
import json
with open('$SHORTCUTS_CONFIG') as f:
    c = json.load(f)
c['shortcuts']['$key'] = '$action'
with open('$SHORTCUTS_CONFIG', 'w') as f:
    json.dump(c, f, indent=2)
print(f'Set: {\"$key\"} → {\"$action\"}')
"
}

# Remove shortcut
cmd_remove() {
  local key="$1"
  
  python3 -c "
import json
with open('$SHORTCUTS_CONFIG') as f:
    c = json.load(f)
if '$key' in c['shortcuts']:
    del c['shortcuts']['$key']
    with open('$SHORTCUTS_CONFIG', 'w') as f:
        json.dump(c, f, indent=2)
    print(f'Removed: {\"$key\"}')
else:
    print(f'Not found: {\"$key\"}')
"
}

# Preset shortcuts
cmd_preset() {
  local preset="$1"
  
  case "$preset" in
    gnome|gnome3)
      echo "Loading GNOME preset..."
      python3 -c "
import json
presets = {
    'super+l': 'lock-screen',
    'alt+f2': 'run-command',
    'super+a': 'show-apps',
    'super+tab': 'switch-applications',
    'ctrl+alt+t': 'terminal',
    'print': 'screenshot-full',
    'ctrl+print': 'screenshot-area'
}
with open('$SHORTCUTS_CONFIG') as f:
    c = json.load(f)
c['shortcuts'].update(presets)
with open('$SHORTCUTS_CONFIG', 'w') as f:
    json.dump(c, f, indent=2)
print('GNOME preset loaded')
"
      ;;
    kde)
      echo "Loading KDE preset..."
      python3 -c "
import json
presets = {
    'alt+space': 'kicker',
    'ctrl+alt+t': 'terminal',
    'super+e': 'file-manager',
    'super+l': 'lock-screen',
    'ctrl+alt+l': 'screen-locker'
}
with open('$SHORTCUTS_CONFIG') as f:
    c = json.load(f)
c['shortcuts'].update(presets)
with open('$SHORTCUTS_CONFIG', 'w') as f:
    json.dump(c, f, indent=2)
print('KDE preset loaded')
"
      ;;
    macos)
      echo "Loading macOS-style preset..."
      python3 -c "
import json
presets = {
    'super+space': 'spotlight',
    'super+q': 'quit-app',
    'super+w': 'close-window',
    'super+m': 'minimize',
    'super+h': 'hide-window',
    'ctrl+super+f': 'fullscreen',
    'super+,': 'preferences'
}
with open('$SHORTCUTS_CONFIG') as f:
    c = json.load(f)
c['shortcuts'].update(presets)
with open('$SHORTCUTS_CONFIG', 'w') as f:
    json.dump(c, f, indent=2)
print('macOS preset loaded')
"
      ;;
    *)
      echo "Available presets: gnome, kde, macos"
      ;;
  esac
}

# Export shortcuts
cmd_export() {
  echo "=== Exported Shortcuts ==="
  echo ""
  cat "$SHORTCUTS_CONFIG" 2>/dev/null
}

# Import shortcuts
cmd_import() {
  local file="$1"
  
  if [ -f "$file" ]; then
    cp "$file" "$SHORTCUTS_CONFIG"
    echo "Imported shortcuts from: ${file}"
  else
    echo "File not found: ${file}"
    return 1
  fi
}

case "${1:-help}" in
  init)          init_shortcuts ;;
  list)          cmd_list ;;
  set)           shift; cmd_set "$@" ;;
  remove)        shift; cmd_remove "$@" ;;
  preset)        shift; cmd_preset "$@" ;;
  export)        cmd_export ;;
  import)        shift; cmd_import "$@" ;;
  *)
    echo "KorrinOS Keyboard Shortcuts Manager"
    echo "Usage: korrinos-shortcuts.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init              Initialize shortcuts config"
    echo "  list              List all shortcuts"
    echo "  set <key> <action>  Set a shortcut"
    echo "  remove <key>      Remove a shortcut"
    echo "  preset <name>     Load preset (gnome|kde|macos)"
    echo "  export            Export shortcuts config"
    echo "  import <file>     Import shortcuts from file"
    ;;
esac

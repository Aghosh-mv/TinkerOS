#!/usr/bin/env bash
# korrinos-hotkeys.sh — Global Hotkey System (toggleable)
# Custom keybinds for anything

set -euo pipefail

HOTKEY_DIR="${HOME}/.config/korrinos/hotkeys"
HOTKEY_CONFIG="$HOTKEY_DIR/config.json"
mkdir -p "$HOTKEY_DIR"

init_hotkeys() {
  if [ ! -f "$HOTKEY_CONFIG" ]; then
    cat > "$HOTKEY_CONFIG" << 'DEFAULTS'
{
  "enabled": false,
  "bindings": {
    "Super+1": "firefox",
    "Super+2": "kitty || xterm",
    "Super+3": "nautilus || thunar",
    "Super+Space": "korrinos-quick-launcher",
    "Super+L": "loginctl lock-session",
    "Super+Q": "loginctl kill-user $USER",
    "Print": "korrinos-tools.sh screenshot",
    "Ctrl+Alt+T": "kitty || xterm"
  }
}
DEFAULTS
    echo "Hotkey config initialized"
  fi
}

# Apply hotkeys using sxhkd or xbindkeys
apply_hotkeys() {
  local enabled
  enabled=$(python3 -c "import json; print(json.load(open('$HOTKEY_CONFIG'))['enabled'])" 2>/dev/null || echo "false")
  [ "$enabled" = "False" ] && { echo "Hotkeys disabled"; return 0; }
  
  if command -v sxhkd &>/dev/null; then
    # Generate sxhkdrc
    local rc="$HOME/.config/sxhkd/sxhkdrc"
    mkdir -p "$(dirname "$rc")"
    
    python3 -c "
import json
with open('$HOTKEY_CONFIG') as f: c = json.load(f)
lines = ['# KorrinOS Hotkeys']
for key, cmd in c.get('bindings', {}).items():
    lines.append(f'{key}')
    lines.append(f'\t{cmd}')
    lines.append('')
print('\n'.join(lines))
" > "$rc"
    
    # Restart sxhkd
    pkill sxhkd 2>/dev/null; sleep 0.5
    sxhkd &>/dev/null &
    echo "Hotkeys applied via sxhkd"
  elif command -v xbindkeys &>/dev/null; then
    # Generate xbindkeys config
    local rc="$HOME/.xbindkeysrc"
    python3 -c "
import json
with open('$HOTKEY_CONFIG') as f: c = json.load(f)
lines = ['# KorrinOS Hotkeys']
for key, cmd in c.get('bindings', {}).items():
    lines.append(f'\"{cmd}\"')
    lines.append(f'  {key}')
    lines.append('')
print('\n'.join(lines))
" > "$rc"
    pkill xbindkeys 2>/dev/null; sleep 0.5
    xbindkeys &>/dev/null &
    echo "Hotkeys applied via xbindkeys"
  else
    echo "Install sxhkd or xbindkeys for hotkey support"
  fi
}

# Add a binding
add_binding() {
  local key="$1" cmd="$2"
  python3 -c "
import json
with open('$HOTKEY_CONFIG') as f: c = json.load(f)
c['bindings']['$key'] = '$cmd'
with open('$HOTKEY_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print(f'Bound: $key  $cmd')
"
}

# Remove a binding
remove_binding() {
  local key="$1"
  python3 -c "
import json
with open('$HOTKEY_CONFIG') as f: c = json.load(f)
if '$key' in c['bindings']:
    del c['bindings']['$key']
    with open('$HOTKEY_CONFIG', 'w') as f: json.dump(c, f, indent=2)
    print(f'Removed: $key')
else:
    print('Not found: $key')
"
}

# Toggle on/off
toggle() {
  python3 -c "
import json
with open('$HOTKEY_CONFIG') as f: c = json.load(f)
c['enabled'] = not c.get('enabled', False)
with open('$HOTKEY_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print(f'Hotkeys: {\"ON\" if c[\"enabled\"] else \"OFF\"}')
"
}

# List bindings
list_bindings() {
  python3 -c "
import json
with open('$HOTKEY_CONFIG') as f: c = json.load(f)
print(f'Enabled: {c.get(\"enabled\", False)}')
print()
for key, cmd in c.get('bindings', {}).items():
    print(f'  {key:20s}  {cmd}')
"
}

case "${1:-help}" in
  init)     init_hotkeys ;;
  apply)    apply_hotkeys ;;
  add)      shift; add_binding "$@" ;;
  remove)   shift; remove_binding "$@" ;;
  toggle)   toggle ;;
  list)     list_bindings ;;
  *)
    echo "KorrinOS Global Hotkeys"
    echo "Usage: korrinos-hotkeys.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init                Initialize config"
    echo "  apply               Apply hotkeys"
    echo "  add <key> <cmd>     Add a binding"
    echo "  remove <key>        Remove a binding"
    echo "  toggle              Toggle on/off"
    echo "  list                List all bindings"
    ;;
esac

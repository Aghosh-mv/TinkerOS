#!/bin/bash
# TinkerOS Modes — top-level territory coordinator / keybind matrix
# Binds the world-switching matrix and launches each world's default action.
#
#   Space+Shift+1  OR  Ctrl+Arrow-Left   -> HACK mode
#   Space+Shift+2  OR  Ctrl+Arrow-Up     -> NORMAL (secure daily driver)
#   Space+Shift+3  OR  Ctrl+Arrow-Right  -> GAME mode
#   Space+Shift+Escape                    -> panic wipe (see panic-wipe.sh)
#
# Also prints the containment matrix and current world.

set -euo pipefail
TERR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$TERR/lib/common.sh"

engine() { "$TERR/world-engine.sh" "$@"; }

# map 1/2/3 (or left/center/right) -> world, matching the visual metaphor
world_of() {
  case "$1" in
    1|left)   echo HACK ;;
    2|center) echo NORMAL ;;
    3|right)  echo GAME ;;
    *) echo "" ;;
  esac
}

# launch the default action for a world
launch_world() {
  local world="$1"
  engine enter "$world"
  case "$world" in
    HACK)   "$TERR/hack/hack-mode.sh" enter ;;
    GAME)   "$TERR/game/game-mode.sh" enter ;;
    NORMAL) "$TERR/secure/secure-mode.sh" enter ;;
  esac
}

key() {  # Space+Shift+N factor: key 1|2|3
  local w; w="$(world_of "${1:-}")"
  [ -n "$w" ] || { echo "mode: expected 1(hack)/2(normal)/3(game)"; return 1; }
  echo ">>> Switching to $w world"
  launch_world "$w"
}

# SxHKD/xbindkeys call pattern sample:
#   modes.sh key 1   (Space+Shift+1 = hack/left)
#   modes.sh key 2   (Space+Shift+2 = normal/center)
#   modes.sh key 3   (Space+Shift+3 = game/right)
#   modes.sh ctrl-left | ctrl-up | ctrl-right   (same mapping)

ctrl() {  # ctrl-left | ctrl-up | ctrl-right
  case "$1" in
    left)  key 1 ;;
    up)    key 2 ;;
    right) key 3 ;;
    *) echo "ctrl: left|up|right"; return 1 ;;
  esac
}

matrix() {
  echo "TinkerOS mode containment matrix:"
  engine matrix
  echo ""
  echo "World definitions:"
  printf '  HACK   = max work PROTECTING the hacker AND HELPING them hack more\n'
  printf '           (offensive + defensive, both maximized)\n'
  printf '  NORMAL = the MOST PROTECTED world: can still FIND/hack the user,\n'
  printf '           but CANNOT be hacked (bulletproof defense)\n'
  printf '  GAME   = the MAXIMUM-optimized world (best gaming performance)\n'
  echo ""
  echo "Keybind map:"
  printf '  Space+Shift+1 / Ctrl+Arrow-Left  -> HACK      (left)\n'
  printf '  Space+Shift+2 / Ctrl+Arrow-Up    -> NORMAL/secure (center)\n'
  printf '  Space+Shift+3 / Ctrl+Arrow-Right -> GAME      (right)\n'
  printf '  Space+Shift+Escape              -> panic wipe\n'
}

emit_keybinds() {  # generate an sxhkd config snippet
  echo "--- add to ~/.config/sxhkd/sxhkdrc ---"
  cat <<EOF
super + shift + 1
    ${0##*/} key 1
super + shift + 2
    ${0##*/} key 2
super + shift + 3
    ${0##*/} key 3
super + shift + Escape
    ${TERR}/hack/panic-wipe.sh trigger full
control + Left
    ${0##*/} ctrl left
control + Right
    ${0##*/} ctrl right
control + Up
    ${0##*/} ctrl up
EOF
}

case "${1:-}" in
  key|mode) shift; key "$@" ;;
  ctrl|arrow) shift; ctrl "$@" ;;
  matrix|map) matrix ;;
  keybinds|bind) emit_keybinds ;;
  current) engine current ;;
  *) echo "TinkerOS Modes
Usage: ${0##*/} <key 1|2|3|ctrl left|up|right|matrix|keybinds|current>
World switch matrix for HACK / NORMAL(secure) / GAME terrains." ;;
esac

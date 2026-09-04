#!/bin/bash
# TinkerOS World Engine
# Manages fully-isolated mode "worlds": NORMAL, HACK, GAME.
# Each world is a separate, scoped environment with its own apps config,
# PATH, per-world state, and no cross-contamination of apps or traces.
#
# World model (visual metaphor):
#   LEFT  = HACK   (Space+Shift+1,  Ctrl+Arrow-Left)
#   CENTER= NORMAL (Space+Shift+2,  Ctrl+Arrow-Up)
#   RIGHT = GAME   (Space+Shift+3,  Ctrl+Arrow-Right)
#
# Each world has:
#   - os/territories/<world>/apps/   (mode-scoped app definitions)
#   - os/territories/<world>/state/  (per-world runtime state)
#   - a dedicated PATH + env profile shell file
#   - installed-app registry (apps only exist in the world you install)
#
# Safety note: modes are scoped user-space environments, not a MAC/type
# enforcement layer. Real isolation for hostile payloads still requires a
# VM/container; see /proc/tinker docs.

set -euo pipefail

TERR_ROOT="${TINKER_TERR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
WORLDS_DIR="$TERR_ROOT"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tinker/worlds"
CURRENT="$STATE_DIR/current-world"
HISTORY="$STATE_DIR/world-history.log"

WORLD_CODES=(NORMAL HACK GAME)
WORLD_KEYBINDS=("Space+Shift+2" "Space+Shift+1" "Space+Shift+3")

# return keybind index for a world code
keybind_idx() {
  local w="$1" i
  for i in "${!WORLD_CODES[@]}"; do
    [ "${WORLD_CODES[$i]}" = "$w" ] && echo "$i" && return 0
  done
  echo 0
}

# ---- world registry ---------------------------------------------------------
world_dirs() {  # returns the three world directory names
  for w in "${WORLD_CODES[@]}"; do
    printf '%s\n' "$(printf '%s' "$w" | tr '[:upper:]' '[:lower:]')"
  done
}

world_config_dir() { echo "$WORLDS_DIR/$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; }
world_apps_dir()    { echo "$(world_config_dir "$1")/apps"; }
world_state_dir()   { echo "$STATE_DIR/$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; }
world_profile()     { echo "$(world_config_dir "$1")/profile.sh"; }

# ---- world management --------------------------------------------------------
ensure_world_dirs() {
  local w
  for w in "${WORLD_CODES[@]}"; do
    mkdir -p "$(world_apps_dir "$w")" "$(world_state_dir "$w")"
    if [ ! -f "$(world_profile "$w")" ]; then
      gen_profile "$w"
    fi
  done
}

gen_profile() {
  local w="$1"; local lw; lw="$(printf '%s' "$w" | tr '[:upper:]' '[:lower:]')"
  cat > "$(world_profile "$w")" <<EOF
# $w world profile — sourced when entering this world
export TINKER_WORLD=$w
export TINKER_WORLD_DIR=$(world_config_dir "$w")
export TINKER_WORLD_APPS=$(world_apps_dir "$w")
export TINKER_WORLD_STATE=$(world_state_dir "$w")
export PATH="$TERR_ROOT/$lw/apps/bin:\$PATH"
export PS1="[Tinker:$w] \w \\\$ "
EOF
}

current_world() {
  [ -f "$CURRENT" ] && cat "$CURRENT" || echo NORMAL
}

set_world() {
  local target="$1"; local lw
  lw="$(printf '%s' "$target" | tr '[:upper:]' '[:lower:]')"
  case "$target" in
    NORMAL|HACK|GAME) : ;;
    *) echo "Unknown world: $target (NORMAL|HACK|GAME)"; return 1 ;;
  esac
  local prev; prev="$(current_world)"
  if [ "$prev" = "$target" ]; then
    echo "Already in $target world."
    return 0
  fi
  # record departure telemetry into world history
  echo "$(date -Iseconds) | $prev -> $target" >> "$HISTORY"
  printf '%s' "$target" > "$CURRENT"
  echo "Switched: $prev -> $target"
  echo "  Hint: apps are mode-scoped; install per-world."
  return 0
}

# ---- mode-scoped app ownership -----------------------------------------------
# An app definition lives only inside the world where it was installed.
install_app() {  # install_app <world> <app-name> <binary-or-cmd>
  local w="$1" app="$2" bin="$3"; local ad
  ad="$(world_apps_dir "$w")"
  mkdir -p "$ad/bin" "$ad/registry"
  [ -z "$bin" ] && { echo "Missing command for $app"; return 1; }
  printf '%s\n' "$bin" > "$ad/$app.cmd"
  ln -sfn "$bin" "$ad/bin/$app" 2>/dev/null || cp "$bin" "$ad/bin/$app"
  printf '%s\n' "$(date -Iseconds) $(whoami)" > "$ad/registry/$app"
  echo "Installed '$app' into $w world."
}

list_apps() {  # list_apps [world]
  local w="${1:-$(current_world)}"; local ad; ad="$(world_apps_dir "$w")"
  echo "Apps available in $w world:"
  ls -1 "$ad" 2>/dev/null | grep -vE '^(bin|registry)$' || echo "  (none installed)"
}

contains_app() {  # contains_app <world> <app>
  [ -f "$(world_apps_dir "$1")/$2.cmd" ]
}

# World-specific gate: an app is only runnable inside its home world.
run_world_app() {
  local app="$1"; local w; w="$(current_world)"
  if [ -f "$(world_apps_dir "$w")/$app.cmd" ]; then
    export TINKER_WORLD="$w"
    # shellcheck disable=SC2046
    $(cat "$(world_apps_dir "$w")/$app.cmd")
  else
    echo "App '$app' is not present in the $w world."
    echo "It may exist in another world. Switch there or install it here."
    return 1
  fi
}

# ---- keystroke resolution ----------------------------------------------------
# Space+Shift+1 => HACK (left), 2 => NORMAL (center), 3 => GAME (right)
bind_to_world() {
  case "${1:-}" in
    1|"left")     echo HACK   ;;
    2|"center")   echo NORMAL ;;
    3|"right")    echo GAME   ;;
    *) echo ""; return 1 ;;
  esac
}

# entry point for keyboard binding wrapper (sxhkd/xbindkeys call with a digit)
keyboard_switch() {
  local world; world="$(bind_to_world "${1:-}")"
  [ -n "$world" ] && set_world "$world" || echo "Usage: keyboard_switch <1|2|3>"
}

# ---- introspection -----------------------------------------------------------
debug_matrix() {
  echo "World containment matrix:"
  local w idx
  for w in "${WORLD_CODES[@]}"; do
    idx="$(keybind_idx "$w")"
    printf '  %-6s (bind %s): ' "$w" "${WORLD_KEYBINDS[$idx]}"
    list_apps "$w" | tail -n +2 | tr '\n' ' '; echo ""
  done
}

show_state() {
  echo "Current world: $(current_world)"
  echo "World dirs:"
  for w in "${WORLD_CODES[@]}"; do
    printf '  %-6s apps=%s\n' "$w" "$(world_apps_dir "$w")"
  done
  echo "Switch history (tail):"; tail -5 "$HISTORY" 2>/dev/null || echo "  (none)"
}

case "${1:-}" in
  enter|switch) shift; set_world "${1:-$(current_world)}" ;;
  cur|current)  current_world ;;
  ls|apps) shift; list_apps "${1:-}" ;;
  add|install) shift; install_app "$@" ;;
  run) shift; run_world_app "$@" ;;
  kb|key) shift; keyboard_switch "${1:-}" ;;
  matrix|show) debug_matrix ;;
  state|info) show_state ;;
  *) echo "TinkerOS World Engine
Usage: ${0##*/} <command> [args]
  enter|switch <NORMAL|HACK|GAME>   switch worlds
  cur|current                        show current world
  ls|apps [world]                    list mode-scoped apps
  add|install <world> <app> <cmd>    add an app to a specific world
  run <app>                          run an app (world-gated)
  kb|key <1|2|3>                     Space+Shift keybind (1=hack,2=normal,3=game)
  matrix|show                        show containment matrix
  state|info                         show world state/history" ;;
esac

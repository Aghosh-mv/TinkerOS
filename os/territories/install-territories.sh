#!/bin/bash
# TinkerOS Territories installer — promotes all 45 territory scripts (18 hack
# + 13 game + 14 secure + the world engine layer) from repo files into REAL,
# launchable code on your live Linux system, as user-level commands with a
# single `tinker-world` launcher. Fully reversible (uninstall).
#
#   install   : link all 45 + engine into ~/.local/bin as `tinker-world <cmd>`
#   uninstall : remove the links (repo stays untouched)
#   status    : show what's live

set -euo pipefail
TERR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/territories"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"

ALL="$(find "$TERR" -maxdepth 2 -name '*.sh' -type f | sort)"

install_all() {
  echo "Promoting all 45 territory scripts to real, launchable code..."
  local n=0 cmd
  for f in $ALL; do
    cmd="tinker-$(basename "$f" .sh)"
    cmd="${cmd#tinker-world-engine}"   # engine keeps its name
    ln -sf "$f" "$BIN/$cmd"
    n=$((n+1))
  done
  echo "  linked $n commands into $BIN (prefix 'tinker-')"
  echo ""
  echo "Real-code entry points (launchable now):"
  echo "  tinker-modes       world-switch matrix (keybinds + definitions)"
  echo "  tinker-world-engine enter HACK|GAME|NORMAL"
  echo "  tinker-hack-mode enter | tinker-game-mode enter | tinker-secure-mode enter"
  echo ""
  echo "Example:  tinker-modes matrix"
}

uninstall_all() {
  echo "Removing territory command links (repo untouched)..."
  local cmd
  for f in $ALL; do
    cmd="tinker-$(basename "$f" .sh)"
    rm -f "$BIN/$cmd"
  done
  echo "  removed links. Re-run install to bring them back."
}

status() {
  echo "Live territory commands in $BIN:"
  ls -1 "$BIN"/tinker-* 2>/dev/null | sed 's#.*/##' | xargs -n1 | wc -l | xargs printf '  %s linked\n'
}

case "${1:-}" in
  install|on|add) install_all ;;
  uninstall|off|remove) uninstall_all ;;
  status) status ;;
  *) echo "TinkerOS Territories installer
Usage: ${0##*/} <install|uninstall|status>
Promotes all 45 territory scripts to real, launchable user commands." ;;
esac

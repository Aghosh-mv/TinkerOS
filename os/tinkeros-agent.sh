#!/bin/bash
# TinkerOS Agentic AI launcher — the preinstalled assistant.
# Press Ctrl+Alt+Gr (right Alt) anywhere in the OS to pop up opencode as a
# tiny agentic-AI sir/terminal. Preinstalled by default (ships in the OS).
#
#   pop    : open a small gnome-terminal running opencode in TinkerOS tree
#   tomboot: append a Ctrl+Alt+Gr keybind to the default shell/profile so it
#            works in the OS (GNOME-style; requires gsettings/gnome-terminal)
#   uninstall: remove the keybind

set -euo pipefail
OC="${OPencode:-$HOME/.opencode/bin/opencode}"
[ -x "$OC" ] || { echo "opencode binary not found at $OC"; exit 1; }

WORK_TREE="${TINKEROS_TREE:-$HOME/linux-kernel}"
[ -d "$WORK_TREE" ] || WORK_TREE="$HOME"

pop() {
  echo "Opening TinkerOS Agentic AI (opencode)..."
  # tiny window: ~90 cols x 26 rows, single pane, black bg for sir-like focus
  gnome-terminal --title "TinkerOS Agent" --geometry 100x28 \
    -- bash -c "cd '$WORK_TREE'; '$OC'" 2>/dev/null \
    || xterm -title "TinkerOS Agent" -geometry 100x28 -e bash -c "cd '$WORK_TREE'; exec '$OC'" 2>/dev/null \
    || { echo "no terminal found"; exit 1; }
}

# Wire Ctrl+Alt+Gr to the launcher. Method: a shell custom keybinding in
# gnome-terminal 0-9 (AltGr isn't a first-class GNOME mod but we bind the
# action to a key; fallback uses xbindkeys/sxhkd if present).
install_bind() {
  local SELF; SELF="$(readlink -f "$0")"
  echo "Installing Ctrl+Alt+Gr -> TinkerOS Agent..."
  # xbindkeys/sxhkd approach (most reliable for right-alt):
  if command -v xbindkeys >/dev/null 2>&1; then
    mkdir -p "$HOME/.config"
    cat >> "$HOME/.xbindkeysrc" <<EOF
# TinkerOS Agent : Ctrl+AltGr
"$SELF pop"
  Control+Mod1+Alt_R
EOF
    pkill -HUP xbindkeys 2>/dev/null || true
    echo "  bound via xbindkeys (Control+Mod1+Alt_R)."
  elif command -v sxhkd >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/sxhkd"
    cat >> "$HOME/.config/sxhkd/sxhkdrc" <<EOF
control + alt + ISO_Level3_Shift
    $SELF pop
EOF
    echo "  bound via sxhkd (control + alt + ISO_Level3_Shift)."
  else
    echo "  no xbindkeys/sxhkd; using GNOME custom shortcuts (gsettings)..."
    if command -v gsettings >/dev/null 2>&1 && gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings >/dev/null 2>&1; then
      # append a GNOME custom keybinding, AltGr = Control+Alt+ISO_Level3_Shift
      local now; now="$(date +%s)"
      gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/tinkeros-agent/']" 2>/dev/null || true
      gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/tinkeros-agent/ name "TinkerOS Agent" 2>/dev/null || true
      gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/tinkeros-agent/ command "$SELF pop" 2>/dev/null || true
      gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/tinkeros-agent/ binding "<Control><Alt>ISO_Level3_Shift" 2>/dev/null || true
      echo "  bound via GNOME custom shortcut (<Control><Alt>ISO_Level3_Shift)."
    else
      echo "  no binding backend available; install xbindkeys/sxhkd, or run:"
      echo "    $SELF pop"
    fi
  fi
  echo "Done. Press Ctrl+Alt+Gr to pop the agent."
}

uninstall_bind() {
  echo "Removing Ctrl+Alt+Gr agent binding..."
  sed -i '/# TinkerOS Agent : Ctrl+AltGr/,+1d' "$HOME/.xbindkeysrc" 2>/dev/null || true
  sed -i '/control + alt + ISO_Level3_Shift/,+1d' "$HOME/.config/sxhkd/sxhkdrc" 2>/dev/null || true
  echo "Done."
}

case "${1:-}" in
  pop|open|run) pop ;;
  install|bind|setup) install_bind ;;
  uninstall|remove) uninstall_bind ;;
  *) echo "TinkerOS Agentic AI
Usage: ${0##*/} <pop|install|uninstall>
Preinstalled agentic AI. Press Ctrl+Alt+Gr to pop opencode as a tiny sir." ;;
esac

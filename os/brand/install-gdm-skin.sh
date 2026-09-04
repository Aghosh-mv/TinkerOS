#!/bin/bash
# TinkerOS GDM login skin — themes the REAL GDM3 greeter with TinkerOS
# branding (dark background, teal logo/accent). Builds on Linux's native
# GDM; we only add a background + greeter CSS so the login page looks like
# TinkerOS while remaining the real GDM login.
#
#   install   : set branded background + greeter CSS   (needs root)
#   uninstall : restore the OS's original GDM background/CSS
#   status    : show current GDM background

set -euo pipefail
THEME_NAME=tinkeros-gdm
CSS_DIR=/usr/share/gnome-shell/theme
CSS_SAVE="$CSS_DIR/gnome-shell-tinkeros.css"
BG_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gdm-tinkeros/tinkeros_login.png"

need_root() { [ "$(id -u)" -eq 0 ]; }

install_theme() {
    echo "Installing TinkerOS GDM login skin..."
    mkdir -p "$CSS_DIR"
    cp "$BG_SRC" "$CSS_DIR/tinkeros_login.png"

    # appends a branded override block to the greeter CSS. We save the
    # original tail so we can remove ours on uninstall.
    cat >> "$CSS_DIR/gnome-shell.css" <<'EOF'
/* === TinkerOS login skin (appended) === */
#lockDialogGroup {
  background: #0D0D12 url("file:///usr/share/gnome-shell/theme/tinkeros_login.png") no-repeat center;
  background-size: cover;
}
.login-dialog-title {
  color: #00D4AA;
}
.login-dialog .button, .login-dialog button {
  background-color: #00D4AA;
  color: #000000;
  border-radius: 8px;
}
EOF

    echo "Applying via gsettings (user-session fallback)..."
    # Some GDM versions read the background from the greeter user; this is
    # best-effort. The css block above is the authoritative skin.
    gsettings set org.gnome.desktop.background picture-uri "file://$CSS_DIR/tinkeros_login.png" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$CSS_DIR/tinkeros_login.png" 2>/dev/null || true
    gsettings set org.gnome.desktop.background primary-color "#0D0D12" 2>/dev/null || true

    echo "TinkerOS GDM login skin installed. (Restart gdm3 to apply: sudo systemctl restart gdm3)"
}

uninstall_theme() {
    echo "Removing TinkerOS GDM login skin..."
    # strip the appended block from gnome-shell.css
    python3 - <<'PY' "$CSS_DIR/gnome-shell.css"
import sys
pth=sys.argv[1]
marker="/* === TinkerOS login skin (appended) === */"
try:
    with open(pth) as f: txt=f.read()
except FileNotFoundError:
    sys.exit(0)
if marker in txt:
    txt=txt.split(marker)[0]
    with open(pth,"w") as f: f.write(txt)
PY
    rm -f "$CSS_DIR/tinkeros_login.png"
    echo "Reverted GDM to original."
}

status() {
    echo "GDM login skin:"
    grep -c 'TinkerOS login skin' "$CSS_DIR/gnome-shell.css" 2>/dev/null | xargs -I{} echo "  branded css blocks: {}"
    [ -f "$CSS_DIR/tinkeros_login.png" ] && echo "  background: tinkeros (installed)" || echo "  background: OS default"
}

case "${1:-}" in
    install|apply|on) need_root && install_theme || echo "Re-run with sudo." ;;
    uninstall|remove|off) need_root && uninstall_theme || echo "Re-run with sudo." ;;
    status) status ;;
    *) echo "TinkerOS GDM Login Skin
Usage: ${0##*/} <install|uninstall|status>
Themes the real GDM3 login with TinkerOS branding." ;;
esac

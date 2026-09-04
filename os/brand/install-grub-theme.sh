#!/bin/bash
# TinkerOS GRUB theme installer — wires the branded boot menu into real Linux
# GRUB as the default. Builds on the existing GRUB bootloader (we only add
# our theme dir + enable it in /etc/default/grub), then regenerate grub.cfg.
#
#   install   : copy theme to /boot/grub/themes/tinkeros + enable
#   uninstall : revert to default GRUB
#   status    : show current GRUB theme

set -euo pipefail
THEME_NAME=tinkeros
THEME_DST=/boot/grub/themes/tinkeros
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/grub-tinkeros"
[ -d "$SRC" ] || SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need_root() { [ "$(id -u)" -eq 0 ]; }

install_theme() {
    echo "Installing TinkerOS GRUB theme..."
    mkdir -p "$THEME_DST"
    cp "$SRC/theme.txt" "$SRC/tinkeros_boot.png" "$SRC/select_hi.png" "$SRC/select_s.png" "$THEME_DST/"

    if command -v update-grub >/dev/null 2>&1 || [ -f /etc/default/grub ]; then
        # enable theme + keep splash in /etc/default/grub
        sed -i "s#^GRUB_THEME=.*#GRUB_THEME=\"$THEME_DST/theme.txt\"#" /etc/default/grub 2>/dev/null || true
        grep -q '^GRUB_THEME=' /etc/default/grub 2>/dev/null || \
            echo "GRUB_THEME=\"$THEME_DST/theme.txt\"" >> /etc/default/grub
        echo "Regenerating GRUB config..."
        if command -v update-grub >/dev/null 2>&1; then
            update-grub || true
        elif [ -x /usr/sbin/grub-mkconfig ]; then
            /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg || true
        fi
    fi
    echo "TinkerOS GRUB theme installed and set as default."
}

uninstall_theme() {
    echo "Removing TinkerOS GRUB theme..."
    rm -rf "$THEME_DST"
    sed -i '/^GRUB_THEME=/d' /etc/default/grub 2>/dev/null || true
    echo "Reverted to default GRUB menu."
}

status() {
    echo "Current GRUB theme:"
    grep -r '^GRUB_THEME=' /etc/default/grub 2>/dev/null || echo " (none set -> GRUB default)"
}

case "${1:-}" in
    install|apply|on) need_root && install_theme || echo "Re-run with sudo." ;;
    uninstall|remove|off) need_root && uninstall_theme || echo "Re-run with sudo." ;;
    status) status ;;
    *) echo "TinkerOS GRUB Theme
Usage: ${0##*/} <install|uninstall|status>
Wires the branded GRUB boot menu into real Linux as the default." ;;
esac

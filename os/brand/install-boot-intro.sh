#!/bin/bash
# KorrinOS Boot Intro installer — wires the branded plymouth intro into real
# Linux as the DEFAULT boot/reboot/restart/shutdown splash. Builds on what
# Linux already provides (plymouth + initramfs); we only add our theme.
#
#   install   : copy theme to /usr/share/plymouth/themes/korrinos, set default
#   uninstall : revert to the OS's default plymouth theme
#   status    : show current plymouth theme

set -euo pipefail
THEME_DIR=/usr/share/plymouth/themes/korrinos
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plymouth-korrinos"
[ -d "$SRC" ] || SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need_root() { [ "$(id -u)" -eq 0 ]; }

install_theme() {
    echo "Installing KorrinOS plymouth theme..."
    mkdir -p "$THEME_DIR"
    cp "$SRC/korrinos.plymouth" "$SRC/korrinos.script" "$SRC/korrinos_logo.png" "$THEME_DIR/"

    # register theme with plymouth
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        cp "$THEME_DIR/korrinos.plymouth" /usr/share/plymouth/themes/
        plymouth-set-default-theme korrinos -R
    fi

    # ensure plymouth boot splash is enabled in the bootloader config
    echo "Updating GRUB for splash (quiet splash)..."
    if [ -r /etc/default/grub ]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub 2>/dev/null || true
    fi

    # rebuild initramfs so the theme ships into every boot
    if command -v update-initramfs >/dev/null 2>&1; then
        echo "Rebuilding initramfs (may take a moment)..."
        update-initramfs -u || true
    elif command -v dracut >/dev/null 2>&1; then
        dracut --force || true
    fi

    echo "KorrinOS boot intro installed and set as default."
}

uninstall_theme() {
    echo "Removing KorrinOS plymouth theme..."
    rm -rf "$THEME_DIR"
    rm -f /usr/share/plymouth/themes/korrinos.plymouth
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        plymouth-set-default-theme --reset || plymouth-set-default-theme default || true
    fi
    echo "Reverted to OS default boot splash."
}

status() {
    echo "Current plymouth theme:"
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        plymouth-set-default-theme --list 2>/dev/null || true
        echo "default: $(readlink /usr/lib/plymouth/default.plymouth 2>/dev/null || cat /etc/alternatives/default.plymouth 2>/dev/null || echo unknown)"
    fi
}

case "${1:-}" in
    install|apply|on) need_root && install_theme || echo "Re-run with sudo." ;;
    uninstall|remove|off) need_root && uninstall_theme || echo "Re-run with sudo." ;;
    status) status ;;
    *) echo "KorrinOS Boot Intro
Usage: ${0##*/} <install|uninstall|status>
Wires the branded plymouth intro into real Linux as the default boot/shutdown splash." ;;
esac

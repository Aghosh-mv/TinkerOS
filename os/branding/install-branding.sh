#!/bin/bash
# KorrinOS boot branding installer — installs the Plymouth splash + GRUB2 theme
# into a KorrinOS rootfs (used at build time via chroot, or post-boot).
#
# Usage:
#   install-branding.sh [ROOTFS]      # ROOTFS base path (default: current /)
#
# Requires plymouth + plymouth-themes inside the target (add them to
# stage2's apt list when baking for a full branding build), plus a GRUB2
# bootloader on the installed system.

set -euo pipefail

ROOTFS="${1:-/}"
SRC="$(cd "$(dirname "$0")" && pwd)"
S=sudo

echo "KorrinOS branding -> $ROOTFS"

echo "[1/3] Plymouth theme"
$S mkdir -p "$ROOTFS/usr/share/plymouth/themes/korrinosplymouth"
$S cp "$SRC/plymouth/"* "$ROOTFS/usr/share/plymouth/themes/korrinosplymouth/"
if [ -x "$ROOTFS/usr/sbin/plymouth-set-default-theme" ] || command -v plymouth-set-default-theme >/dev/null 2>&1; then
  if [ "$ROOTFS" = "/" ]; then
    sudo plymouth-set-default-theme korrinosplymouth && echo "  default splash: korrinosplymouth"
  else
    sudo chroot "$ROOTFS" plymouth-set-default-theme korrinosplymouth && echo "  default splash: korrinosplymouth"
  fi
else
  echo "  WARN: plymouth not installed in target — install 'plymouth plymouth-themes'"
fi

echo "[2/3] GRUB theme"
$S mkdir -p "$ROOTFS/boot/grub/themes/korrinos"
$S cp "$SRC/grub/"* "$ROOTFS/boot/grub/themes/korrinos/"
if [ "$ROOTFS" = "/" ]; then
  sudo sed -i 's|^#*GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/korrinos/theme.txt"|' /etc/default/grub 2>/dev/null || true
  sudo update-grub 2>/dev/null | tail -1 || true
else
  sudo sed -i 's|^#*GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/korrinos/theme.txt"|' "$ROOTFS/etc/default/grub" 2>/dev/null || true
fi

echo "[3/3] done. Reboot to see the KorrinOS splash + menu."
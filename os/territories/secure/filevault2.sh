#!/bin/bash
# TinkerOS FileVault2 — full-disk / file encryption engine (SECURE territory)
# Wraps LUKS + LVM full-disk encryption setup and per-file gpg encryption.
# PRE-BOOT: lock the boot key (TPM/LUKS passphrase) with a duress-capable
# setup (see split-personality) so the disk is unreadable without the key.
#
# This tool provides the scaffolding + verification for LUKS-based FDE and
# gpg file encryption. Requires root + cryptsetup.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
need_root

encrypt_file() {  # encrypt_file <path>
  local f="$1"; test -f "$f" || { echo "no file: $f"; return 1; }
  if has gpg; then
    gpg -c --cipher-algo AES256 -o "$f.gpg" "$f" 2>&1 | tail -2
    echo "Encrypted -> $f.gpg (AES256). Delete original only after verifying."
  else
    echo "gpg not installed."
  fi
}

decrypt_file() {  # decrypt_file <file.gpg>
  local f="$1"; test -f "$f" || { echo "no file: $f"; return 1; }
  has gpg && gpg -d "$f" 2>/dev/null || echo "gpg needed"
}

encrypt_dir() {  # encrypt_dir <dir> -> tar | gpg
  local d="$1"; test -d "$d" || { echo "no dir: $d"; return 1; }
  has gpg || { echo "gpg needed"; return 1; }
  tar -czf - -C "$d" . | gpg -c --cipher-algo AES256 -o "$d.tar.gz.gpg"
  echo "Encrypted dir -> $d.tar.gz.gpg"
}

fde_check() {  # check FDE readiness / current encryption state
  echo "FDE readiness:"
  lsblk -o NAME,SIZE,TYPE,FSTYPE 2>/dev/null | grep -iE "crypt|lvm|NAME" | head
  echo "  A fully encrypted root needs a LUKS/LVM volume (see your distro installer)."
}

luks_add_detached() {  # store a detached LUKS header backup
  local device="${1:-}" keystore="${2:-${TINKER_STATE}/lvm-backup}"
  [ -b "$device" ] || { echo "usage: luks-add <block-device>"; return 1; }
  mkdir -p "$keystore"
  sudo cryptsetup luksHeaderBackup "$device" --header-backup-file "$keystore/$(basename "$device").hdr"
  echo "Detached header backup saved to $keystore"
}

usage() { echo "TinkerOS FileVault2
Usage: ${0##*/} <encrypt <file>|decrypt <file.gpg>|dir <dir>|fde-check|luks-add <device>>"; }

case "${1:-}" in
  encrypt|enc) shift; encrypt_file "$@" ;;
  decrypt|dec) shift; decrypt_file "$@" ;;
  dir|folder) shift; encrypt_dir "$@" ;;
  fde-check|check) fde_check ;;
  luks-add|luks) shift; luks_add_detached "$@" ;;
  *) usage ;;
esac

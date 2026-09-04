#!/bin/bash
# TinkerOS Vault Engine — encrypted container manager (SECURE territory)
# Manages encrypted vaults (LUKS/cryptsetup or gocryptfs) for sensitive
# files. Each world can have its own vault so nothing bleeds between
# normalize/hack/game. Storage-scoped, keyed by user passphrase.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

VAULTS="${TINKER_CFG}/vaults"
MOUNT_BASE="${TINKER_STATE}/vault-mounts"
mkdir -p "$VAULTS" "$MOUNT_BASE"

init_vault() {  # init_vault <name> <size>
  local name="$1" size="${2:-512M}"
  need_root || return 1
  local img="$VAULTS/$name.img"
  [ -e "$img" ] && { echo "vault $name exists"; return 1; }
  echo "[vault] Creating encrypted vault '$name' ($size)..."
  truncate -s "$size" "$img"
  local loop; loop=$(sudo losetup -fP --show "$img")
  echo "  Enter a strong passphrase for $name:"; sudo cryptsetup luksFormat -q "$loop"
  echo "  Vault created ON LOOP $loop (use 'open' to mount)."
}

open() {  # open <name> [mountpoint]
  local name="$1" mp="${2:-$MOUNT_BASE/$name}"
  need_root || return 1
  local img="$VAULTS/$name.img"
  [ -e "$img" ] || { echo "no vault $name"; return 1; }
  local loop; loop=$(sudo losetup -fP --show "$img")
  sudo cryptsetup open "$loop" "tinker_$name" 2>&1
  mkdir -p "$mp"
  sudo mount "/dev/mapper/tinker_$name" "$mp"
  echo "Mounted $name at $mp. This is world-scoped; nothing else sees it."
}

close() {  # close <name>
  local name="$1"
  need_root || return 1
  sudo umount "$MOUNT_BASE/$name" 2>/dev/null || true
  sudo cryptsetup close "tinker_$name" 2>/dev/null || true
  echo "Vault $name closed."
}

list() {
  echo "Vaults:"; ls -1 "$VAULTS" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
  echo "Mounted:"; mount | grep tinker_ || echo "  (none mounted)"
}

usage() { echo "TinkerOS Vault Engine
Usage: ${0##*/} <init <name> [size]|open <name> [mp]|close <name>|list>"; }

case "${1:-}" in
  init|create) shift; init_vault "$@" ;;
  open|mount) shift; open "$@" ;;
  close|umount) shift; close "$@" ;;
  list|ls) list ;;
  *) usage ;;
esac

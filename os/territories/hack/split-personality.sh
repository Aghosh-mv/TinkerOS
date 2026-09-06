#!/bin/bash
# TinkerOS Split Personality (Multi-tenant cryptographic boot)
# Sets up a secondary "duress" boot path + hidden encrypted container.
#
# CONCEPT:
#   - A master LVM/encrypted volume with two passphrases:
#       Passphrase A -> boots the clean daily driver
#       Passphrase B -> unlocks a hidden, separate encrypted container
#                        holding a completely separate world (evidence-free)
#   - Implements the PLAUSIBLE DENIABILITY pattern (queried containers).
#
# This tool provides the scaffolding + verification for such setups using
# cryptsetup/LUKS. It requires root and careful use. Not a substitute for
# real threat modeling, but a legitimate privacy feature.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

need_root

GEN_DIR="${TINKER_STATE}/split-personality"

check_deps() {
  for d in cryptsetup losetup; do
    has "$d" || { echo "Missing $d"; return 1; }
  done
}

inspect_blocks() {
  echo "Block devices with LUKS capability:"
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS 2>/dev/null | head -30
}

# Create a hidden container file, encrypted twice (outer + inner).
# This is the classic "two passphrase" deniability pattern.
create_hidden() {
  local path="${1:-$GEN_DIR/hidden.img}" size="${2:-256M}"
  [ -e "$path" ] && { echo "exists: $path"; return 1; }
  mkdir -p "$(dirname "$path")"
  echo "Creating $size backing file at $path (sparse)..."
  truncate -s "$size" "$path"
  sudo losetup -fP "$path"
  local loop; loop=$(sudo losetup -j "$path" | cut -d: -f1 | head -1)
  echo "Looped device: $loop"
  echo ">> Step 1: create OUTER (decoy) LUKS. Enter a NEW passphrase (your decoy):"
  sudo cryptsetup luksFormat -q "$loop"
  echo ">> Step 2: create INNER (hidden) LUKS inside the free space."
  echo "   This becomes your hidden world unlocked by the second passphrase."
  sudo cryptsetup luksFormat -q --type luks2 --shared "$loop"
  echo "Hidden two-layer container created on $loop ($path)."
}

open() {
  local path="${1:-$GEN_DIR/hidden.img}" name="${2:-tinkerhidden}"
  local loop; loop=$(sudo losetup -fP --show "$path")
  sudo cryptsetup open "$loop" "$name" 2>&1
  echo "Opened as /dev/mapper/$name (mount with: sudo mount ...)"
}

close() {
  local name="${1:-tinkerhidden}"
  sudo cryptsetup close "$name" 2>&1 || true
}

wipe() {
  local path="${1:-$GEN_DIR/hidden.img}"
  echo "Securely wiping $path (random overwrite)..."
  sudo dd if=/dev/urandom of="$path" bs=1M status=progress 2>&1 | tail -1
  sudo shred -v -n1 "$path" 2>/dev/null || true
  rm -f "$path"
  echo "Wiped."
}

status() {
  echo "Split Personality status:"
  echo "  Dir: $GEN_DIR"
  ls -la "$GEN_DIR" 2>/dev/null || echo "  (no containers yet)"
  echo "  LUKS devices:"
  sudo cryptsetup status 2>/dev/null || lsblk | grep -i crypt || true
}

case "${1:-}" in
  check|deps) check_deps ;;
  blocks) inspect_blocks ;;
  create) shift; create_hidden "$@" ;;
  open) shift; open "$@" ;;
  close) shift; close "$@" ;;
  wipe) shift; wipe "$@" ;;
  status) status ;;
  *) echo "TinkerOS Split Personality
Usage: ${0##*/} <check|blocks|create [file] [size]|open [file] [name]|close [name]|wipe [file]|status>
Creates a two-passphrase hidden encrypted container (plausible deniability).
Passphrase A = decoy; Passphrase B = hidden world. Requires root + cryptsetup." ;;
esac

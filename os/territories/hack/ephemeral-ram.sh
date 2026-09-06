#!/bin/bash
# TinkerOS Ephemeral RAM Disks (HACK + SECURE territory)
# Runs a mode-world entirely in volatile RAM (tmpfs) so that all payloads,
# logs, and state vanish on mode-switch off or power loss — zero trace left
# on persistent SSD at the hardware level.
#
# HOW: create a tmpfs mount, route the world's state dir onto it, and make
# sure nothing is swapped to disk (set swap max-pressure to 0 for that world).
#
# This is a genuine privacy/forensics-resistance feature using standard
# Linux tmpfs. It only protects data that lives on the tmpfs; anything the
# user writes to /home or other persistent mounts is NOT covered.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

RAM_MNT="${TINKER_STATE}/ram-world"
SIZE="${TINKER_RAM_SIZE:-512M}"

mount_ram() {
  echo "Mounting ephemeral RAM disk ($SIZE) at $RAM_MNT..."
  mkdir -p "$RAM_MNT"
  if has sudo; then
    sudo mount -t tmpfs -o size="$SIZE",mode=0700 tmpfs "$RAM_MNT"
    echo "RAM disk mounted at $RAM_MNT. All data here is volatile."
  else
    echo "need root to mount tmpfs."
  fi
}

# Route the current world state onto the RAM disk
bind_world() {
  local world="$1"
  mkdir -p "$RAM_MNT/$world"
  sudo mount --bind "$RAM_MNT/$world" "$(world_state "$world")" 2>/dev/null || {
    # fallback: symlink
    echo "bind failed; symlinking world state instead"
    mv "$(world_state "$world")" "$RAM_MNT/$world" 2>/dev/null
    ln -sfn "$RAM_MNT/$world" "$(world_state "$world")"
  }
  echo "World '$world' state now lives in RAM (volatile)."
}

# Prevent the RAM world from ever swapping to disk
no_swap() {
  echo "Setting swap-pressure to 0 for this session (no swap-out)..."
  echo 0 | sudo tee /proc/sys/vm/swapiness >/dev/null 2>&1 || true
  sudo swapoff -a 2>/dev/null && echo "All swap disabled (RAM-world cannot spill to disk)." || true
}

# Attach a payload file into the RAM world (copies, not references)
stage_payload() {
  local src="$1"
  test -f "$src" || { echo "no file: $src"; return 1; }
  cp "$src" "$RAM_MNT/" && echo "Staged $(basename "$src") into RAM (originals on disk still persist!)."
}

wipe_ram() {
  echo "Wiping RAM disk contents before unmount..."
  find "$RAM_MNT" -type f 2>/dev/null | while read -r f; do
    dd if=/dev/urandom of="$f" bs=1M conv=notrunc 2>/dev/null || true
    rm -f "$f"
  done
  sudo umount "$RAM_MNT" 2>/dev/null || true
  echo "RAM disk unmounted — contents gone."
}

# Stealth: run a command with HOME redirected into the RAM world
run_in_ram() {
  echo "Running '$*' with HOME/state redirected to RAM ($RAM_MNT)..."
  HOME="$RAM_MNT/home" TMPDIR="$RAM_MNT/tmp" sudo -E "$@" 2>&1 | head -30
}

status() {
  echo "Ephemeral RAM disk status:"
  mount | grep "$RAM_MNT" && echo "  mounted: $RAM_MNT ($(du -sh "$RAM_MNT" 2>/dev/null | cut -f1))" || echo "  not mounted"
  cat /proc/sys/vm/swapiness 2>/dev/null | sed 's/^/  swapiness: /'
}

case "${1:-}" in
  mount|ram) mount_ram ;;
  bind) shift; bind_world "$@" ;;
  noswap|swap-off) no_swap ;;
  stage) shift; stage_payload "$@" ;;
  wipe|off) wipe_ram ;;
  run) shift; run_in_ram "$@" ;;
  status) status ;;
  *) echo "TinkerOS Ephemeral RAM Disks
Usage: ${0##*/} <mount|bind <world>|noswap|stage <file>|wipe|run <cmd>|status>
Volatile tmpfs workspace; disappears on unmount/power-loss. Not for /home data." ;;
esac

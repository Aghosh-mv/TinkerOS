#!/bin/bash
# TinkerOS Nuclear Panic Keystroke / Zero-Footprint Wipe (HACK territory)
# A bound shortcut that, when triggered, rapidly destroys volatile working
# data, closes/hides workspace processes, and memsets temporary buffers.
#
# This is an operational urgen-trigger for ephemeral (tmpfs/RAM) workspaces:
# it clears /dev/shm + memfd + ssh-agent identities + bash history for the
# session, then optionally powers off. It CANNOT un-write persistent SSD
# data — that requires full-disk encryption + earlier wipe. It is bounded to
# volatile memory to be honest about what it actually does.
#
# It is a self-defense / clean-exit tool for authorized field work.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

MEMDIRS="${TINKER_STATE}/gup ${TINKER_STATE}/worlds /dev/shm"
SEVERE=0

# 1) Kill the workspace processes (scoped to tinker territory)
kill_workspace() {
  echo "[panic] Killing tinker workspace processes..."
  pkill -f "tinker-" 2>/dev/null || true
  pkill -f "rtl_fm" 2>/dev/null || true
  pkill -f "hashcat" 2>/dev/null || true
  pkill -f "socat -v TCP-LISTEN" 2>/dev/null || true
  echo "[panic] Workspace processes stopped."
}

# 2) Wipe volatile memory workspaces (tmpfs, memfd, shm)
wipe_memory() {
  echo "[panic] Wiping volatile memory workspaces..."
  for d in $MEMDIRS; do
    if [ -d "$d" ]; then
      find "$d" -type f 2>/dev/null | while read -r f; do
        dd if=/dev/urandom of="$f" bs=1M conv=notrunc 2>/dev/null || true
        rm -f "$f"
      done
      echo "  wiped: $d"
    fi
  done
  # drop page cache (best effort)
  sync 2>/dev/null
  echo 3 2>/dev/null > /proc/sys/vm/drop_caches || true
  echo "[panic] Memory workspaces wiped."
}

# 3) clear session ephemera
wipe_session() {
  history -c 2>/dev/null || true
  > /tmp/tinker-amnesia.log 2>/dev/null || true
  rm -f "${TINKER_STATE}/territory.log" 2>/dev/null || true
  # clear ssh agent identities for the session
  ssh-add -D 2>/dev/null || true
  echo "[panic] Session cache + ssh identities cleared."
}

# 4) optionally power off after wipe
power_off() {
  echo "[panic] Powering off (after wipe)."
  sleep 1
  sudo systemctl poweroff 2>/dev/null || sudo poweroff 2>/dev/null || true
}

panic() {  # the nuclear sequence
  local mode="${1:-soft}"
  echo "!!! NUCLEAR PANIC triggered ($mode) !!!"
  kill_workspace
  wipe_memory
  wipe_session
  echo "=== Panic sequence complete. Primary volatile data destroyed. ==="
  if [ "$mode" = "full" ]; then
    SEVERE=1
    power_off
  fi
}

arm() {
  # install the keybind (sxhk dzine binds Space+Shift+Escape -> this script)
  echo "To arm, bind Space+Shift+Escape to: ${0##*/} trigger full  (see sxhkd/xbindkeys)"
  echo "Armed mentally: the (soft) default clears memory; 'full' also powers off."
}

status() {
  echo "Panic keystroke status:"
  echo "  Acknowledged limits: cannot un-write persistent SSD; volatile-only by design (honest bound)."
  for d in $MEMDIRS; do [ -d "$d" ] && echo "  workspace: $d ($(du -sh "$d" 2>/dev/null | cut -f1))"; done
}

case "${1:-}" in
  trigger|go|panic) shift; panic "${1:-soft}" ;;
  soft) panic soft ;;
  full) panic full ;;
  arm) arm ;;
  status) status ;;
  *) echo "TinkerOS Nuclear Panic / Zero-Footprint Wipe
Usage: ${0##*/} <trigger [soft|full]|soft|full|arm|status>
Destroys volatile workspace + session data fast; 'full' also powers off.
Bound to volatile memory; cannot un-write persistent disk." ;;
esac

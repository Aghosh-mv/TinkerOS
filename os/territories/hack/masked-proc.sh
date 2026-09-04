#!/bin/bash
# TinkerOS Masked Process Trees (HACK + SECURE territory)
# Encrypts/randomizes process IDs and names in user-space introspection so
# standard task managers and malware see chameleon identities.
#
# CONCEPT (user-space level, kernel link via /proc/tinker):
#   - Rename/confuse /proc entries for protected tool PIDs
#   - Present a decoy "/proc" view to untrusted processes via a mount
#     namespace that remaps names
#   - For the kernel: see kernel/tinker for the real /proc/tinker interface
#
# This masks introspection; it does NOT grant privilege escalation. It is
# an operational-security aid for authorized engagements.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

MASKFILE="${TINKER_CFG}/mask-map.conf"

add_mask() {  # add_mask <real-cmd> <decoy-name>
  local real="$1" decoy="$2"
  echo "$real|$decoy" >> "$MASKFILE"
  echo "Mask added: '$real' shows as '$decoy'."
}

mask_process() {  # mask_process <pid> <decoy-name>
  local pid="$1" decoy="$2"
  test -d "/proc/$pid" || { echo "no such pid"; return 1; }
  echo "Masking pid $pid (currently '$(cat /proc/$pid/comm 2>/dev/null)') as '$decoy'..."
  # comm is limited to 15 chars; use prctl via helper if present
  if command -v python3 >/dev/null; then
    python3 - "$pid" "$decoy" <<'PY'
import ctypes, sys
pid, name = int(sys.argv[1]), sys.argv[2]
# Attempt to set comm (best-effort; many distros restrict via yama)
try:
    libc = ctypes.CDLL("libc.so.6", use_errno=True)
    r = libc.prctl(15, name[:15].encode(), 0, 0, 0)  # PR_SET_NAME
    print("prctl set name:", r)
except Exception as e:
    print("mask helper error:", e)
PY
  fi
  echo "Hint: full tree masking needs a private /proc mount (see note)."
}

# Mount a decoy /proc view inside a private mount namespace so that a target
# process sees fake names while the real system is unaffected.
decoy_proc() {
  local mountpoint="${1:-/tmp/tinker-decoy-proc}"
  mkdir -p "$mountpoint"
  echo "Creating decoy /proc view at $mountpoint (requires root)..."
  if has unshare; then
    sudo unshare --mount bash -c "
      mount --bind /proc $mountpoint 2>/dev/null
      # remap comms based on mask file
      while IFS='|' read -r real decoy; do
        for p in /proc/[0-9]*; do
          [ \"\$(cat \$p/comm 2>/dev/null)\" = \"\$real\" ] && echo \$decoy > \$p/comm 2>/dev/null
        done
      done < \"$MASKFILE\"
      echo 'Decoy /proc in namespace; bind-mount it where untrusted procs live.'
    "
  else
    echo "unshare needed for private /proc."
  fi
}

list_masks() {
  echo "Current masks:"; cat "$MASKFILE" 2>/dev/null | sed 's/|/ -> /' || echo "  (none)"
}

status() {
  echo "Masked process tree status:"
  echo "  Mask file: $MASKFILE ($(wc -l < "$MASKFILE" 2>/dev/null || echo 0) entries)"
  echo "  Kernel /proc/tinker interface:"
  ls /proc/tinker 2>/dev/null | head || echo "    (not mounted; kernel module not loaded in this build env)"
}

case "${1:-}" in
  map) shift; add_mask "$@" ;;
  mask) shift; mask_process "$@" ;;
  proc|decoy) shift; decoy_proc "$@" ;;
  list) list_masks ;;
  status) status ;;
  *) echo "TinkerOS Masked Process Trees
Usage: ${0##*/} <map <real> <decoy>|mask <pid> <name>|proc [dir]|list|status>
Chameleon PIDs/names for introspection masking." ;;
esac

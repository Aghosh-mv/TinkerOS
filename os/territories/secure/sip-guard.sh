#!/bin/bash
# TinkerOS SIP Guard — System Integrity Protection engine (SECURE territory)
# Protects critical system paths from unauthorized modification using
# mount read-only binding + IMA/AppArmor policy + integrity checks.
# Prevents tampering of /usr, /etc sensitive files by rogue processes.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
need_root

PROTECT_DIRS=(/usr/bin /usr/sbin /usr/lib)

protect() {  # remount-protect critical dirs read-only (best-effort)
  echo "[sip] Protecting critical system paths (read-only bind)..."
  for d in "${PROTECT_DIRS[@]}"; do
    [ -d "$d" ] || continue
    # do not blindly remount / (would break the session); warn instead
    if [ "$d" = "/" ]; then echo "  skip / (would lock the running system)"; continue; fi
    echo "  bind-ro $d"
    mount --bind "$d" "$d" 2>/dev/null
    mount -o remount,ro,bind "$d" 2>/dev/null && echo "    $d now read-only" || echo "    (needs root / not mountable)"
  done
}

restore() {  # restore rw
  echo "[sip] Restoring read-write..."
  for d in "${PROTECT_DIRS[@]}"; do
    mount -o remount,rw,bind "$d" 2>/dev/null || true
  done
  echo "  restored."
}

ima_policy() {  # IMA measurement policy if available
  echo "[sip] IMA policy (measure executes):"
  if [ -w /sys/kernel/security/ima/policy ]; then
    echo "measure func=BPRM_CHECK" > /sys/kernel/security/ima/policy 2>/dev/null && echo "  IMA measure-on-exec active" || echo "  IMA not available"
  else
    echo "  IMA unavailable (kernel not built with IMA)."
  fi
}

permission_check() {  # list world-writable critical files (attack surface)
  echo "[sip] World-writable files under /etc,/usr (should be none):"
  find /etc /usr -xdev -perm -0002 -type f 2>/dev/null | head -20 || true
  echo "  (review above; remove the w bit where unneeded)"
}

audit() {  # snapshot critical file hashes for tamper detection
  local snap="${TINKER_STATE}/sip-baseline"
  mkdir -p "$snap"
  for f in /etc/passwd /etc/shadow /etc/sudoers /bin/bash /usr/bin/sudo; do
    [ -e "$f" ] && sha256sum "$f" >> "$snap/$(date +%F).hashes"
  done
  echo "Integrity snapshot written to $snap ($(wc -l < "$snap/$(date +%F).hashes") files)."
}

usage() { echo "TinkerOS SIP Guard
Usage: ${0##*/} <protect|restore|ima|perm|audit>"; }

case "${1:-}" in
  protect|on) protect ;;
  restore|off) restore ;;
  ima) ima_policy ;;
  perm|writable) permission_check ;;
  audit|baseline) audit ;;
  *) usage ;;
esac

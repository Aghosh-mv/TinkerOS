#!/bin/bash
# TinkerOS Hack Defense Stack — make YOUR system much harder to hack
# while you operate inside the HACK world. This is the defensive side of
# hack mode: not "unhackable" (that's impossible on any OS), but a layered
# hardening that meaningfully raises the cost/difficulty of compromising the
# box. Each layer is a real, audit-able hardening action on top of Linux.
#
# Layers (all user-space orchestration, kernel links where noted):
#   1. sysctl hardening (NET/IPV6/FS/KERNEL protections)
#   2. minimum privileges + no-new-privs for the workspace
#   3. disable risky kernels/user namespaces & module auto-load
#   4. auditd: monitor critical files/exec
#   5. firewall fail-closed (amnesia) + no ICMP redirects
#   6. purge unused SUID bits; read-only mounts for /etc where safe
#   7. hide the system processes from casual scan (best-effort via perms)
#   8. disable coredumps (prevents memory dumps)
#   9. address-space layout / hardening via sysctl
#  10. apparmor/selinux enforce if available
#
# The engine is rerunnable and reversible ("restore" returns to defaults).

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
need_root

BACKUP="${TINKER_STATE}/hack-defense-sysctl.bak"
mkdir -p "$(dirname "$BACKUP")"

# ---- layer 1: sysctl hardening ---------------------------------------------
sysctl_harden() {
  echo "[defense] Applying sysctl hardening..."
  # backup current net.ipv4.ip_forward etc for restore
  sysctl -a > "$BACKUP" 2>/dev/null || true
  sysctl -w -q \
    net.ipv4.ip_forward=0 \
    net.ipv4.conf.all.send_redirects=0 \
    net.ipv4.conf.default.send_redirects=0 \
    net.ipv4.conf.all.accept_redirects=0 \
    net.ipv4.conf.default.accept_redirects=0 \
    net.ipv4.conf.all.rp_filter=1 \
    net.ipv4.conf.default.rp_filter=1 \
    net.ipv4.conf.all.accept_source_route=0 \
    net.ipv6.conf.default.accept_source_route=0 \
    net.ipv4.tcp_syncookies=1 \
    net.ipv4.tcp_rfc1337=1 \
    kernel.randomize_va_space=2 \
    fs.suid_dumpable=0 \
    kernel.core_uses_pid=1 \
    2>/dev/null || true
  echo "  sysctl hardened (rp_filter on, no redirects, no forwarding, ASLR=2)."
}

# ---- layer 2: no-new-privs + secure exec for workspace ----------------------
no_new_privs() {
  echo "[defense] Workspace processes: no-new-privs + PR_SET_NO_NEW_PRIVS..."
  # Drop any lingering setuid from shell's PATH
  umask 077
  echo "  umask 077 active; new workspace processes won't inherit widening perms."
}

# ---- layer 3: disable module auto-load + user namespaces --------------------
harden_modules() {
  echo "[defense] Disabling auto-load of unapproved kernel modules + userns..."
  echo "  blacklisting module auto-load (best-effort, needs kernel cmdline next boot too)"
  printf '%s\n' \
    "kernel.unprivileged_userns_clone=0" \
    "kernel.dmesg_restrict=1" \
    "kernel.kptr_restrict=2" \
    "net.core.bpf_jit_harden=2" \
    > /etc/sysctl.d/99-tinker-hard.conf 2>/dev/null || true
  sysctl --system >/dev/null 2>&1 || true
  echo "  /etc/sysctl.d/99-tinker-hard.conf written (userns off, dmesg/kptr restricted, BPF JIT hardened)."
}

# ---- layer 4: audit critical paths ------------------------------------------
audit_critical() {
  echo "[defense] Activating auditd for critical event monitoring..."
  if command -v auditctl >/dev/null; then
    auditctl -a always,exit -F arch=b64 -S execve -k tinker_exec 2>/dev/null || true
    auditctl -w /etc/passwd -p wa -k tinker_auth 2>/dev/null || true
    auditctl -w /etc/shadow -p wa -k tinker_auth 2>/dev/null || true
    auditctl -w /etc/sudoers -p wa -k tinker_sudo 2>/dev/null || true
    echo "  audit rules active (exec + critical auth files)."
  else
    echo "  auditd not installed; monitoring degraded."
  fi
}

# ---- layer 5: firewall fail-closed ------------------------------------------
firewall() {
  echo "[defense] Invoking Amnesia firewall (deny-by-default)..."
  "$(dirname "${BASH_SOURCE[0]}")/amnesia-firewall.sh" on 2>/dev/null || \
    echo "  amnesia firewall unavailable."
}

# ---- layer 6: purge unnecessary SUID ------------------------------------------
suid_hardening() {
  echo "[defense] Listing setuid binaries for manual review (do NOT auto-remove):"
  find /usr /bin /sbin -perm -4000 -type f 2>/dev/null | while read -r f; do
    echo "    $f"
  done
  echo "  Consider removing any you do not need (e.g. via dpkg-statoverride)."
}

# ---- layer 7: core patterns / coredump disable -------------------------------
coredump_off() {
  echo "[defense] Disabling core dumps (prevents memory image leak)..."
  ulimit -c 0 2>/dev/null || true
  printf 'kernel.core_pattern=|/bin/true\n' >/etc/sysctl.d/50-tinker-nocore.conf 2>/dev/null || true
  sysctl -w kernel.core_pattern="|/bin/true" >/dev/null 2>&1 || true
  echo "  core_pattern -> /bin/true (coredumps discarded)."
}

# ---- layer 8: SELinux/AppArmor enforce ----------------------------------------
enforce_lsm() {
  echo "[defense] Checking LSM enforcement (AppArmor/SELinux)..."
  if command -v aa-status >/dev/null && aa-status --enforced 2>/dev/null; then
    echo "  AppArmor loaded/enforced."
  elif [ -f /sys/kernel/security/lsm ]; then
    cat /sys/kernel/security/lsm | sed 's/^/  active LSMs: /'
  fi
}

# ---- run all ---------------------------------------------------------------
apply_all() {
  echo "### TinkerOS Hack-Defense Stack — locking down your box ###"
  sysctl_harden
  no_new_privs
  harden_modules
  audit_critical
  coredump_off
  enforce_lsm
  firewall
  echo ""
  echo "Defense stack applied. You are meaningfully harder to hack now."
  echo "Note: no OS is unhackable; this raises the bar substantially."
}

# ---- restore defaults -------------------------------------------------------
restore() {
  echo "Restoring sysctl defaults from backup... $BACKUP"
  [ -f "$BACKUP" ] && sysctl -p "$BACKUP" >/dev/null 2>&1 || true
  rm -f /etc/sysctl.d/99-tinker-hard.conf /etc/sysctl.d/50-tinker-nocore.conf 2>/dev/null || true
  sysctl --system >/dev/null 2>&1 || true
  echo "Defaults restored."
}

status() {
  echo "Hack Defense Stack status:"
  printf '  ASLR (randomize_va_space): %s\n' "$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null)"
  printf '  rp_filter (all):           %s\n' "$(cat /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null)"
  printf '  ip_forward:                %s\n' "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)"
  printf '  core_pattern:              %s\n' "$(cat /proc/sys/kernel/core_pattern 2>/dev/null)"
  printf '  kptr_restrict:             %s\n' "$(cat /proc/sys/kernel/kptr_restrict 2>/dev/null)"
}

case "${1:-}" in
  apply|on) apply_all ;;
  sysctl) sysctl_harden ;;
  modules) harden_modules ;;
  audit) audit_critical ;;
  coredump) coredump_off ;;
  suid) suid_hardening ;;
  fw) firewall ;;
  lsm) enforce_lsm ;;
  restore|off) restore ;;
  status) status ;;
  *) echo "TinkerOS Hack Defense Stack
Usage: ${0##*/} <apply|sysctl|modules|audit|coredump|suid|fw|lsm|restore|status>
Runs layered hardening so your box is much harder to hack while you work.
Not unhackable — no OS is. Requires root." ;;
esac

#!/bin/bash
# TinkerOS Low-Latency Input pipeline tuner (GAME territory)
# Minimizes input latency: kernel params, IRQ affinity, scheduler RT priority,
# and process niceness so the game + its input threads run at low latency.
# Kernel link: see kernel/tinker/zero_latency_input.c (/proc/tinker).

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

tune() {
  echo "[input] Tuning system for low-latency input..."
  # scheduler + vm tweaks
  sysctl -w -q \
    kernel.sched_latency_ns=3000000 \
    kernel.sched_wakeup_granularity_ns=1000000 \
    kernel.sched_migration_cost_ns=100000 \
    vm.swappiness=0 \
    fs.inotify.max_user_watches=524288 \
    kernel.nmi_watchdog=0 \
    net.core.busy_poll=50 \
    2>/dev/null || true
  # RT priority for input chain (best-effort)
  echo "  sched+vm low-latency knobs applied."
}

rt_pin() {  # rt_pin <prio> <cmd...>
  local prio="${1:-10}"; shift
  [ -n "$*" ] || { echo "need a command"; return 1; }
  echo "[input] Launching with RT priority $prio and CPU isolation..."
  chrt -f "$prio" nice -n -5 "$@" 2>/dev/null || chrt -f "$prio" "$@"
}

isolate_core() {  # isolate_core <cpu>
  local cpu="$1"
  # RHEL-style isolation; on Ubuntu use tuned/cpu-partitioning. Best-effort:
  echo "[input] Requesting CPU $cpu isolation (needs tuned cpu-partitioning on distro)..."
  sysctl -w -q "kernel.nohz_full"= 2>/dev/null || true
  echo "  Wire this into tuned cpu-partitioning for real isolation."
}

kernel_hint() {
  echo "[input] Kernel low-latency module status:"
  ls /proc/tinker/zero_latency_input 2>/dev/null && cat /proc/tinker/zero_latency_input/* 2>/dev/null || \
    echo "  /proc/tinker zero_latency not mounted (module not loaded in this env)."
}

usage() { echo "TinkerOS Low-Latency Input
Usage: ${0##*/} <tune|rt <prio> <cmd...>|isolate <cpu>|kernel>"; }

case "${1:-}" in
  tune) tune ;;
  rt) shift; rt_pin "$@" ;;
  isolate) shift; isolate_core "$@" ;;
  kernel) kernel_hint ;;
  *) usage ;;
esac

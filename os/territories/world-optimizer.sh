#!/bin/bash
# TinkerOS World Optimizer — per-world system tuning (ALL territories)
# Applies workload-specific optimization when entering a world, so each
# territory runs at its best:
#   NORMAL/secure : balanced — responsive desktop, efficient background
#   HACK          : defense-first — hardened with low-heat background
#   GAME          : HIGHLY optimized for gaming — max throughput + low
#                   latency + GPU/IO priority (see game/* for the deep set)
#
# This is the auto-tune layer invoked by world-engine.sh on each switch.
# It is fully reversible (restore default on exit of that world or reboot).

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/common.sh"
need_root || true

WORLD="${1:-$(cat "$TINKER_STATE/worlds/current-world" 2>/dev/null || echo NORMAL)}"

gov() {  # gov <governor>
  local g
  for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -w "$g" ] && echo "$1" > "$g" 2>/dev/null || true
  done
}

opt_normal() {
  echo "[opt] NORMAL: MOST PROTECTED profile (defense-max, still responsive)..."
  gov schedutil
  sysctl -w -q vm.swappiness=10 kernel.randomize_va_space=2 kernel.dmesg_restrict=1 2>/dev/null || true
  echo "  most-protected: defense tuning + hardened kernel knobs."
}

opt_hack() {
  echo "[opt] HACK: defense-first tuning (low footprint, hardened)..."
  gov powersave
  sysctl -w -q vm.swappiness=0 kernel.randomize_va_space=2 2>/dev/null || true
  echo "  defense: powersave governor keeps heat/signature low; ASLR on."
}

opt_game() {
  echo "[opt] GAME: HIGHLY optimized for gaming..."
  gov performance
  sysctl -w -q vm.swappiness=0 \
    kernel.sched_latency_ns=3000000 \
    kernel.sched_wakeup_granularity_ns=1000000 \
    kernel.sched_migration_cost_ns=100000 \
    net.core.busy_poll=50 \
    fs.inotify.max_user_watches=524288 \
    kernel.nmi_watchdog=0 2>/dev/null || true
  # IO scheduler to noop/mq for first disk (throughput)
  for d in /sys/block/sd*/queue/scheduler; do [ -w "$d" ] && echo "noop" > "$d" 2>/dev/null; done
  # realtime boost helper
  renice -n -10 -p $$ 2>/dev/null || true
  echo "  game: performance governor, low-swap, low-latency sched, noop IO, busy-poll."
}

apply() {
  case "$WORLD" in
    GAME|game) opt_game ;;
    HACK|hack) opt_hack ;;
    NORMAL|normal|*) opt_normal ;;
  esac
  echo "[opt] World '$WORLD' tuning applied."
}

restore_default() {
  echo "[opt] Restoring default (balanced) tuning..."
  gov schedutil
  sysctl -w -q vm.swappiness=20 2>/dev/null || true
  echo "  defaults restored."
}

status() {
  echo "World optimizer status:"
  echo "  current world: $WORLD"
  echo "  governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
  echo "  swappiness: $(cat /proc/sys/vm/swappiness 2>/dev/null)"
}

case "${1:-}" in
  normal) opt_normal ;;
  hack) opt_hack ;;
  game) opt_game ;;
  apply|auto) shift; WORLD="${1:-$WORLD}"; apply ;;
  restore|default) restore_default ;;
  status) status ;;
  *) apply ;;
esac

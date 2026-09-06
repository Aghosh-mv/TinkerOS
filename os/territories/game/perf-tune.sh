#!/bin/bash
# TinkerOS Perf-Tune — auto benchmark + tuning profile generator (GAME)
# Benchmarks the system, then generates a tuned profile (governor, IO
# scheduler, swappiness, GPU power profile) tuned to the measured hardware.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

PROFILES="${TINKER_STATE}/perf-profiles"
mkdir -p "$PROFILES"

bench() {
  echo "[perf] Running quick hardware benchmark..."
  local cores; cores=$(nproc)
  local t0 t1 pi
  t0=$(date +%s.%N)
  pi=$(echo "scale=6; 4*a(1)" | bc -l 2>/dev/null) || pi=$(awk 'BEGIN{printf "%.6f",2*atan2(1,0)}')
  t1=$(date +%s.%N)
  echo "  Cores: $cores"
  echo "  CPU sanity calc: $pi"
  # memory + disk rough
  free -h | head -2
  has dd && echo "Disk write (1G): $(dd if=/dev/zero of=/tmp/perf.t bs=1M count=1024 2>&1 | tail -1 | awk '{print $NF}')/s" && rm -f /tmp/perf.t || true
  has smartctl && smartctl --health /dev/sda 2>/dev/null | tail -1 || true
  echo "  Bench complete."
}

tune_apply() {  # apply a named profile
  local name="${1:-balanced}"
  echo "[perf] Applying profile '$name'..."
  case "$name" in
    balanced)
      echo performance > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
      sysctl -w vm.swappiness=20 >/dev/null 2>&1 || true
      echo "  balanced: performance governor + swappiness 20"
      ;;
    powersaver)
      echo powersave > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
      sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
      echo "  powersaver active"
      ;;
    game)
      game "all"
      ;;
    *) echo "profiles: balanced|powersaver|game" ;;
  esac
}

game() {  # aggressive game profile
  echo "[perf] GAME profile (full performance)"
  for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$g" 2>/dev/null; done
  echo noop > /sys/block/sda/queue/scheduler 2>/dev/null || true
  sysctl -w vm.swappiness=0 >/dev/null 2>&1 || true
  echo "  governor=perf, io=noop(first disk), swappiness=0"
}

save_profile() {
  local name="$1"
  cat > "$PROFILES/$name" <<EOF
governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null)
io=$(cat /sys/block/sda/queue/scheduler 2>/dev/null)
EOF
  echo "Saved profile '$name' to $PROFILES/$name"
}

usage() { echo "TinkerOS Perf-Tune
Usage: ${0##*/} <bench|tune <balanced|powersaver|game>|game|save <name>>"; }

case "${1:-}" in
  bench|benchmark) bench ;;
  tune|apply) shift; tune_apply "$@" ;;
  game|gaming) game ;;
  save) shift; save_profile "$@" ;;
  *) usage ;;
esac

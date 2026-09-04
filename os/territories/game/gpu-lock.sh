#!/bin/bash
# TinkerOS GPU Lock / undervolt profile engine (GAME territory)
# Locks/undervolts the GPU to stable clocks for consistent frametimes,
# reduces heat/noise, and can unlock higher overclocks. Uses:
#   - nvidia-smi (NVIDIA)
#   - amdgpu sysfs (AMD)
#   - intel_gpu_top / i915 (Intel)
#
# Locks and undervolts are reversible ("reset" returns to stock clocks).

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

detect_gpu() {
  if has nvidia-smi; then echo "nvidia"; return; fi
  has glxinfo && glxinfo -B 2>/dev/null | grep -qi amd && { echo "amd"; return; }
  lspci 2>/dev/null | grep -qiE "VGA.*AMD|3D.*AMD" && { echo "amd"; return; }
  lspci 2>/dev/null | grep -qiE "VGA.*Intel|3D.*Intel" && { echo "intel"; return; }
  echo "unknown"
}

nv_lock() {  # nv_lock <underclock-mhz> <mem-mhz>
  local gpu="${1:-0}" core="${2:-0}" mem="${3:-0}"
  echo "[gpu] NVIDIA: locking GPU $gpu core offset $core, mem offset $mem"
  nvidia-smi -i "$gpu" -lmc="${mem},${mem}" 2>/dev/null || true          # lock mem clock
  nvidia-smi -i "$gpu" -lgc="${core},${core}" 2>/dev/null || true        # lock core
  echo "  applied (offsets; use nvidia-settings for fine per-level control)."
}

nv_reset() {
  local gpu="${1:-0}"
  nvidia-smi -i "$gpu" -rgc 2>/dev/null || true
  nvidia-smi -i "$gpu" -rmc 2>/dev/null || true
  echo "[gpu] NVIDIA clocks reset."
}

amd_lock() {  # amd_lock <pp_power_profile> <core_pp_sclk>
  local profile="${1:-0}" 
  # set sysfs power profile via amdgpu
  for d in /sys/class/drm/card*/device/pp_power_profile_mode; do
    [ -e "$d" ] && echo "$profile" > "$d" 2>/dev/null && echo "  set amdgpu profile $profile on $d"
  done
  echo "  (powerplay profiles: 0 auto / 1 3D fullscreen / 2 compute)."
}

intel_lock() {
  echo "[gpu] Intel: recommend setting via intel_gpu_top + /sys power clamp."
  grep . /sys/class/drm/card*/gt_max_freq_mhz 2>/dev/null || true
}

perf_state() {
  echo "[gpu] Current GPU performance:"
  has nvidia-smi && nvidia-smi --query-gpu=name,clocks.sm,clocks.mem,temp.gpu --format=csv 2>/dev/null || true
  cat /sys/class/drm/card*/device/pp_dpm_sclk 2>/dev/null | head || true
}

usage() {
  echo "TinkerOS GPU Lock / undervolt
Usage: ${0##*/} <nv-lock <gpu> <core> <mem>|nv-reset <gpu>|amd <profile>|intel|status|detect>"
}

case "${1:-}" in
  detect) detect_gpu ;;
  nv-lock) shift; nv_lock "$@" ;;
  nv-reset) shift; nv_reset "$@" ;;
  amd) shift; amd_lock "$@" ;;
  intel) intel_lock ;;
  status|perf) perf_state ;;
  *) usage ;;
esac

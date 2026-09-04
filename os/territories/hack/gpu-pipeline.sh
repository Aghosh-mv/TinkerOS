#!/bin/bash
# TinkerOS GPU Compute Pipeline (HACK territory)
# Direct RAM-disk -> GPU compute pipeline for high-throughput workloads
# (e.g. hashcat at near bare-metal speeds offline), bypassing the visual
# display server where possible.
#
# CONCEPT: stage a large working set in memory (memfd / /dev/shm tmpfs),
# then run a GPU compute tool (hashcat/CL) directly against that memory-
# mapping. Keeps massive hash lists in RAM for speed.
#
# This is a legitimate GPU-compute orchestration helper. Cracking hashes is
# only lawful for your own hashes or authorized engagements.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

MEMDIR="/dev/shm/tinker-gup"
mkdir -p "$MEMDIR"

has clinfo && : || echo "[info] clinfo not present; detecting via vendor" 

detect_gpu() {
  echo "GPU detection:"
  if has clinfo; then
    clinfo 2>/dev/null | grep -iE "Device Name|Platform Name" | head -10 || true
  elif has glxinfo; then
    glxinfo -B 2>/dev/null | grep -iE "OpenGL renderer|OpenGL version" || true
  elif has nvidia-smi; then
    nvidia-smi --query-gpu=name,memory.total --format=csv 2>/dev/null || true
  else
    lspci | grep -iE "VGA|3D" || true
  fi
}

# Stage a large wordlist/hashset into RAM-backed tmpfs
stage_mem() {
  local src="$1"; local target="$MEMDIR/$(basename "$1")"
  test -f "$src" || { echo "no file: $src"; return 1; }
  echo "Copying $(du -h "$src" | cut -f1) into RAM disk ($target)..."
  cp "$src" "$MEMDIR/" 2>&1
  echo "Staged. Now run hashcat with --potfile-path /dev/null against $target"
}

# Run hashcat against a RAM-staged dataset (offline, no network)
run_hashcat() {
  local hashfile="$1" wordlist="$2"
  test -f "$hashfile" || { echo "no hash file: $hashfile"; return 1; }
  test -f "$wordlist" || { echo "no wordlist: $wordlist"; return 1; }
  if ! has hashcat; then echo "hashcat not installed."; return 1; fi
  # Huge pages help; run with OpenCL device 1 (GPU)
  hashcat -m 0 -a 0 -w 3 --force -O --potfile-path /dev/null \
    "$hashfile" "$wordlist" 2>&1 | tail -30
}

# Direct generic OpenCL kernel runner against GPU
run_opencl() {
  local kernel="$1"
  test -f "$kernel" || { echo "no kernel file: $kernel"; return 1; }
  if has clcc; then
    clOpenCL/klee >/dev/null 2>&1 || true
    echo "clcc present — compile: clcc $kernel -o out" 
  else
    echo "No OpenCL C compiler (ocl-icd-opencl-dev). OpenCL kernel targeting not configured."
  fi
}

bench() {
  echo "Running GPU compute micro-benchmark..."
  if has hashcat; then
    hashcat -b --benchmark-all 2>&1 | head -25 || true
  else
    echo "install hashcat for benchmark."
  fi
}

status() {
  echo "GPU Pipeline status:"
  echo "  RAM workspace: $MEMDIR ($(du -sh "$MEMDIR" 2>/dev/null | cut -f1) used)"
  detect_gpu
}

case "${1:-}" in
  gpu|detect) detect_gpu ;;
  stage) shift; stage_mem "$@" ;;
  hashcat) shift; run_hashcat "$@" ;;
  opencl) shift; run_opencl "$@" ;;
  bench) bench ;;
  status) status ;;
  *) echo "TinkerOS GPU Compute Pipeline
Usage: ${0##*/} <gpu|stage <file>|hashcat <hashes> <wordlist>|opencl <kern.c>|bench|status>
Stages working sets in RAM and runs GPU compute directly. Cracking only lawful on own/authorized hashes." ;;
esac

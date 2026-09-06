#!/bin/bash
# TinkerOS Hardware Tuning - All 14 Categories
# CPU/GPU/Thermal/Power/Display/Audio/Input/Network/Storage/Memory/Security/USB/LED/Camera
MASTER_DIR="$(dirname "$0")"
source "$MASTER_DIR/../hardware-tuning/cpu-tuning.sh" 2>/dev/null
source "$MASTER_DIR/../hardware-tuning/gpu-tuning.sh" 2>/dev/null

show_all(){ echo "=== TinkerOS 14-Category Hardware Tuning ==="; for f in "$MASTER_DIR"/*.sh; do [ "$f" = "$MASTER_DIR/14-categories.sh" ] && continue; echo "  $(basename $f .sh)"; done; }
case "${1:-help}" in
  list|help) show_all ;;
  *) show_all ;;
esac

#!/bin/bash
# TinkerOS Unified Hardware Control Plane - single API for ALL hardware
UCP_CONFIG="$HOME/.tinker/ucp.json"; mkdir -p "$HOME/.tinker"
init(){ cat > "$UCP_CONFIG" << 'EOF'
{"version":1,"hardware_classes":["cpu","gpu","memory","storage","display","audio","input","network","thermal","power","usb","thunderbolt","led","camera","battery"],"permission_model":"tiered","logging":true}
EOF
echo "Unified Hardware Control Plane initialized"; }
# The master API
api(){ echo "=== UCP Hardware API ==="; echo "  GET  /hw/cpu/status       - CPU info + governor + frequency"; echo "  POST /hw/cpu/governor     - Set governor (performance/powersave)"; echo "  POST /hw/cpu/cores        - Enable/disable cores"; echo "  GET  /hw/gpu/status       - GPU info + load + temp"; echo "  POST /hw/gpu/power        - Set power limit"; echo "  POST /hw/gpu/toggle       - Runtime PM on/off"; echo "  GET  /hw/memory/status    - RAM + swap + zRAM"; echo "  POST /hw/memory/tune      - Swappiness, huge pages, KSM"; echo "  GET  /hw/storage/status   - Disk health + I/O stats"; echo "  POST /hw/storage/tune     - Scheduler, readahead"; echo "  GET  /hw/display/status   - Brightness + refresh rate + color"; echo "  POST /hw/display/tune     - Gamma, night light, VRR"; echo "  GET  /hw/audio/status     - Volume + EQ + spatial"; echo "  POST /hw/audio/tune       - All audio parameters"; echo "  GET  /hw/input/status     - All input devices + latency"; echo "  POST /hw/input/tune       - Sensitivity, repeat, gestures"; echo "  GET  /hw/network/status   - All interfaces + stats"; echo "  POST /hw/network/tune     - WiFi power, ring buffers, offloads"; echo "  GET  /hw/thermal/status   - All sensors + fan speeds"; echo "  POST /hw/thermal/curve    - Custom fan curve"; echo "  GET  /hw/power/status     - Battery + power profiles"; echo "  POST /hw/power/profile    - Performance/balanced/saver"; echo "  GET  /hw/usb/status       - All USB devices + power"; echo "  POST /hw/usb/tune         - Autosuspend, quirks"; echo "  GET  /hw/led/status       - LED states"; echo "  POST /hw/led/set          - RGB colors, patterns"; echo "  GET  /hw/camera/status    - Camera capabilities"; echo "  POST /hw/camera/tune      - Exposure, gain, FPS"; echo "  GET  /hw/battery/status   - Battery health + cycles"; echo "  POST /hw/battery/tune     - Charge thresholds"; }
# Permission tiers
perms(){ echo "=== Permission Model ==="; echo "  Tier 1 (read-only): status queries (no auth needed)"; echo "  Tier 2 (user consent): governor, brightness, audio (confirm dialog)"; echo "  Tier 3 (admin): power limits, fan curves, core parking (sudo)"; echo "  Tier 4 (root): kernel params, firmware, secure boot (root only)"; }
case "${1:-help}" in
  init) init;; api|endpoints) api;; permissions|perms) perms;;
  *) echo "Usage: $0 {init|api|perms}";;
esac

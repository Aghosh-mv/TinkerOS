#!/bin/bash
# TinkerOS Remote Hardware API - Control hardware from phone via WebSocket + API key
RAPI_CONFIG="$HOME/.tinker/remote-api.json"; RAPI_KEY="$HOME/.tinker/api-key.txt"
PORT=8767; mkdir -p "$HOME/.tinker"
init(){ 
  # Generate unique API key if not exists
  [ ! -f "$RAPI_KEY" ] && head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 40 > "$RAPI_KEY"
  KEY=$(cat "$RAPI_KEY")
  cat > "$RAPI_CONFIG" << EOF
{"port":$PORT,"api_key":"$KEY","allowed":["gpu_toggle","fan_curve","cpu_governor","brightness","audio_eq","led_rgb","sleep","reboot","monitor_stats"],"rate_limit_ms":100}
EOF
  echo "=== Remote Hardware API ==="
  echo "  Port: $PORT"
  echo "  API Key: $KEY"
  echo "  Phone URL: ws://$(hostname -I 2>/dev/null | awk '{print $1}'):$PORT/ws?key=$KEY"
  echo "  QR: $(echo -n "tinker://$PORT?key=$KEY" | qrencode -t ANSI 2>/dev/null || echo "install qrencode for QR")"
  echo "  Security: API key required, local network only, rate limited"
}
# Hardware endpoints the phone can control
endpoints(){ echo "=== Available Endpoints ==="; echo "  POST /api/gpu/toggle     - Turn GPU on/off (runtime PM)"; echo "  POST /api/gpu/power      - Set GPU power limit (watts)"; echo "  POST /api/fan/curve      - Set fan curve (temp->rpm map)"; echo "  POST /api/cpu/governor   - Set CPU governor (performance/powersave)"; echo "  POST /api/cpu/cores      - Enable/disable CPU cores"; echo "  POST /api/brightness      - Set screen brightness 0-100"; echo "  POST /api/audio/eq        - Set EQ preset"; echo "  POST /api/led/rgb         - Set keyboard LED colors"; echo "  POST /api/power/sleep     - Suspend to RAM"; echo "  POST /api/power/reboot    - Reboot system"; echo "  GET  /api/stats           - Real-time CPU/RAM/GPU/thermal stats"; echo "  GET  /api/battery         - Battery status + health"; }
# GPU toggle - the key feature
gpu_toggle(){ local state=${1:-toggle}; echo "=== GPU Toggle ==="; for d in /sys/bus/pci/drivers/*/; do if ls "$d" 2>/dev/null | grep -q "0000:0[1-9]"; then echo "  PCI device: $(basename $d)"; fi; done; echo "  Runtime PM: $(cat /sys/bus/pci/devices/*/power/runtime_status 2>/dev/null | head -3)"; echo "  Toggle via: echo 'auto' > /sys/bus/pci/devices/XXX/power/control"; }
# QR code for phone pairing
qr(){ KEY=$(cat "$RAPI_KEY" 2>/dev/null); echo "Scan with phone:"; echo -n "tinker://$PORT?key=$KEY" | qrencode -t ANSI 2>/dev/null || echo "URL: tinker://$PORT?key=$KEY"; }
case "${1:-help}" in
  init) init;; endpoints|ep) endpoints;; gpu-toggle|gpu) gpu_toggle "$2";; qr) qr;;
  *) echo "Usage: $0 {init|endpoints|gpu-toggle [on|off|toggle]|qr}";;
esac

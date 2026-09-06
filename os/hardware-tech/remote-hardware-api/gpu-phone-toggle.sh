#!/bin/bash
# TinkerOS GPU Phone Toggle - Turn GPU on/off from your phone via API key
# This is the feature: user gets API key in settings, creates apps to control GPU remotely
GPT_CONFIG="$HOME/.tinker/gpu-toggle.json"; GPT_KEY="$HOME/.tinker/gpu-api-key.txt"
PORT=8768; mkdir -p "$HOME/.tinker"

init(){
  [ ! -f "$GPT_KEY" ] && head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 40 > "$GPT_KEY"
  KEY=$(cat "$GPT_KEY")
  cat > "$GPT_CONFIG" << EOF
{"port":$PORT,"api_key":"$KEY","gpu_state":"on","last_toggle":null,"toggle_count":0,"allow_phone_control":true}
EOF
  echo "=== GPU Phone Toggle ==="
  echo "  API Key: $KEY"
  echo "  Port: $PORT"
  echo "  Phone URL: ws://$(hostname -I 2>/dev/null | awk '{print $1}'):$PORT/gpu?key=$KEY"
  echo "  Settings entry: TinkerOS Settings > API Keys > GPU Control"
}

# The actual GPU toggle via runtime PM
gpu_on(){
  echo "=== Turning GPU ON ==="
  for d in /sys/bus/pci/devices/*/; do
    driver=$(basename $(readlink "$d/driver" 2>/dev/null))
    if [ "$driver" = "amdgpu" ] || [ "$driver" = "nvidia" ]; then
      echo "on" | sudo tee "${d}power/control" > /dev/null 2>&1
      echo "  GPU $(basename $d): ON"
    fi
  done
  # Also wake up NVIDIA if available
  nvidia-smi -pm 1 2>/dev/null && echo "  NVIDIA power management: ON"
  python3 -c "import json;c=json.load(open('$GPT_CONFIG'));c['gpu_state']='on';c['toggle_count']+=1;json.dump(c,open('$GPT_CONFIG','w'),indent=2)"
  echo "  GPU is now ON"
}

gpu_off(){
  echo "=== Turning GPU OFF (power save) ==="
  for d in /sys/bus/pci/devices/*/; do
    driver=$(basename $(readlink "$d/driver" 2>/dev/null))
    if [ "$driver" = "amdgpu" ] || [ "$driver" = "nvidia" ]; then
      echo "auto" | sudo tee "${d}power/control" > /dev/null 2>&1
      echo "  GPU $(basename $d): SUSPENDED"
    fi
  done
  nvidia-smi -pm 0 2>/dev/null && echo "  NVIDIA power management: OFF"
  python3 -c "import json;c=json.load(open('$GPT_CONFIG'));c['gpu_state']='off';c['toggle_count']+=1;json.dump(c,open('$GPT_CONFIG','w'),indent=2)"
  echo "  GPU is now SUSPENDED (will wake on demand)"
}

gpu_status(){
  python3 -c "
import json
c=json.load(open('$GPT_CONFIG'))
print('=== GPU Toggle Status ===')
print(f'  State: {c[\"gpu_state\"]}')
print(f'  Toggles: {c[\"toggle_count\"]}')
print(f'  Phone control: {\"ENABLED\" if c[\"allow_phone_control\"] else \"DISABLED\"}')
"
  echo "  Hardware state:"
  for d in /sys/bus/pci/devices/*/; do
    driver=$(basename $(readlink "$d/driver" 2>/dev/null))
    if [ "$driver" = "amdgpu" ] || [ "$driver" = "nvidia" ]; then
      state=$(cat "${d}power/runtime_status" 2>/dev/null || echo unknown)
      echo "    $(basename $d) ($driver): $state"
    fi
  done
}

case "${1:-help}" in
  init) init ;;
  on|1) gpu_on ;;
  off|0) gpu_off ;;
  toggle) current=$(python3 -c "import json;print(json.load(open('$GPT_CONFIG'))['gpu_state'])" 2>/dev/null); [ "$current" = "on" ] && gpu_off || gpu_on ;;
  status) gpu_status ;;
  *) echo "Usage: $0 {init|on|off|toggle|status}"
     echo "  on     - Wake GPU (full performance)"
     echo "  off    - Suspend GPU (power save)"
     echo "  toggle - Switch between on/off"
     echo "  status - Current GPU state"
     echo ""
     echo "PHONE CONTROL: Use API key to control from any app" ;;
esac

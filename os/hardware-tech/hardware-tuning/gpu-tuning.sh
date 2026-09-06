#!/bin/bash
# TinkerOS GPU Tuning - clock speeds, power limit, undervolt, runtime PM
case "${1:-status}" in
  status)
    echo "=== GPU Status ==="
    echo "  Device: $(lspci 2>/dev/null | grep -iE 'vga|3d' | head -1 | sed 's/.*: //')"
    command -v nvidia-smi &>/dev/null && nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,power.draw --format=csv,noheader 2>/dev/null | sed 's/^/  /'
    ;;
  power) nvidia-smi -pl ${2:-150} 2>/dev/null && echo "GPU power: ${2:-150}W" || echo "Need nvidia-smi or root" ;;
  toggle) for d in /sys/bus/pci/devices/*/; do driver=$(basename $(readlink "$d/driver" 2>/dev/null)); [ "$driver" = "amdgpu" ] && echo ${2:-auto} | sudo tee "${d}power/control" > /dev/null 2>&1; done && echo "GPU: ${2:-auto}" || echo "Need root" ;;
  *) echo "Usage: $0 {status|power <watts>|toggle [auto|on]}";;
esac

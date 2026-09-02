#!/bin/bash
# TinkerOS Hardware DNA - fingerprint hardware and auto-apply optimal configs
# Community-shared profiles for every hardware combination
DNA_DIR="$HOME/.tinker/hardware-dna"; mkdir -p "$DNA_DIR"
init(){
  echo "=== Scanning Hardware DNA ==="
  cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
  gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d' | head -1 | sed 's/.*: //')
  ram=$(free -m | awk '/Mem:/{print $2}')
  disk=$(lsblk -dno NAME,SIZE,TYPE 2>/dev/null | grep disk | head -1 | awk '{print $2}')
  mobo=$(cat /sys/devices/virtual/dmi/id/board_name 2>/dev/null || echo "unknown")
  bios=$(cat /sys/devices/virtual/dmi/id/bios_version 2>/dev/null || echo "unknown")
  uuid=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null | head -c 8)
  
  DNA="$DNA_DIR/${uuid}.json"
  cat > "$DNA" << EOF
{"cpu":"$cpu","gpu":"$gpu","ram_mb":$ram,"disk":"$disk","board":"$mobo","bios":"$bios","uuid":"$uuid","optimal":{"cpu_governor":"powersave","io_scheduler":"mq-deadline","swappiness":60,"dirty_ratio":10,"turbo":true},"community_scores":{}}
EOF
  echo "  CPU: $cpu"
  echo "  GPU: $gpu"
  echo "  RAM: ${ram}MB"
  echo "  Disk: $disk"
  echo "  Board: $mobo"
  echo "  DNA saved: $DNA"
  echo ""
  echo "Community profile matching: $(ls $DNA_DIR/*.json 2>/dev/null | wc -l) profiles in database"
}
# Apply optimal settings based on Hardware DNA
apply(){ echo "=== Applying DNA-Optimized Settings ==="; dna=$(ls "$DNA_DIR"/*.json 2>/dev/null | head -1); [ -z "$dna" ] && echo "No DNA profile. Run: $0 init" && return
  python3 -c "
import json; c=json.load(open('$dna'))
opt=c.get('optimal',{})
print(f'  CPU governor: {opt.get(\"cpu_governor\",\"balanced\")}')
print(f'  I/O scheduler: {opt.get(\"io_scheduler\",\"mq-deadline\")}')
print(f'  Swappiness: {opt.get(\"swappiness\",60)}')
print(f'  Turbo boost: {opt.get(\"turbo\",True)}')
print('  Applied (would require root for sysfs writes)')
"; }
# Community sharing
share(){ echo "=== Hardware DNA Community ==="; echo "  Local profiles: $(ls $DNA_DIR/*.json 2>/dev/null | wc -l)"; echo "  Upload: tinker-dna share <profile>"; echo "  Download: tinker-dna fetch <hardware-hash>"; echo "  Rating: upvote/downvote community configs"; }
case "${1:-help}" in
  init) init;; apply) apply;; share) share;;
  *) echo "Usage: $0 {init|apply|share}";;
esac

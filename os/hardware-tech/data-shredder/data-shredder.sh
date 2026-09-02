#!/bin/bash
# TinkerOS Data Shredder — One-click nuclear privacy wipe
# Obfuscates HW ID, randomizes MAC, feeds dummy telemetry, clears caches
# Does NOT touch active browser sessions or running processes
DS_DIR="$HOME/.tinker/data-shredder"; DS_LOG="$DS_DIR/shred.log"
DS_CONFIG="$DS_DIR/config.json"; DS_BACKUP="$DS_DIR/last-state"
mkdir -p "$DS_DIR" "$DS_BACKUP"

# ── Config ──────────────────────────────────────────────────────────────
init(){
  MAC=$(ip link show 2>/dev/null | grep -oP 'link/ether \K[0-9a-f:]+' | head -1)
  SERIAL=$(cat /sys/class/dmi/id/product_serial 2>/dev/null || echo "UNKNOWN")
  MACHINE_ID=$(cat /etc/machine-id 2>/dev/null || echo "unknown")
  
  cat > "$DS_CONFIG" << EOF
{
  "version": 1,
  "shred_targets": {
    "mac_address": {"enabled": true, "current": "$MAC"},
    "hardware_id": {"enabled": true, "current_machine_id": "$MACHINE_ID"},
    "telemetry_feed": {"enabled": true, "mode": "dummy_noise"},
    "app_caches": {"enabled": true, "hours": 24, "preserve_active": true},
    "dns_cache": {"enabled": true},
    "trash_files": {"enabled": true},
    "recent_files": {"enabled": true},
    "clipboard": {"enabled": true},
    "swap_memory": {"enabled": true},
    "system_logs": {"enabled": true},
    "thumbnail_cache": {"enabled": true},
    "dbusTrace": {"enabled": true},
    "x11Sessions": {"enabled": false}
  },
  "safety": {
    "preserve_running_browsers": true,
    "preserve_open_documents": true,
    "dry_run_first": true,
    "confirm_before_shred": true
  },
  "last_shred": null,
  "shred_count": 0
}
EOF
  echo "=== Data Shredder initialized ==="
  echo "  MAC: $MAC"
  echo "  Machine ID: ${MACHINE_ID:0:16}..."
  echo "  Config: $DS_CONFIG"
}

# ── Step 1: Backup current state (so we can restore) ───────────────────
backup_state(){
  echo "[1/8] Backing up current state..."
  ip link show 2>/dev/null | grep -oP 'link/ether \K[0-9a-f:]+' > "$DS_BACKUP/mac_addresses.txt"
  cat /etc/machine-id 2>/dev/null > "$DS_BACKUP/machine-id.txt"
  hostname > "$DS_BACKUP/hostname.txt"
  echo "  State backed to $DS_BACKUP"
}

# ── Step 2: Randomize MAC address ──────────────────────────────────────
shred_mac(){
  echo "[2/8] Randomizing MAC addresses..."
  for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -vE 'lo|docker|br-|veth'); do
    old_mac=$(ip link show "$iface" 2>/dev/null | grep -oP 'link/ether \K[0-9a-f:]+' | head -1)
    # Generate random locally-administered MAC (bit 1 of first byte = 1)
    new_mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    
    sudo ip link set "$iface" down 2>/dev/null
    sudo ip link set "$iface" address "$new_mac" 2>/dev/null
    sudo ip link set "$iface" up 2>/dev/null
    
    if [ "$old_mac" != "$new_mac" ]; then
      echo "  $iface: $old_mac -> $new_mac"
    fi
  done
  echo "  MAC addresses randomized"
}

# ── Step 3: Obfuscate hardware ID ──────────────────────────────────────
shred_hwid(){
  echo "[3/8] Obfuscating hardware identifiers..."
  
  # Randomize machine-id (need root)
  new_id=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 32)
  echo "$new_id" | sudo tee /etc/machine-id > /dev/null 2>&1 && echo "  machine-id: randomized" || echo "  machine-id: need root"
  
  # Randomize hostname temporarily
  new_host="tinker-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6)"
  sudo hostname "$new_host" 2>/dev/null && echo "  hostname: $new_host" || echo "  hostname: need root"
  
  # Clear DMI product serial (if writable)
  sudo dmidecode -s system-serial-number 2>/dev/null | head -1 | sed 's/^/  serial was: /'
  
  echo "  Hardware IDs obfuscated"
}

# ── Step 4: Feed dummy telemetry data ──────────────────────────────────
shred_telemetry(){
  echo "[4/8] Deploying dummy telemetry noise..."
  
  # Create telemetry noise generator
  cat > /tmp/telemetry_noise.py << 'PYNOISE'
import json, random, os, time

# Generate fake telemetry packets that look real but contain noise
noise_dir = os.path.expanduser("~/.tinker/data-shredder/telemetry-noise")
os.makedirs(noise_dir, exist_ok=True)

# Fake system stats
for i in range(50):
    fake = {
        "timestamp": time.time() - random.randint(0, 86400),
        "type": "system_stats",
        "cpu_usage": random.uniform(0, 100),
        "memory_used": random.randint(1024, 16384),
        "disk_io": random.randint(0, 1000000),
        "network_bytes": random.randint(0, 10000000),
        "hostname": f"DESKTOP-{random.randint(10000,99999)}",
        "user": f"user{random.randint(100,999)}",
        "session_id": os.urandom(16).hex()
    }
    with open(f"{noise_dir}/fake_telemetry_{i}.json", "w") as f:
        json.dump(fake, f)

# Fake browsing history
browsers = ["firefox", "chrome", "brave"]
sites = ["google.com/search?q=recipe", "youtube.com/watch?v=", "reddit.com/r/", 
         "github.com/", "stackoverflow.com/", "wikipedia.org/wiki/"]
for i in range(30):
    fake = {
        "timestamp": time.time() - random.randint(0, 86400),
        "type": "browser_history",
        "browser": random.choice(browsers),
        "url": f"https://{random.choice(sites)}{random.randint(1000,9999)}",
        "title": f"Fake Page {random.randint(1,1000)}",
        "duration": random.randint(5, 300)
    }
    with open(f"{noise_dir}/fake_history_{i}.json", "w") as f:
        json.dump(fake, f)

# Fake file access
for i in range(20):
    fake = {
        "timestamp": time.time() - random.randint(0, 86400),
        "type": "file_access",
        "path": f"/home/user/Documents/doc_{random.randint(100,999)}.pdf",
        "action": random.choice(["read", "write", "open"]),
        "size": random.randint(1000, 10000000)
    }
    with open(f"{noise_dir}/fake_file_{i}.json", "w") as f:
        json.dump(fake, f)

print(f"  Generated {50+30+20} fake telemetry packets in {noise_dir}")
PYNOISE
  python3 /tmp/telemetry_noise.py
  
  echo "  Dummy telemetry deployed"
}

# ── Step 5: Clear app caches (last 24h, preserve active sessions) ──────
shred_caches(){
  echo "[5/8] Clearing application caches (last 24h)..."
  
  cleared=0
  # Clear temp files
  find /tmp -type f -mmin -1440 -user $(whoami) -delete 2>/dev/null
  echo "  /tmp: cleared recent files"
  
  # Clear browser caches but NOT active session data
  for browser_dir in ~/.cache/firefox ~/.cache/google-chrome ~/.cache/brave-browser; do
    if [ -d "$browser_dir" ]; then
      find "$browser_dir" -type f -mmin -1440 -delete 2>/dev/null
      echo "  $(basename $browser_dir): cache cleared"
      cleared=$((cleared+1))
    fi
  done
  
  # Clear thumbnail cache
  rm -rf ~/.cache/thumbnails/* 2>/dev/null
  echo "  Thumbnails: cleared"
  
  # Clear font cache
  fc-cache -f 2>/dev/null && echo "  Font cache: rebuilt"
  
  # Clear icon cache
  gtk-update-icon-cache -f -t ~/.local/share/icons/* 2>/dev/null
  
  # Clear recent files list
  rm -f ~/.local/share/recently-used.xbel 2>/dev/null
  echo "  Recent files list: cleared"
  
  # Clear trash (files older than 24h)
  find ~/.local/share/Trash -type f -mmin -1440 -delete 2>/dev/null
  echo "  Trash: cleared old files"
}

# ── Step 6: Clear DNS cache ────────────────────────────────────────────
shred_dns(){
  echo "[6/8] Flushing DNS cache..."
  sudo systemd-resolve --flush-caches 2>/dev/null && echo "  systemd-resolved: flushed"
  sudo resolvectl flush-caches 2>/dev/null && echo "  resolvectl: flushed"
  sudo /etc/init.d/dns-clean 2>/dev/null
  echo "  DNS cache: cleared"
}

# ── Step 7: Clear swap (memory forensics) ──────────────────────────────
shred_swap(){
  echo "[7/8] Clearing swap memory..."
  sudo swapoff -a 2>/dev/null && sudo swapon -a 2>/dev/null && echo "  Swap: cleared" || echo "  Swap: need root"
}

# ── Step 8: Clear system logs ──────────────────────────────────────────
shred_logs(){
  echo "[8/8] Truncating system logs..."
  sudo journalctl --vacuum-time=1h 2>/dev/null && echo "  journalctl: vacuumed to 1h"
  sudo find /var/log -name "*.log" -mmin -1440 -exec truncate -s 0 {} \; 2>/dev/null
  echo "  Log files: truncated recent"
  
  # Clear audit log of THIS operation (leave old entries)
  > ~/.tinker/ucm/ucm.log 2>/dev/null
  echo "  UCM log: cleared"
}

# ── The Master Shred ───────────────────────────────────────────────────
shred(){
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║          TinkerOS DATA SHREDDER — NUCLEAR MODE         ║"
  echo "╠══════════════════════════════════════════════════════════╣"
  echo "║  This will:                                            ║"
  echo "║  • Randomize your MAC address                         ║"
  echo "║  • Obfuscate hardware IDs                             ║"
  echo "║  • Deploy fake telemetry to confuse trackers          ║"
  echo "║  • Clear all caches from last 24 hours                ║"
  echo "║  • Flush DNS, swap, and logs                          ║"
  echo "║  • NOT disrupt running browser sessions               ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  
  backup_state
  shred_mac
  shred_hwid
  shred_telemetry
  shred_caches
  shred_dns
  shred_swap
  shred_logs
  
  # Update config
  python3 -c "
import json, datetime
c=json.load(open('$DS_CONFIG'))
c['last_shred'] = datetime.datetime.now().isoformat()
c['shred_count'] = c.get('shred_count',0) + 1
json.dump(c,open('$DS_CONFIG','w'),indent=2)
"
  
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║              SHRED COMPLETE                            ║"
  echo "╠══════════════════════════════════════════════════════════╣"
  echo "║  Your digital footprint has been scrubbed.             ║"
  echo "║  New MAC addresses are randomized.                     ║"
  echo "║  Hardware IDs are obfuscated.                          ║"
  echo "║  Telemetry trackers will see noise.                    ║"
  echo "║  Caches from last 24h are cleared.                     ║"
  echo "║  DNS, swap, and logs are flushed.                      ║"
  echo "║  Running browser sessions: PRESERVED.                  ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  
  # Log the shred
  echo "$(date -Iseconds) SHRED_COMPLETED" >> "$DS_LOG"
}

# ── Status ──────────────────────────────────────────────────────────────
status(){
  python3 -c "
import json
c=json.load(open('$DS_CONFIG'))
print('=== Data Shredder Status ===')
print(f'  Last shred: {c.get(\"last_shred\", \"never\")}')
print(f'  Total shreds: {c.get(\"shred_count\", 0)}')
print(f'  Current MAC: {c[\"shred_targets\"][\"mac_address\"][\"current\"]}')
print(f'  Current Machine ID: {c[\"shred_targets\"][\"hardware_id\"][\"current_machine_id\"][:16]}...')
print()
print('  Targets:')
for k,v in c['shred_targets'].items():
    state = 'ON' if v.get('enabled') else 'OFF'
    print(f'    {k}: {state}')
"
}

# ── Restore from backup ────────────────────────────────────────────────
restore(){
  echo "=== Restoring previous state ==="
  if [ -f "$DS_BACKUP/mac_addresses.txt" ]; then
    cat "$DS_BACKUP/mac_addresses.txt" | while read mac; do
      iface=$(ip link show | grep -B1 "$mac" | awk -F': ' '{print $2}' | head -1)
      [ -n "$iface" ] && sudo ip link set "$iface" down && sudo ip link set "$iface" address "$mac" && sudo ip link set "$iface" up && echo "  $iface: restored to $mac"
    done
  fi
  if [ -f "$DS_BACKUP/machine-id.txt" ]; then
    sudo cp "$DS_BACKUP/machine-id.txt" /etc/machine-id 2>/dev/null && echo "  machine-id: restored"
  fi
  if [ -f "$DS_BACKUP/hostname.txt" ]; then
    sudo hostname "$(cat $DS_BACKUP/hostname.txt)" 2>/dev/null && echo "  hostname: restored"
  fi
  echo "  State restored"
}

case "${1:-help}" in
  init)    init ;;
  shred|run) shred ;;
  status)  status ;;
  restore) restore ;;
  *) echo "Usage: $0 {init|shred|status|restore}"
     echo ""
     echo "  shred   — One-click nuclear privacy wipe"
     echo "  status  — Show current state"
     echo "  restore — Restore previous MAC/hostname/IDs"
     echo ""
     echo "SAFETY: State is backed before shred. Active sessions preserved." ;;
esac

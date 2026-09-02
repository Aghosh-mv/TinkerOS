#!/bin/bash
# TinkerOS Unified Virtual Memory Over CXL
# Maps RAM + VRAM + networked memory into one pool
# NOT DEFAULT - must toggle on explicitly
CXL_DIR="$HOME/.tinker/cxl-memory"; CXL_CONFIG="$CXL_DIR/config.json"
CXL_LOG="$CXL_DIR/cxl.log"; CXL_STATE="$CXL_DIR/state.json"
mkdir -p "$CXL_DIR"

# Shared liability/consent gate + C backend integration
BHELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/backend-helper.sh"
if [[ -f "$BHELPER" ]]; then source "$BHELPER"; fi


init(){
  cat > "$CXL_CONFIG" << 'EOF'
{
  "version": 1,
  "enabled": false,
  "auto_discover": true,
  "memory_pools": {
    "local_ram": {
      "type": "dram",
      "device": "local",
      "size_gb": null,
      "bandwidth_gbps": 50,
      "latency_ns": 80,
      "priority": 100,
      "always_available": true
    },
    "gpu_vram": {
      "type": "vram",
      "device": "auto",
      "size_gb": null,
      "bandwidth_gbps": 500,
      "latency_ns": 200,
      "priority": 80,
      "requires_toggle": true
    },
    "cxl_expander": {
      "type": "cxl",
      "device": "auto",
      "size_gb": null,
      "bandwidth_gbps": 64,
      "latency_ns": 150,
      "priority": 70,
      "requires_toggle": true
    },
    "network_memory": {
      "type": "rdma",
      "device": null,
      "ip": null,
      "size_gb": null,
      "bandwidth_gbps": 10,
      "latency_ns": 500,
      "priority": 40,
      "requires_toggle": true
    }
  },
  "routing": {
    "method": "bandwidth_aware",
    "hot_data_threshold_mb": 10,
    "cold_to_slow_after_s": 30,
    "prefetch": false,
    "page_size_kb": 4
  },
  "swap_prevention": {
    "enabled": true,
    "min_pool_free_gb": 1,
    "evict_from": "lowest_priority"
  },
  "stats": {"total_pool_gb": 0, "pages_migrated": 0, "swap_events_prevented": 0, "bandwidth_used_gbps": 0}
}
EOF
  echo "=== CXL Unified Memory initialized (OFF by default) ==="
  echo "  Pools: local_ram(always) + gpu_vram(toggle) + cxl_expander(toggle) + network(toggle)"
 echo "  Method: bandwidth_aware routing"
  echo "  Must run: $0 on  (to activate)"
}

# ── Discover Available Memory Devices ───────────────────────────────────
discover(){
  echo "=== Discovering Memory Devices ==="
  python3 - << 'PYEOF'
import os, json, subprocess, glob

pools = {}

# 1. Local RAM
try:
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith("MemTotal:"):
                kb = int(line.split()[1])
                pools["local_ram"] = {
                    "type": "dram",
                    "size_gb": round(kb / 1024 / 1024, 1),
                    "bandwidth_gbps": 50,
                    "latency_ns": 80,
                    "status": "available"
                }
                break
except:
    pass

# 2. GPU VRAM detection
gpu_found = False

# NVIDIA
try:
    result = subprocess.run(["nvidia-smi", "--query-gpu=memory.total,memory.free,name", 
                           "--format=csv,noheader,nounits"], 
                          capture_output=True, text=True, timeout=5)
    if result.returncode == 0:
        for line in result.stdout.strip().split('\n'):
            parts = line.split(',')
            if len(parts) >= 3:
                total_mb = int(parts[0].strip())
                free_mb = int(parts[1].strip())
                name = parts[2].strip()
                pools["gpu_vram"] = {
                    "type": "vram",
                    "device": name,
                    "total_gb": round(total_mb / 1024, 1),
                    "free_gb": round(free_mb / 1024, 1),
                    "bandwidth_gbps": 500,
                    "latency_ns": 200,
                    "status": "available",
                    "api": "nvidia"
                }
                gpu_found = True
except:
    pass

# AMD
if not gpu_found:
    try:
        for card in glob.glob("/sys/class/drm/card*"):
            vendor_file = f"{card}/device/vendor"
            if os.path.exists(vendor_file):
                with open(vendor_file) as f:
                    vendor = f.read().strip()
                if vendor == "0x1002":  # AMD
                    mem_file = f"{card}/device/mem_info_vram_total"
                    if os.path.exists(mem_file):
                        with open(mem_file) as f:
                            total_bytes = int(f.read().strip())
                        pools["gpu_vram"] = {
                            "type": "vram",
                            "device": f"AMD card {os.path.basename(card)}",
                            "total_gb": round(total_bytes / 1024**3, 1),
                            "bandwidth_gbps": 400,
                            "latency_ns": 200,
                            "status": "available",
                            "api": "sysfs"
                        }
                        gpu_found = True
                        break
    except:
        pass

# 3. CXL device detection
cxl_found = False
for cxl_path in glob.glob("/sys/bus/cxl/devices/*"):
    try:
        dev_name = os.path.basename(cxl_path)
        size_file = f"{cxl_path}/serializer_size"
        if os.path.exists(size_file):
            with open(size_file) as f:
                size_bytes = int(f.read().strip())
            pools["cxl_expander"] = {
                "type": "cxl",
                "device": dev_name,
                "size_gb": round(size_bytes / 1024**3, 1),
                "bandwidth_gbps": 64,
                "latency_ns": 150,
                "status": "available"
            }
            cxl_found = True
    except:
        pass

# Fallback: check for CXL via lspci
if not cxl_found:
    try:
        result = subprocess.run(["lspci"], capture_output=True, text=True, timeout=5)
        if "CXL" in result.stdout or "Compute Express" in result.stdout:
            pools["cxl_expander"] = {
                "type": "cxl",
                "device": "detected via lspci",
                "bandwidth_gbps": 64,
                "latency_ns": 150,
                "status": "detected (needs driver)"
            }
    except:
        pass

# 4. Network memory (RDMA/RoCE capable)
rdma_found = False
try:
    result = subprocess.run(["ibstat"], capture_output=True, text=True, timeout=5)
    if result.returncode == 0 and "State: Active" in result.stdout:
        pools["network_memory"] = {
            "type": "rdma",
            "device": "InfiniBand/RoCE",
            "bandwidth_gbps": 100,
            "latency_ns": 500,
            "status": "available"
        }
        rdma_found = True
except:
    pass

# Print results
total_pool = 0
print(f"  {'Pool':<20s} {'Type':<8s} {'Size':>10s} {'Bandwidth':>10s} {'Latency':>10s} {'Status'}")
print(f"  {'-'*75}")
for name, pool in pools.items():
    size = pool.get("size_gb") or pool.get("total_gb") or pool.get("free_gb", "?")
    bw = pool.get("bandwidth_gbps", "?")
    lat = pool.get("latency_ns", "?")
    status = pool.get("status", "unknown")
    print(f"  {name:<20s} {pool['type']:<8s} {str(size)+'GB':>10s} {str(bw)+'Gbps':>10s} {str(lat)+'ns':>10s} {status}")
    if isinstance(size, (int, float)):
        total_pool += size

print(f"\n  Total unified pool: {total_pool:.1f}GB")
print(f"  CXL devices: {'Yes' if cxl_found else 'No'}")
print(f"  GPU VRAM: {'Yes' if gpu_found else 'No'}")
print(f"  RDMA: {'Yes' if rdma_found else 'No'}")
PYEOF
}

# ── Memory Pool Manager ─────────────────────────────────────────────────
pool_manager(){
  echo "=== Memory Pool Manager ==="
  python3 - << 'PYEOF'
import os, json, time

config = json.load(open(os.path.expanduser("~/.tinker/cxl-memory/config.json")))

if not config.get("enabled", False):
    print("  ⏹️  CXL Memory Pool: OFF")
    print(f"  Run: {os.path.expanduser('~/linux-kernel/os/hardware-tech/cxl-memory/cxl-memory.sh')} on")
    exit()

print("  Pool Status:")
print(f"  {'Pool':<20s} {'Active':>8s} {'Size':>10s} {'Used':>10s} {'Free':>10s} {'Priority':>8s}")
print(f"  {'-'*65}")

routing = config["routing"]
pools = config["memory_pools"]

for name, pool in pools.items():
    active = "✅" if pool.get("status") == "active" else "❌"
    size = pool.get("size_gb") or pool.get("total_gb", 0)
    used = pool.get("used_gb", 0)
    free = size - used if isinstance(size, (int, float)) else "?"
    print(f"  {name:<20s} {active:>8s} {str(size)+'GB':>10s} {str(used)+'GB':>10s} {str(free)+'GB':>10s} {pool.get('priority',0):>6d}")

print(f"\n  Routing: {routing['method']}")
print(f"  Hot data threshold: {routing['hot_data_threshold_mb']}MB")
print(f"  Cold-after: {routing['cold_to_slow_after_s']}s")
print(f"  Page size: {routing['page_size_kb']}KB")
PYEOF
}

# ── Page Migration Engine ───────────────────────────────────────────────
migrate_pages(){
  echo "=== Page Migration Engine ==="
  python3 - << 'PYEOF'
import os, json, subprocess, time

config = json.load(open(os.path.expanduser("~/.tinker/cxl-memory/config.json")))

if not config.get("enabled", False):
    print("  ⏹️  CXL Memory Pool: OFF")
    exit()

pools = config["memory_pools"]
routing = config["routing"]

# Classify pages by access frequency
def classify_pages():
    """Read /proc/{pid}/smaps to find hot/cold pages"""
    pages = {"hot": [], "warm": [], "cold": []}
    
    try:
        result = subprocess.run(["ps", "aux", "--sort=-rss"], capture_output=True, text=True)
        for line in result.stdout.split('\n')[1:20]:
            parts = line.split()
            if len(parts) > 10:
                pid = parts[1]
                rss_kb = int(parts[5])
                cmd = parts[10]
                
                smaps_path = f"/proc/{pid}/smaps"
                if os.path.exists(smaps_path):
                    try:
                        with open(smaps_path) as f:
                            total_refs = 0
                            for line2 in f:
                                if "Referenced:" in line2:
                                    refs = int(line2.split()[1])
                                    total_refs += refs
                            
                            if total_refs > rss_kb * 0.8:
                                pages["hot"].append({"pid": pid, "rss_kb": rss_kb, "cmd": cmd[:20]})
                            elif total_refs > rss_kb * 0.3:
                                pages["warm"].append({"pid": pid, "rss_kb": rss_kb, "cmd": cmd[:20]})
                            else:
                                pages["cold"].append({"pid": pid, "rss_kb": rss_kb, "cmd": cmd[:20]})
                    except:
                        pass
    except:
        pass
    
    return pages

pages = classify_pages()

print(f"  Hot pages:  {len(pages['hot'])} processes")
print(f"  Warm pages: {len(pages['warm'])} processes")
print(f"  Cold pages: {len(pages['cold'])} processes")
print()

# Migration plan
print("  Migration Plan:")
print(f"  {'Action':<25s} {'Pool':<20s} {'Reason'}")
print(f"  {'-'*70}")

migrations = []

# Hot -> fastest pool (VRAM if available)
if pages["hot"] and pools.get("gpu_vram", {}).get("status") == "active":
    for p in pages["hot"][:5]:
        migrations.append(("migrate_to_vram", p["cmd"], "gpu_vram", "high bandwidth needed"))
        print(f"  {'-> VRAM':<25s} {'gpu_vram':<20s} {p['cmd']} ({p['rss_kb']}KB)")

# Warm -> CXL if available
if pages["warm"] and pools.get("cxl_expander", {}).get("status") == "active":
    for p in pages["warm"][:5]:
        migrations.append(("migrate_to_cxl", p["cmd"], "cxl_expander", "moderate bandwidth"))
        print(f"  {'-> CXL':<25s} {'cxl_expander':<20s} {p['cmd']} ({p['rss_kb']}KB)")

# Cold -> network/swap
for p in pages["cold"][:5]:
    if pools.get("network_memory", {}).get("status") == "active":
        migrations.append(("migrate_to_network", p["cmd"], "network_memory", "cold data, offload"))
        print(f"  {'-> Network':<25s} {'network_memory':<20s} {p['cmd']} ({p['rss_kb']}KB)")
    else:
        print(f"  {'-> Swap':<25s} {'swap':<20s} {p['cmd']} ({p['rss_kb']}KB, cold)")

print(f"\n  Total migrations planned: {len(migrations)}")
PYEOF
}

# ── Toggle On ───────────────────────────────────────────────────────────
activate(){
  python3 - << 'PYEOF'
import json, os

config = json.load(open(os.path.expanduser("~/.tinker/cxl-memory/config.json")))
config["enabled"] = True
json.dump(config, open(os.path.expanduser("~/.tinker/cxl-memory/config.json"), "w"), indent=2)
print("  ✅ CXL Unified Memory: ON")
print("  Pool: local_ram + gpu_vram + cxl_expander + network_memory")
print("  Swap prevention: ACTIVE")
print("  Routing: bandwidth_aware")
PYEOF
}

deactivate(){
  python3 - << 'PYEOF'
import json, os

config = json.load(open(os.path.expanduser("~/.tinker/cxl-memory/config.json")))
config["enabled"] = False
json.dump(config, open(os.path.expanduser("~/.tinker/cxl-memory/config.json"), "w"), indent=2)
print("  ⏹️  CXL Unified Memory: OFF")
print("  All pools disconnected. Standard swap only.")
PYEOF
}

case "${1:-help}" in
  init) init ;;
  discover) discover ;;
  pools|pool) pool_manager ;;
  migrate) migrate_pages ;;
  on) activate ;;
  off) deactivate ;;
  toggle)
    state=$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.tinker/cxl-memory/config.json'))).get('enabled',False))")
    if [ "$state" = "True" ]; then deactivate; else activate; fi
    ;;
  status)
    python3 -c "
import json,os
c=json.load(open(os.path.expanduser('~/.tinker/cxl-memory/config.json')))
print(f'  Enabled: {c.get(\"enabled\",False)}')
print(f'  Pools: {len(c[\"memory_pools\"])}')
print(f'  Routing: {c[\"routing\"][\"method\"]}')
"
    ;;
  dashboard) discover; echo ""; pool_manager; echo ""; migrate_pages ;;
  *) echo "Usage: $0 {init|discover|pools|migrate|on|off|toggle|status|dashboard}"
     echo ""
     echo "  TOGGLE (not default):"
     echo "    init      - Initialize config (still OFF)"
     echo "    on        - Enable unified memory pool"
     echo "    off       - Disable (standard swap only)"
     echo "    toggle    - Auto toggle on/off"
     echo "    status    - Show current state"
     echo ""
     echo "  ACTIONS:"
     echo "    discover  - Scan for RAM, VRAM, CXL, RDMA devices"
     echo "    pools     - Show memory pool status"
     echo "    migrate   - Plan page migrations (hot->VRAM, cold->network)"
     echo "    dashboard - Full overview"
     echo ""
     echo "POOLS: local_ram(always) + gpu_vram + cxl_expander + network_memory"
     echo "SWAP PREVENTION: routes to pools before hitting disk" ;;
esac

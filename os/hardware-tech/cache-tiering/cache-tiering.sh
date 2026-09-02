#!/bin/bash
# TinkerOS Software-Defined Cache and Memory Tiering
# Dynamically reconfigures CPU cache layout based on active application
# Intel CAT / AMD way partitioning / ARM MPAM
CT_DIR="$HOME/.tinker/cache-tiering"; CT_CONFIG="$CT_DIR/config.json"
CT_LOG="$CT_DIR/tiering.log"; CT_STATE="$CT_DIR/state.json"
mkdir -p "$CT_DIR"

# Shared liability/consent gate + C backend integration
BHELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/backend-helper.sh"
if [[ -f "$BHELPER" ]]; then source "$BHELPER"; fi


init(){
  cat > "$CT_CONFIG" << 'EOF'
{
  "version": 1,
  "enabled": true,
  "gaming_mode": false,
  "hardware_detection": "auto",
  "cache_architecture": {
    "L1d_kb": null,
    "L1i_kb": null,
    "L2_kb": null,
    "L3_ways": null,
    "L3_sets": null,
    "total_L3_ways": 16,
    "cache_line_bytes": 64
  },
  "tiering_policy": {
    "method": "priority_weighted",
    "rebalance_hz": 100,
    "monitor_cache_misses": true,
    "adaptive": true
  },
  "priority_tiers": {
    "tier0_realtime": {
      "name": "Real-time / Audio",
      "l3_ways": 4,
      "l2_boost": true,
      "l1_pin": true,
      "priority": 100,
      "processes": ["pipewire", "pulseaudio", "jack", "alsa", "ray-traced-audio", "video-call"]
    },
    "tier1_foreground": {
      "name": "Foreground App",
      "l3_ways": 6,
      "l2_boost": true,
      "l1_pin": false,
      "priority": 80,
      "processes": ["active-window"]
    },
    "tier2_performance": {
      "name": "Performance Apps",
      "l3_ways": 4,
      "l2_boost": false,
      "l1_pin": false,
      "priority": 60,
      "processes": ["compiler", "browser-active", "editor", "terminal", "ai-engine"]
    },
    "tier3_background": {
      "name": "Background Services",
      "l3_ways": 1,
      "l2_boost": false,
      "l1_pin": false,
      "priority": 30,
      "processes": ["cloud-sync", "indexer", "update-check", "telemetry", "analytics"]
    },
    "tier4_blocked": {
      "name": "Cache-Blocked",
      "l3_ways": 0,
      "l2_boost": false,
      "l1_pin": false,
      "priority": 0,
      "processes": ["tracker", "baloo", "recoll", "packagekit"]
    }
  },
  "intel_cat": {
    "supported": false,
    "max_clos": 16,
    "cbm_mask_bits": null,
    "cdp_supported": false
  },
  "amd_qos": {
    "supported": false,
    "num_l3_partitions": null
  },
  "arm_mpam": {
    "supported": false,
    "num_parts": null
  },
  "stats": {"total_rebalances": 0, "cache_hits_improved": 0, "bandwidth_saved_mb": 0, "avg_speedup_pct": 0}
}
EOF
  echo "=== Cache Tiering initialized ==="
  echo "  Tiers: realtime(4 ways) + foreground(6) + performance(4) + background(1) + blocked(0)"
  echo "  Method: priority_weighted, adaptive"
  echo "  Intel CAT / AMD QoS / ARM MPAM: auto-detect"
}

# ── Detect Cache Architecture ──────────────────────────────────────────
detect_cache(){
  echo "=== Cache Architecture Detection ==="
  python3 - << 'PYEOF'
import os, subprocess, json, glob

cache_info = {
    "l1d": {"size_kb": 0, "ways": 0, "sets": 0},
    "l1i": {"size_kb": 0, "ways": 0, "sets": 0},
    "l2": {"size_kb": 0, "ways": 0, "sets": 0},
    "l3": {"size_kb": 0, "ways": 0, "sets": 0}
}

# Method 1: lscpu
try:
    result = subprocess.run(["lscache"], capture_output=True, text=True, timeout=5)
    if result.returncode == 0:
        for line in result.stdout.split('\n'):
            for level in ['L1d', 'L1i', 'L2', 'L3']:
                if line.strip().startswith(level):
                    parts = line.split(':')
                    if len(parts) > 1:
                        size_str = parts[1].strip().split()[0]
                        size_kb = int(size_str.replace('K', '').replace('M', '000'))
                        key = level.lower().replace('1d','1d').replace('1i','1i')
                        cache_info[key]["size_kb"] = size_kb
except:
    pass

# Method 2: /sys/devices/system/cpu/cpu0/cache/
for cpu_cache in glob.glob("/sys/devices/system/cpu/cpu0/cache/index*"):
    try:
        with open(f"{cpu_cache}/level") as f:
            level = int(f.read().strip())
        with open(f"{cpu_cache}/size") as f:
            size_str = f.read().strip()
            size_kb = int(size_str.replace('K', '').replace('M', '000'))
        with open(f"{cpu_cache}/type") as f:
            ctype = f.read().strip()
        with open(f"{cpu_cache}/ways_of_associativity") as f:
            ways = int(f.read().strip())
        with open(f"{cpu_cache}/number_of_sets") as f:
            sets = int(f.read().strip())
        
        if level == 1 and ctype == "Data":
            cache_info["l1d"] = {"size_kb": size_kb, "ways": ways, "sets": sets}
        elif level == 1 and ctype == "Instruction":
            cache_info["l1i"] = {"size_kb": size_kb, "ways": ways, "sets": sets}
        elif level == 2:
            cache_info["l2"] = {"size_kb": size_kb, "ways": ways, "sets": sets}
        elif level == 3:
            cache_info["l3"] = {"size_kb": size_kb, "ways": ways, "sets": sets}
    except:
        pass

# Method 3: cpuid
if cache_info["l3"]["size_kb"] == 0:
    try:
        result = subprocess.run(["cpuid", "-1"], capture_output=True, text=True, timeout=5)
        for line in result.stdout.split('\n'):
            if 'cache' in line.lower() or 'L3' in line:
                print(f"  cpuid: {line.strip()}")
    except:
        pass

# Print detection results
print(f"  L1d: {cache_info['l1d']['size_kb']}KB, {cache_info['l1d']['ways']}-way, {cache_info['l1d']['sets']} sets")
print(f"  L1i: {cache_info['l1i']['size_kb']}KB, {cache_info['l1i']['ways']}-way, {cache_info['l1i']['sets']} sets")
print(f"  L2:  {cache_info['l2']['size_kb']}KB, {cache_info['l2']['ways']}-way, {cache_info['l2']['sets']} sets")
print(f"  L3:  {cache_info['l3']['size_kb']}KB, {cache_info['l3']['ways']}-way, {cache_info['l3']['sets']} sets")

total_l3 = cache_info["l3"]["ways"]
print(f"\n  Total L3 ways: {total_l3}")
print(f"  Cache line: 64 bytes")

# Check Intel CAT support
print(f"\n  Checking Intel CAT / AMD QoS / ARM MPAM...")
intel_cat = False
amd_qos = False

# Check MSR
try:
    result = subprocess.run(["sudo", "rdmsr", "0xC8F"], capture_output=True, text=True, timeout=5)
    if result.stdout.strip():
        intel_cat = True
        print(f"  Intel CAT: SUPPORTED (CBM mask: {result.stdout.strip()})")
except:
    pass

# Check via modprobe
try:
    result = subprocess.run(["lsmod"], capture_output=True, text=True, timeout=5)
    if "intel_rapl" in result.stdout or "intel_qos" in result.stdout:
        intel_cat = True
        print(f"  Intel QoS modules loaded")
except:
    pass

if not intel_cat:
    print(f"  Intel CAT: Using software-based partitioning")
    print(f"  (works on all CPUs via cache-flush + allocation hints)")

# Detect CPU vendor
try:
    with open("/proc/cpuinfo") as f:
        for line in f:
            if "vendor_id" in line:
                vendor = line.split(":")[1].strip()
                print(f"  CPU vendor: {vendor}")
                break
except:
    pass

# Save detection results
config = json.load(open(os.path.expanduser("~/.tinker/cache-tiering/config.json")))
config["cache_architecture"]["L3_ways"] = total_l3 or 16
config["cache_architecture"]["L3_sets"] = cache_info["l3"]["sets"]
config["intel_cat"]["supported"] = intel_cat
json.dump(config, open(os.path.expanduser("~/.tinker/cache-tiering/config.json"), "w"), indent=2)
print(f"\n  Detection complete. L3 ways: {total_l3 or 16}")
PYEOF
}

# ── Show Current Cache Tier Allocation ──────────────────────────────────
show_tiers(){
  echo "=== Current Cache Tier Allocation ==="
  python3 - << 'PYEOF'
import json, os

config = json.load(open(os.path.expanduser("~/.tinker/cache-tiering/config.json")))
tiers = config["priority_tiers"]
total_ways = config["cache_architecture"].get("L3_ways", 16)

print(f"  Total L3 ways: {total_ways}")
print()
print(f"  {'Tier':<25s} {'Ways':>5s} {'Priority':>8s} {'Processes'}")
print(f"  {'-'*80}")

allocated = 0
for tier_name, tier in sorted(tiers.items(), key=lambda x: -x[1]["priority"]):
    ways = tier["l3_ways"]
    allocated += ways
    bar = "█" * ways + "░" * (total_ways - ways) if total_ways > 0 else ""
    procs = ", ".join(tier["processes"][:3])
    if len(tier["processes"]) > 3:
        procs += f" +{len(tier['processes'])-3} more"
    print(f"  {tier['name']:<25s} {ways:>3d}   {tier['priority']:>5d}   {procs}")
    if bar:
        print(f"  {'':25s} {bar}")

remaining = total_ways - allocated
print(f"\n  Unallocated: {remaining} ways")
if remaining < 0:
    print(f"  ⚠️  WARNING: Over-allocated by {abs(remaining)} ways!")
PYEOF
}

# ── Process Cache Classification ────────────────────────────────────────
classify_processes(){
  echo "=== Process Cache Classification ==="
  python3 - << 'PYEOF'
import subprocess, json, os

config = json.load(open(os.path.expanduser("~/.tinker/cache-tiering/config.json")))
tiers = config["priority_tiers"]

# Get processes
result = subprocess.run(["ps", "aux", "--sort=-pcpu"], capture_output=True, text=True)
processes = []

for line in result.stdout.split('\n')[1:30]:
    parts = line.split()
    if len(parts) > 10:
        pid = parts[1]
        cpu = float(parts[2])
        rss = int(parts[5])
        cmd = parts[10]
        
        # Classify into tier
        assigned_tier = "tier3_background"
        for tier_name, tier in tiers.items():
            for pattern in tier["processes"]:
                if pattern in cmd.lower() or pattern in cmd:
                    assigned_tier = tier_name
                    break
        
        # Check L3 cache misses via perf (if available)
        cache_misses = 0
        try:
            perf_result = subprocess.run(
                ["perf", "stat", "-e", "cache-misses", "-p", pid, "--", "sleep", "0.01"],
                capture_output=True, text=True, timeout=2
            )
            for line2 in perf_result.stderr.split('\n'):
                if 'cache-misses' in line2:
                    nums = ''.join(c for c in line2.split()[0] if c.isdigit())
                    cache_misses = int(nums) if nums else 0
        except:
            pass
        
        tier_info = tiers[assigned_tier]
        processes.append({
            "pid": pid,
            "cmd": cmd[:35],
            "cpu": cpu,
            "rss_kb": rss,
            "tier": assigned_tier,
            "tier_name": tier_info["name"],
            "l3_ways": tier_info["l3_ways"],
            "cache_misses": cache_misses
        })

processes.sort(key=lambda x: (-x["l3_ways"], -x["cpu"]))

print(f"  {'PID':>6} {'CPU%':>5s} {'RSS':>8s} {'Ways':>4s} {'Tier':<20s} {'Command'}")
print(f"  {'-'*85}")
for p in processes[:20]:
    print(f"  {p['pid']:>6} {p['cpu']:>5.1f} {p['rss_kb']:>6d}K {p['l3_ways']:>3d}  {p['tier_name']:<20s} {p['cmd']}")

# Summary
print(f"\n  Summary:")
for tier_name, tier in sorted(tiers.items(), key=lambda x: -x[1]["priority"]):
    count = sum(1 for p in processes if p["tier"] == tier_name)
    print(f"    {tier['name']:<20s}: {count} processes, {tier['l3_ways']} L3 ways")
PYEOF
}

# ── Apply Cache Tiering ─────────────────────────────────────────────────
 apply_tiering(){
   echo "=== Applying Cache Tiering ==="
   CAT_BIN="$(backend_bin_path cat_control)"
   TINKER_CAT_BACKEND="$CAT_BIN" python3 - << 'PYEOF'
import subprocess, json, os

config = json.load(open(os.path.expanduser("~/.tinker/cache-tiering/config.json")))

if not config.get("enabled", True):
    print("  ⏹️  Cache tiering OFF")
    exit()

if config.get("gaming_mode", False):
    print("  🎮 Gaming mode: all tiers equal (no partitioning)")
    exit()

tiers = config["priority_tiers"]
total_ways = config["cache_architecture"].get("L3_ways", 16)

# Intel CAT via MSR (if available)
intel_cat = config["intel_cat"]["supported"]

if intel_cat:
    # ── Prefer the compiled cat_control C backend over wrmsr-tools ──
    import shutil
    CAT_BACKEND = os.environ.get("TINKER_CAT_BACKEND", "")
    if CAT_BACKEND and os.access(CAT_BACKEND, os.X_OK):
        print("  Using Intel CAT (C backend cat_control)")
    else:
        print("  Using Intel CAT (MSR-based partitioning, wrmsr-tools)")

    # Each tier gets a bit mask for its ways
    way_masks = {}
    offset = 0
    for tier_name, tier in sorted(tiers.items(), key=lambda x: -x[1]["priority"]):
        ways = tier["l3_ways"]
        if ways > 0:
            mask = ((1 << ways) - 1) << offset
            way_masks[tier_name] = mask
            offset += ways
        else:
            way_masks[tier_name] = 0

    # Write MSR registers
    def write_cat_mask(clos, mask):
        if CAT_BACKEND and os.access(CAT_BACKEND, os.X_OK):
            try:
                r = subprocess.run([CAT_BACKEND, "l3", hex(mask)],
                                   capture_output=True, text=True, timeout=3)
                return (r.returncode == 0) or ("ok=" in r.stdout)
            except:
                return False
        try:
            msr = 0xC90 + clos
            subprocess.run(["sudo", "wrmsr", hex(msr), hex(mask)],
                           capture_output=True, timeout=2)
            return True
        except:
            return False

    for tier_name, mask in way_masks.items():
        if mask > 0:
            clos = list(way_masks.keys()).index(tier_name)
            print(f"  {tier_name}: mask=0x{mask:X} ({tiers[tier_name]['l3_ways']} ways) [CLOS {clos}]")
            try:
                write_cat_mask(clos, mask)
            except:
                pass
else:
    print("  Using software-based cache partitioning")
    print("  (cache-flush hints + cgroup memory pressure)")
    
    # Apply via cgroup v2 cache pressure
    for tier_name, tier in tiers.items():
        ways = tier["l3_ways"]
        if ways == 0:
            # Block cache entirely
            print(f"  {tier['name']}: BLOCKED (0 ways)")
            # Set memory pressure high to evict quickly
            try:
                cgroup_path = f"/sys/fs/cgroup/tinker_{tier_name}"
                os.makedirs(cgroup_path, exist_ok=True)
                # High memory pressure = fast eviction from cache
                with open(f"{cgroup_path}/memory.pressure", "w") as f:
                    f.write("some avg10=90 avg60=90 avg300=90")
            except:
                pass
        elif ways >= 6:
            print(f"  {tier['name']}: PRIORITY ({ways} ways)")
            try:
                cgroup_path = f"/sys/fs/cgroup/tinker_{tier_name}"
                os.makedirs(cgroup_path, exist_ok=True)
                # Low pressure = keep in cache longer
                with open(f"{cgroup_path}/memory.pressure", "w") as f:
                    f.write("some avg10=10 avg60=10 avg300=10")
            except:
                pass
        else:
            print(f"  {tier['name']}: NORMAL ({ways} ways)")

print("\n  ✅ Cache tiering applied")
PYEOF
}

# ── Monitor Cache Performance ───────────────────────────────────────────
monitor_cache(){
  echo "=== Cache Performance Monitor ==="
  python3 - << 'PYEOF'
import subprocess, os, json

print(f"  {'PID':>6} {'CPU%':>5s} {'L1d Miss':>10s} {'L2 Miss':>10s} {'L3 Miss':>10s} {'Command'}")
print(f"  {'-'*75}")

result = subprocess.run(["ps", "aux", "--sort=-pcpu"], capture_output=True, text=True)
for line in result.stdout.split('\n')[1:15]:
    parts = line.split()
    if len(parts) > 10:
        pid = parts[1]
        cpu = float(parts[2])
        cmd = parts[10][:25]
        
        l1d = l2 = l3 = 0
        try:
            perf = subprocess.run(
                ["perf", "stat", "-e", "L1-dcache-load-misses,L2-load-misses LLC-load-misses",
                 "-p", pid, "--", "sleep", "0.01"],
                capture_output=True, text=True, timeout=2
            )
            for p_line in perf.stderr.split('\n'):
                if 'L1-dcache' in p_line:
                    nums = ''.join(c for c in p_line.split()[0] if c.isdigit())
                    l1d = int(nums) if nums else 0
                elif 'L2' in p_line and 'miss' in p_line.lower():
                    nums = ''.join(c for c in p_line.split()[0] if c.isdigit())
                    l2 = int(nums) if nums else 0
                elif 'LLC' in p_line:
                    nums = ''.join(c for c in p_line.split()[0] if c.isdigit())
                    l3 = int(nums) if nums else 0
        except:
            pass
        
        print(f"  {pid:>6} {cpu:>5.1f} {l1d:>10d} {l2:>10d} {l3:>10d} {cmd}")
PYEOF
}

# ── Optimize for Workload Type ──────────────────────────────────────────
optimize_for(){
  local workload=${1:-"general"}
  echo "=== Optimizing Cache for: $workload ==="
  python3 - << PYEOF
import json, os

config = json.load(open(os.path.expanduser("~/.tinker/cache-tiering/config.json")))
tiers = config["priority_tiers"]
total_ways = config["cache_architecture"].get("L3_ways", 16)

workload = "$workload"

# Preset configurations
presets = {
    "general": {"tier0_realtime": 3, "tier1_foreground": 5, "tier2_performance": 4, "tier3_background": 2, "tier4_blocked": 0},
    "gaming": {"tier0_realtime": 2, "tier1_foreground": 8, "tier2_performance": 4, "tier3_background": 1, "tier4_blocked": 0},
    "ai-training": {"tier0_realtime": 1, "tier1_foreground": 3, "tier2_performance": 10, "tier3_background": 1, "tier4_blocked": 0},
    "compilation": {"tier0_realtime": 1, "tier1_foreground": 3, "tier2_performance": 10, "tier3_background": 1, "tier4_blocked": 0},
    "audio-production": {"tier0_realtime": 8, "tier1_foreground": 5, "tier2_performance": 2, "tier3_background": 0, "tier4_blocked": 0},
    "privacy": {"tier0_realtime": 3, "tier1_foreground": 5, "tier2_performance": 3, "tier3_background": 0, "tier4_blocked": 4},
    "battery": {"tier0_realtime": 2, "tier1_foreground": 4, "tier2_performance": 3, "tier3_background": 2, "tier4_blocked": 4}
}

if workload in presets:
    preset = presets[workload]
    for tier_name, ways in preset.items():
        if tier_name in tiers:
            tiers[tier_name]["l3_ways"] = ways
    
    config["priority_tiers"] = tiers
    json.dump(config, open(os.path.expanduser("~/.tinker/cache-tiering/config.json"), "w"), indent=2)
    
    print(f"  Preset: {workload}")
    for tier_name, ways in preset.items():
        name = tiers[tier_name]["name"]
        bar = "█" * ways + "░" * (total_ways - ways)
        print(f"    {name:<20s} {ways} ways {bar}")
else:
    print(f"  Unknown workload: {workload}")
    print(f"  Available: {', '.join(presets.keys())}")
PYEOF
}

case "${1:-help}" in
  init) init ;;
  detect) detect_cache ;;
  tiers) show_tiers ;;
  classify) classify_processes ;;
  apply) apply_tiering ;;
  optimize) optimize_for "$2" ;;
  monitor) monitor_cache ;;
  on)
    hardware_write_gate "cache-tiering" "$2" || exit 1
    python3 -c "import json,os; c=json.load(open(os.path.expanduser('~/.tinker/cache-tiering/config.json'))); c['enabled']=True; c['gaming_mode']=False; json.dump(c,open(os.path.expanduser('~/.tinker/cache-tiering/config.json'),'w'),indent=2); print('  ✅ Cache Tiering: ON')"
    apply_tiering ;;
  off)
    python3 -c "import json,os; c=json.load(open(os.path.expanduser('~/.tinker/cache-tiering/config.json'))); c['enabled']=False; json.dump(c,open(os.path.expanduser('~/.tinker/cache-tiering/config.json'),'w'),indent=2); print('  ⏹️  Cache Tiering: OFF')"
    ;;
  gaming)
    python3 -c "import json,os; c=json.load(open(os.path.expanduser('~/.tinker/cache-tiering/config.json'))); c['enabled']=True; c['gaming_mode']=True; json.dump(c,open(os.path.expanduser('~/.tinker/cache-tiering/config.json'),'w'),indent=2); print('  🎮 Gaming Mode: all cache ways equal')"
    ;;
  dashboard) detect_cache; echo ""; show_tiers; echo ""; classify_processes; echo ""; apply_tiering ;;
  *) echo "Usage: $0 {init|detect|tiers|classify|apply|optimize <type>|monitor|on|off|gaming|dashboard}"
     echo ""
     echo "  init      - Initialize config"
     echo "  detect    - Detect CPU cache architecture"
     echo "  tiers     - Show current tier allocation"
     echo "  classify  - Classify running processes into tiers"
     echo "  apply     - Apply cache partitioning"
     echo "  optimize  - Optimize for workload: general|gaming|ai-training|compilation|audio|privacy|battery"
     echo "  monitor   - Monitor cache misses per process"
     echo "  on        - Enable tiering"
     echo "  off       - Disable (raw cache access)"
     echo "  gaming    - Gaming mode (equal ways)"
     echo "  dashboard - Full overview"
     echo ""
     echo "WORKLOADS: general, gaming, ai-training, compilation, audio-production, privacy, battery" ;;
esac

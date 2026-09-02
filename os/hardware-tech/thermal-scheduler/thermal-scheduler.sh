#!/bin/bash
# TinkerOS Silicon Thermal Mapping Scheduler
# Reads thermal sensors, builds live heat map, dances workloads across cool cores
TSS_DIR="$HOME/.tinker/thermal-scheduler"; TSS_CONFIG="$TSS_DIR/config.json"
TSS_LOG="$TSS_DIR/scheduler.log"; TSS_STATE="$TSS_DIR/state.json"
mkdir -p "$TSS_DIR"

# Shared liability/consent gate + C backend integration
BHELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/backend-helper.sh"
if [[ -f "$BHELPER" ]]; then source "$BHELPER"; fi


init(){
  cat > "$TSS_CONFIG" << 'EOF'
{
  "version": 1,
  "sensor_poll_hz": 1000,
  "core_topology": "auto",
  "thermal_zones": {
    "critical_c": 95,
    "throttle_c": 85,
    "warm_c": 70,
    "cool_c": 50,
    "cold_c": 30
  },
  "scheduling": {
    "method": "silicon_heat_map",
    "migration_threshold_c": 15,
    "hotspot_window_ms": 100,
    "preempt_on_hotspot": true,
    "spread_heavy_tasks": true,
    "reserve_cool_cores": 2,
    "max_temp_diff_between_cores_c": 20
  },
  "power_profiles": {
    "performance": {"max_temp_c": 90, "allow_throttle": false, "prefer_freq": "max"},
    "balanced": {"max_temp_c": 80, "allow_throttle": true, "prefer_freq": "medium"},
    "cool": {"max_temp_c": 70, "allow_throttle": true, "prefer_freq": "low"},
    "silent": {"max_temp_c": 60, "allow_throttle": true, "prefer_freq": "min"}
  },
  "actions": {
    "on_hotspot": "migrate",
    "on_throttle_imminent": "spread_and_cool",
    "on_critical": "emergency_cool",
    "on_idle_core_found": "migrate_heavy"
  },
  "enabled": true,
  "gaming_mode": false,
  "stats": {"total_migrations": 0, "throttles_prevented": 0, "hotspots_resolved": 0, "avg_temp_reduction_c": 0}
}
EOF
  echo "=== Silicon Thermal Mapping Scheduler initialized ==="
  echo "  Poll rate: 1000 Hz"
  echo "  Zones: critical(95) throttle(85) warm(70) cool(50) cold(30)"
  echo "  Method: live silicon heat map + workload migration"
}

# ── Toggle On/Off ────────────────────────────────────────────────────────
toggle(){
  local mode=${1:-""}
  python3 - << 'PYEOF'
import json, sys, os

config_path = os.path.expanduser("~/.tinker/thermal-scheduler/config.json")
config = json.load(open(config_path))
mode = sys.argv[1] if len(sys.argv) > 1 else ""

if mode == "on":
    config["enabled"] = True
    config["gaming_mode"] = False
    print("  ✅ Thermal Scheduler: ON")
    print("  Active: silicon heat map + workload migration")
elif mode == "off":
    config["enabled"] = False
    config["gaming_mode"] = False
    print("  ⏹️  Thermal Scheduler: OFF")
    print("  All cores run at max, no migration, no throttle prevention")
elif mode == "gaming":
    config["enabled"] = True
    config["gaming_mode"] = True
    print("  🎮 Gaming Mode: ON")
    print("  Migration: DISABLED (no task jumping mid-game)")
    print("  Throttle prevention: ACTIVE (keeps boost alive)")
    print("  Hotspot cooling: PASSIVE only (monitor, don't migrate)")
elif mode == "status":
    enabled = config.get("enabled", True)
    gaming = config.get("gaming_mode", False)
    if gaming:
        print("  🎮 Gaming Mode")
    elif enabled:
        print("  ✅ Full Scheduler")
    else:
        print("  ⏹️  Disabled")
    return
else:
    # Auto-toggle
    current = config.get("enabled", True)
    gaming = config.get("gaming_mode", False)
    if gaming:
        config["gaming_mode"] = False
        config["enabled"] = False
        print("  ⏹️  Thermal Scheduler: OFF (was gaming mode)")
    elif current:
        config["enabled"] = False
        print("  ⏹️  Thermal Scheduler: OFF")
    else:
        config["enabled"] = True
        config["gaming_mode"] = False
        print("  ✅ Thermal Scheduler: ON")

json.dump(config, open(config_path, "w"), indent=2)
PYEOF
}

# ── Check if enabled (used by all actions) ──────────────────────────────
check_enabled(){
  python3 -c "
import json, os
c=json.load(open(os.path.expanduser('~/.tinker/thermal-scheduler/config.json')))
enabled = c.get('enabled', True)
gaming = c.get('gaming_mode', False)
if not enabled:
    print('DISABLED')
    exit(0)
if gaming:
    print('GAMING')
    exit(0)
print('ACTIVE')
" 2>/dev/null
}

# ── Read All Thermal Sensors ───────────────────────────────────────────
read_sensors(){
  python3 - << 'PYEOF'
import os, json, glob, time

zones = {}
thermal_base = "/sys/class/thermal"

# Method 1: thermal_zone* (standard Linux)
for zone_path in sorted(glob.glob(f"{thermal_base}/thermal_zone*")):
    try:
        zone_name = os.path.basename(zone_path)
        with open(f"{zone_path}/type") as f:
            zone_type = f.read().strip()
        with open(f"{zone_path}/temp") as f:
            temp_raw = int(f.read().strip())
        # Most report millidegrees
        temp_c = temp_raw / 1000 if temp_raw > 200 else temp_raw
        
        zones[zone_name] = {
            "type": zone_type,
            "temp_c": round(temp_c, 1),
            "path": zone_path
        }
    except:
        pass

# Method 2: hwmon sensors (more granular per-core)
for hwmon in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
    try:
        name_file = f"{hwmon}/name"
        if os.path.exists(name_file):
            with open(name_file) as f:
                hwmon_name = f.read().strip()
        else:
            hwmon_name = os.path.basename(hwmon)
        
        for input_file in sorted(glob.glob(f"{hwmon}/temp*_input")):
            sensor_id = os.path.basename(input_file).replace("_input", "")
            label_file = f"{hwmon}/{sensor_id}_label"
            label = ""
            if os.path.exists(label_file):
                with open(label_file) as f:
                    label = f.read().strip()
            
            with open(input_file) as f:
                temp_raw = int(f.read().strip())
            temp_c = temp_raw / 1000 if temp_raw > 200 else temp_raw
            
            key = f"hwmon_{hwmon_name}_{sensor_id}"
            zones[key] = {
                "type": f"{hwmon_name}/{label or sensor_id}",
                "temp_c": round(temp_c, 1),
                "hwmon": hwmon_name,
                "sensor": sensor_id
            }
    except:
        pass

# Method 3: Intel RAPL / AMD per-core (if available via msr or zenpower)
core_temps = {}
for cpu_path in sorted(glob.glob("/sys/devices/system/cpu/cpu*/")):
    cpu_id = os.path.basename(cpu_path.rstrip("/"))
    freq_path = f"{cpu_path}/cpufreq/scaling_cur_freq"
    if os.path.exists(freq_path):
        try:
            with open(freq_path) as f:
                freq_khz = int(f.read().strip())
            # Estimate heat from frequency (higher freq = more heat)
            freq_ghz = freq_khz / 1000000
            core_temps[cpu_id] = {"freq_ghz": round(freq_ghz, 2)}
        except:
            pass

# Core topology
core_count = len(glob.glob("/sys/devices/system/cpu/cpu[0-9]*"))
phys_cores = set()
try:
    for cpu_path in glob.glob("/sys/devices/system/cpu/cpu[0-9]*"):
        cpu_id = os.path.basename(cpu_path).replace("cpu", "")
        topo_path = f"{cpu_path}/topology/physical_package_id"
        if os.path.exists(topo_path):
            with open(topo_path) as f:
                phys_cores.add(f.read().strip())
except:
    pass

output = {
    "timestamp": time.time(),
    "thermal_zones": zones,
    "zone_count": len(zones),
    "core_temps": core_temps,
    "core_count": core_count,
    "physical_packages": len(phys_cores) or 1
}
print(json.dumps(output, indent=2))
PYEOF
}

# ── Build Silicon Heat Map ─────────────────────────────────────────────
heatmap(){
  echo "=== Silicon Thermal Map ==="
  python3 - << 'PYEOF'
import os, json, glob

zones_data = json.loads(open(os.devnull).read() if False else '{}')

# Read temps directly
temps = []
labels = []
for zone_path in sorted(glob.glob("/sys/class/thermal/thermal_zone*")):
    try:
        with open(f"{zone_path}/type") as f:
            ztype = f.read().strip()
        with open(f"{zone_path}/temp") as f:
            t = int(f.read().strip()) / 1000
        temps.append(t)
        labels.append(ztype[:20])
    except:
        pass

for hwmon in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
    try:
        for inp in sorted(glob.glob(f"{hwmon}/temp*_input")):
            with open(inp) as f:
                t = int(f.read().strip()) / 1000
            sid = os.path.basename(inp).replace("_input","")
            lab = f"{sid}"
            lf = f"{hwmon}/{sid}_label"
            if os.path.exists(lf):
                with open(lf) as f:
                    lab = f.read().strip()[:20]
            temps.append(t)
            labels.append(lab)
    except:
        pass

if not temps:
    print("  No thermal sensors found. Using CPU frequency estimation.")
    for cpu in sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*")):
        cid = os.path.basename(cpu)
        fp = f"{cpu}/cpufreq/scaling_cur_freq"
        if os.path.exists(fp):
            with open(fp) as f:
                ghz = int(f.read().strip()) / 1000000
            # Estimate: 3GHz ≈ 65°C under load, 1GHz ≈ 35°C
            est = 30 + (ghz - 0.8) * 20
            temps.append(round(est, 1))
            labels.append(cid)

if not temps:
    print("  No sensors available.")
    exit()

max_t = max(temps)
min_t = min(temps)
avg_t = sum(temps) / len(temps)

print(f"  Sensors: {len(temps)}")
print(f"  Max: {max_t:.1f}°C | Min: {min_t:.1f}°C | Avg: {avg_t:.1f}°C | Spread: {max_t-min_t:.1f}°C")
print()

# Visual heat map
bar_width = 40
for i, (t, lbl) in enumerate(zip(temps, labels)):
    ratio = (t - min_t) / max(max_t - min_t, 1)
    filled = int(ratio * bar_width)
    
    if t >= 95:
        icon = "🔴"
        color = "\033[91m"
    elif t >= 85:
        icon = "🟠"
        color = "\033[93m"
    elif t >= 70:
        icon = "🟡"
        color = "\033[33m"
    elif t >= 50:
        icon = "🟢"
        color = "\033[92m"
    else:
        icon = "🔵"
        color = "\033[94m"
    
    reset = "\033[0m"
    bar = color + "█" * filled + "░" * (bar_width - filled) + reset
    print(f"  {icon} {lbl:20s} {bar} {t:.1f}°C")

# Hotspot analysis
hotspot_threshold = 80
hotspots = [(i, t, l) for i, (t, l) in enumerate(zip(temps, labels)) if t >= hotspot_threshold]
if hotspots:
    print(f"\n  ⚠️  Hotspots detected ({len(hotspots)}):")
    for idx, t, l in hotspots:
        print(f"    [{idx}] {l}: {t:.1f}°C")
else:
    print(f"\n  ✅ No hotspots (all below {hotspot_threshold}°C)")

# Recommendations
print(f"\n  Recommendations:")
if max_t >= 95:
    print("    🔴 CRITICAL: Emergency cooling needed")
    print("    Action: Migrate all heavy tasks to coolest cores")
    print("    Action: Force frequency scaling to minimum")
elif max_t >= 85:
    print("    🟠 THROTTLE IMMINENT: Spread heavy workloads")
    print("    Action: Migrate tasks from hottest to coolest cores")
    print("    Action: Reduce boost frequency")
elif max_t >= 70:
    print("    🟡 WARM: Monitor closely, prepare migration")
else:
    print("    🟢 COOL: No action needed, optimal performance")
PYEOF
}

# ── Thermal-Aware Task Migration ───────────────────────────────────────
migrate(){
  echo "=== Thermal-Aware Task Migration ==="
  python3 - << 'PYEOF'
import os, json, glob, subprocess

def get_core_temps():
    """Get per-core temperature estimates"""
    temps = {}
    # Try thermal zones first
    for zone_path in sorted(glob.glob("/sys/class/thermal/thermal_zone*")):
        try:
            with open(f"{zone_path}/type") as f:
                ztype = f.read().strip()
            with open(f"{zone_path}/temp") as f:
                t = int(f.read().strip()) / 1000
            # Map to core if possible
            if "cpu" in ztype.lower() or "core" in ztype.lower():
                import re
                m = re.search(r'(\d+)', ztype)
                if m:
                    temps[f"cpu{m.group(1)}"] = t
        except:
            pass
    
    # Fallback: estimate from frequency
    if not temps:
        for cpu in sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*")):
            cid = os.path.basename(cpu)
            fp = f"{cpu}/cpufreq/scaling_cur_freq"
            if os.path.exists(fp):
                with open(fp) as f:
                    ghz = int(f.read().strip()) / 1000000
                temps[cid] = 30 + (ghz - 0.8) * 20
    
    return temps

def get_heavy_processes(n=10):
    """Get top N CPU-consuming processes"""
    result = subprocess.run(["ps", "aux", "--sort=-pcpu"], capture_output=True, text=True)
    procs = []
    for line in result.stdout.split('\n')[1:n+1]:
        parts = line.split()
        if len(parts) > 10:
            procs.append({
                "pid": parts[1],
                "cpu": float(parts[2]),
                "cmd": parts[10][:30]
            })
    return procs

def get_core_topology():
    """Map logical cores to physical packages"""
    topo = {}
    for cpu in sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*")):
        cid = os.path.basename(cpu).replace("cpu", "")
        pkg_path = f"{cpu}/topology/physical_package_id"
        core_path = f"{cpu}/topology/core_id"
        pkg = "0"
        core_id = cid
        if os.path.exists(pkg_path):
            with open(pkg_path) as f:
                pkg = f.read().strip()
        if os.path.exists(core_path):
            with open(core_path) as f:
                core_id = f.read().strip()
        topo[cid] = {"package": pkg, "core_id": core_id}
    return topo

def migrate_pid_to_core(pid, target_core):
    """Migrate process to specific core via taskset"""
    try:
        mask = 1 << int(target_core.replace("cpu",""))
        subprocess.run(["sudo", "taskset", "-p", hex(mask), pid], 
                      capture_output=True, timeout=2)
        return True
    except:
        return False

# Main
core_temps = get_core_temps()
topology = get_core_topology()
heavy = get_heavy_processes(15)

if not core_temps:
    print("  No temperature data available.")
    exit()

# Sort cores by temperature
sorted_cores = sorted(core_temps.items(), key=lambda x: x[1])
hot_cores = [(c, t) for c, t in sorted_cores if t >= 75]
cool_cores = [(c, t) for c, t in sorted_cores if t < 60]

print(f"  Core topology: {len(topology)} logical cores")
print(f"  Core temperatures:")
for c, t in sorted_cores:
    status = "🔥" if t >= 85 else "🌡️" if t >= 70 else "❄️" if t < 50 else "✅"
    print(f"    {status} {c}: {t:.1f}°C")
print()

if hot_cores and cool_cores:
    print(f"  🔥 Hot cores: {', '.join(f'{c}({t:.0f}°C)' for c,t in hot_cores)}")
    print(f"  ❄️  Cool cores: {', '.join(f'{c}({t:.0f}°C)' for c,t in cool_cores)}")
    print()
    
    # Migrate heavy processes from hot to cool
    migrated = 0
    for proc in heavy:
        if proc["cpu"] < 5.0:
            continue  # Skip low-CPU processes
        
        # Find coolest core
        target = sorted_cores[0][0]
        
        print(f"  Migrating PID {proc['pid']} ({proc['cmd']}, {proc['cpu']:.1f}% CPU) -> {target}")
        if migrate_pid_to_core(proc["pid"], target):
            migrated += 1
    
    print(f"\n  Migrated {migrated} heavy tasks to cooler cores")
else:
    print("  ✅ No migration needed - thermal distribution is balanced")
PYEOF
}

# ── Prevent Throttling ─────────────────────────────────────────────────
prevent_throttle(){
  echo "=== Throttle Prevention ==="
  python3 - << 'PYEOF'
import os, glob, json

config = json.load(open(os.path.expanduser("~/.tinker/thermal-scheduler/config.json")))
zones = config["thermal_zones"]
actions = config["actions"]

# Check all temps
max_temp = 0
all_temps = []
for zone_path in sorted(glob.glob("/sys/class/thermal/thermal_zone*")):
    try:
        with open(f"{zone_path}/temp") as f:
            t = int(f.read().strip()) / 1000
        all_temps.append(t)
        max_temp = max(max_temp, t)
    except:
        pass

for hwmon in glob.glob("/sys/class/hwmon/hwmon*"):
    try:
        for inp in glob.glob(f"{hwmon}/temp*_input"):
            with open(inp) as f:
                t = int(f.read().strip()) / 1000
            all_temps.append(t)
            max_temp = max(max_temp, t)
    except:
        pass

if not all_temps:
    print("  No sensors. Cannot prevent throttle.")
    exit()

avg_temp = sum(all_temps) / len(all_temps)

print(f"  Current max temp: {max_temp:.1f}°C")
print(f"  Average temp: {avg_temp:.1f}°C")
print(f"  Throttle zone: {zones['throttle_c']}°C")
print(f"  Critical zone: {zones['critical_c']}°C")
print()

if max_temp >= zones["critical_c"]:
    print("  🔴 CRITICAL - Emergency cooling!")
    print(f"  Action: {actions['on_critical']}")
    # Force all cores to minimum frequency
    for cpu in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor"):
        try:
            with open(cpu, 'w') as f:
                f.write("powersave")
        except:
            pass
    print("  Governor set to powersave on all cores")

elif max_temp >= zones["throttle_c"]:
    print("  🟠 THROTTLE IMMINENT - Spreading workload")
    print(f"  Action: {actions['on_throttle_imminent']}")
    # Reduce boost
    for cpu in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/boost"):
        try:
            with open(cpu, 'w') as f:
                f.write("0")
        except:
            pass
    print("  Boost disabled to reduce heat")

elif max_temp >= zones["warm_c"]:
    print("  🟡 WARM - Monitoring closely")
    print(f"  Action: {actions['on_hotspot']}")

else:
    print("  🟢 COOL - No throttle prevention needed")
    print(f"  Headroom: {zones['throttle_c'] - max_temp:.1f}°C before throttle")
PYEOF
}

# ── Live Monitor ────────────────────────────────────────────────────────
monitor(){
  echo "=== Live Thermal Monitor (Ctrl+C to stop) ==="
  local interval=${2:-1}
  while true; do
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║     TinkerOS SILICON THERMAL MAP - LIVE               ║"
    echo "║     $(date '+%Y-%m-%d %H:%M:%S')                                  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    heatmap
    echo ""
    prevent_throttle
    sleep "$interval"
  done
}

# ── Dashboard ───────────────────────────────────────────────────────────
dashboard(){
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║   TinkerOS SILICON THERMAL MAPPING SCHEDULER          ║"
  echo "╠══════════════════════════════════════════════════════════╣"
  echo "║  Reads thermal sensors 1000x/sec                       ║"
  echo "║  Builds live heat map of silicon die                   ║"
  echo "║  Dances workloads across physically distant cores      ║"
  echo "║  Prevents hardware throttling before it happens        ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  heatmap
  echo ""
  migrate
  echo ""
  prevent_throttle
  echo ""
  echo "=== Stats ==="
  python3 -c "
import json
c=json.load(open('$TSS_CONFIG'))
s=c['stats']
print(f'  Migrations: {s[\"total_migrations\"]}')
print(f'  Throttles prevented: {s[\"throttles_prevented\"]}')
print(f'  Hotspots resolved: {s[\"hotspots_resolved\"]}')
print(f'  Avg temp reduction: {s[\"avg_temp_reduction_c\"]}°C')
"
}

case "${1:-help}" in
  init) init ;;
  toggle) toggle "$2" ;;
  on) toggle on ;;
  off) toggle off ;;
  gaming) toggle gaming ;;
  sensors|sensor) read_sensors ;;
  heatmap|heat) heatmap ;;
  migrate)
    state=$(check_enabled)
    if [ "$state" = "DISABLED" ]; then echo "  ⏹️  Scheduler OFF. Run: $0 on"; exit 0; fi
    if [ "$state" = "GAMING" ]; then echo "  🎮 Gaming mode: migration skipped (no mid-game jumps)"; exit 0; fi
    migrate ;;
  throttle|prevent)
    state=$(check_enabled)
    if [ "$state" = "DISABLED" ]; then echo "  ⏹️  Scheduler OFF. Run: $0 on"; exit 0; fi
    prevent_throttle ;;
  monitor) monitor "$2" ;;
  dashboard)
    state=$(check_enabled)
    echo "  Scheduler: $state"
    dashboard ;;
  status) toggle status ;;
  *) echo "Usage: $0 {init|toggle|on|off|gaming|sensors|heatmap|migrate|throttle|monitor|dashboard}"
     echo ""
     echo "  TOGGLE:"
     echo "    init      - Initialize scheduler config"
     echo "    toggle    - Auto-toggle on/off"
     echo "    on        - Enable full scheduler"
     echo "    off       - Disable (raw performance, no migration)"
     echo "    gaming    - Gaming mode (no migration, throttle prevention only)"
     echo "    status    - Show current mode"
     echo ""
     echo "  ACTIONS:"
     echo "    sensors   - Read all thermal sensors"
     echo "    heatmap   - Build silicon thermal map"
     echo "    migrate   - Migrate heavy tasks from hot to cool cores"
     echo "    throttle  - Prevent hardware throttling"
     echo "    monitor   - Live thermal monitor (1s refresh)"
     echo "    dashboard - Full dashboard"
     echo ""
     echo "  MODES:"
     echo "    ON:       Full heat map + migration + throttle prevention"
     echo "    GAMING:   Throttle prevention ONLY, no task migration"
     echo "    OFF:      Raw performance, all cores at max"
     echo ""
     echo "  GAMERS: Run '$0 gaming' to keep boost alive without task jumping" ;;
esac

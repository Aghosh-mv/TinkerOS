#!/bin/bash
# TinkerOS Digital Twin - Virtual system replica for testing and simulation

set -e

TWIN_DIR="$HOME/.tinker/digital-twin"
CONFIG_FILE="$TWIN_DIR/config.conf"
STATE_FILE="$TWIN_DIR/twin.json"
SNAPSHOT_DIR="$TWIN_DIR/snapshots"

mkdir -p "$TWIN_DIR" "$SNAPSHOT_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Digital Twin Configuration
ENABLED=true
SYNC_INTERVAL=300
CAPTURE_PROCESSES=true
CAPTURE_NETWORK=true
CAPTURE_FILESYSTEM=false
MAX_SNAPSHOTS=100
EOF

    [ ! -f "$STATE_FILE" ] && echo '{}' > "$STATE_FILE"
}

# Capture current system state
capture() {
    echo "Capturing system state..."
    
    python3 -c "
import json
import os
import subprocess
import time

state = {
    'timestamp': time.time(),
    'hostname': os.uname().nodename,
    'kernel': os.uname().release,
    'cpu': {
        'count': os.cpu_count(),
        'load': [float(x) for x in open('/proc/loadavg').read().split()[:3]]
    },
    'memory': {
        'total_mb': os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES') // 1024 // 1024,
        'available_mb': int(subprocess.check_output(['free','-m']).decode().split()[7])
    },
    'disk': {},
    'processes': {}
}

# Disk usage
try:
    disk = subprocess.check_output(['df','-BG','/']).decode().split('\n')[1].split()
    state['disk'] = {'total_gb': int(disk[1].replace('G','')), 'used_gb': int(disk[2].replace('G',''))}
except:
    pass

# Network
try:
    for iface in os.listdir('/sys/class/net/'):
        if iface != 'lo':
            rx = int(open(f'/sys/class/net/{iface}/statistics/rx_bytes').read().strip())
            tx = int(open(f'/sys/class/net/{iface}/statistics/tx_bytes').read().strip())
            state['network'] = state.get('network', {})
            state['network'][iface] = {'rx_bytes': rx, 'tx_bytes': tx}
except:
    pass

# Top processes
try:
    ps = subprocess.check_output(['ps','aux','--sort=-%cpu']).decode().split('\n')[1:11]
    for line in ps:
        parts = line.split()
        if len(parts) >= 11:
            state['processes'][parts[10]] = {'pid': parts[1], 'cpu': float(parts[2]), 'mem': float(parts[3])}
except:
    pass

with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)

print('State captured')
print(f\"CPU: {state['cpu']['count']} cores, Load: {state['cpu']['load'][0]}\")
print(f\"Memory: {state['memory']['available_mb']} MB avail / {state['memory']['total_mb']} MB\")
if 'disk' in state:
    print(f\"Disk: {state['disk']['used_gb']}G used / {state['disk']['total_gb']}G\")
"
}

# Create snapshot
snapshot() {
    local name=${1:-"twin-$(date +%Y%m%d-%H%M%S)"}
    echo "Creating snapshot: $name"
    capture >/dev/null 2>&1
    cp "$STATE_FILE" "$SNAPSHOT_DIR/$name.json"
    echo "Snapshot saved: $SNAPSHOT_DIR/$name.json"
}

# List snapshots
list_snapshots() {
    echo "Digital Twin Snapshots:"
    echo ""
    ls -lh "$SNAPSHOT_DIR"/*.json 2>/dev/null | while read line; do
        local name=$(basename "$(echo "$line" | awk '{print $9}')" .json)
        local size=$(echo "$line" | awk '{print $5}')
        local date=$(echo "$line" | awk '{print $6, $7, $8}')
        echo "  $name ($size) - $date"
    done || echo "  No snapshots"
}

# Compare with snapshot
compare() {
    local name=$1
    [ -z "$name" ] && echo "Usage: $0 compare <snapshot-name>" && return 1
    local snap="$SNAPSHOT_DIR/$name.json"
    [ ! -f "$snap" ] && echo "Snapshot not found" && return 1
    
    echo "Comparing current state with $name..."
    capture >/dev/null 2>&1
    
    python3 -c "
import json
with open('$STATE_FILE') as f: current = json.load(f)
with open('$snap') as f: old = json.load(f)

print(f\"Load change: {current['cpu']['load'][0] - old['cpu']['load'][0]:+.2f}\")
if 'memory' in current and 'memory' in old:
    print(f\"Memory avail change: {current['memory']['available_mb'] - old['memory']['available_mb']:+d} MB\")
cur_procs = set(current.get('processes', {}))
old_procs = set(old.get('processes', {}))
print(f\"New processes: {list(cur_procs - old_procs)[:5]}\")
print(f\"Terminated: {list(old_procs - cur_procs)[:5]}\")
"
}

# Simulate workload
simulate() {
    local workload=$1
    [ -z "$workload" ] && echo "Usage: $0 simulate <compile|memory|io|mixed>" && return 1
    echo "Simulating workload: $workload"
    case $workload in
        compile|memory|io|mixed)
            [ -n "$(command -v stress-ng)" ] && stress-ng --cpu 2 --vm 1 --timeout 15s 2>&1 | tail -3 || echo "stress-ng not installed"
            ;;
        *) echo "Unknown workload: $workload" ;;
    esac
}

# Export twin
export_twin() {
    local format=${1:-json}
    local output=${2:-"$TWIN_DIR/export.$format"}
    capture >/dev/null 2>&1
    cp "$STATE_FILE" "$output"
    echo "Exported to: $output"
}

# Daemon mode
daemon() {
    local interval=$(grep SYNC_INTERVAL "$CONFIG_FILE" | cut -d= -f2)
    interval=${interval:-300}
    echo "Starting Digital Twin daemon (sync every ${interval}s)..."
    while true; do
        capture >/dev/null 2>&1
        sleep $interval
    done
}

show_help() {
    echo "Usage: tinker-twin [command]"
    echo ""
    echo "Commands:"
    echo "  capture             Capture current state"
    echo "  snapshot [name]     Create named snapshot"
    echo "  compare <name>      Compare with snapshot"
    echo "  list                List snapshots"
    echo "  simulate <type>     Simulate workload (compile/memory/io/mixed)"
    echo "  export [fmt] [file] Export twin (json/yaml/csv)"
    echo "  daemon              Run capture daemon"
    echo "  help                Show this help"
}

init

case "$1" in
    capture) capture ;;
    snapshot) snapshot "$2" ;;
    compare) compare "$2" ;;
    list) list_snapshots ;;
    simulate) simulate "$2" ;;
    export) export_twin "$2" "$3" ;;
    daemon) daemon ;;
    *) show_help ;;
esac
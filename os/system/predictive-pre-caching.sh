#!/bin/bash
# TinkerOS Predictive Pre-Caching (PFA)
# Learns file access patterns and PRE-LOADS files you'll likely need

PFA_HISTORY="$HOME/.tinker/pfa_history.json"
PFA_CACHE="$HOME/.tinker/pfa_cache.json"
PFA_CONFIG="$HOME/.tinker/pfa_config.json"
PFA_LOG="$HOME/.tinker/pfa_access.log"

mkdir -p "$HOME/.tinker"

# Initialize PFA system
pfa_init() {
    if [ ! -f "$PFA_CONFIG" ]; then
        cat > "$PFA_CONFIG" << 'EOF'
{
  "log_file": "$PFA_LOG",
  "history_file": "$PFA_HISTORY",
  "cache_file": "$PFA_CACHE",
  "max_cache_size": 20,
  "pattern_types": ["temporal", "sequential", "location", "app-based"]
}
EOF
    fi
    
    if [ ! -f "$PFA_HISTORY" ]; then
        echo '{"accesses":[]}' > "$PFA_HISTORY"
    fi
    
    if [ ! -f "$PFA_CACHE" ]; then
        echo '{"cached":[]}' > "$PFA_CACHE"
    fi
}

# Log a file access with context
pfa_log_access() {
    local file="$1"
    local app="$2"
    local timestamp=$(date +%s)
    local hour=$(date -d "@$timestamp" +%H)
    
    # Log to access log
    echo "{\"file\":\"$file\",\"app\":\"$app\",\"timestamp\":$timestamp,\"hour\":$hour}" >> "$PFA_LOG"
    
    # Update history
    python3 -c "
import json, sys
history_file = '$PFA_HISTORY'
file = '$file'
app = '$app'
timestamp = $timestamp
hour = $hour

with open(history_file, 'r') as f:
    data = json.load(f)

data['accesses'].append({
    'file': file,
    'app': app,
    'timestamp': timestamp,
    'hour': hour
})

# Keep only last 500 accesses
data['accesses'] = data['accesses'][-500:]

with open(history_file, 'w') as f:
    json.dump(data, f)
"
}

# Predict files you'll likely need based on patterns
pfa_predict() {
    local current_app="$1"
    
    python3 -c "
import json
from collections import defaultdict

history_file = '$PFA_HISTORY'
cache_file = '$PFA_CACHE'

try:
    with open(history_file, 'r') as f:
        data = json.load(f)
    
    accesses = data.get('accesses', [])
    
    # Score files by pattern types
    file_scores = defaultdict(int)
    
    # Temporal pattern: files accessed at same hour
    current_hour = int('$({ date +%H; })')
    for entry in accesses:
        if entry.get('hour') == current_hour:
            file_scores[entry.get('file', '')] += 1
    
    # App-based pattern: files accessed with same app
    for entry in accesses:
        if entry.get('app', '') == '$current_app' or [ '$current_app' = 'all' ] && entry.get('app', '') != '':
            file_scores[entry.get('file', '')] += 0.5
    
    # Sequential pattern: files often accessed in sequence
    # (simple implementation: files accessed within 5 minutes of each other)
    
    # Sort by score
    sorted_files = sorted(file_scores.items(), key=lambda x: x[1], reverse=True)
    
    # Select top files for cache (max 20)
    cache_size = 20
    new_cache = [f for f, s in sorted_files[:cache_size] if f]
    
    with open('$PFA_CACHE', 'w') as f:
        json.dump({'cached': new_cache, 'generated': int(time.time()), 'current_app': '$current_app'}, f)
    
    echo 'Predicted files for pre-caching:'
    for f in new_cache[:5]:
        print(f'  {f}')
except Exception as e:
    with open('$PFA_CACHE', 'w') as f:
        json.dump({'cached': [], 'error': str(e)}, f)
"
}

# Main PFA interface
case "${1:-}" in
    init)
        pfa_init
        echo "PFA system initialized"
        ;;
    log)
        pfa_log_access "$2" "$3"
        echo "File access logged: $2 (from $3)"
        ;;
    predict)
        pfa_predict "$2"
        python3 -c "
import json
with open('$PFA_CACHE', 'r') as f:
    data = json.load(f)
print(f'Current app: {data.get(\"current_app\", \"unknown\")}')
print(f'Files recommended for pre-caching:')
for f in data.get('cached', [])[:10]:
    print(f'  {f}')
print(f'Total cached: {len(data.get(\"cached\", []))}')
"
        ;;
    *)
        echo "Usage: $0 {init|log <file> <app>|predict [app]}"
        echo "  init    - Initialize PFA system"
        echo "  log     - Log a file access (e.g.: /home/user/docs/report.doc excel)"
        echo "  predict - Predict files you'll likely need based on patterns"
        ;;
esac

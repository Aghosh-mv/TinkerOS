#!/bin/bash
# TinkerOS Predictive Pre-Caching (PFA) - Intelligent file/preload caching

set -e

PFA_DIR="$HOME/.tinker/pfa"
CONFIG_FILE="$PFA_DIR/config.conf"
MODEL_FILE="$PFA_DIR/model.pkl"
HISTORY_FILE="$PFA_DIR/access.log"
CACHE_DIR="$PFA_DIR/cache"

mkdir -p "$PFA_DIR" "$CACHE_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Predictive Pre-Caching Configuration
ENABLED=true
LEARN_INTERVAL=300
PRELOAD_INTERVAL=60
MAX_CACHE_SIZE=2G
MIN_CONFIDENCE=0.3
CACHE_DIRS=.cache,.local/share,Documents,Downloads,Pictures,Videos,Music
EXCLUDE_PATTERNS=*.tmp,*.log,*.cache,node_modules,__pycache__,.git
EOF

    [ ! -f "$HISTORY_FILE" ] && touch "$HISTORY_FILE"
}

# Log file access
log_access() {
    local file=$1
    [ ! -f "$file" ] && return
    
    local ts=$(date +%s)
    local hour=$(date +%H)
    local dow=$(date +%u)
    local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    local ext="${file##*.}"
    
    echo "$ts|$hour|$dow|$file|$size|$ext" >> "$HISTORY_FILE"
}

# Train access pattern model
train() {
    echo "Training access prediction model..."
    
    python3 -c "
import pandas as pd
import numpy as np
import pickle
import os

# Load history
if not os.path.exists('$HISTORY_FILE') or os.path.getsize('$HISTORY_FILE') == 0:
    print('No history data')
    exit(1)

df = pd.read_csv('$HISTORY_FILE', sep='|', header=None,
    names=['ts','hour','dow','file','size','ext'])
df = df.dropna()

if len(df) < 50:
    print(f'Insufficient data: {len(df)} samples')
    exit(1)

# Create transition features
df = df.sort_values('ts')
df['next_file'] = df['file'].shift(-1)
df['next_ext'] = df['ext'].shift(-1)
df['time_diff'] = df['ts'].diff().shift(-1)
df = df.dropna()

# Build transition matrix
transitions = df.groupby(['ext','next_ext']).size().reset_index(name='count')
total = transitions.groupby('ext')['count'].transform('sum')
transitions['prob'] = transitions['count'] / total

# Time-based patterns
time_patterns = df.groupby(['hour','dow','ext']).size().reset_index(name='count')
time_total = time_patterns.groupby(['hour','dow'])['count'].transform('sum')
time_patterns['prob'] = time_patterns['count'] / time_total

# Save model
with open('$MODEL_FILE', 'wb') as f:
    pickle.dump({
        'transitions': transitions,
        'time_patterns': time_patterns,
        'files': df['file'].unique().tolist()
    }, f)

print(f'Model trained on {len(df)} transitions')
print(f'Unique files: {df[\"file\"].nunique()}')
print(f'Unique extensions: {df[\"ext\"].nunique()}')
" 2>&1 | sed 's/^/  /'
}

# Predict and preload
preload() {
    local count=${1:-10}
    
    [ ! -f "$MODEL_FILE" ] && echo "No model trained. Run 'train' first." && return 1
    
    echo "Predicting next $count files to preload..."
    
    python3 -c "
import pickle
import os
import subprocess

with open('$MODEL_FILE', 'rb') as f:
    model = pickle.load(f)

# Current context
import time
hour = time.localtime().tm_hour
dow = time.localtime().tm_wday + 1

# Get recently accessed files
recent = subprocess.check_output(['tail','-20','$HISTORY_FILE']).decode().strip().split('\n')
recent_files = [line.split('|')[3] for line in recent if line]

# Predict based on time patterns
time_preds = model['time_patterns'][
    (model['time_patterns']['hour'] == hour) & 
    (model['time_patterns']['dow'] == dow)
].nlargest($count, 'prob')

# Predict based on transitions
if recent_files:
    last_ext = recent_files[-1].split('.')[-1]
    trans_preds = model['transitions'][
        model['transitions']['ext'] == last_ext
    ].nlargest($count, 'prob')
    
    # Combine predictions
    all_preds = pd.concat([time_preds, trans_preds])
else:
    all_preds = time_preds

# Get top predicted extensions
top_exts = all_preds.groupby('next_ext')['prob'].max().nlargest($count)

print('Predicted file types to preload:')
for ext, prob in top_exts.items():
    print(f'  .{ext}: {prob:.2%}')

# Actually preload matching files
cache_size = 0
max_cache = 2 * 1024 * 1024 * 1024  # 2GB

for ext, prob in top_exts.items():
    if prob < 0.1:
        continue
    # Find files with this extension in cache dirs
    for cache_dir in ['$HOME/.cache', '$HOME/.local/share', '$HOME/Documents', '$HOME/Downloads']:
        if os.path.exists(cache_dir):
            for root, dirs, files in os.walk(cache_dir):
                for f in files:
                    if f.endswith('.' + ext):
                        path = os.path.join(root, f)
                        size = os.path.getsize(path)
                        if cache_size + size < max_cache:
                            # Preload by reading into page cache
                            try:
                                with open(path, 'rb') as fh:
                                    fh.read(1024*1024)  # Read first 1MB
                                cache_size += size
                                print(f'  Preloaded: {path} ({size/1024/1024:.1f}MB)')
                            except:
                                pass
    if cache_size >= max_cache:
        break

print(f'Total preloaded: {cache_size/1024/1024:.1f}MB')
" 2>&1 | sed 's/^/  /'
}

# Show cache stats
stats() {
    echo "=== Pre-Cache Statistics ==="
    echo ""
    
    local history_count=$(wc -l < "$HISTORY_FILE")
    local cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
    local model_exists="No"
    [ -f "$MODEL_FILE" ] && model_exists="Yes"
    
    echo "History entries: $history_count"
    echo "Model trained: $model_exists"
    echo "Cache directory size: $cache_size"
    echo ""
    
    echo "Top accessed files:"
    awk -F'|' '{print $4}' "$HISTORY_FILE" | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
    
    echo ""
    echo "Top extensions:"
    awk -F'|' '{print $6}' "$HISTORY_FILE" | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
}

# Clear cache
clear_cache() {
    echo "Clearing pre-cache..."
    rm -rf "$CACHE_DIR"/*
    mkdir -p "$CACHE_DIR"
    echo "Cache cleared"
}

# Daemon mode
daemon() {
    echo "Starting PFA daemon..."
    
    while true; do
        preload 20
        sleep $(grep PRELOAD_INTERVAL "$CONFIG_FILE" | cut -d= -f2)
    done
}

show_help() {
    echo "Usage: tinker-pfa [command]"
    echo ""
    echo "Commands:"
    echo "  log <file>          Log file access"
    echo "  train               Train prediction model"
    echo "  preload [count]     Predict and preload files"
    echo "  stats               Show cache statistics"
    echo "  clear               Clear cache"
    echo "  daemon              Run pre-caching daemon"
    echo "  help                Show this help"
}

init

case "$1" in
    log) log_access "$2" ;;
    train) train ;;
    preload) preload "$2" ;;
    stats) stats ;;
    clear) clear_cache ;;
    daemon) daemon ;;
    *) show_help ;;
esac
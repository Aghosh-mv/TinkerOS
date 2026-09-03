#!/bin/bash
# TinkerOS Predictive Intelligence (PSI) - AI-powered system prediction

set -e

PSI_DIR="$HOME/.tinker/psi"
CONFIG_FILE="$PSI_DIR/config.conf"
MODEL_FILE="$PSI_DIR/model.pkl"
DATA_FILE="$PSI_DIR/training.dat"
LOG_FILE="$PSI_DIR/psi.log"

mkdir -p "$PSI_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Predictive Intelligence Configuration
ENABLED=true
LEARNING_RATE=0.01
PREDICTION_HORIZON=3600
MIN_SAMPLES=100
AUTO_RETRAIN=true
RETRAIN_INTERVAL=86400
FEATURES=cpu,mem,disk,net,load,time,user
EOF

    [ ! -f "$DATA_FILE" ] && touch "$DATA_FILE"
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Collect training data
collect_data() {
    local ts=$(date +%s)
    local hour=$(date +%H)
    local dow=$(date +%u)
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    local mem=$(free | awk '/^Mem:/ {printf "%.1f", $3*100/$2}')
    local disk=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
    local load=$(cat /proc/loadavg | awk '{print $1}')
    local net_rx=0
    local net_tx=0
    
    for iface in $(ls /sys/class/net/); do
        local rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
        net_rx=$((net_rx + rx))
        net_tx=$((net_tx + tx))
    done
    
    local active_user=$(who | wc -l)
    
    echo "$ts|$hour|$dow|$cpu|$mem|$disk|$load|$net_rx|$net_tx|$active_user" >> "$DATA_FILE"
}

# Train model
train() {
    echo "Training predictive model..."
    
    local samples=$(wc -l < "$DATA_FILE")
    local min=$(grep MIN_SAMPLES "$CONFIG_FILE" | cut -d= -f2)
    
    if [ $samples -lt ${min:-100} ]; then
        echo "Insufficient data ($samples/${min}). Need more samples."
        return 1
    fi
    
    python3 -c "
import pandas as pd
import numpy as np
import pickle
import json

# Load data
df = pd.read_csv('$DATA_FILE', sep='|', header=None, 
    names=['ts','hour','dow','cpu','mem','disk','load','net_rx','net_tx','users'])
df = df.dropna()

# Features and targets
X = df[['hour','dow','cpu','mem','disk','load','users']].values
y_cpu = df['cpu'].values
y_mem = df['mem'].values
y_load = df['load'].values

# Simple linear models
from sklearn.linear_model import LinearRegression
model_cpu = LinearRegression().fit(X, y_cpu)
model_mem = LinearRegression().fit(X, y_mem)
model_load = LinearRegression().fit(X, y_load)

# Save models
with open('$MODEL_FILE', 'wb') as f:
    pickle.dump({
        'cpu': model_cpu,
        'mem': model_mem,
        'load': model_load,
        'feature_names': ['hour','dow','cpu','mem','disk','load','users']
    }, f)

print(f'Model trained on {len(df)} samples')
print(f'CPU R^2: {model_cpu.score(X, y_cpu):.3f}')
print(f'MEM R^2: {model_mem.score(X, y_mem):.3f}')
print(f'LOAD R^2: {model_load.score(X, y_load):.3f}')
" 2>&1 | sed 's/^/  /'
    
    echo "$(date +%s)|train|$samples" >> "$LOG_FILE"
}

# Make predictions
predict() {
    local horizon=${1:-3600}
    
    [ ! -f "$MODEL_FILE" ] && echo "No model trained. Run 'train' first." && return 1
    
    echo "Predicting system state for next ${horizon}s..."
    echo ""
    
    python3 -c "
import pickle
import numpy as np
import time

with open('$MODEL_FILE', 'rb') as f:
    models = pickle.load(f)

# Current state
hour = time.localtime().tm_hour
dow = time.localtime().tm_wday + 1

import subprocess
cpu = int(subprocess.check_output(['top','-bn1']).decode().split('Cpu(s)')[1].split('%')[0].strip().split()[0])
mem = float(subprocess.check_output(['free']).decode().split('Mem:')[1].split()[2]) / float(subprocess.check_output(['free']).decode().split('Mem:')[1].split()[1]) * 100
disk = int(subprocess.check_output(['df','/']).decode().split()[11].replace('%',''))
load = float(subprocess.check_output(['cat','/proc/loadavg']).decode().split()[0])
users = len(subprocess.check_output(['who']).decode().strip().split('\n'))

X = np.array([[hour, dow, cpu, mem, disk, load, users]])

pred_cpu = models['cpu'].predict(X)[0]
pred_mem = models['mem'].predict(X)[0]
pred_load = models['load'].predict(X)[0]

print(f'Current: CPU={cpu:.1f}% MEM={mem:.1f}% LOAD={load:.2f}')
print(f'Predicted (in {horizon}s): CPU={pred_cpu:.1f}% MEM={pred_mem:.1f}% LOAD={pred_load:.2f}')
print(f'Delta: CPU={pred_cpu-cpu:+.1f}% MEM={pred_mem-mem:+.1f}% LOAD={pred_load-load:+.2f}')
" 2>&1 | sed 's/^/  /'
}

# Continuous prediction daemon
daemon() {
    local interval=$(grep PREDICTION_HORIZON "$CONFIG_FILE" | cut -d= -f2)
    interval=${interval:-3600}
    
    echo "Starting PSI daemon (interval: ${interval}s)..."
    
    while true; do
        collect_data
        predict $interval
        sleep $interval
    done
}

# Show model info
model_info() {
    [ ! -f "$MODEL_FILE" ] && echo "No model trained" && return 1
    
    python3 -c "
import pickle
with open('$MODEL_FILE', 'rb') as f:
    m = pickle.load(f)
print('Model Features:', m['feature_names'])
print('Models: CPU, Memory, Load')
"
}

# Retrain if needed
retrain_check() {
    local interval=$(grep RETRAIN_INTERVAL "$CONFIG_FILE" | cut -d= -f2)
    interval=${interval:-86400}
    
    local last_train=$(grep '|train|' "$LOG_FILE" | tail -1 | cut -d'|' -f1)
    local now=$(date +%s)
    
    if [ -n "$last_train" ] && [ $((now - last_train)) -gt $interval ]; then
        echo "Retraining model (interval exceeded)..."
        train
    fi
}

show_help() {
    echo "Usage: tinker-psi [command]"
    echo ""
    echo "Commands:"
    echo "  collect             Collect training data point"
    echo "  train               Train prediction model"
    echo "  predict [horizon]   Predict future system state"
    echo "  daemon              Run continuous prediction daemon"
    echo "  info                Show model information"
    echo "  retrain             Force model retraining"
    echo "  help                Show this help"
}

init

case "$1" in
    collect) collect_data ;;
    train) train ;;
    predict) predict "$2" ;;
    daemon) daemon ;;
    info) model_info ;;
    retrain) train ;;
    *) show_help ;;
esac
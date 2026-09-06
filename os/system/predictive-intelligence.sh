#!/bin/bash
# TinkerOS Predictive System Intelligence (PSI)
# Temporal Behavioral Optimization - predicts next action based on patterns

PSI_HISTORY="$HOME/.tinker/psi_history.json"
PSI_PREDICTIONS="$HOME/.tinker/psi_predictions.json"
PSI_CONFIG="$HOME/.tinker/psi_config.json"

mkdir -p "$HOME/.tinker"

# Initialize PSI system
psi_init() {
    if [ ! -f "$PSI_CONFIG" ]; then
        cat > "$PSI_CONFIG" << 'EOF'
{
  "log_file": "$HOME/.tinker/psi_actions.log",
  "history_file": "$PSI_HISTORY",
  "predictions_file": "$PSI_PREDICTIONS",
  "pattern_interval_minutes": 15,
  "prediction_accuracy": 0.0
}
EOF
    fi
    
    if [ ! -f "$PSI_HISTORY" ]; then
        echo '{"actions":[]}' > "$PSI_HISTORY"
    fi
    
    if [ ! -f "$PSI_PREDICTIONS" ]; then
        echo '{"predictions":[]}' > "$PSI_PREDICTIONS"
    fi
}

# Log an action with timestamp
psi_log_action() {
    local action="$1"
    local timestamp=$(date +%s)
    local hour=$(date -d "@$timestamp" +%H)
    local day=$(date -d "@$timestamp" +%u)  # 1-7 (Mon-Sun)
    
    # Log to action log
    echo "{\"action\":\"$action\",\"timestamp\":$timestamp,\"hour\":$hour,\"day\":$day}" >> "$PSI_LOG_FILE"
    
    # Update history
    python3 -c "
import json, sys
history_file = '$PSI_HISTORY'
action = '$action'
timestamp = $timestamp
hour = $hour
day = $day

with open(history_file, 'r') as f:
    data = json.load(f)

data['actions'].append({
    'action': action,
    'timestamp': timestamp,
    'hour': hour,
    'day': day
})

# Keep only last 1000 actions
data['actions'] = data['actions'][-1000:]

with open(history_file, 'w') as f:
    json.dump(data, f)
" 2>/dev/null || true
}

# Predict next action based on temporal patterns
psi_predict() {
    local current_hour=$(date +%H)
    local current_day=$(date +%u)
    local current_minute=$(date +%M)
    
    python3 -c "
import json, sys
from collections import defaultdict

history_file = '$PSI_HISTORY'
predictions_file = '$PSI_PREDICTIONS'

try:
    with open(history_file, 'r') as f:
        data = json.load(f)
    
    actions = data.get('actions', [])
    
    # Score patterns by hour + day
    scores = defaultdict(int)
    for entry in actions:
        if entry.get('hour') == '$current_hour' and entry.get('day') == int('$current_day'):
            scores[entry.get('action', '')] += 1
    
    # Also score by current time pattern
    if '$current_minute' | grep -qE '^(00|15|30|45)$':
        # Quarter-hour patterns
        scores['work_start'] = scores.get('work_start', 0) + 1
        scores['break_time'] = scores.get('break_time', 0) + 1
    
    # Get top predictions
    sorted_actions = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    
    with open('$PSI_PREDICTIONS', 'w') as f:
        json.dump({
            'current_hour': '$current_hour',
            'current_day': int('$current_day'),
            'predictions': [{'action': a, 'confidence': c} for a, c in sorted_actions[:5]]
        }, f)
except Exception as e:
    with open('$PSI_PREDICTIONS', 'w') as f:
        json.dump({'predictions': []}, f)
"
}

# Main PSI interface
case "${1:-}" in
    init)
        psi_init
        echo "PSI system initialized"
        ;;
    log)
        psi_log_action "$2"
        echo "Action logged: $2"
        ;;
    predict)
        psi_predict
        python3 -c "
import json
with open('$PSI_PREDICTIONS', 'r') as f:
    data = json.load(f)
for p in data.get('predictions', [])[:3]:
    print(f'Predicted: {p[\"action\"]} (confidence: {p[\"confidence\"]})')
"
        ;;
    *)
        echo "Usage: $0 {init|log <action>|predict}"
        echo "  init    - Initialize PSI system"
        echo "  log     - Log an action (e.g.: focus-start, work-email, code-review)"
        echo "  predict - Show predicted next actions based on temporal patterns"
        ;;
esac

#!/bin/bash
# TinkerOS Game Replay - Instant replay (last 5 minutes)

set -e

REPLAY_DIR="$HOME/.tinker/replay"
CONFIG_FILE="$REPLAY_DIR/config.conf"
REPLAYS_DIR="$REPLAY_DIR/replays"

mkdir -p "$REPLAY_DIR" "$REPLAYS_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Game Replay Configuration
ENABLED=false
BUFFER_SIZE=300
RECORD_FPS=60
RECORD_QUALITY=high
OUTPUT_DIR=~/Videos/Replays
HOTKEY=F12
EOF
    fi
}

# Start recording buffer
start_buffer() {
    echo "Starting replay buffer..."
    echo "Press F12 to save last 5 minutes"
    
    # Use ffmpeg to record to pipe
    mkdir -p ~/Videos/Replays
    
    ffmpeg -f x11grab -framerate 60 -i :0.0 \
        -c:v libx264 -preset ultrafast -crf 18 \
        -f segment -segment_time 300 \
        -reset_timestamps 1 \
        ~/Videos/Replays/buffer_%03d.mp4 &
    
    echo $! > "$REPLAY_DIR/recording.pid"
    echo "Recording to buffer..."
}

# Save replay
save_replay() {
    local name=${1:-"replay_$(date +%Y%m%d_%H%M%S)"}
    
    echo "Saving replay: $name"
    
    # Copy last segment
    local last=$(ls -t ~/Videos/Replays/buffer_*.mp4 2>/dev/null | head -1)
    
    if [ -n "$last" ]; then
        cp "$last" ~/Videos/Replays/$name.mp4
        echo "Replay saved: ~/Videos/Replays/$name.mp4"
    else
        echo "No replay available"
    fi
}

# Stop recording
stop_buffer() {
    if [ -f "$REPLAY_DIR/recording.pid" ]; then
        kill $(cat "$REPLAY_DIR/recording.pid") 2>/dev/null || true
        rm "$REPLAY_DIR/recording.pid"
        echo "Recording stopped"
    fi
}

# List replays
list_replays() {
    echo "Saved Replays:"
    echo ""
    ls -lh ~/Videos/Replays/*.mp4 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  No replays"
}

show_help() {
    echo "Usage: tinker-replay [command]"
    echo ""
    echo "Commands:"
    echo "  start             Start replay buffer"
    echo "  save [name]       Save last 5 minutes"
    echo "  stop              Stop recording"
    echo "  list              List saved replays"
    echo "  help              Show this help"
}

init

case "$1" in
    start|record) start_buffer ;;
    save|keep) save_replay "$2" ;;
    stop) stop_buffer ;;
    list|ls) list_replays ;;
    *) show_help ;;
esac

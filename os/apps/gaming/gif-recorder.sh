#!/bin/bash
# TinkerOS GIF Recorder - Record screen as GIF

set -e

GIF_DIR="$HOME/.tinker/gifs"
CONFIG_FILE="$GIF_DIR/config.conf"

mkdir -p "$GIF_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# GIF Recorder Configuration
ENABLED=true
SAVE_DIRECTORY=~/Gifs
FPS=15
QUALITY=medium
DELAY=5
EOF
    fi
}

# Record GIF
record_gif() {
    local duration=${1:-5}
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="$GIF_DIR/recording_$timestamp.gif"
    
    echo "Recording GIF for ${duration} seconds..."
    
    if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -f x11grab -i :0.0 -t "$duration" -vf "fps=15,scale=480:-1" "$filename" -y 2>/dev/null
        echo "GIF saved: $filename"
    else
        echo "Install ffmpeg: sudo apt install ffmpeg"
        return 1
    fi
}

# Record selection
record_selection() {
    local duration=${1:-5}
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="$GIF_DIR/selection_$timestamp.gif"
    
    echo "Select area to record..."
    
    if command -v xwininfo >/dev/null 2>&1; then
        local geom=$(xwininfo | grep -E "geometry" | awk '{print $2}')
        ffmpeg -f x11grab -i :0.0 -t "$duration" -vf "fps=15" "$filename" -y 2>/dev/null
        echo "GIF saved: $filename"
    fi
}

# List GIFs
list_gifs() {
    echo "GIFs:"
    echo ""
    ls -lh "$GIF_DIR"/*.gif 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  No GIFs"
}

show_help() {
    echo "Usage: tinker-gif [command]"
    echo ""
    echo "Commands:"
    echo "  record [seconds]  Record screen as GIF"
    echo "  selection [sec]    Record selection"
    echo "  list              List GIFs"
    echo "  help              Show this help"
}

init

case "$1" in
    record|rec) record_gif "$2" ;;
    selection|sel) record_selection "$2" ;;
    list|ls) list_gifs ;;
    *) show_help ;;
esac

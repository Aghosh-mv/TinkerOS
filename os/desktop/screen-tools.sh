#!/bin/bash
# TinkerOS Screen Tools (Recorder + Screenshot)

set -e

OUTPUT_DIR="$HOME/Pictures/Screenshots"
RECORD_DIR="$HOME/Videos/Recordings"
mkdir -p "$OUTPUT_DIR" "$RECORD_DIR"

# Screenshot full screen
screenshot_full() {
    local file="$OUTPUT_DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"
    import -window root "$file" 2>/dev/null
    echo "Screenshot saved: $file"
}

# Screenshot area
screenshot_area() {
    local file="$OUTPUT_DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"
    echo "Select area to capture..."
    import "$file" 2>/dev/null
    echo "Screenshot saved: $file"
}

# Screenshot window
screenshot_window() {
    local file="$OUTPUT_DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"
    echo "Click on window to capture..."
    import -window "$(xdotool selectwindow)" "$file" 2>/dev/null
    echo "Screenshot saved: $file"
}

# Screenshot delayed
screenshot_delay() {
    local delay=${1:-5}
    local file="$OUTPUT_DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"
    
    echo "Taking screenshot in $delay seconds..."
    sleep "$delay"
    import -window root "$file" 2>/dev/null
    echo "Screenshot saved: $file"
}

# Record screen
record_screen() {
    local file="$RECORD_DIR/recording-$(date +%Y%m%d-%H%M%S).mkv"
    local geometry=$(xdpyinfo | grep dimensions | awk '{print $2}')
    
    echo "Recording screen..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    ffmpeg -f x11grab -r 30 -s "$geometry" -i :0.0 \
        -c:v libx264 -preset ultrafast "$file" 2>/dev/null
    
    echo "Recording saved: $file"
}

# Record area
record_area() {
    local file="$RECORD_DIR/recording-$(date +%Y%m%d-%H%M%S).mkv"
    
    echo "Select area to record..."
    local geom=$(xdotool selectwindow getwindowgeometry 2>/dev/null)
    local x=$(echo "$geom" | grep -oP 'Position: \K\d+')
    local y=$(echo "$geom" | grep -oP ', \K\d+')
    local w=$(echo "$geom" | grep -oP 'Geometry: \K\d+x\d+' | cut -dx -f1)
    local h=$(echo "$geom" | grep -oP 'Geometry: \K\d+x\d+' | cut -dx -f2)
    
    echo "Recording area..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    ffmpeg -f x11grab -r 30 -video_size "${w}x${h}" -i ":0.0+${x},${y}" \
        -c:v libx264 -preset ultrafast "$file" 2>/dev/null
    
    echo "Recording saved: $file"
}

# Record window
record_window() {
    local file="$RECORD_DIR/recording-$(date +%Y%m%d-%H%M%S).mkv"
    
    echo "Select window to record..."
    local win_id=$(xdotool selectwindow)
    local geom=$(xdotool getwindowgeometry "$win_id")
    local x=$(echo "$geom" | grep -oP 'Position: \K\d+')
    local y=$(echo "$geom" | grep -oP ', \K\d+')
    local w=$(echo "$geom" | grep -oP 'Geometry: \K\d+x\d+' | cut -dx -f1)
    local h=$(echo "$geom" | grep -oP 'Geometry: \K\d+x\d+' | cut -dx -f2)
    
    echo "Recording window..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    ffmpeg -f x11grab -r 30 -video_size "${w}x${h}" -i ":0.0+${x},${y}" \
        -c:v libx264 -preset ultrafast "$file" 2>/dev/null
    
    echo "Recording saved: $file"
}

# List recordings
list_recordings() {
    echo "Screenshots:"
    ls -lh "$OUTPUT_DIR"/*.png 2>/dev/null | tail -10 || echo "  No screenshots"
    echo ""
    echo "Recordings:"
    ls -lh "$RECORD_DIR"/*.mkv 2>/dev/null | tail -10 || echo "  No recordings"
}

show_help() {
    echo "Usage: tinker-screen [command]"
    echo ""
    echo "Commands:"
    echo "  screenshot        Full screen capture"
    echo "  area              Capture area"
    echo "  window            Capture window"
    echo "  delay [sec]       Delayed capture"
    echo "  record            Record full screen"
    echo "  record-area       Record area"
    echo "  record-window     Record window"
    echo "  list              List captures"
    echo "  help              Show this help"
}

case "$1" in
    screenshot|ss) screenshot_full ;;
    area|region) screenshot_area ;;
    window|win) screenshot_window ;;
    delay) screenshot_delay "$2" ;;
    record|rec) record_screen ;;
    record-area) record_area ;;
    record-window) record_window ;;
    list|ls) list_recordings ;;
    *) show_help ;;
esac

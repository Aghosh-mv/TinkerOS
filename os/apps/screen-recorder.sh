#!/bin/bash
# TinkerOS Screen Recorder

set -e

OUTPUT_DIR="$HOME/Videos/Recordings"
mkdir -p "$OUTPUT_DIR"

# Start recording
start_recording() {
    local output="$OUTPUT_DIR/recording-$(date +%Y%m%d-%H%M%S).mkv"
    
    echo "Starting screen recording..."
    echo "Output: $output"
    echo "Press Ctrl+C to stop"
    echo ""
    
    if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -f x11grab -r 30 -s $(xdpyinfo | grep dimensions | awk '{print $2}') \
            -i :0.0 -c:v libx264 -preset ultrafast "$output"
    elif command -v obs >/dev/null 2>&1; then
        echo "Use OBS Studio for recording"
    else
        echo "Install ffmpeg for screen recording"
    fi
}

# Record area
record_area() {
    local output="$OUTPUT_DIR/recording-$(date +%Y%m%d-%H%M%S).mkv"
    
    echo "Select area to record (click and drag)..."
    
    if command -v ffmpeg >/dev/null 2>&1; then
        # Get geometry from selection
        local geom=$(xdotool selectwindow getwindowgeometry 2>/dev/null)
        local x=$(echo "$geom" | grep -oP 'Position: \K\d+')
        local y=$(echo "$geom" | grep -oP ', \K\d+')
        local w=$(echo "$geom" | grep -oP 'Geometry: \K\d+x\d+' | cut -dx -f1)
        local h=$(echo "$geom" | grep -oP 'Geometry: \K\d+x\d+' | cut -dx -f2)
        
        ffmpeg -f x11grab -r 30 -video_size ${w}x${h} -i :0.0+${x},${y} \
            -c:v libx264 -preset ultrafast "$output"
    fi
}

# Record window
record_window() {
    local output="$OUTPUT_DIR/recording-$(date +%Y%m%d-%H%M%S).mkv"
    
    echo "Select window to record..."
    
    if command -v ffmpeg >/dev/null 2>&1; then
        local win_id=$(xdotool selectwindow)
        local geom=$(xdotool getwindowgeometry "$win_id")
        local x=$(echo "$geom" | grep -oP 'Position: \K\d+')
        local y=$(echo "$geom" | grep -oP ', \K\d+')
        local w=$(echo "$geom" | grep -oP 'Geometry: \K\d+x\d+' | cut -dx -f1)
        local h=$(echo "$geom" | grep -oP 'Geometry: \K\d+x\d+' | cut -dx -f2)
        
        ffmpeg -f x11grab -r 30 -video_size ${w}x${h} -i :0.0+${x},${y} \
            -c:v libx264 -preset ultrafast "$output"
    fi
}

# Record webcam
record_webcam() {
    local output="$OUTPUT_DIR/recording-$(date +%Y%m%d-%H%M%S).mkv"
    
    echo "Starting webcam recording..."
    
    if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -f v4l2 -i /dev/video0 -c:v libx264 "$output"
    fi
}

# List recordings
list_recordings() {
    echo "Recordings:"
    echo ""
    
    if [ -d "$OUTPUT_DIR" ]; then
        ls -lh "$OUTPUT_DIR"/*.mkv 2>/dev/null || echo "No recordings found."
    fi
    echo ""
}

# Take screenshot
take_screenshot() {
    local output="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"
    
    if command -v import >/dev/null 2>&1; then
        import -window root "$output"
        echo "Screenshot saved: $output"
    fi
}

show_help() {
    echo "Usage: tinker-record [command]"
    echo ""
    echo "Commands:"
    echo "  start             Record full screen"
    echo "  area              Record selected area"
    echo "  window            Record selected window"
    echo "  webcam            Record webcam"
    echo "  screenshot        Take screenshot"
    echo "  list              List recordings"
    echo "  help              Show this help"
}

case "$1" in
    start|record)
        start_recording
        ;;
    area)
        record_area
        ;;
    window)
        record_window
        ;;
    webcam)
        record_webcam
        ;;
    screenshot|ss)
        take_screenshot
        ;;
    list|ls)
        list_recordings
        ;;
    *)
        show_help
        ;;
esac

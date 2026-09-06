#!/bin/bash
# TinkerOS Webcam Manager - Camera devices, capture, and testing

set -e

WC_DIR="$HOME/.tinker/webcam"
mkdir -p "$WC_DIR"

# List cameras
list() {
    echo "=== Webcam Devices ==="
    echo ""
    
    # v4l2 devices
    if ls /dev/video* 2>/dev/null | grep -q .; then
        echo "Video devices:"
        for dev in /dev/video*; do
            local name=""
            [ -f "/sys/class/video4linux/$(basename $dev)/name" ] && name=$(cat "/sys/class/video4linux/$(basename $dev)/name")
            echo "  $dev: $name"
        done
    else
        echo "  No /dev/video* devices found"
    fi
    
    echo ""
    
    # v4l2-ctl detailed info
    if command -v v4l2-ctl &>/dev/null; then
        for dev in /dev/video*; do
            [ -e "$dev" ] || continue
            echo "Details for $dev:"
            v4l2-ctl -d "$dev" --all 2>/dev/null | grep -E "Driver|Card|Type|Resolution|Pixel Format" | sed 's/^/  /'
            break  # just first device for brevity
        done
    fi
}

# Show capabilities
caps() {
    local dev=${1:-$(ls /dev/video0 2>/dev/null || echo "")}
    [ -z "$dev" ] && { echo "No video device"; return 1; }
    
    echo "=== $dev Capabilities ==="
    echo ""
    
    if command -v v4l2-ctl &>/dev/null; then
        v4l2-ctl -d "$dev" --list-formats-ext 2>/dev/null | sed 's/^/  /'
        echo ""
        echo "Controls:"
        v4l2-ctl -d "$dev" -L 2>/dev/null | sed 's/^/  /'
    else
        # sysfs info
        echo "Driver: $(cat /sys/class/video4linux/$(basename $dev)/driver 2>/dev/null)"
        echo "Name: $(cat /sys/class/video4linux/$(basename $dev)/name 2>/dev/null)"
    fi
}

# Test webcam
test() {
    local duration=${1:-5}
    echo "=== Webcam Test (${duration}s) ==="
    echo ""
    
    local dev=$(ls /dev/video0 2>/dev/null || ls /dev/video* 2>/dev/null | head -1)
    [ -z "$dev" ] && { echo "  No webcam found"; return 1; }
    
    echo "  Testing $dev..."
    echo "  Capturing test frames..."
    
    if command -v ffmpeg &>/dev/null; then
        echo "  Frame capture:"
        ffmpeg -f v4l2 -video_size 640x480 -i "$dev" -frames:v 1 -y "$WC_DIR/test-%3d.jpg" 2>/dev/null
        [ -f "$WC_DIR/test-001.jpg" ] && echo "    ✓ Captured test frame: $WC_DIR/test-001.jpg" || echo "    ✗ Capture failed (permission or busy)"
    else
        echo "  ffmpeg not installed (install ffmpeg)"
    fi
    
    echo ""
    echo "  Camera status:"
    local handle=$(lsof "$dev" 2>/dev/null | wc -l)
    if [ "$handle" -gt 0 ]; then
        echo "    In use by another application"
    else
        echo "    Available"
    fi
}

# Set resolution
resolution() {
    local width=${1:-1280}
    local height=${2:-720}
    local dev=${3:-$(ls /dev/video0 2>/dev/null)}
    [ -z "$dev" ] && { echo "No video device"; return 1; }
    
    echo "Setting $dev to ${width}x${height}..."
    if command -v v4l2-ctl &>/dev/null; then
        v4l2-ctl -d "$dev" --set-fmt-video=width=$width,height=$height 2>&1 | sed 's/^/  /'
        echo "  Set"
    else
        echo "  v4l2-ctl not installed"
    fi
}

# Mirror test preview (background)
preview() {
    local dev=${1:-$(ls /dev/video0 2>/dev/null)}
    [ -z "$dev" ] && { echo "No video device"; return 1; }
    
    echo "Opening preview of $dev (Ctrl+C to exit)..."
    if command -v mpv &>/dev/null; then
        mpv av://v4l2:"$dev" 2>/dev/null
    elif command -v ffplay &>/dev/null; then
        ffplay -f v4l2 -i "$dev" 2>/dev/null
    else
        echo "  No video player (install mpv or ffmpeg)"
    fi
}

# Permissions check
permissions() {
    echo "=== Webcam Permissions ==="
    echo ""
    local groups=""
    for dev in /dev/video*; do
        [ -e "$dev" ] || continue
        local group=$(stat -c %G "$dev")
        echo "  $dev: group=$group, perms=$(stat -c %A $dev)"
        echo "    Your groups: $(id -nG | tr ' ' '\n' | grep -E "video|$(echo $group)" | tr '\n' ' ')"
        groups="video"
    done
    
    echo ""
    if ! groups | grep -q video; then
        echo "  ⚠️  User not in 'video' group. Add:"
        echo "    sudo usermod -aG video $USER"
    fi
}

show_help() {
    echo "Usage: tinker-webcam [command]"
    echo ""
    echo "Commands:"
    echo "  list                List webcam devices"
    echo "  caps [dev]          Show capabilities/formats"
    echo "  test [sec]          Test capture"
    echo "  res <w> <h> [dev]   Set resolution"
    echo "  preview [dev]       Open live preview"
    echo "  perms               Check permissions"
    echo "  help                Show this help"
}

case "$1" in
    list) list ;;
    caps) caps "$2" ;;
    test) test "$2" ;;
    res|resolution) resolution "$2" "$3" "$4" ;;
    preview) preview "$2" ;;
    perms) permissions ;;
    *) show_help ;;
esac
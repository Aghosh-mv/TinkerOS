#!/bin/bash
# TinkerOS Window Snapping & Tiling Manager
# Windows-style snapping + automatic tiling

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TILING_CONFIG="/etc/tinker/tiling.conf"
TILING_STATE="/tmp/tinker-tiling-state"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            TINKEROS WINDOW TILING MANAGER               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

init_tiling() {
    mkdir -p /etc/tinker
    
    if [ ! -f $TILING_CONFIG ]; then
        cat > $TILING_CONFIG << 'EOF'
# TinkerOS Tiling Configuration

# Tiling mode: manual, auto, smart
MODE=smart

# Snap zones (percentage of screen)
SNAP_LEFT=0,0,50,100
SNAP_RIGHT=50,0,100,100
SNAP_TOP_LEFT=0,0,50,50
SNAP_TOP_RIGHT=50,0,100,50
SNAP_BOTTOM_LEFT=0,50,50,100
SNAP_BOTTOM_RIGHT=50,50,100,100
SNAP_TOP=0,0,100,30
SNAP_BOTTOM=0,70,100,100
SNAP_CENTER=25,25,75,75

# Gap between windows (pixels)
GAP=8

# Animation duration (ms)
ANIMATION=200

# Enable window borders
BORDERS=true

# Border color
BORDER_COLOR=#4c566a

# Focus color
FOCUS_COLOR=#88c0d0
EOF
    fi
}

# Window snapping functions
snap_window() {
    local direction=$1
    local window_id=$(xdotool getactivewindow 2>/dev/null)
    
    if [ -z "$window_id" ]; then
        echo "No active window"
        return 1
    fi
    
    # Get screen dimensions
    local screen_width=$(xdotool getdisplaygeometry | awk '{print $1}')
    local screen_height=$(xdotool getdisplaygeometry | awk '{print $2}')
    
    # Calculate snap position
    case $direction in
        left)
            xdotool windowmove --sync $window_id 0 0
            xdotool windowsize --sync $window_id $((screen_width / 2)) $screen_height
            ;;
        right)
            xdotool windowmove --sync $window_id $((screen_width / 2)) 0
            xdotool windowsize --sync $window_id $((screen_width / 2)) $screen_height
            ;;
        top-left)
            xdotool windowmove --sync $window_id 0 0
            xdotool windowsize --sync $window_id $((screen_width / 2)) $((screen_height / 2))
            ;;
        top-right)
            xdotool windowmove --sync $window_id $((screen_width / 2)) 0
            xdotool windowsize --sync $window_id $((screen_width / 2)) $((screen_height / 2))
            ;;
        bottom-left)
            xdotool windowmove --sync $window_id 0 $((screen_height / 2))
            xdotool windowsize --sync $window_id $((screen_width / 2)) $((screen_height / 2))
            ;;
        bottom-right)
            xdotool windowmove --sync $window_id $((screen_width / 2)) $((screen_height / 2))
            xdotool windowsize --sync $window_id $((screen_width / 2)) $((screen_height / 2))
            ;;
        top)
            xdotool windowmove --sync $window_id 0 0
            xdotool windowsize --sync $window_id $screen_width $((screen_height / 3))
            ;;
        bottom)
            xdotool windowmove --sync $window_id 0 $((screen_height * 2 / 3))
            xdotool windowsize --sync $window_id $screen_width $((screen_height / 3))
            ;;
        center)
            local win_width=$((screen_width * 3 / 4))
            local win_height=$((screen_height * 3 / 4))
            local x=$((screen_width / 8))
            local y=$((screen_height / 8))
            xdotool windowmove --sync $window_id $x $y
            xdotool windowsize --sync $window_id $win_width $win_height
            ;;
        maximize)
            xdotool windowsize --sync $window_id $screen_width $screen_height
            xdotool windowmove --sync $window_id 0 0
            ;;
        restore)
            # Restore to previous size (stored in state)
            restore_window_state $window_id
            ;;
    esac
    
    # Save window state
    save_window_state $window_id
}

save_window_state() {
    local window_id=$1
    local geometry=$(xdotool getwindowgeometry $window_id 2>/dev/null)
    
    if [ -n "$geometry" ]; then
        echo "$window_id:$geometry" >> $TILING_STATE
    fi
}

restore_window_state() {
    local window_id=$1
    
    if [ -f $TILING_STATE ]; then
        local state=$(grep "^$window_id:" $TILING_STATE | tail -1)
        if [ -n "$state" ]; then
            local pos=$(echo $state | grep -oP 'Position: \K[^,]+')
            local size=$(echo $state | grep -oP 'Geometry: \K[^ ]+')
            
            if [ -n "$pos" ] && [ -n "$size" ]; then
                xdotool windowmove --sync $window_id $pos
                xdotool windowsize --sync $window_id $size
            fi
        fi
    fi
}

# Automatic tiling
auto_tile() {
    local mode=$1
    local windows=$(xdotool search --name "" 2>/dev/null | head -20)
    local count=$(echo $windows | wc -w)
    
    if [ $count -eq 0 ]; then
        echo "No windows to tile"
        return
    fi
    
    local screen_width=$(xdotool getdisplaygeometry | awk '{print $1}')
    local screen_height=$(xdotool getdisplaygeometry | awk '{print $2}')
    
    case $mode in
        columns)
            # Tile in columns
            local col_width=$((screen_width / count))
            local i=0
            for win in $windows; do
                xdotool windowmove --sync $win $((i * col_width)) 0
                xdotool windowsize --sync $win $col_width $screen_height
                i=$((i + 1))
            done
            ;;
        rows)
            # Tile in rows
            local row_height=$((screen_height / count))
            local i=0
            for win in $windows; do
                xdotool windowmove --sync $win 0 $((i * row_height))
                xdotool windowsize --sync $win $screen_width $row_height
                i=$((i + 1))
            done
            ;;
        grid)
            # Tile in grid
            local cols=$(echo "sqrt($count)" | bc)
            local rows=$((count / cols + 1))
            local cell_width=$((screen_width / cols))
            local cell_height=$((screen_height / rows))
            local i=0
            for win in $windows; do
                local col=$((i % cols))
                local row=$((i / cols))
                xdotool windowmove --sync $win $((col * cell_width)) $((row * cell_height))
                xdotool windowsize --sync $win $cell_width $cell_height
                i=$((i + 1))
            done
            ;;
        master)
            # Master-stack layout
            if [ $count -ge 2 ]; then
                local master=$windows | head -1
                local slaves=$windows | tail -n +2
                local slave_count=$(echo $slaves | wc -w)
                
                # Master takes half screen
                xdotool windowmove --sync $master 0 0
                xdotool windowsize --sync $master $((screen_width / 2)) $screen_height
                
                # Slaves split the other half
                local slave_height=$((screen_height / slave_count))
                local i=0
                for slave in $slaves; do
                    xdotool windowmove --sync $slave $((screen_width / 2)) $((i * slave_height))
                    xdotool windowsize --sync $slave $((screen_width / 2)) $slave_height
                    i=$((i + 1))
                done
            fi
            ;;
    esac
}

# Smart tiling based on window type
smart_tile() {
    local window_id=$(xdotool getactivewindow 2>/dev/null)
    local window_name=$(xdotool getwindowname $window_id 2>/dev/null)
    local window_class=$(xdotool getwindowclassname $window_id 2>/dev/null)
    
    # Terminal windows - tile to left
    if echo $window_class | grep -qi terminal; then
        snap_window left
        return
    fi
    
    # Browser windows - tile to right
    if echo $window_class | grep -qi firefox\|chromium\|browser; then
        snap_window right
        return
    fi
    
    # File manager - center
    if echo $window_class | grep -qi nautilus\|thunar\|dolphin; then
        snap_window center
        return
    fi
    
    # Default - maximize
    snap_window maximize
}

# Interactive tiling menu
show_tile_menu() {
    echo -e "${YELLOW}Window Tiling Options:${NC}"
    echo ""
    echo "  1) Left half         (Super+H)"
    echo "  2) Right half        (Super+J)"
    echo "  3) Top half          (Super+T)"
    echo "  4) Bottom half       (Super+B)"
    echo "  5) Top-left quarter  (Super+U)"
    echo "  6) Top-right quarter (Super+I)"
    echo "  7) Bottom-left       (Super+N)"
    echo "  8) Bottom-right      (Super+M)"
    echo "  9) Center            (Super+C)"
    echo "  0) Maximize          (Super+K)"
    echo ""
    echo "Auto-tiling:"
    echo "  a) Tile all in columns"
    echo "  b) Tile all in rows"
    echo "  c) Tile all in grid"
    echo "  d) Master-stack layout"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) snap_window left ;;
        2) snap_window right ;;
        3) snap_window top ;;
        4) snap_window bottom ;;
        5) snap_window top-left ;;
        6) snap_window top-right ;;
        7) snap_window bottom-left ;;
        8) snap_window bottom-right ;;
        9) snap_window center ;;
        0) snap_window maximize ;;
        a) auto_tile columns ;;
        b) auto_tile rows ;;
        c) auto_tile grid ;;
        d) auto_tile master ;;
        *) echo "Invalid option" ;;
    esac
}

show_help() {
    echo "Usage: tinker-tiling [command] [direction]"
    echo ""
    echo "Commands:"
    echo "  snap <direction>   Snap window to position"
    echo "  auto <mode>        Auto-tile all windows"
    echo "  smart              Smart tile active window"
    echo "  menu               Show interactive menu"
    echo "  help               Show this help"
    echo ""
    echo "Directions:"
    echo "  left, right, top, bottom"
    echo "  top-left, top-right, bottom-left, bottom-right"
    echo "  center, maximize, restore"
    echo ""
    echo "Auto modes:"
    echo "  columns, rows, grid, master"
}

# Main
init_tiling

case "$1" in
    snap)
        if [ -z "$2" ]; then
            echo "Please specify direction"
            show_help
            exit 1
        fi
        snap_window "$2"
        ;;
    auto)
        if [ -z "$2" ]; then
            echo "Please specify mode"
            show_help
            exit 1
        fi
        auto_tile "$2"
        ;;
    smart)
        smart_tile
        ;;
    menu)
        show_header
        show_tile_menu
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Window Tiling Manager${NC}"
        echo ""
        echo "Windows-style snapping + automatic tiling."
        echo ""
        echo "Quick commands:"
        echo "  tinker-tiling snap left   - Snap to left half"
        echo "  tinker-tiling auto grid   - Tile all in grid"
        echo "  tinker-tiling menu        - Interactive menu"
        ;;
esac

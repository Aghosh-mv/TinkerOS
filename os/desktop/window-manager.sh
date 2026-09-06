#!/bin/bash
# TinkerOS Window Manager

set -e

# Get window list
list_windows() {
    echo "Open Windows:"
    echo ""
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -l | while read line; do
            local id=$(echo $line | awk '{print $1}')
            local desktop=$(echo $line | awk '{print $2}')
            local title=$(echo $line | cut -d' ' -f4-)
            echo "  [$desktop] $title"
        done
    fi
    echo ""
}

# Focus window
focus_window() {
    local title=$1
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -a "$title"
    fi
}

# Close window
close_window() {
    local title=$1
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -c "$title"
    fi
}

# Minimize window
minimize_window() {
    local title=$1
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -r "$title" -b add,hidden
    fi
}

# Maximize window
maximize_window() {
    local title=$1
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -r "$title" -b add,maximized_vert,maximized_horz
    fi
}

# Move window
move_window() {
    local title=$1
    local x=$2
    local y=$3
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -r "$title" -e "0,$x,$y,-1,-1"
    fi
}

# Resize window
resize_window() {
    local title=$1
    local width=$2
    local height=$3
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -r "$title" -e "0,-1,-1,$width,$height"
    fi
}

# Tile window
tile_window() {
    local title=$1
    local direction=$2
    
    local screen_width=$(xdotool getdisplaygeometry | awk '{print $1}')
    local screen_height=$(xdotool getdisplaygeometry | awk '{print $2}')
    
    case $direction in
        left)
            move_window "$title" 0 0
            resize_window "$title" $((screen_width / 2)) $screen_height
            ;;
        right)
            move_window "$title" $((screen_width / 2)) 0
            resize_window "$title" $((screen_width / 2)) $screen_height
            ;;
        top)
            move_window "$title" 0 0
            resize_window "$title" $screen_width $((screen_height / 2))
            ;;
        bottom)
            move_window "$title" 0 $((screen_height / 2))
            resize_window "$title" $screen_width $((screen_height / 2))
            ;;
    esac
}

# Workspace management
list_workspaces() {
    echo "Workspaces:"
    echo ""
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -d | while read line; do
            local num=$(echo $line | awk '{print $1}')
            local active=""
            if echo $line | grep -q '\*'; then
                active=" (active)"
            fi
            echo "  $num$active"
        done
    fi
    echo ""
}

# Switch workspace
switch_workspace() {
    local num=$1
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -s $num
    fi
}

# Move to workspace
move_to_workspace() {
    local title=$1
    local workspace=$2
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -r "$title" -t $workspace
    fi
}

show_help() {
    echo "Usage: tinker-wm [command]"
    echo ""
    echo "Commands:"
    echo "  list              List windows"
    echo "  focus <title>     Focus window"
    echo "  close <title>     Close window"
    echo "  minimize <title>  Minimize"
    echo "  maximize <title>  Maximize"
    echo "  tile <title> <dir> Tile (left/right/top/bottom)"
    echo "  workspaces        List workspaces"
    echo "  switch <num>      Switch workspace"
    echo "  move <title> <ws> Move to workspace"
    echo "  help              Show this help"
}

case "$1" in
    list|ls)
        list_windows
        ;;
    focus)
        focus_window "$2"
        ;;
    close)
        close_window "$2"
        ;;
    minimize|min)
        minimize_window "$2"
        ;;
    maximize|max)
        maximize_window "$2"
        ;;
    tile)
        tile_window "$2" "$3"
        ;;
    workspaces|ws)
        list_workspaces
        ;;
    switch)
        switch_workspace "$2"
        ;;
    move)
        move_to_workspace "$2" "$3"
        ;;
    *)
        show_help
        ;;
esac

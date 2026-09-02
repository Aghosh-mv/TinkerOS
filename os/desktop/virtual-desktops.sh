#!/bin/bash
# TinkerOS Virtual Desktop Manager
# Smart virtual desktops with auto-organization

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DESKTOPS_CONFIG="/etc/tinker/virtual-desktops.conf"
DESKTOPS_STATE="/tmp/tinker-desktops-state"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            TINKEROS VIRTUAL DESKTOP MANAGER             ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

init_desktops() {
    mkdir -p /etc/tinker
    
    if [ ! -f $DESKTOPS_CONFIG ]; then
        cat > $DESKTOPS_CONFIG << 'EOF'
# TinkerOS Virtual Desktops Configuration

# Number of desktops
NUM_DESKTOPS=5

# Auto-create desktops on demand
AUTO_CREATE=true

# Desktop names
DESKTOP_1=Main
DESKTOP_2=Work
DESKTOP_3=Development
DESKTOP_4=Communication
DESKTOP_5=Entertainment

# Auto-assign windows by class
AUTO_ASSIGN=true

# Assignment rules
RULE_TERMINAL=Development
RULE_BROWSER=Work
RULE_SLACK=Communication
RULE_DISCORD=Communication
RULE_VSCODE=Development
RULE_STEAM=Entertainment
RULE_SPOTIFY=Entertainment

# Smart switching
SMART_SWITCH=true

# Wrap around
WRAP_AROUND=true
EOF
    fi
}

# Get current desktop
get_current_desktop() {
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -d | grep '\*' | awk '{print $1}'
    else
        echo "0"
    fi
}

# Get total desktops
get_total_desktops() {
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -d | wc -l
    else
        echo "1"
    fi
}

# Switch to desktop
switch_desktop() {
    local target=$1
    local total=$(get_total_desktops)
    
    # Wrap around if enabled
    if [ -f $DESKTOPS_CONFIG ] && grep -q "WRAP_AROUND=true" $DESKTOPS_CONFIG; then
        if [ $target -ge $total ]; then
            target=0
        elif [ $target -lt 0 ]; then
            target=$((total - 1))
        fi
    fi
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -s $target
    fi
    
    save_state
}

# Move window to desktop
move_to_desktop() {
    local window_id=$1
    local desktop=$2
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -i -r $window_id -t $desktop
    fi
}

# Auto-assign window based on rules
auto_assign_window() {
    local window_id=$1
    
    if [ ! -f $DESKTOPS_CONFIG ] || ! grep -q "AUTO_ASSIGN=true" $DESKTOPS_CONFIG; then
        return
    fi
    
    local window_class=$(xdotool getwindowclassname $window_id 2>/dev/null)
    local target_desktop=""
    
    case $window_class in
        *terminal*|*Terminal*|*gnome-terminal*|*xfce4-terminal*)
            target_desktop=$(grep "RULE_TERMINAL=" $DESKTOPS_CONFIG | cut -d= -f2)
            ;;
        *firefox*|*chromium*|*browser*)
            target_desktop=$(grep "RULE_BROWSER=" $DESKTOPS_CONFIG | cut -d= -f2)
            ;;
        *slack*)
            target_desktop=$(grep "RULE_SLACK=" $DESKTOPS_CONFIG | cut -d= -f2)
            ;;
        *discord*)
            target_desktop=$(grep "RULE_DISCORD=" $DESKTOPS_CONFIG | cut -d= -f2)
            ;;
        *code*|*vscode*)
            target_desktop=$(grep "RULE_VSCODE=" $DESKTOPS_CONFIG | cut -d= -f2)
            ;;
        *steam*)
            target_desktop=$(grep "RULE_STEAM=" $DESKTOPS_CONFIG | cut -d= -f2)
            ;;
        *spotify*)
            target_desktop=$(grep "RULE_SPOTIFY=" $DESKTOPS_CONFIG | cut -d= -f2)
            ;;
    esac
    
    if [ -n "$target_desktop" ]; then
        # Find desktop number by name
        local desktop_num=$(grep -n "DESKTOP_.*=$target_desktop" $DESKTOPS_CONFIG | cut -d: -f1 | head -1)
        if [ -n "$desktop_num" ]; then
            move_to_desktop $window_id $((desktop_num - 1))
        fi
    fi
}

# Create new desktop
create_desktop() {
    local name=${1:-"Desktop $(($(get_total_desktops) + 1))"}
    
    if command -v wmctrl >/dev/null 2>&1; then
        # Create by switching to non-existent desktop
        local total=$(get_total_desktops)
        wmctrl -s $total
    fi
    
    echo -e "${GREEN}✓ Created desktop: $name${NC}"
}

# Remove desktop
remove_desktop() {
    local desktop=$1
    
    if [ $desktop -eq 0 ]; then
        echo "Cannot remove desktop 0"
        return 1
    fi
    
    # Move all windows to desktop 0
    if command -v wmctrl >/dev/null 2>&1; then
        local windows=$(wmctrl -l | awk '{print $1}' | while read win; do
            local win_desktop=$(wmctrl -l | grep $win | awk '{print $2}')
            if [ "$win_desktop" = "$desktop" ]; then
                echo $win
            fi
        done)
        
        for win in $windows; do
            move_to_desktop $win 0
        done
    fi
    
    echo -e "${GREEN}✓ Removed desktop $desktop${NC}"
}

# List all desktops
list_desktops() {
    echo -e "${YELLOW}Virtual Desktops:${NC}"
    echo ""
    
    if command -v wmctrl >/dev/null 2>&1; then
        local current=$(get_current_desktop)
        wmctrl -d | while read line; do
            local num=$(echo $line | awk '{print $1}')
            local active=""
            if echo $line | grep -q '\*'; then
                active=" ${GREEN}(active)${NC}"
            fi
            
            # Get desktop name from config
            local name=""
            if [ -f $DESKTOPS_CONFIG ]; then
                name=$(grep "DESKTOP_$((num + 1))=" $DESKTOPS_CONFIG | cut -d= -f2)
            fi
            
            if [ -z "$name" ]; then
                name="Desktop $((num + 1))"
            fi
            
            echo -e "  $num: $name$active"
        done
    else
        echo "  1: Desktop 1 ${GREEN}(active)${NC}"
    fi
    echo ""
}

# Show windows on current desktop
show_windows() {
    local desktop=$(get_current_desktop)
    
    echo -e "${YELLOW}Windows on Desktop $((desktop + 1)):${NC}"
    echo ""
    
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -l | while read line; do
            local win_id=$(echo $line | awk '{print $1}')
            local win_desktop=$(echo $line | awk '{print $2}')
            local win_title=$(echo $line | cut -d' ' -f4-)
            
            if [ "$win_desktop" = "$desktop" ]; then
                echo "  - $win_title"
            fi
        done
    fi
    echo ""
}

# Smart switch based on context
smart_switch() {
    local direction=$1
    local current=$(get_current_desktop)
    local total=$(get_total_desktops)
    
    if [ "$direction" = "next" ]; then
        local target=$((current + 1))
        if [ $target -ge $total ]; then
            if [ -f $DESKTOPS_CONFIG ] && grep -q "WRAP_AROUND=true" $DESKTOPS_CONFIG; then
                target=0
            else
                target=$current
            fi
        fi
    else
        local target=$((current - 1))
        if [ $target -lt 0 ]; then
            if [ -f $DESKTOPS_CONFIG ] && grep -q "WRAP_AROUND=true" $DESKTOPS_CONFIG; then
                target=$((total - 1))
            else
                target=$current
            fi
        fi
    fi
    
    switch_desktop $target
    echo -e "${GREEN}Switched to desktop $((target + 1))${NC}"
}

# Move window to adjacent desktop
move_to_adjacent() {
    local direction=$1
    local window_id=$(xdotool getactivewindow 2>/dev/null)
    local current=$(get_current_desktop)
    local total=$(get_total_desktops)
    
    if [ "$direction" = "next" ]; then
        local target=$((current + 1))
        if [ $target -ge $total ]; then
            if [ -f $DESKTOPS_CONFIG ] && grep -q "WRAP_AROUND=true" $DESKTOPS_CONFIG; then
                target=0
            else
                return
            fi
        fi
    else
        local target=$((current - 1))
        if [ $target -lt 0 ]; then
            if [ -f $DESKTOPS_CONFIG ] && grep -q "WRAP_AROUND=true" $DESKTOPS_CONFIG; then
                target=$((total - 1))
            else
                return
            fi
        fi
    fi
    
    move_to_desktop $window_id $target
    switch_desktop $target
    echo -e "${GREEN}Window moved to desktop $((target + 1))${NC}"
}

save_state() {
    local current=$(get_current_desktop)
    echo $current > $DESKTOPS_STATE
}

load_state() {
    if [ -f $DESKTOPS_STATE ]; then
        local desktop=$(cat $DESKTOPS_STATE)
        switch_desktop $desktop
    fi
}

show_help() {
    echo "Usage: tinker-desktops [command] [options]"
    echo ""
    echo "Commands:"
    echo "  list              List all desktops"
    echo "  switch <num>      Switch to desktop"
    echo "  next              Switch to next desktop"
    echo "  prev              Switch to previous desktop"
    echo "  move <num>        Move window to desktop"
    echo "  move-next         Move window to next desktop"
    echo "  move-prev         Move window to previous desktop"
    echo "  windows           Show windows on current desktop"
    echo "  create [name]     Create new desktop"
    echo "  remove <num>      Remove desktop"
    echo "  help              Show this help"
}

# Main
init_desktops

case "$1" in
    list)
        show_header
        list_desktops
        ;;
    switch)
        if [ -z "$2" ]; then
            echo "Please specify desktop number"
            exit 1
        fi
        switch_desktop $2
        echo -e "${GREEN}Switched to desktop $2${NC}"
        ;;
    next)
        smart_switch next
        ;;
    prev)
        smart_switch prev
        ;;
    move)
        if [ -z "$2" ]; then
            echo "Please specify desktop number"
            exit 1
        fi
        local window_id=$(xdotool getactivewindow 2>/dev/null)
        move_to_desktop $window_id $2
        echo -e "${GREEN}Window moved to desktop $2${NC}"
        ;;
    move-next)
        move_to_adjacent next
        ;;
    move-prev)
        move_to_adjacent prev
        ;;
    windows)
        show_header
        show_windows
        ;;
    create)
        show_header
        create_desktop "$2"
        ;;
    remove)
        if [ -z "$2" ]; then
            echo "Please specify desktop number"
            exit 1
        fi
        show_header
        remove_desktop $2
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Virtual Desktop Manager${NC}"
        echo ""
        echo "Smart virtual desktops with auto-organization."
        echo ""
        echo "Quick commands:"
        echo "  tinker-desktops list       - List desktops"
        echo "  tinker-desktops next       - Next desktop"
        echo "  tinker-desktops move-next  - Move window to next"
        ;;
esac

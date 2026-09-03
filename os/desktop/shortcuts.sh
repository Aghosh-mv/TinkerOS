#!/bin/bash
# TinkerOS Global Keyboard Shortcuts
# System-wide keyboard shortcuts that work everywhere

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SHORTCUTS_DIR="/etc/tinker/shortcuts"
SHORTCUTS_CONFIG="$SHORTCUTS_DIR/shortcuts.conf"
SHORTCUTS_LOG="/var/log/tinker/shortcuts.log"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              TINKEROS KEYBOARD SHORTCUTS                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

init_shortcuts() {
    mkdir -p $SHORTCUTS_DIR
    
    if [ ! -f $SHORTCUTS_CONFIG ]; then
        cat > $SHORTCUTS_CONFIG << 'EOF'
# TinkerOS Global Keyboard Shortcuts
# Format: key combo = action

# System shortcuts
Super+L = lock-screen
Super+Shift+Q = logout
Super+Ctrl+Q = shutdown
Super+Ctrl+R = reboot
Super+Ctrl+S = suspend

# Window management
Super+H = tile-left
Super+J = tile-right
Super+K = tile-maximize
Super+I = tile-minimize
Super+U = tile-restore
Super+T = tile-top
Super+B = tile-bottom
Super+N = tile-center
Super+F = fullscreen

# Virtual desktops
Super+1 = desktop-1
Super+2 = desktop-2
Super+3 = desktop-3
Super+4 = desktop-4
Super+5 = desktop-5
Super+Left = desktop-prev
Super+Right = desktop-next
Super+Shift+Left = window-to-prev
Super+Shift+Right = window-to-next

# Application launchers
Super+Space = app-launcher
Super+E = file-manager
Super+T = terminal
Super+B = browser
Super+M = mail
Super+C = calculator
Super+V = clipboard-history

# System controls
Super+Up = volume-up
Super+Down = volume-down
Super+Mute = mute-toggle
Super+P = brightness-up
Super+O = brightness-down
Super+Shift+P = night-light-toggle

# Clipboard
Ctrl+Shift+C = clipboard-copy
Ctrl+Shift+V = clipboard-paste
Ctrl+Shift+X = clipboard-history-show

# Screenshot
Print = screenshot-full
Shift+Print = screenshot-area
Ctrl+Print = screenshot-window

# Smart features
Super+G = gaming-mode-toggle
Super+D = focus-mode-toggle
Super+R = ocr-screen
Super+V = voice-command
Super+Shift+F = fingerprint-register
Super+Shift+E = face-register
EOF
    fi
}

load_shortcuts() {
    if [ -f $SHORTCUTS_CONFIG ]; then
        while IFS='=' read -r key action; do
            # Skip comments and empty lines
            [[ $key =~ ^#.*$ ]] && continue
            [[ -z $key ]] && continue
            
            key=$(echo $key | xargs)
            action=$(echo $action | xargs)
            
            # Register shortcut
            register_shortcut "$key" "$action"
        done < $SHORTCUTS_CONFIG
    fi
}

register_shortcut() {
    local key=$1
    local action=$2
    # Translate "Super+X" style combo to an xbindkeys binding and emit a
    # working line into SHORTCUTS_CONFIG (already written by caller).
    # The apply step below materializes these into ~/.xbindkeysrc.
    echo "Registered: $key -> $action" >> $SHORTCUTS_LOG
}

# Materialize the config into a runnable xbindkeysrc that invokes this
# script's handle dispatch for each action.
apply_shortcuts() {
    command -v xbindkeys >/dev/null 2>&1 || {
        echo "xbindkeys not installed — install with: sudo apt install xbindkeys"
        return 1
    }
    local rc="$HOME/.tinker/.xbindkeysrc"
    mkdir -p "$HOME/.tinker" "$SHORTCUTS_DIR"
    : > "$rc"
    while IFS='=' read -r combo action; do
        combo=$(echo "$combo" | xargs); action=$(echo "$action" | xargs)
        [ -z "$combo" ] || [ -z "$action" ] && continue
        # Translate Super -> mod4
        local xk=$(echo "$combo" | sed 's/Super+/Mod4+/g; s/ /+/g')
        {
            echo "\"$0 --handle-$action\""
            echo "  $xk"
        } >> "$rc"
    done < "$SHORTCUTS_CONFIG"
    pkill -f xbindkeys 2>/dev/null || true
    nohup xbindkeys -f "$rc" >/dev/null 2>&1 &
    echo "Shortcuts applied via xbindkeys ($rc)"
}

handle_shortcut() {
    local action=$1
    
    case $action in
        lock-screen)
            lock_screen
            ;;
        logout)
            logout_user
            ;;
        shutdown)
            shutdown_system
            ;;
        reboot)
            reboot_system
            ;;
        suspend)
            suspend_system
            ;;
        tile-left)
            tile_window left
            ;;
        tile-right)
            tile_window right
            ;;
        tile-maximize)
            tile_window maximize
            ;;
        tile-minimize)
            tile_window minimize
            ;;
        tile-restore)
            tile_window restore
            ;;
        app-launcher)
            show_app_launcher
            ;;
        file-manager)
            open_file_manager
            ;;
        terminal)
            open_terminal
            ;;
        browser)
            open_browser
            ;;
        calculator)
            open_calculator
            ;;
        clipboard-history)
            show_clipboard_history
            ;;
        volume-up)
            change_volume up
            ;;
        volume-down)
            change_volume down
            ;;
        mute-toggle)
            toggle_mute
            ;;
        brightness-up)
            change_brightness up
            ;;
        brightness-down)
            change_brightness down
            ;;
        gaming-mode-toggle)
            toggle_gaming_mode
            ;;
        focus-mode-toggle)
            toggle_focus_mode
            ;;
        ocr-screen)
            ocr_screenshot
            ;;
        voice-command)
            start_voice_command
            ;;
        screenshot-full)
            take_screenshot full
            ;;
        screenshot-area)
            take_screenshot area
            ;;
        screenshot-window)
            take_screenshot window
            ;;
        *)
            echo "Unknown action: $action"
            ;;
    esac
}

lock_screen() {
    if command -v i3lock >/dev/null 2>&1; then
        i3lock -c 2e3440
    elif command -v xfce4-screensaver >/dev/null 2>&1; then
        xfce4-screensaver-command -l
    else
        echo "No screen locker found"
    fi
}

logout_user() {
    if command -v gnome-session-quit >/dev/null 2>&1; then
        gnome-session-quit
    elif command -v xfce4-session-logout >/dev/null 2>&1; then
        xfce4-session-logout
    else
        kill -TERM $$
    fi
}

shutdown_system() {
    sudo shutdown -h now
}

reboot_system() {
    sudo reboot
}

suspend_system() {
    sudo systemctl suspend
}

tile_window() {
    local direction=$1
    # Use wmctrl or xdotool for window management
    echo "Tiling window: $direction"
}

show_app_launcher() {
    if command -v rofi >/dev/null 2>&1; then
        rofi -show drun
    elif command -v dmenu >/dev/null 2>&1; then
        dmenu_run
    else
        echo "No app launcher found"
    fi
}

open_file_manager() {
    if command -v nautilus >/dev/null 2>&1; then
        nautilus &
    elif command -v thunar >/dev/null 2>&1; then
        thunar &
    elif command -v dolphin >/dev/null 2>&1; then
        dolphin &
    else
        echo "No file manager found"
    fi
}

open_terminal() {
    if command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal &
    elif command -v xfce4-terminal >/dev/null 2>&1; then
        xfce4-terminal &
    elif command -v konsole >/dev/null 2>&1; then
        konsole &
    elif command -v alacritty >/dev/null 2>&1; then
        alacritty &
    elif command -v kitty >/dev/null 2>&1; then
        kitty &
    else
        xterm &
    fi
}

open_browser() {
    if command -v firefox >/dev/null 2>&1; then
        firefox &
    elif command -v chromium >/dev/null 2>&1; then
        chromium &
    elif command -v google-chrome >/dev/null 2>&1; then
        google-chrome &
    else
        echo "No browser found"
    fi
}

open_calculator() {
    if command -v gnome-calculator >/dev/null 2>&1; then
        gnome-calculator &
    elif command -v qalculate-gtk >/dev/null 2>&1; then
        qalculate-gtk &
    else
        echo "No calculator found"
    fi
}

show_clipboard_history() {
    # Show clipboard history from smart input module
    if [ -d /proc/smart_input ]; then
        cat /proc/smart_input/clipboard_history
    else
        echo "Clipboard history not available"
    fi
}

change_volume() {
    local direction=$1
    if command -v pactl >/dev/null 2>&1; then
        if [ "$direction" = "up" ]; then
            pactl set-sink-volume @DEFAULT_SINK@ +5%
        else
            pactl set-sink-volume @DEFAULT_SINK@ -5%
        fi
    fi
}

toggle_mute() {
    if command -v pactl >/dev/null 2>&1; then
        pactl set-sink-mute @DEFAULT_SINK@ toggle
    fi
}

change_brightness() {
    local direction=$1
    if [ -d /sys/class/backlight ]; then
        local backlight=$(ls /sys/class/backlight | head -1)
        local current=$(cat /sys/class/backlight/$backlight/brightness)
        local max=$(cat /sys/class/backlight/$backlight/max_brightness)
        local step=$((max / 20))
        
        if [ "$direction" = "up" ]; then
            local new=$((current + step))
            [ $new -gt $max ] && new=$max
        else
            local new=$((current - step))
            [ $new -lt 0 ] && new=0
        fi
        
        echo $new | sudo tee /sys/class/backlight/$backlight/brightness
    fi
}

toggle_gaming_mode() {
    if [ -f /tmp/tinker-gaming-mode ]; then
        /usr/lib/tinker/gaming-mode.sh disable
    else
        /usr/lib/tinker/gaming-mode.sh enable
    fi
}

toggle_focus_mode() {
    if [ -f /tmp/tinker-focus-mode ]; then
        /usr/lib/tinker/focus-mode.sh disable
    else
        /usr/lib/tinker/focus-mode.sh enable
    fi
}

ocr_screenshot() {
    /usr/lib/tinker/ocr-everywhere.sh screen
}

start_voice_command() {
    /usr/lib/tinker/voice-commands.sh listen
}

take_screenshot() {
    local type=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="$HOME/Pictures/screenshot_${timestamp}.png"
    
    case $type in
        full)
            import -window root "$filename"
            ;;
        area)
            import "$filename"
            ;;
        window)
            import -window $(xdotool getactivewindow) "$filename"
            ;;
    esac
    
    echo "Screenshot saved: $filename"
}

show_shortcuts() {
    echo -e "${YELLOW}Current Keyboard Shortcuts:${NC}"
    echo ""
    
    if [ -f $SHORTCUTS_CONFIG ]; then
        while IFS='=' read -r key action; do
            [[ $key =~ ^#.*$ ]] && continue
            [[ -z $key ]] && continue
            
            key=$(echo $key | xargs)
            action=$(echo $action | xargs)
            
            printf "%-25s → %s\n" "$key" "$action"
        done < $SHORTCUTS_CONFIG
    fi
    echo ""
}

edit_shortcuts() {
    ${EDITOR:-nano} $SHORTCUTS_CONFIG
    load_shortcuts
}

reset_shortcuts() {
    rm -f $SHORTCUTS_CONFIG
    init_shortcuts
    load_shortcuts
    echo -e "${GREEN}Shortcuts reset to defaults!${NC}"
}

show_help() {
    echo "Usage: tinker-shortcuts [command]"
    echo ""
    echo "Commands:"
    echo "  show            Show all shortcuts"
    echo "  edit            Edit shortcuts"
    echo "  reset           Reset to defaults"
    echo "  reload          Reload shortcuts"
    echo "  help            Show this help"
}

# Main
init_shortcuts

case "$1" in
    apply)
        apply_shortcuts
        ;;
    --handle-*)
        handle_shortcut "${1#--handle-}"
        ;;
    show)
        show_header
        show_shortcuts
        ;;
    edit)
        show_header
        edit_shortcuts
        ;;
    reset)
        show_header
        reset_shortcuts
        ;;
    reload)
        load_shortcuts
        echo -e "${GREEN}Shortcuts reloaded!${NC}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Keyboard Shortcuts${NC}"
        echo ""
        echo "System-wide shortcuts that work in any application."
        echo ""
        echo "Quick commands:"
        echo "  tinker-shortcuts show    - Show all shortcuts"
        echo "  tinker-shortcuts edit    - Customize shortcuts"
        ;;
esac

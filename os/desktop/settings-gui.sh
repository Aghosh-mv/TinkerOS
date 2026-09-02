#!/bin/bash
# TinkerOS Settings GUI

set -e

CONFIG_DIR="$HOME/.tinker"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"

# Load settings
load_settings() {
    if [ -f "$SETTINGS_FILE" ]; then
        source "$SETTINGS_FILE"
    fi
}

# Save setting
save_setting() {
    local key=$1
    local value=$2
    
    if [ -f "$SETTINGS_FILE" ]; then
        sed -i "s/^$key=.*/$key=$value/" "$SETTINGS_FILE"
    else
        echo "$key=$value" >> "$SETTINGS_FILE"
    fi
}

# Main settings menu
show_settings() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                 TINKEROS SETTINGS                       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "  1)  Appearance"
    echo "  2)  Display"
    echo "  3)  Sound"
    echo "  4)  Network"
    echo "  5)  Bluetooth"
    echo "  6)  Power"
    echo "  7)  Privacy"
    echo "  8)  Security"
    echo "  9)  Keyboard"
    echo "  10) Mouse"
    echo "  11) Language"
    echo "  12) Date & Time"
    echo "  13) Users"
    echo "  14) About"
    echo ""
    echo "  0)  Exit"
    echo ""
    read -p "Choose (0-14): " choice
    
    case $choice in
        1) show_appearance ;;
        2) show_display ;;
        3) show_sound ;;
        4) show_network ;;
        5) show_bluetooth ;;
        6) show_power ;;
        7) show_privacy ;;
        8) show_security ;;
        9) show_keyboard ;;
        10) show_mouse ;;
        11) show_language ;;
        12) show_datetime ;;
        13) show_users ;;
        14) show_about ;;
        0) exit 0 ;;
        *) show_settings ;;
    esac
}

# Appearance settings
show_appearance() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  APPEARANCE"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Theme: ${THEME:-dark}"
    echo "  Accent: ${ACCENT:-blue}"
    echo "  Icons: ${ICONS:-default}"
    echo "  Font: ${FONT:-sans-serif}"
    echo ""
    echo "  1) Change theme (dark/light/auto)"
    echo "  2) Change accent color"
    echo "  3) Change icon theme"
    echo "  4) Change font"
    echo "  5) Back"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1)
            echo "  1) Dark  2) Light  3) Auto"
            read -p "  Choose: " theme
            case $theme in
                1) save_setting "THEME" "dark" ;;
                2) save_setting "THEME" "light" ;;
                3) save_setting "THEME" "auto" ;;
            esac
            show_appearance
            ;;
        2)
            echo "  1) Blue  2) Green  3) Purple  4) Red"
            read -p "  Choose: " color
            case $color in
                1) save_setting "ACCENT" "blue" ;;
                2) save_setting "ACCENT" "green" ;;
                3) save_setting "ACCENT" "purple" ;;
                4) save_setting "ACCENT" "red" ;;
            esac
            show_appearance
            ;;
        3) show_appearance ;;
        4) show_appearance ;;
        5) show_settings ;;
    esac
}

# Display settings
show_display() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  DISPLAY"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Resolution: $(xrandr 2>/dev/null | grep '*' | head -1 | awk '{print $1}')"
    echo "  Refresh Rate: $(xrandr 2>/dev/null | grep '*' | head -1 | awk '{print $2}')"
    echo "  Brightness: $(cat /sys/class/backlight/*/brightness 2>/dev/null || echo 'N/A')"
    echo ""
    echo "  1) Change resolution"
    echo "  2) Change refresh rate"
    echo "  3) Adjust brightness"
    echo "  4) Multi-monitor"
    echo "  5) Back"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1)
            echo "Available resolutions:"
            xrandr 2>/dev/null | grep "   " | awk '{print $1}'
            read -p "Enter resolution: " res
            xrandr --output $(xrandr | grep " connected" | head -1 | awk '{print $1}') --mode "$res" 2>/dev/null
            show_display
            ;;
        2) show_display ;;
        3) show_display ;;
        4) show_display ;;
        5) show_settings ;;
    esac
}

# Sound settings
show_sound() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  SOUND"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if command -v pactl >/dev/null 2>&1; then
        local vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1)
        echo "  Volume: $vol"
    fi
    
    echo ""
    echo "  1) Adjust volume"
    echo "  2) Change output device"
    echo "  3) Change input device"
    echo "  4) Test sound"
    echo "  5) Back"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1)
            read -p "Volume (0-100): " vol
            pactl set-sink-volume @DEFAULT_SINK@ "${vol}%"
            show_sound
            ;;
        2) show_sound ;;
        3) show_sound ;;
        4) show_sound ;;
        5) show_settings ;;
    esac
}

# Network settings
show_network() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  NETWORK"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  WiFi: $(iwgetid -r 2>/dev/null || echo 'Disconnected')"
    echo "  IP: $(hostname -I 2>/dev/null | awk '{print $1}')"
    echo ""
    echo "  1) WiFi settings"
    echo "  2) Ethernet settings"
    echo "  3) VPN"
    echo "  4) Proxy"
    echo "  5) Back"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1) show_network ;;
        2) show_network ;;
        3) show_network ;;
        4) show_network ;;
        5) show_settings ;;
    esac
}

# Placeholder settings
show_bluetooth() { echo "Bluetooth settings"; read -p "Press Enter..."; show_settings; }
show_power() { echo "Power settings"; read -p "Press Enter..."; show_settings; }
show_privacy() { echo "Privacy settings"; read -p "Press Enter..."; show_settings; }
show_security() { echo "Security settings"; read -p "Press Enter..."; show_settings; }
show_keyboard() { echo "Keyboard settings"; read -p "Press Enter..."; show_settings; }
show_mouse() { echo "Mouse settings"; read -p "Press Enter..."; show_settings; }
show_language() { echo "Language settings"; read -p "Press Enter..."; show_settings; }
show_datetime() { echo "Date & Time settings"; read -p "Press Enter..."; show_settings; }
show_users() { echo "User settings"; read -p "Press Enter..."; show_settings; }

# About
show_about() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  ABOUT TINKEROS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  TinkerOS v1.0"
    echo "  Built on Linux Kernel 7.2.0"
    echo ""
    echo "  Your computer. Your rules."
    echo ""
    echo "  Kernel: $(uname -r)"
    echo "  OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2)"
    echo ""
    read -p "Press Enter..."
    show_settings
}

# Main
load_settings
show_settings

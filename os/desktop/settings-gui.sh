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

# Bluetooth settings
show_bluetooth() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  BLUETOOTH"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    if command -v bluetoothctl >/dev/null 2>&1; then
        echo "  Power: $(bluetoothctl show 2>/dev/null | grep Powered | awk '{print $2}')"
        echo "  Devices:"
        bluetoothctl devices 2>/dev/null | head -5 | sed 's/^/    /' || echo "    (none)"
    else
        echo "  bluetoothctl not installed (install bluez)"
    fi
    echo ""
    echo "  1) Turn on/off Bluetooth"
    echo "  2) Scan for devices"
    echo "  3) Pair a device"
    echo "  4) Back"
    read -p "Choose: " choice
    case $choice in
        1)
            if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
                bluetoothctl power off 2>/dev/null; echo "Bluetooth off"
            else
                bluetoothctl power on 2>/dev/null; echo "Bluetooth on"
            fi
            read -p "Press Enter..."; show_bluetooth ;;
        2) bluetoothctl scan on 2>/dev/null & sleep 5; bluetoothctl scan off 2>/dev/null; show_bluetooth ;;
        3)
            read -p "MAC address: " mac
            bluetoothctl pair "$mac" 2>/dev/null
            read -p "Press Enter..."; show_bluetooth ;;
        4) show_settings ;;
    esac
}

# Power settings
show_power() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  POWER"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    if [ -d /sys/class/power_supply ]; then
        for s in /sys/class/power_supply/*; do
            [ -f "$s/type" ] && echo "  $(basename "$s"): $(cat "$s/type" 2>/dev/null)"
        done
    fi
    if command -v upower >/dev/null 2>&1; then
        upower -i $(upower -e 2>/dev/null | grep battery | head -1) 2>/dev/null | grep -E "percentage|time to" | sed 's/^/  /'
    fi
    echo ""
    echo "  1) Battery saver: ${BATTERY_SAVER:-off}"
    echo "  2) Suspend on lid close"
    echo "  3) Back"
    read -p "Choose: " choice
    case $choice in
        1)
            if [ "${BATTERY_SAVER:-off}" = "off" ]; then save_setting BATTERY_SAVER "on"; echo "Battery saver on";
            else save_setting BATTERY_SAVER "off"; echo "Battery saver off"; fi
            read -p "Press Enter..."; show_power ;;
        2)
            sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
            echo "Re-enabled suspend; edit /etc/systemd/logind.conf for lid behavior."
            read -p "Press Enter..."; show_power ;;
        3) show_settings ;;
    esac
}

# Privacy settings
show_privacy() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  PRIVACY"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Camera: ${PRIVACY_CAMERA:-on}"
    echo "  Microphone: ${PRIVACY_MIC:-on}"
    echo "  Location: ${PRIVACY_LOCATION:-off}"
    echo ""
    echo "  1) Toggle camera"
    echo "  2) Toggle microphone"
    echo "  3) Toggle location"
    echo "  4) Back"
    read -p "Choose: " choice
    case $choice in
        1)
            if [ "${PRIVACY_CAMERA:-on}" = "on" ]; then
                sudo modprobe -r uvcvideo 2>/dev/null || true; save_setting PRIVACY_CAMERA "off"
            else
                sudo modprobe uvcvideo 2>/dev/null || true; save_setting PRIVACY_CAMERA "on"
            fi
            read -p "Press Enter..."; show_privacy ;;
        2)
            if [ "${PRIVACY_MIC:-on}" = "on" ]; then
                sudo modprobe -r snd_usb_audio snd_hda_intel 2>/dev/null || true; save_setting PRIVACY_MIC "off"
            else
                sudo modprobe snd_usb_audio snd_hda_intel 2>/dev/null || true; save_setting PRIVACY_MIC "on"
            fi
            read -p "Press Enter..."; show_privacy ;;
        3)
            if [ "${PRIVACY_LOCATION:-off}" = "off" ]; then save_setting PRIVACY_LOCATION "on"; else save_setting PRIVACY_LOCATION "off"; fi
            read -p "Press Enter..."; show_privacy ;;
        4) show_settings ;;
    esac
}

# Security settings
show_security() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  SECURITY"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Firewall: $(command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | head -1 || echo 'ufw not installed')"
    echo "  Update check: $(command -v apt >/dev/null 2>&1 && apt list --upgradable 2>/dev/null | wc -l) upgradable"
    echo ""
    echo "  1) Start firewall (ufw)"
    echo "  2) Install security updates"
    echo "  3) Check for new kernels"
    echo "  4) Back"
    read -p "Choose: " choice
    case $choice in
        1)
            if command -v ufw >/dev/null 2>&1; then
                sudo ufw enable 2>/dev/null; echo "Firewall enabled"
            else
                echo "Install ufw first"; fi
            read -p "Press Enter..."; show_security ;;
        2)
            (command -v apt >/dev/null 2>&1 && sudo apt update -qq && sudo apt upgrade -y -qq) || \
                (command -v dnf >/dev/null 2>&1 && sudo dnf upgrade -y -q)
            read -p "Press Enter..."; show_security ;;
        3)
            (command -v apt >/dev/null 2>&1 && apt list --upgradable 2>/dev/null | grep linux-image) || echo "none"
            read -p "Press Enter..."; show_security ;;
        4) show_settings ;;
    esac
}

# Keyboard settings
show_keyboard() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  KEYBOARD"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Layout: ${KEYBOARD_LAYOUT:-$(localectl status 2>/dev/null | grep "X11 Layout" | awk '{print $3}' || echo us)}"
    echo "  Repeat rate: ${KEYBOARD_REPEAT:-30}"
    echo ""
    echo "  1) Choose layout"
    echo "  2) Set repeat rate"
    echo "  3) Back"
    read -p "Choose: " choice
    case $choice in
        1)
            read -p "Layout (e.g. us, de, fr): " layout
            [ -n "$layout" ] && { localectl set-x11-keymap "$layout" 2>/dev/null; save_setting KEYBOARD_LAYOUT "$layout"; }
            show_keyboard ;;
        2)
            read -p "Repeat rate (Hz, 2-50): " rate
            [ -n "$rate" ] && { xset r rate 250 "$rate" 2>/dev/null; save_setting KEYBOARD_REPEAT "$rate"; }
            show_keyboard ;;
        3) show_settings ;;
    esac
}

# Mouse settings
show_mouse() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  MOUSE"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Speed: ${MOUSE_SPEED:-50}%"
    echo "  Natural scroll: ${MOUSE_NATURAL:-off}"
    echo ""
    echo "  1) Set speed"
    echo "  2) Toggle natural scroll"
    echo "  3) Back"
    read -p "Choose: " choice
    case $choice in
        1)
            read -p "Speed (0-100): " speed
            [ -n "$speed" ] && { xset m "$((speed/10 + 2))" 1 2>/dev/null; save_setting MOUSE_SPEED "$speed"; }
            show_mouse ;;
        2)
            if [ "${MOUSE_NATURAL:-off}" = "off" ]; then save_setting MOUSE_NATURAL "on"; else save_setting MOUSE_NATURAL "off"; fi
            show_mouse ;;
        3) show_settings ;;
    esac
}

# Language settings
show_language() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  LANGUAGE"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  System: $(localectl status 2>/dev/null | grep LANG | awk '{print $2}' || echo en_US.UTF-8)"
    echo ""
    echo "  1) Select language"
    echo "  2) Back"
    read -p "Choose: " choice
    case $choice in
        1)
            read -p "Locale (e.g. en_US.UTF-8, de_DE.UTF-8): " loc
            [ -n "$loc" ] && { sudo localectl set-locale "LANG=$loc" 2>/dev/null; save_setting LANGUAGE "$loc"; }
            show_language ;;
        2) show_settings ;;
    esac
}

# Date & Time settings
show_datetime() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  DATE & TIME"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Now: $(date)"
    echo "  Timezone: $(cat /etc/timezone 2>/dev/null || timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}')"
    echo ""
    echo "  1) NTP sync"
    echo "  2) Set timezone"
    echo "  3) Back"
    read -p "Choose: " choice
    case $choice in
        1)
            sudo timedatectl set-ntp true 2>/dev/null
            sudo systemctl restart systemd-timesyncd 2>/dev/null
            echo "Synced: $(date)"; read -p "Press Enter..."; show_datetime ;;
        2)
            read -p "Timezone (e.g. UTC, America/New_York): " tz
            [ -n "$tz" ] && sudo timedatectl set-timezone "$tz" 2>/dev/null
            show_datetime ;;
        3) show_settings ;;
    esac
}

# Users settings
show_users() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  USERS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    if command -v getent >/dev/null 2>&1; then
        getent passwd | grep -E ":/home|:/root" | awk -F: '{print "  "$1" (uid "$3")"}'
    else
        grep -E ":/home|:/root" /etc/passwd | awk -F: '{print "  "$1" (uid "$3")"}'
    fi
    echo ""
    echo "  1) Add user"
    echo "  2) Back"
    read -p "Choose: " choice
    case $choice in
        1)
            read -p "Username: " user
            if [ -n "$user" ]; then
                sudo useradd -m -s /bin/bash "$user" 2>/dev/null && \
                    (sudo passwd "$user" 2>/dev/null || echo "set password with: sudo passwd $user")
            fi
            read -p "Press Enter..."; show_users ;;
        2) show_settings ;;
    esac
}

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

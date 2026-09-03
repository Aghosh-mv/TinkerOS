#!/bin/bash
# TinkerOS Audio Mixer - Device, volume, and per-application audio control

set -e

AM_DIR="$HOME/.tinker/audio"
mkdir -p "$AM_DIR"

# Detect audio backend
detect_backend() {
    if command -v wpctl &>/dev/null; then echo "wireplumber"
    elif command -v pactl &>/dev/null; then echo "pulseaudio"
    elif command -v amixer &>/dev/null; then echo "alsa"
    else echo "none"
    fi
}

# List audio devices
devices() {
    local backend=$(detect_backend)
    echo "=== Audio Devices (backend: $backend) ==="
    echo ""
    
    case $backend in
        wireplumber)
            echo "Sinks (output):"
            wpctl status 2>/dev/null | sed 's/^/  /'
            ;;
        pulseaudio)
            echo "Sinks (output):"
            pactl list short sinks 2>/dev/null | sed 's/^/  /'
            echo ""
            echo "Sources (input):"
            pactl list short sources 2>/dev/null | sed 's/^/  /'
            ;;
        alsa)
            echo "Sound cards:"
            cat /proc/asound/cards 2>/dev/null | sed 's/^/  /'
            echo ""
            echo "Control elements:"
            amixer -c 0 scontrols 2>/dev/null | sed 's/^/  /'
            ;;
        none)
            echo "  No audio backend (wpctl/pactl/amixer)"
            ;;
    esac
}

# Show volume
volume() {
    local backend=$(detect_backend)
    echo "=== Current Volume ==="
    echo ""
    
    case $backend in
        wireplumber)
            wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed 's/^/  Volume: /'
            wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | sed 's/^/  Mic: /'
            ;;
        pulseaudio)
            pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | sed 's/^/  Volume: /'
            pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | sed 's/^/  Mic: /'
            ;;
        alsa)
            amixer get Master 2>/dev/null | grep -E "Front|Mono|\[" | sed 's/^/  /'
            ;;
        none)
            echo "  No audio backend"
            ;;
    esac
}

# Set volume
set_vol() {
    local level=${1:-50}
    local backend=$(detect_backend)
    
    echo "Setting volume to $level%"
    
    case $backend in
        wireplumber) wpctl set-volume @DEFAULT_AUDIO_SINK@ "$level%" ;;
        pulseaudio) pactl set-sink-volume @DEFAULT_SINK@ "$level%" ;;
        alsa) amixer set Master "$level%" ;;
        none) echo "No audio backend"; return 1 ;;
    esac
}

# Adjust volume up/down
adjust() {
    local direction=$1
    local backend=$(detect_backend)
    local step=${2:-5}
    
    case $backend in
        wireplumber)
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "${step}%$direction"
            ;;
        pulseaudio)
            if [ "$direction" = "+" ]; then
                pactl set-sink-volume @DEFAULT_SINK@ "+${step}%"
            else
                pactl set-sink-volume @DEFAULT_SINK@ "-${step}%"
            fi
            ;;
        alsa)
            amixer set Master "${step}%$direction"
            ;;
        none)
            echo "No audio backend"; return 1
            ;;
    esac
    
    volume
}

# Mute/unmute
mute() {
    local which=${1:-output}
    local backend=$(detect_backend)
    
    case $backend in
        wireplumber)
            case $which in
                output) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
                mic|input) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
            esac
            ;;
        pulseaudio)
            case $which in
                output) pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
                mic|input) pactl set-source-mute @DEFAULT_SOURCE@ toggle ;;
            esac
            ;;
        alsa)
            amixer set Master toggle
            ;;
        none)
            echo "No audio backend"; return 1
            ;;
    esac
    
    echo "Toggled $which mute"
    volume
}

# Set default device
set_default() {
    local dev=$1
    local backend=$(detect_backend)
    [ -z "$dev" ] && { echo "Usage: $0 set-default <device-name>"; devices; return 1; }
    
    case $backend in
        wireplumber) wpctl set-default "$dev" 2>/dev/null || echo "  Device not found: $dev" ;;
        pulseaudio) pactl set-default-sink "$dev" 2>/dev/null || echo "  Device not found: $dev" ;;
        *) echo "  Backend doesn't support this" ;;
    esac
}

# Per-application volume
app_volume() {
    local backend=$(detect_backend)
    echo "=== Per-Application Audio ==="
    echo ""
    
    case $backend in
        pulseaudio)
            echo "Playing streams:"
            pactl list short sink-inputs 2>/dev/null | while read line; do
                local id=$(echo "$line" | cut -d$'\t' -f1)
                local app=$(echo "$line" | cut -d$'\t' -f3)
                local vol=$(pactl list sink-inputs 2>/dev/null | awk -v id="$id" '$0 ~ /Sink Input #/ {match($0, /#[0-9]+/, m); if (m[0] == "#" id) getline}')
                echo "  #$id $app"
            done
            ;;
        wireplumber)
            wpctl status 2>/dev/null | grep -A30 "Applications" | sed 's/^/  /'
            ;;
        *)
            echo "  Per-app control requires pulseaudio/wireplumber"
            ;;
    esac
}

# Set app volume
set_app_vol() {
    local app=$1
    local level=${2:-50}
    local backend=$(detect_backend)
    
    [ -z "$app" ] && { echo "Usage: $0 app <app-name> [level]"; return 1; }
    
    case $backend in
        pulseaudio)
            local id=$(pactl list short sink-inputs 2>/dev/null | grep -i "$app" | head -1 | cut -d$'\t' -f1)
            [ -n "$id" ] && pactl set-sink-input-volume "$id" "$level%" && echo "Set $app to $level%" || echo "App not playing: $app"
            ;;
        *)
            echo "  Requires pulseaudio"
            ;;
    esac
}

# Balance
balance() {
    local left=${1:-100}
    local right=${2:-100}
    local backend=$(detect_backend)
    
    case $backend in
        alsa)
            amixer set Master ${left}%,${right}% 2>/dev/null
            echo "Set balance L${left}% R${right}%"
            ;;
        *)
            echo "  Balance control requires ALSA mixer"
            ;;
    esac
}

show_help() {
    echo "Usage: tinker-audio [command]"
    echo ""
    echo "Commands:"
    echo "  devices             List audio devices"
    echo "  volume              Show current volume"
    echo "  set <level>         Set volume (0-100)"
    echo "  up [step]           Increase volume"
    echo "  down [step]         Decrease volume"
    echo "  mute [output|mic]   Toggle mute"
    echo "  set-default <dev>   Set default device"
    echo "  app <name> [level]  Per-app volume control"
    echo "  balance <L> <R>     Set left/right balance"
    echo "  help                Show this help"
}

case "$1" in
    devices) devices ;;
    volume|vol) volume ;;
    set) set_vol "$2" ;;
    up) adjust "+" "$2" ;;
    down) adjust "-" "$2" ;;
    mute) mute "$2" ;;
    set-default) set_default "$2" ;;
    app) set_app_vol "$2" "$3" ;;
    balance) balance "$2" "$3" ;;
    *) show_help ;;
esac
#!/bin/bash
# TinkerOS Streaming Manager - OBS/Twitch integration

set -e

STREAM_DIR="$HOME/.tinker/streaming"
CONFIG_FILE="$STREAM_DIR/config.conf"
PROFILES_DIR="$STREAM_DIR/profiles"

mkdir -p "$STREAM_DIR" "$PROFILES_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Streaming Manager Configuration
ENABLED=false
DEFAULT_PLATFORM=twitch
DEFAULT_QUALITY=1080p60
ENABLE_OVERLAY=true
ENABLE_ALERTS=true
EOF
    fi
}

# Check OBS
check_obs() {
    echo "Checking OBS installation..."
    
    if command -v obs >/dev/null 2>&1; then
        echo "OBS Studio: Installed"
        echo "  Version: $(obs --version 2>/dev/null | head -1)"
    else
        echo "OBS Studio: Not installed"
        echo "  Install: sudo apt install obs-studio"
    fi
}

# Configure OBS for streaming
configure_obs() {
    echo "Configuring OBS for streaming..."
    
    mkdir -p ~/.config/obs-studio/basic/profiles/TinkerOS
    
    cat > ~/.config/obs-studio/basic/profiles/TinkerOS/basic.ini << 'EOF'
[General]
Name=TinkerOS Streaming

[Video]
BaseCX=1920
BaseCY=1080
OutputCX=1920
OutputCY=1080
FPSCommon=60

[Output]
Mode=Simple
Encoder=obs_x264
Bitrate=6000
EOF
    
    echo "OBS configured for TinkerOS"
}

# Setup Twitch
setup_twitch() {
    echo "Twitch Streaming Setup"
    echo ""
    echo "1. Get stream key from: https://dashboard.twitch.tv/settings/stream"
    echo "2. In OBS: Settings > Stream > Service: Twitch"
    echo "3. Paste your stream key"
    echo ""
    echo "For alerts and overlays, use Streamlabs or StreamElements"
}

# Setup YouTube
setup_youtube() {
    echo "YouTube Streaming Setup"
    echo ""
    echo "1. Enable live streaming at: https://studio.youtube.com"
    echo "2. Get stream key from YouTube Studio"
    echo "3. In OBS: Settings > Stream > Service: YouTube"
    echo "4. Paste your stream key"
}

show_help() {
    echo "Usage: tinker-stream [command]"
    echo ""
    echo "Commands:"
    echo "  check             Check OBS installation"
    echo "  configure         Configure OBS for streaming"
    echo "  twitch            Setup Twitch streaming"
    echo "  youtube           Setup YouTube streaming"
    echo "  help              Show this help"
}

init

case "$1" in
    check) check_obs ;;
    configure|config) configure_obs ;;
    twitch) setup_twitch ;;
    youtube) setup_youtube ;;
    *) show_help ;;
esac

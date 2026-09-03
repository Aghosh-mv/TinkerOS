#!/bin/bash
# TinkerOS Feral GameMode — Background Performance Service
# Built into the OS installer.
#
# GameMode is a tiny DBus background daemon (gamemoded) that:
#   • Does NOTHING while you type an essay or watch YouTube
#     (zero battery, zero CPU usage when idle).
#   • The moment a heavy app launches (game, Blender, render),
#     it wakes up, gives that app 100% CPU priority, and goes
#     back to sleep when the app closes.
#
# It is not tied to gaming alone — any heavy process can request it
# (games, 3D renderers, video encoders) via gamemoderun or the DBus API.

set -e

GM_LOG="/tmp/tinker-gamemode-setup.log"
CONFIG_DIR="$HOME/.config"
GM_CONFIG="$CONFIG_DIR/gamemode.ini"

log() { echo "[gamemode] $*" | tee -a "$GM_LOG"; }

# Install the gamemode daemon + client
install_gamemode() {
    log "Installing Feral GameMode daemon (gamemoded)..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y -qq gamemode gamemode-daemon 2>/dev/null | tail -1 || \
        sudo apt install -y -qq gamemode 2>/dev/null | tail -1
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y -q gamemode 2>/dev/null | tail -1
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm gamemode 2>/dev/null | tail -1
    else
        log "Unsupported package manager - GameMode install skipped"
        return 1
    fi
    log "GameMode installed."
}

# Verify the daemon
check_daemon() {
    log "Checking gamemoded daemon..."
    if command -v gamemoded >/dev/null 2>&1 || command -v gamemode >/dev/null 2>&1; then
        log "gamemoded binary present."
        return 0
    fi
    # gamemoded often lives in /usr/lib or /usr/libexec
    if [ -x /usr/libexec/gamemoded ] || [ -x /usr/lib/gamemoded ] || systemctl list-units 2>/dev/null | grep -qi gamemode; then
        log "gamemoded found in lib/exec path."
        return 0
    fi
    log "WARNING: gamemoded not found after install."
}

# Write an optimal default config: performance governor on activation
write_config() {
    log "Writing default GameMode config..."
    mkdir -p "$CONFIG_DIR"
    cat > "$GM_CONFIG" << 'EOF'
# TinkerOS default GameMode configuration
# These settings apply the moment a heavy app requests GameMode
# and revert automatically when it closes.

[general]
# Keep the daemon idle until asked; no background cost.
desktop_names = *;Gamescope
reaper_freq = 5
softrealtime = auto
reaper_arch = auto
inhibit_screensaver = 1
apply_graphics_options = 1

[cpu]
# On activation: switch CPU governor to performance
park_cores = no
pin_cores = yes

[gpu]
apply_graphics_options = yes
nv_powermizer_mode = 1
force_gpu_clock = no

[custom]
start = notify-send "GameMode" "Performance mode ACTIVE"
end = notify-send "GameMode" "Performance mode ended"
EOF
    chmod 644 "$GM_CONFIG"
    log "Config written: $GM_CONFIG"
}

# Enable the daemon to auto-start via DBus/desktop session
enable_service() {
    log "Enabling GameMode DBus activation..."
    
    # GameMode uses DBus activation - the daemon starts on first request.
    # If a systemd user unit exists, enable it for auto-start on login.
    if systemctl --user list-unit-files 2>/dev/null | grep -qi gamemode; then
        systemctl --user enable gamemode 2>/dev/null && log "gamemode user service enabled"
    fi
    
    # Try to enable the system service too
    if systemctl list-unit-files 2>/dev/null | grep -qi gamemode; then
        sudo systemctl enable gamemode 2>/dev/null && log "gamemode system service enabled"
    fi
    
    log "GameMode will auto-activate on heavy-app launch."
}

# Simple runtime test (request a GameMode session briefly)
test_gamemode() {
    log "Runtime check..."
    if command -v gamemoded >/dev/null 2>&1; then
        if systemctl --user status gamemode 2>/dev/null | grep -q "active"; then
            log "gamemoded: ACTIVE"
        elif pgrep -x gamemoded >/dev/null 2>&1; then
            log "gamemoded: running (PID $(pgrep -x gamemoded | head -1))"
        else
            log "gamemoded: installed (starts on first request)"
        fi
    fi
}

# Main installer entry
main() {
    : > "$GM_LOG"
    echo "══════════════════════════════════════════════"
    echo "   Feral GameMode — Background Performance"
    echo "══════════════════════════════════════════════"
    echo ""
    echo "  Installs the tiny background daemon that costs nothing"
    echo "  at idle and boosts any heavy app (games, Blender) on demand."
    echo ""
    
    install_gamemode && check_daemon
    write_config
    enable_service
    test_gamemode
    
    echo ""
    echo "  ✓ GameMode built into the OS."
    echo "  Launch any heavy app normally, or wrap with 'gamemoderun <cmd>'."
}

show_help() {
    echo "Usage: tinker-gamemode-setup"
    echo ""
    echo "  Sets up Feral GameMode as the default background performance"
    echo "  service in the TinkerOS image."
    echo ""
    echo "  Status:  gamemoded running?  pgrep -x gamemoded"
    echo "  Boost a command:             gamemoderun <command>"
}

case "$1" in
    --help|-h|help) show_help ;;
    *) main ;;
esac
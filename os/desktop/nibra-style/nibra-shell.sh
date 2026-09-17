#!/bin/bash
# KorrinOS Desktop Shell v2.0
# Frosted glass, smooth layout, KorrinOS identity — served as a real desktop
# home powered by server.py, wired into REAL VOKK v4 + world engine + system.

set -euo pipefail

KORRINOS_DIR="/opt/korrinos/os"
DESKTOP_DIR="$KORRINOS_DIR/desktop/nibra-style"
PICOM_CONF="$DESKTOP_DIR/picom.conf"
SERVER="$DESKTOP_DIR/server.py"
DESKTOP_URL="http://127.0.0.1:8898/"
WALLPAPER_DIR="/usr/share/korrinos/wallpapers"

log() { echo "[korrinos-desktop] $(date '+%H:%M:%S') $*"; }

# ============================================
#  WALLPAPER — soft blue/white gradient
# ============================================
setup_wallpaper() {
    log "Setting up KorrinOS wallpaper..."
    mkdir -p "$WALLPAPER_DIR"
    WP="$WALLPAPER_DIR/korrinos-desktop.png"

    if [ ! -f "$WP" ]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 << 'PYEOF' "$WP"
import sys
try:
    from PIL import Image
except ImportError:
    sys.exit(1)

w, h = 1920, 1080
img = Image.new('RGB', (w, h))
pixels = img.load()

for y in range(h):
    for x in range(w):
        t = y / h
        r = int(150 + 70 * t)
        g = int(195 + 45 * t)
        b = int(240 + 10 * t)
        # warm glow lower-right
        dx = (x - w*0.7) / w
        dy = (y - h*0.75) / h
        dist = (dx*dx + dy*dy) ** 0.5
        glow = max(0.0, 1 - dist*2.2)
        r = min(255, int(r + 40 * glow))
        g = min(255, int(g + 30 * glow))
        b = min(255, int(b + 20 * glow))
        pixels[x, y] = (r, g, b)

img.save(sys.argv[1])
PYEOF
        fi
    fi

    if [ -f "$WP" ]; then
        feh --bg-fill "$WP" 2>/dev/null || \
        nitrogen --set-zoom-fill "$WP" 2>/dev/null || \
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$WP" 2>/dev/null || true
        log "Wallpaper set."
    fi
}

# ============================================
#  PICOM — frosted glass compositor
# ============================================
start_picom() {
    log "Starting picom..."
    pkill picom 2>/dev/null || true
    sleep 0.3
    if command -v picom >/dev/null 2>&1; then
        picom --config "$PICOM_CONF" -b --experimental-backends 2>/dev/null || \
        picom --config "$PICOM_CONF" -b 2>/dev/null || \
        log "picom failed"
        sleep 0.5
    fi
}

# ============================================
#  DESKTOP SERVER + UI
# ============================================
start_server() {
    log "Starting desktop server (port 8898)..."
    if ! curl -s -m 1 "$DESKTOP_URL" -o /dev/null 2>/dev/null; then
        python3 "$SERVER" --foreground >/dev/null 2>&1 &
        sleep 1
    fi
    if curl -s -m 1 "$DESKTOP_URL" -o /dev/null 2>/dev/null; then
        log "Desktop server is up."
    else
        log "WARNING: desktop server did not start."
    fi
}

open_desktop() {
    log "Opening KorrinOS Desktop home..."
    # Prefer a chromeless webview-style window; fall back to the default browser.
    if command -v epiphany >/dev/null 2>&1; then
        epiphany -a --navigation-expansion-level=0 "$DESKTOP_URL" >/dev/null 2>&1 &
    elif command -v firefox >/dev/null 2>&1; then
        firefox --new-window "$DESKTOP_URL" >/dev/null 2>&1 &
    else
        xdg-open "$DESKTOP_URL" >/dev/null 2>&1 &
    fi
}

launch() {
    log "Launching KorrinOS Desktop..."
    pkill -f korrinos-liquid-glass 2>/dev/null || true
    pkill -f korrinos-widgets-panel 2>/dev/null || true
    pkill -f korrinos-dock 2>/dev/null || true
    pkill -f korrinos-smoothui 2>/dev/null || true
    sleep 0.3

    setup_wallpaper
    start_picom
    start_server
    open_desktop
    log "KorrinOS Desktop ready."
}

stop() {
    log "Stopping..."
    pkill picom 2>/dev/null || true
    pkill -f "nibra-style/server.py" 2>/dev/null || true
    log "Stopped."
}

case "${1:-start}" in
    start|launch) launch ;;
    stop) stop ;;
    restart) stop; sleep 1; launch ;;
    status)
        curl -s -m 1 "$DESKTOP_URL" -o /dev/null 2>/dev/null && echo "server: running" || echo "server: stopped"
        pgrep -a picom >/dev/null && echo "picom: running" || echo "picom: stopped"
        ;;
    *) echo "Usage: $0 {start|stop|restart|status}" ;;
esac
#!/bin/bash
# TinkerOS Conky/System Stats - Desktop widgets
set -e
CONKY_DIR="$HOME/.tinker/conky"
CONKYRC="$CONKY_DIR/conky.conf"
mkdir -p "$CONKY_DIR"

[ ! -f "$CONKYRC" ] && cat > "$CONKYRC" << 'CONF'
conky.config = {
    alignment = 'top_right', background = true, font = 'Monospace:size=10',
    gap_x = 50, gap_y = 50, minimum_width = 250, own_window = true,
    own_window_type = 'desktop', own_window_transparent = true, update_interval = 1.0,
};
conky.text = [[
${color white}SYSTEM${hr 2}
${color cyan}Kernel:${color white} $kernel
${color cyan}Uptime:${color white} $uptime
${color white}CPU${hr 2}${color cyan}Usage:${color white} $cpu%
${cpubar}
${color white}MEMORY${hr 2}${color cyan}RAM:${color white} $mem/$memmax
${membar}
${color white}NETWORK${hr 2}${color cyan}Down:${color white} ${downspeed eth0}
${color cyan}Up:${color white} ${upspeed eth0}
]];
CONF

start() {
    if command -v conky >/dev/null 2>&1; then
        conky -d -c "$CONKYRC" &
        echo "Conky started"
    else
        echo "Install conky: sudo apt install conky-all"
    fi
}
stop() { pkill conky 2>/dev/null && echo "Conky stopped"; }
edit() { nano "$CONKYRC"; }

show_help() { echo "Usage: tinker-conky [start|stop|edit]"; }

case "$1" in
    start|on) start ;;
    stop|off) stop ;;
    edit|config) edit ;;
    *) show_help ;;
esac

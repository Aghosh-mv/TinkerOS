#!/bin/bash
# KorrinOS Mascot Framework v1.0
# Hooks for a desktop companion character
# NO CONTENT YET — waiting for user's mascot file
# Just the framework: event hooks, click handler, positioning

MASCOT_DIR="/opt/korrinos/os/mascot"
MASCOT_HTML="$MASCOT_DIR/mascot.html"
MASCOT_EVENTS="$MASCOT_DIR/events.conf"
MASCOT_LOG="${HOME}/.cache/korrinos-mascot.log"

# ============================================================
#  EVENT SYSTEM — hooks for system events
# ============================================================
# When the user provides their mascot file, events trigger reactions
# Format: EVENT_NAME → callback function

declare -A MASCOT_HOOKS

register_hook() {
    local event="$1"
    local callback="$2"
    MASCOT_HOOKS["$event"]="$callback"
    echo "[$(date '+%H:%M:%S')] Hook registered: $event → $callback" >> "$MASCOT_LOG" 2>/dev/null || true
}

# Pre-registered event hooks (stubs — will activate when mascot content arrives)
register_hook "compile_start"     "on_compile_start"
register_hook "compile_done"      "on_compile_done"
register_hook "game_launch"       "on_game_launch"
register_hook "trash_empty"       "on_trash_empty"
register_hook "high_cpu"          "on_high_cpu"
register_hook "high_memory"       "on_high_memory"
register_hook "low_battery"       "on_low_battery"
register_hook "network_down"      "on_network_down"
register_hook "network_up"        "on_network_up"
register_hook "update_available"  "on_update_available"
register_hook "install_done"      "on_install_done"
register_hook "click"             "on_click"
register_hook "boot"              "on_boot"
register_hook "wake"              "on_wake"
register_hook "shutdown"          "on_shutdown"

# ============================================================
#  STUB CALLBACKS — placeholder implementations
#  Replace with real content when user provides mascot file
# ============================================================
on_compile_start() {
    echo "[mascot] Compile started — ready for reactions"
}

on_compile_done() {
    echo "[mascot] Compile done — ready for reactions"
}

on_game_launch() {
    echo "[mascot] Game launched — ready for reactions"
}

on_trash_empty() {
    echo "[mascot] Trash emptied — ready for reactions"
}

on_high_cpu() {
    echo "[mascot] CPU high — ready for reactions"
}

on_high_memory() {
    echo "[mascot] Memory high — ready for reactions"
}

on_low_battery() {
    echo "[mascot] Battery low — ready for reactions"
}

on_network_down() {
    echo "[mascot] Network down — ready for reactions"
}

on_network_up() {
    echo "[mascot] Network up — ready for reactions"
}

on_update_available() {
    echo "[mascot] Update available — ready for reactions"
}

on_install_done() {
    echo "[mascot] Install done — ready for reactions"
}

on_click() {
    echo "[mascot] Clicked — ready for reactions"
}

on_boot() {
    echo "[mascot] Booted — ready for reactions"
}

on_wake() {
    echo "[mascot] Woke up — ready for reactions"
}

on_shutdown() {
    echo "[mascot] Shutting down — ready for reactions"
}

# ============================================================
#  EVENT TRIGGER — call this to fire an event
# ============================================================
trigger_event() {
    local event="$1"
    local callback="${MASCOT_HOOKS[$event]:-}"
    
    if [ -n "$callback" ]; then
        $callback
        echo "[$(date '+%H:%M:%S')] Event triggered: $event" >> "$MASCOT_LOG" 2>/dev/null || true
    else
        echo "[$(date '+%H:%M:%S')] Unknown event: $event" >> "$MASCOT_LOG" 2>/dev/null || true
    fi
}

# ============================================================
#  SYSTEMD SERVICE — mascot daemon
# ============================================================
install_service() {
    sudo tee /etc/systemd/system/korrinos-mascot.service > /dev/null << 'EOF'
[Unit]
Description=KorrinOS Desktop Mascot
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
ExecStart=/opt/korrinos/os/mascot/mascot-daemon.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    echo "Mascot service installed (will activate when content arrives)"
}

# ============================================================
#  MAIN
# ============================================================
case "${1:-}" in
    trigger)
        trigger_event "${2:-click}"
        ;;
    status)
        echo "Mascot Framework v1.0"
        echo ""
        echo "Registered hooks:"
        for event in "${!MASCOT_HOOKS[@]}"; do
            echo "  $event → ${MASCOT_HOOKS[$event]}"
        done
        echo ""
        echo "Status: Waiting for mascot content from user"
        ;;
    install)
        install_service
        ;;
    test)
        echo "=== Mascot Framework Test ==="
        trigger_event "boot"
        trigger_event "click"
        trigger_event "compile_start"
        trigger_event "low_battery"
        ;;
    *)
        echo "KorrinOS Mascot Framework v1.0"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  trigger <event>  Fire a mascot event"
        echo "  status           Show registered hooks"
        echo "  install          Install systemd service"
        echo "  test             Test event system"
        echo ""
        echo "Events: boot, wake, shutdown, click, compile_start,"
        echo "        compile_done, game_launch, trash_empty,"
        echo "        high_cpu, high_memory, low_battery,"
        echo "        network_down, network_up, update_available, install_done"
        ;;
esac

#!/bin/bash
# TinkerOS Gatekeeper - Application execution policy and security gating

set -e

GK_DIR="$HOME/.tinker/gatekeeper"
CONFIG_FILE="$GK_DIR/config.conf"
ALLOW_LIST="$GK_DIR/allowlist"
DENY_LIST="$GK_DIR/denylist"
LOG_FILE="$GK_DIR/gatekeeper.log"
mkdir -p "$GK_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Gatekeeper Configuration
MODE=monitor          # monitor | enforce
SCRIPT_VETTING=true
UNTRUSTED_LOCATIONS=/tmp,/var/tmp,/dev/shm,/home/*/.cache
LOG_EVENTS=true
EOF
    touch "$ALLOW_LIST" "$DENY_LIST" "$LOG_FILE"
}

# Status
status() {
    echo "=== Gatekeeper Status ==="
    echo ""
    echo "  Mode: $(grep MODE "$CONFIG_FILE" | cut -d= -f2)"
    echo "  Script vetting: $(grep SCRIPT_VETTING "$CONFIG_FILE" | cut -d= -f2)"
    echo "  Logging: $(grep LOG_EVENTS "$CONFIG_FILE" | cut -d= -f2)"
    echo ""
    echo "  Allowlist entries: $(grep -c . "$ALLOW_LIST" 2>/dev/null || echo 0)"
    echo "  Denylist entries: $(grep -c . "$DENY_LIST" 2>/dev/null || echo 0)"
}

# Scan for suspicious scripts/binaries
scan() {
    echo "=== Scanning for Suspicious Files ==="
    echo ""
    local found=0
    
    # World-writable binaries in PATH
    for dir in $(echo "$PATH" | tr ':' ' '); do
        [ -d "$dir" ] || continue
        for bin in "$dir"/*; do
            [ -x "$bin" ] || continue
            if [ "$(stat -c %a "$bin" 2>/dev/null | cut -c3)" = "2" ] || [ "$(stat -c %a "$bin" 2>/dev/null | cut -c3)" = "6" ]; then
                echo "  ⚠️  World-writable in PATH: $bin"
                found=$((found+1))
            fi
        done
    done
    
    # Suspect scripts in untrusted locations
    local untrusted=$(grep UNTRUSTED_LOCATIONS "$CONFIG_FILE" | cut -d= -f2)
    for loc in $(echo "$untrusted" | tr ',' ' '); do
        for pat in "$loc"/*.sh "$loc"/*.py; do
            [ -e "$pat" ] || continue
            echo "  ⚠️  Script in untrusted location: $pat"
            found=$((found+1))
        done
    done
    
    [ $found -eq 0 ] && echo "  ✓ No suspicious files detected"
    echo ""
    echo "  Note: Gatekeeper can't fully sandbox; use enforcement with care."
}

# Check a specific command against policy
check() {
    local cmd=${1:-}
    [ -z "$cmd" ] && { echo "Usage: $0 check <command-or-path>"; return 1; }
    
    local bin=$(command -v "$cmd" 2>/dev/null || echo "$cmd")
    
    echo "=== Check: $cmd ==="
    echo "  Binary: $bin"
    
    # Allowlist
    if grep -qx "$cmd" "$ALLOW_LIST" 2>/dev/null || grep -qx "$bin" "$ALLOW_LIST" 2>/dev/null; then
        echo "  ✓ ALLOWED (allowlist)"
        grep -q LOG_EVENTS "$CONFIG_FILE" && echo "$(date +%s)|allow|$cmd" >> "$LOG_FILE"
        return 0
    fi
    
    # Denylist
    if grep -qx "$cmd" "$DENY_LIST" 2>/dev/null || grep -qx "$bin" "$DENY_LIST" 2>/dev/null; then
        echo "  ✗ BLOCKED (denylist)"
        grep -q LOG_EVENTS "$CONFIG_FILE" && echo "$(date +%s)|deny|$cmd" >> "$LOG_FILE"
        return 1
    fi
    
    echo "  ? UNKNOWN - not in lists"
    return 0
}

# Add to allowlist
allow() {
    local cmd=$1
    [ -z "$cmd" ] && { echo "Usage: $0 allow <command>"; return 1; }
    echo "$cmd" >> "$ALLOW_LIST"
    echo "  ✓ Added '$cmd' to allowlist"
}

# Add to denylist
deny() {
    local cmd=$1
    [ -z "$cmd" ] && { echo "Usage: $0 deny <command>"; return 1; }
    echo "$cmd" >> "$DENY_LIST"
    echo "  ✗ Added '$cmd' to denylist"
}

# Remove from deny list
unblock() {
    local cmd=$1
    [ -z "$cmd" ] && { echo "Usage: $0 unblock <command>"; return 1; }
    sed -i "/^$cmd$/d" "$DENY_LIST"
    echo "  ✓ Removed '$cmd' from denylist"
}

# Enable enforcement mode
enforce() {
    sed -i 's/^MODE=.*/MODE=enforce/' "$CONFIG_FILE"
    echo "  ✓ Enforcement mode enabled (beware: may block legitimate apps)"
}

# Monitor mode
monitor() {
    sed -i 's/^MODE=.*/MODE=monitor/' "$CONFIG_FILE"
    echo "  ✓ Monitor mode enabled (report only)"
}

# Show logs
logs() {
    echo "=== Gatekeeper Logs ==="
    echo ""
    [ -s "$LOG_FILE" ] && tail -30 "$LOG_FILE" | sed 's/^/  /' || echo "  No events logged"
}

show_help() {
    echo "Usage: tinker-gatekeeper [command]"
    echo ""
    echo "Commands:"
    echo "  status              Show gatekeeper status"
    echo "  scan                Scan for suspicious files"
    echo "  check <cmd>         Check a command against policy"
    echo "  allow <cmd>         Add to allowlist"
    echo "  deny <cmd>          Add to denylist"
    echo "  unblock <cmd>       Remove from denylist"
    echo "  enforce             Enable enforcement mode"
    echo "  monitor             Enable monitor (report) mode"
    echo "  logs                Show event logs"
    echo "  help                Show this help"
}

init

case "$1" in
    status) status ;;
    scan) scan ;;
    check) check "$2" ;;
    allow) allow "$2" ;;
    deny) deny "$2" ;;
    unblock) unblock "$2" ;;
    enforce) enforce ;;
    monitor) monitor ;;
    logs) logs ;;
    *) show_help ;;
esac
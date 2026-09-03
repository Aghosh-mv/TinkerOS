#!/bin/bash
# TinkerOS Privacy - Privacy audit, tracker blocking, and data management
# Local-only. No analytics. No cloud.

set -e

PV_DIR="$HOME/.tinker/privacy"
HOSTS_BACKUP="$PV_DIR/hosts.backup"
CONFIG_FILE="$PV_DIR/config.conf"
mkdir -p "$PV_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Privacy Configuration
BLOCK_TRACKERS=true
BLOCK_ADS=true
CLEAR_LOG_DAYS=30
ENABLE_DO_NOT_TRACK=true
EOF
}

# Audit tracking exposure
audit() {
    echo "=== Privacy Audit ==="
    echo ""
    
    # Browser telemetry (generic)
    echo "1. Browser telemetry:"
    command -v firefox &>/dev/null && echo "  - Firefox installed (review privacy settings)"
    command -v chromium &>/dev/null && echo "  - Chromium installed (review telemetry)"
    
    echo ""
    echo "2. Online tracking protection:"
    if grep -qi "0.0.0.0" "$PV_DIR/hosts.block" 2>/dev/null; then
        local blocked=$(grep -c "0.0.0.0" "$PV_DIR/hosts.block")
        echo "  - $blocked active tracker/domain blocks"
    else
        echo "  - No tracker block list active"
    fi
    
    echo ""
    echo "3. Command history: $([ -f "$HOME/.bash_history" ] && echo "present" || echo "off")"
    echo "4. Localization/telemetry:"
    echo "  - Locale: $LANG"
    
    echo ""
    echo "5. Files with sensitive names:"
    find "$HOME" -maxdepth 2 -iname "*password*" -o -iname "*secret*" -o -iname "*.key" 2>/dev/null | grep -v "\.tinker" | head -5 | sed 's/^/  /'
}

# Block known ad/tracker domains in /etc/hosts
block() {
    local domain=$1
    [ -z "$domain" ] && { echo "Usage: $0 block <domain>"; return 1; }
    
    echo "Blocking tracker/ad domain: $domain"
    echo "0.0.0.0 $domain" >> "$PV_DIR/hosts.block"
    echo "  ✓ Added (activates when applied to /etc/hosts)"
}

# Apply blocklist to /etc/hosts
apply_hosts() {
    echo "=== Applying Tracker Blocklist ==="
    echo ""
    
    if [ ! -s "$PV_DIR/hosts.block" ]; then
        echo "  No blocklist entries yet. Add domains with:"
        echo "    tinker-privacy block <domain>"
        return 0
    fi
    
    # Backup /etc/hosts first
    [ ! -f "$HOSTS_BACKUP" ] && sudo cp /etc/hosts "$HOSTS_BACKUP" && echo "  ✓ Backed up /etc/hosts"
    
    echo "  Applying $1 block rules..."
    { cat "$HOSTS_BACKUP" 2>/dev/null; echo ""; echo "# TinkerOS Privacy Blocklist $(date +%F)"; cat "$PV_DIR/hosts.block"; } | sudo tee /etc/hosts >/dev/null
    echo "  ✓ Applied to /etc/hosts"
}

# Restore original hosts
restore_hosts() {
    echo "Restoring original /etc/hosts..."
    [ -f "$HOSTS_BACKUP" ] && sudo cp "$HOSTS_BACKUP" /etc/hosts && echo "  ✓ Restored" || echo "  - No backup found"
}

# Clear system logs and history
clear_data() {
    echo "=== Clear Privacy Data ==="
    echo ""
    local days=$(grep CLEAR_LOG_DAYS "$CONFIG_FILE" | cut -d= -f2)
    days=${days:-30}
    
    echo "1. Remove command history ($days days)..."
    [ -f "$HOME/.bash_history" ] && cat /dev/null > "$HOME/.bash_history" && echo "   ✓ Cleared bash history"
    
    echo "2. Clear recent files (GTK)..."
    [ -f ~/.local/share/recently-used.xbel ] && rm -f ~/.local/share/recently-used.xbel && echo "   ✓ Cleared recent files"
    
    echo "3. Old temp files..."
    find /tmp -type f -mtime +$days -delete 2>/dev/null && echo "   ✓ Cleaned $days-day-old temp files"
    
    echo ""
    echo "Note: Clearing browser data should be done in-browser."
}

# Do-Not-Track status
dnt() {
    echo "=== Do Not Track ==="
    echo ""
    echo "  Linux has no global DNT. Set in browsers:"
    echo "    - Firefox: about:preferences#privacy"
    echo "    - Chromium: settings/privacy"
    echo ""
    echo "  Recommended privacy tools (all local):"
    echo "    - Firefox: strict tracking protection"
    echo "    - uBlock Origin (local blocklists)"
    echo "    - Encrypted DNS in browser settings"
}

# List blocked domains
list_blocked() {
    echo "=== Blocked Domains ($(grep -c . "$PV_DIR/hosts.block" 2>/dev/null || echo 0) total) ==="
    echo ""
    [ -s "$PV_DIR/hosts.block" ] && sed 's/^/  /' "$PV_DIR/hosts.block" || echo "  No domains blocked"
}

show_help() {
    echo "Usage: tinker-privacy [command]"
    echo ""
    echo "Commands:"
    echo "  audit               Run privacy audit"
    echo "  block <domain>      Block a tracker/ad domain"
    echo "  apply               Apply blocklist to /etc/hosts"
    echo "  restore             Restore original /etc/hosts"
    echo "  clear               Clear logs and history"
    echo "  dnt                 Do-Not-Track info"
    echo "  list                List blocked domains"
    echo "  help                Show this help"
}

init

case "$1" in
    audit) audit ;;
    block) block "$2" ;;
    apply|apply-hosts) apply_hosts ;;
    restore) restore_hosts ;;
    clear) clear_data ;;
    dnt|tracking) dnt ;;
    list) list_blocked ;;
    *) show_help ;;
esac
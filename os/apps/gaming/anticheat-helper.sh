#!/bin/bash
# TinkerOS Anti-Cheat Helper - Configure anti-cheat for games

set -e

AC_DIR="$HOME/.tinker/anticheat"
CONFIG_FILE="$AC_DIR/config.conf"

mkdir -p "$AC_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Anti-Cheat Helper Configuration
ENABLED=true
PROTON_VERSION=experimental
ENABLE_EAC=true
ENABLE_BATTLEYE=true
EOF
    fi
}

# Check anti-cheat support
check_support() {
    echo "Anti-Cheat Support Status"
    echo ""
    echo "Easy Anti-Cheat (EAC):"
    echo "  - Supported via Proton"
    echo "  - Enable in Steam Play settings"
    echo ""
    echo "BattlEye:"
    echo "  - Supported via Proton"
    echo "  - Enable in Steam Play settings"
    echo ""
    echo "To enable:"
    echo "  1. Steam > Settings > Steam Play"
    echo "  2. Enable for all titles"
    echo "  3. Use Proton Experimental"
}

# Configure Proton
configure_proton() {
    echo "Configuring Proton..."
    echo ""
    echo "1. Open Steam"
    echo "2. Go to Settings > Steam Play"
    echo "3. Enable Steam Play for all titles"
    echo "4. Select Proton Experimental"
    echo "5. For specific games, right-click > Properties > Compatibility"
    echo "   - Check 'Force the use of a specific Steam Play compatibility tool'"
    echo "   - Select Proton Experimental"
}

show_help() {
    echo "Usage: tinker-anticheat [command]"
    echo ""
    echo "Commands:"
    echo "  check             Check anti-cheat support"
    echo "  configure         Configure Proton"
    echo "  help              Show this help"
}

init

case "$1" in
    check|status) check_support ;;
    configure|config) configure_proton ;;
    *) show_help ;;
esac

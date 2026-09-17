#!/bin/bash
# KorrinOS Apt Personality Layer
# Wraps apt/apt-get with personality messages during install
# Hooked via apt.conf.d or LD_PRELOAD

APT_PERSONALITY_DIR="/etc/apt/apt.conf.d"
APT_PERSONALITY_HOOK="/opt/korrinos/os/system/korrinos-apt-hook.sh"
APT_PERSONALITY_LOG="/var/log/korrinos-apt.log"

# ============================================================
#  MY OWN LINES — sarcastic install messages
# ============================================================
INSTALL_MESSAGES=(
    "Installing {pkg}. Hope you don't need your disk space."
    "Downloading bloat... I mean, {pkg}."
    "Ah, {pkg}. Another dependency to maintain forever."
    "Installing {pkg}. Your future self will have questions."
    "Fetching {pkg}. The package manager sighs quietly."
    "Installing {pkg}. This is fine. Everything is fine."
    "{pkg} incoming. Brace yourself."
    "Pulling {pkg} from the void. You're welcome."
    "Installing {pkg}. The hard drive barely flinched."
    "{pkg} downloading. The internet holds its breath."
    "Installing {pkg}. Another brick in the dependency wall."
    "{pkg} is being installed. Your system just got heavier."
    "Here comes {pkg}. It brought friends."
    "Installing {pkg}. The terminal is feeling ambitious."
    "{pkg} install in progress. Productivity: paused."
    "Grabbing {pkg}. The server nods in approval."
    "Installing {pkg}. Somewhere, a sysadmin just winced."
    "{pkg} downloading. Your bandwidth called. It's concerned."
    "Installing {pkg}. This won't take long. Just kidding, it will."
    "{pkg} incoming. Your RAM is watching nervously."
)

REMOVE_MESSAGES=(
    "Removing {pkg}. Gone but not forgotten. Actually, forgotten."
    "Purging {pkg}. Goodbye, old friend. You won't be missed."
    "{pkg} has been evicted. The system breathes easier."
    "Removing {pkg}. This is a breakup. A necessary one."
    "{pkg} deleted. Your disk space just sent a thank you note."
    "Removing {pkg}. The dependency tree just got simpler."
    "{pkg} is out. The package manager is relieved."
    "Evicting {pkg}. Your system needed this."
)

UPDATE_MESSAGES=(
    "Updating package list. The system is getting smarter."
    "Refreshing repositories. The servers are checking in."
    "Checking for updates. Something probably needs fixing."
    "Package list refreshed. New toys incoming."
    "Update check complete. Your system is up to date. Suspicious."
    "Repositories refreshed. The package gods are pleased."
)

UPGRADE_MESSAGES=(
    "Upgrading packages. The system is evolving."
    "Applying upgrades. Your software just leveled up."
    "Upgrading. This is progress. Uncomfortable, but progress."
    "Packages being upgraded. The old versions didn't deserve this."
    "System upgrade in progress. Don't panic. Panic is for later."
)

# ============================================================
#  MESSAGE PICKER
# ============================================================
get_random_message() {
    local -n arr=$1
    local idx=$((RANDOM % ${#arr[@]}))
    echo "${arr[$idx]}"
}

format_message() {
    local msg="$1"
    local pkg="$2"
    echo "${msg//\{pkg\}/$pkg}"
}

# ============================================================
#  APT HOOK — called before/after apt operations
# ============================================================
apt_hook() {
    local action="$1"
    local package="${2:-unknown}"
    
    local message=""
    local color=""
    
    case "$action" in
        install)
            message=$(get_random_message INSTALL_MESSAGES)
            message=$(format_message "$message" "$package")
            color='\033[1;32m'  # Green
            ;;
        remove|purge)
            message=$(get_random_message REMOVE_MESSAGES)
            message=$(format_message "$message" "$package")
            color='\033[1;33m'  # Yellow
            ;;
        update)
            message=$(get_random_message UPDATE_MESSAGES)
            color='\033[1;34m'  # Blue
            ;;
        upgrade|dist-upgrade)
            message=$(get_random_message UPGRADE_MESSAGES)
            color='\033[1;36m'  # Cyan
            ;;
    esac
    
    if [ -n "$message" ]; then
        echo -e "${color}[KorrinOS]${NC} ${message}" >&2
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $action: $message" >> "$APT_PERSONALITY_LOG" 2>/dev/null || true
    fi
}

# ============================================================
#  MAIN
# ============================================================
case "${1:-}" in
    hook)
        apt_hook "${2:-}" "${3:-}"
        ;;
    test)
        echo "=== Apt Personality Test ==="
        echo ""
        echo "  INSTALL:"
        for i in {1..3}; do echo "    $(get_random_message INSTALL_MESSAGES | sed 's/{pkg}/firefox/g')"; done
        echo ""
        echo "  REMOVE:"
        for i in {1..3}; do echo "    $(get_random_message REMOVE_MESSAGES | sed 's/{pkg}/old-app/g')"; done
        echo ""
        echo "  UPDATE:"
        for i in {1..3}; do echo "    $(get_random_message UPDATE_MESSAGES)"; done
        echo ""
        echo "  UPGRADE:"
        for i in {1..3}; do echo "    $(get_random_message UPGRADE_MESSAGES)"; done
        ;;
    install-hook)
        echo "Installing apt personality hook..."
        sudo tee "$APT_PERSONALITY_DIR/99-korrinos-personality" > /dev/null << 'EOF'
# KorrinOS Apt Personality — adds personality to apt operations
DPkg::Pre-Install-Pkgs {
    "/opt/korrinos/os/system/korrinos-apt-hook.sh hook install";
};
DPkg::Pre-Remove {
    "/opt/korrinos/os/system/korrinos-apt-hook.sh hook remove";
};
EOF
        echo "  Hook installed at $APT_PERSONALITY_DIR/99-korrinos-personality"
        ;;
    *)
        echo "KorrinOS Apt Personality v1.0"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  hook <action> <pkg>  Show personality message"
        echo "  install-hook         Install apt hook"
        echo "  test                 Show sample messages"
        ;;
esac

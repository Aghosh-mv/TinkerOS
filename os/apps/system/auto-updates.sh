#!/bin/bash
# TinkerOS Auto Updates - Comprehensive update management

set -e

UPDATE_DIR="$HOME/.tinker/auto-updates"
CONFIG_FILE="$UPDATE_DIR/config.conf"
LOG_FILE="$UPDATE_DIR/updates.log"
HISTORY_FILE="$UPDATE_DIR/history.log"

mkdir -p "$UPDATE_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Auto Updates Configuration
ENABLED=true
CHECK_INTERVAL=daily
AUTO_INSTALL_SECURITY=true
AUTO_INSTALL_ALL=false
NOTIFY_BEFORE_INSTALL=true
NOTIFY_AFTER_INSTALL=true
EXCLUDE_PACKAGES=
BACKUP_BEFORE_UPDATE=true
MAX_DOWNTIME=300
EOF

    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
    [ ! -f "$HISTORY_FILE" ] && touch "$HISTORY_FILE"
}

# Detect package manager
get_pm() {
    if command -v apt &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v pacman &>/dev/null; then echo "pacman"
    elif command -v zypper &>/dev/null; then echo "zypper"
    else echo "unknown"; fi
}

# Check for updates
check_updates() {
    local pm=$(get_pm)
    local updates=0
    local security=0
    
    case $pm in
        apt)
            apt update -qq 2>/dev/null
            updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0)
            security=$(apt list --upgradable 2>/dev/null | grep -c security || echo 0)
            ;;
        dnf)
            updates=$(dnf check-update -q 2>/dev/null | grep -c "^[a-z]" || echo 0)
            security=$(dnf updateinfo list security 2>/dev/null | grep -c "^[a-z]" || echo 0)
            ;;
        pacman)
            pacman -Sy >/dev/null 2>&1
            updates=$(pacman -Qu 2>/dev/null | wc -l)
            security=0
            ;;
        zypper)
            zypper refresh >/dev/null 2>&1
            updates=$(zypper list-updates 2>/dev/null | grep -c "^v" || echo 0)
            security=$(zypper list-patches --category security 2>/dev/null | grep -c "^[a-z]" || echo 0)
            ;;
    esac
    
    echo "Updates Available: $updates ($security security)"
    echo "$(date +%s)|$updates|$security" >> "$LOG_FILE"
    
    # Return counts for scripting
    echo "$updates $security"
}

# Show update details
list_updates() {
    local pm=$(get_pm)
    
    case $pm in
        apt)
            apt list --upgradable 2>/dev/null | grep upgradable | while read line; do
                echo "  $line"
            done
            ;;
        dnf)
            dnf check-update 2>/dev/null | grep -E "^[a-z]" | while read line; do
                echo "  $line"
            done
            ;;
        pacman)
            pacman -Qu 2>/dev/null | while read line; do
                echo "  $line"
            done
            ;;
        zypper)
            zypper list-updates 2>/dev/null | grep "^v" | while read line; do
                echo "  $line"
            done
            ;;
    esac
}

# Install updates
install_updates() {
    local type=${1:-all}
    local pm=$(get_pm)
    local exclude=$(grep EXCLUDE_PACKAGES "$CONFIG_FILE" | cut -d= -f2)
    
    echo "Installing $type updates..."
    
    # Backup before update
    if grep -q "BACKUP_BEFORE_UPDATE=true" "$CONFIG_FILE"; then
        echo "Creating pre-update snapshot..."
        if command -v timeshift &>/dev/null; then
            timeshift --create --comments "Pre-update $(date)" --tags D 2>/dev/null || true
        elif command -v snapper &>/dev/null; then
            snapper create --description "Pre-update $(date)" 2>/dev/null || true
        fi
    fi
    
    case $pm in
        apt)
            if [ "$type" = "security" ]; then
                apt upgrade -y -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/security.sources.list 2>&1 | tail -20
            else
                DEBIAN_FRONTEND=noninteractive apt upgrade -y 2>&1 | tail -20
            fi
            ;;
        dnf)
            if [ "$type" = "security" ]; then
                dnf update --security -y 2>&1 | tail -20
            else
                dnf upgrade -y 2>&1 | tail -20
            fi
            ;;
        pacman)
            pacman -Syu --noconfirm 2>&1 | tail -20
            ;;
        zypper)
            if [ "$type" = "security" ]; then
                zypper patch --category security -y 2>&1 | tail -20
            else
                zypper update -y 2>&1 | tail -20
            fi
            ;;
    esac
    
    local result=${PIPESTATUS[0]}
    if [ $result -eq 0 ]; then
        echo "Updates installed successfully"
        echo "$(date +%s)|installed|$type" >> "$HISTORY_FILE"
        grep -q "NOTIFY_AFTER_INSTALL=true" "$CONFIG_FILE" && notify-send "Updates Complete" "System updated" 2>/dev/null || true
    else
        echo "Update failed (exit code: $result)"
        echo "$(date +%s)|failed|$type" >> "$HISTORY_FILE"
    fi
    
    return $result
}

# Schedule auto-updates
schedule() {
    local freq=${1:-daily}
    local time=${2:-03:00}
    
    echo "Scheduling auto-updates: $freq at $time"
    
    # Create systemd timer
    cat > /etc/systemd/system/tinker-auto-update.service << EOF
[Unit]
Description=TinkerOS Auto Update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/home/tinkerspace/linux-kernel/os/apps/system/auto-updates.sh auto-run
Environment=HOME=/home/tinkerspace
EOF

    local timer_spec=""
    case $freq in
        hourly) timer_spec="OnCalendar=*:00" ;;
        daily) timer_spec="OnCalendar=*-*-* $time" ;;
        weekly) timer_spec="OnCalendar=Mon *-*-* $time" ;;
        monthly) timer_spec="OnCalendar=*-1 $time" ;;
    esac
    
    cat > /etc/systemd/system/tinker-auto-update.timer << EOF
[Unit]
Description=Run TinkerOS Auto Update $freq

[Timer]
$timer_spec
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable --now tinker-auto-update.timer 2>/dev/null || true
    
    echo "Timer created and enabled"
}

# Auto-run (called by timer)
auto_run() {
    if ! grep -q "ENABLED=true" "$CONFIG_FILE" 2>/dev/null; then
        echo "Auto-updates disabled"
        exit 0
    fi
    
    local security_only=$(grep AUTO_INSTALL_SECURITY "$CONFIG_FILE" | cut -d= -f2)
    local all=$(grep AUTO_INSTALL_ALL "$CONFIG_FILE" | cut -d= -f2)
    
    local updates=$(check_updates | awk '{print $1}')
    
    if [ "$updates" -gt 0 ]; then
        if [ "$security_only" = "true" ]; then
            local security=$(check_updates | awk '{print $2}')
            if [ "$security" -gt 0 ]; then
                grep -q "NOTIFY_BEFORE_INSTALL=true" "$CONFIG_FILE" && notify-send "Auto Update" "Installing $security security updates..." 2>/dev/null || true
                install_updates security
            fi
        elif [ "$all" = "true" ]; then
            grep -q "NOTIFY_BEFORE_INSTALL=true" "$CONFIG_FILE" && notify-send "Auto Update" "Installing $updates updates..." 2>/dev/null || true
            install_updates all
        fi
    fi
}

# Show history
history() {
    echo "Update History:"
    echo ""
    tail -20 "$HISTORY_FILE" | while IFS='|' read -r ts action type; do
        local time=$(date -d @$ts "+%Y-%m-%d %H:%M" 2>/dev/null || echo "?")
        echo "  $time: $action ($type)"
    done
}

show_help() {
    echo "Usage: tinker-auto-updates [command]"
    echo ""
    echo "Commands:"
    echo "  check               Check for available updates"
    echo "  list                List available updates"
    echo "  install [type]      Install updates (all|security)"
    echo "  auto-run            Run automatic update check (for timer)"
    echo "  schedule [freq] [time] Schedule auto-updates"
    echo "  history             Show update history"
    echo "  config              Show/edit configuration"
    echo "  help                Show this help"
    echo ""
    echo "Frequencies: hourly, daily, weekly, monthly"
}

init

case "$1" in
    check) check_updates ;;
    list) list_updates ;;
    install) install_updates "$2" ;;
    auto-run) auto_run ;;
    schedule) schedule "$2" "$3" ;;
    history) history ;;
    config) cat "$CONFIG_FILE" ;;
    *) show_help ;;
esac
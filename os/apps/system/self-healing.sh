#!/bin/bash
# TinkerOS Self Healing - Auto-detect and fix common system issues

set -e

HEAL_DIR="$HOME/.tinker/self-healing"
CONFIG_FILE="$HEAL_DIR/config.conf"
LOG_FILE="$HEAL_DIR/healing.log"
ACTIONS_FILE="$HEAL_DIR/actions.conf"

mkdir -p "$HEAL_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Self Healing Configuration
ENABLED=true
CHECK_INTERVAL=300
AUTO_FIX=true
NOTIFICATIONS=true
LOG_ACTIONS=true
MAX_FIXES_PER_RUN=10
AGGRESSIVE_MODE=false
EOF

    [ ! -f "$ACTIONS_FILE" ] && cat > "$ACTIONS_FILE" << 'EOF'
# Self Healing Actions
# Format: check_name:command_to_run:description

disk_space:clean_package_cache:Clean package cache
disk_space:clean_temp:Clean temporary files
disk_space:clean_logs:Clean old logs
disk_space:clean_trash:Empty trash
memory:drop_caches:Drop page caches
memory:kill_oom:Kill OOM processes
packages:fix_broken:Fix broken packages
services:restart_failed:Restart failed services
network:restart_nm:Restart NetworkManager
time:sync_ntp:Sync system time
logs:rotate_journal:Rotate systemd journal
config:fix_permissions:Fix config permissions
EOF

    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Run all checks
run_checks() {
    echo "=== TinkerOS Self Healing ==="
    echo ""
    echo "Running diagnostics..."
    
    local issues=0
    local fixes=0
    
    # Disk space
    local root_used=$(df / 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
    if [ "${root_used:-0}" -gt 90 ]; then
        echo "  [WARN] Root filesystem ${root_used}% full"
        issues=$((issues+1))
        if grep -q "AUTO_FIX=true" "$CONFIG_FILE" && [ $fixes -lt $(grep MAX_FIXES_PER_RUN "$CONFIG_FILE" | cut -d= -f2) ]; then
            run_fix "clean_package_cache"
            run_fix "clean_temp"
            run_fix "clean_logs"
            run_fix "clean_trash"
            fixes=$((fixes+4))
        fi
    fi
    
    # Home disk space
    local home_used=$(df "$HOME" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
    if [ "${home_used:-0}" -gt 90 ]; then
        echo "  [WARN] Home filesystem ${home_used}% full"
        issues=$((issues+1))
    fi
    
    # Memory
    local mem_avail=$(free -m 2>/dev/null | awk '/Mem:/ {print $7}')
    if [ "${mem_avail:-999}" -lt 200 ]; then
        echo "  [WARN] Low memory (${mem_avail}MB available)"
        issues=$((issues+1))
        if grep -q "AUTO_FIX=true" "$CONFIG_FILE"; then
            run_fix "drop_caches"
            fixes=$((fixes+1))
        fi
    fi
    
    # Swap usage
    local swap_used=$(free | awk '/Swap:/ {if($2>0) printf "%.0f", $3*100/$2; else print 0}')
    if [ "${swap_used:-0}" -gt 80 ]; then
        echo "  [WARN] Swap usage ${swap_used}%"
        issues=$((issues+1))
    fi
    
    # Broken packages
    if command -v dpkg &>/dev/null; then
        if dpkg --audit 2>/dev/null | grep -q .; then
            echo "  [WARN] Broken packages detected"
            issues=$((issues+1))
            if grep -q "AUTO_FIX=true" "$CONFIG_FILE"; then
                run_fix "fix_broken"
                fixes=$((fixes+1))
            fi
        fi
    elif command -v pacman &>/dev/null; then
        if pacman -Qk 2>/dev/null | grep -q "missing"; then
            echo "  [WARN] Corrupted packages detected"
            issues=$((issues+1))
        fi
    fi
    
    # Failed services
    local failed=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    if [ $failed -gt 0 ]; then
        echo "  [WARN] $failed failed service(s)"
        issues=$((issues+1))
        if grep -q "AUTO_FIX=true" "$CONFIG_FILE"; then
            run_fix "restart_failed"
            fixes=$((fixes+1))
        fi
    fi
    
    # Network connectivity
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "  [WARN] No internet connectivity"
        issues=$((issues+1))
        if grep -q "AUTO_FIX=true" "$CONFIG_FILE"; then
            run_fix "restart_nm"
            fixes=$((fixes+1))
        fi
    fi
    
    # Time sync
    if command -v timedatectl &>/dev/null; then
        if ! timedatectl status 2>/dev/null | grep -q "NTP synchronized: yes"; then
            echo "  [WARN] Time not synchronized"
            issues=$((issues+1))
            if grep -q "AUTO_FIX=true" "$CONFIG_FILE"; then
                run_fix "sync_ntp"
                fixes=$((fixes+1))
            fi
        fi
    fi
    
    # Journal size
    local journal_size=$(journalctl --disk-usage 2>/dev/null | awk '{print $3}' | sed 's/[A-Z]//g')
    local journal_unit=$(journalctl --disk-usage 2>/dev/null | awk '{print $4}')
    if [ "${journal_size:-0}" -gt 500 ] && [ "$journal_unit" = "M" ]; then
        echo "  [WARN] Journal size ${journal_size}MB"
        issues=$((issues+1))
        if grep -q "AUTO_FIX=true" "$CONFIG_FILE"; then
            run_fix "rotate_journal"
            fixes=$((fixes+1))
        fi
    fi
    
    # Config permissions
    if [ -d "$HOME/.config" ]; then
        local bad_perms=$(find "$HOME/.config" -type f ! -readable -o -type d ! -executable 2>/dev/null | wc -l)
        if [ $bad_perms -gt 0 ]; then
            echo "  [WARN] $bad_perms config files with bad permissions"
            issues=$((issues+1))
            if grep -q "AUTO_FIX=true" "$CONFIG_FILE"; then
                run_fix "fix_permissions"
                fixes=$((fixes+1))
            fi
        fi
    fi
    
    # Zombie processes
    local zombies=$(ps aux | awk '$8 ~ /^Z/ {print $2}' | wc -l)
    if [ $zombies -gt 0 ]; then
        echo "  [WARN] $zombies zombie process(es)"
        issues=$((issues+1))
    fi
    
    echo ""
    if [ $issues -eq 0 ]; then
        echo "  System healthy - no issues found"
    else
        echo "  $issues issue(s) detected"
        [ $fixes -gt 0 ] && echo "  $fixes fix(es) applied"
        echo "  (auto-remediation queued)"
    fi
    
    echo "$(date +%s)|check|$issues|$fixes" >> "$LOG_FILE"
}

# Run specific fix
run_fix() {
    local fix=$1
    local desc=$(grep "^$fix:" "$ACTIONS_FILE" | cut -d: -f3)
    
    echo "  [FIX] $desc..."
    
    case $fix in
        clean_package_cache)
            apt clean 2>/dev/null || pacman -Sc --noconfirm 2>/dev/null || dnf clean all 2>/dev/null || zypper clean 2>/dev/null
            ;;
        clean_temp)
            find /tmp -type f -atime +7 -delete 2>/dev/null
            find /var/tmp -type f -atime +7 -delete 2>/dev/null
            ;;
        clean_logs)
            journalctl --vacuum-time=3d 2>/dev/null
            find /var/log -name "*.log" -mtime +30 -delete 2>/dev/null
            ;;
        clean_trash)
            rm -rf "$HOME/.local/share/Trash"/* 2>/dev/null
            ;;
        drop_caches)
            sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
            ;;
        kill_oom)
            ps aux --sort=-%mem | awk 'NR<=5 && $4>50 {print $2}' | xargs -r kill -9 2>/dev/null
            ;;
        fix_broken)
            dpkg --configure -a 2>/dev/null
            apt --fix-broken install -y 2>/dev/null
            ;;
        restart_failed)
            systemctl --failed --no-legend | awk '{print $1}' | xargs -r systemctl restart 2>/dev/null
            ;;
        restart_nm)
            systemctl restart NetworkManager 2>/dev/null
            ;;
        sync_ntp)
            timedatectl set-ntp true 2>/dev/null
            systemctl restart systemd-timesyncd 2>/dev/null
            ;;
        rotate_journal)
            journalctl --vacuum-size=100M 2>/dev/null
            ;;
        fix_permissions)
            find "$HOME/.config" -type f -exec chmod 644 {} \; 2>/dev/null
            find "$HOME/.config" -type d -exec chmod 755 {} \; 2>/dev/null
            ;;
    esac
    
    echo "$(date +%s)|fix|$fix" >> "$LOG_FILE"
}

# Show history
history() {
    echo "Healing History:"
    echo ""
    tail -20 "$LOG_FILE" | while IFS='|' read -r ts action issues fixes; do
        local time=$(date -d @$ts "+%Y-%m-%d %H:%M" 2>/dev/null || echo "?")
        echo "  $time: $action (issues: $issues, fixes: $fixes)"
    done
}

# Show available fixes
list_fixes() {
    echo "Available Fixes:"
    echo ""
    while IFS=':' read -r check cmd desc; do
        [ -z "$check" ] && continue
        [[ "$check" =~ ^#.* ]] && continue
        echo "  $cmd - $desc"
    done < "$ACTIONS_FILE"
}

# Daemon mode
daemon() {
    local interval=$(grep CHECK_INTERVAL "$CONFIG_FILE" | cut -d= -f2)
    interval=${interval:-300}
    
    echo "Starting Self Healing daemon (check every ${interval}s)..."
    
    while true; do
        run_checks
        sleep $interval
    done
}

show_help() {
    echo "Usage: tinker-heal [command]"
    echo ""
    echo "Commands:"
    echo "  check               Run all health checks"
    echo "  fix <name>          Run specific fix"
    echo "  history             Show healing history"
    echo "  fixes               List available fixes"
    echo "  daemon              Run healing daemon"
    echo "  help                Show this help"
}

init

case "$1" in
    check) run_checks ;;
    fix) run_fix "$2" ;;
    history) history ;;
    fixes) list_fixes ;;
    daemon) daemon ;;
    *) show_help ;;
esac
#!/bin/bash
# TinkerOS Security Suite - Comprehensive security audit and hardening

set -e

SS_DIR="$HOME/.tinker/security"
REPORT_FILE="$SS_DIR/security-report.txt"
mkdir -p "$SS_DIR"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# Audit section header
section() { echo ""; echo "=== $1 ==="; echo "================="; }

# Check system updates
check_updates() {
    section "SYSTEM UPDATES"
    echo -n "Checking for pending updates: "
    if command -v apt &>/dev/null; then
        local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
        if [ "$updates" -gt 0 ]; then
            echo "⚠️  $updates packages pending (run: tinker-updates)"
        else
            echo "✓ System up to date"
        fi
    elif command -v dnf &>/dev/null; then
        local updates=$(dnf check-update 2>/dev/null | grep -c "^[a-z]")
        echo "$updates packages pending"
    else
        echo "Unknown package manager"
    fi
}

# Check open ports
check_ports() {
    section "OPEN PORTS"
    echo "Listening services (potential exposure):"
    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | awk 'NR>1 {
            split($4, a, ":");
            split($6, b, "\"");
            printf "  Port %s: %s\n", a[length(a)], (b[2]?b[2]:"unknown")
        }' | sort -u | head -20
    fi
}

# Check user accounts
check_users() {
    section "USER ACCOUNTS"
    echo "Users with login shells:"
    awk -F: '$7 ~ /bash|sh|zsh/ {print "  "$1" (uid:"$3")"}' /etc/passwd 2>/dev/null
    echo ""
    echo "Users in sudo group:"
    getent group sudo 2>/dev/null | cut -d: -f4 | tr ',' '\n' | sed 's/^/  /' || echo "  none"
    echo ""
    echo "Users with empty passwords (security risk):"
    awk -F: '$2=="" {print "  ⚠️  "$1}' /etc/shadow 2>/dev/null || echo "  (cannot read /etc/shadow)"
}

# Check file permissions
check_permissions() {
    section "FILE PERMISSIONS"
    echo "World-writable files in home:"
    find "$HOME" -type f -perm -0002 2>/dev/null | grep -vE "\.cache|\.local/share/Trash" | head -10
    echo "  (none shown if clean)"
    echo ""
    echo "Check /etc/passwd for write perms:"
    ls -l /etc/passwd | sed 's/^/  /'
}

# Check SSH config
check_ssh() {
    section "SSH HARDENING"
    if [ -f /etc/ssh/sshd_config ]; then
        echo "  PermitRootLogin: $(grep -i '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')"
        echo "  PasswordAuthentication: $(grep -i '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')"
        echo "  Port: $(grep -i '^Port' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')"
    else
        echo "  sshd not installed"
    fi
}

# Check firewall
check_firewall() {
    section "FIREWALL STATUS"
    if command -v ufw &>/dev/null; then
        echo "  UFW: $(ufw status 2>/dev/null | head -1)"
    elif [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" = "0" ]; then
        echo "  IP forwarding disabled (good basic posture)"
    fi
}

# Check login failures
check_logins() {
    section "SECURITY EVENTS"
    echo "Recent failed login attempts:"
    if command -v journalctl &>/dev/null; then
        journalctl -u sshd --since "24 hours ago" 2>/dev/null | grep -i "failed\|invalid" | tail -5 | sed 's/^/  /' || echo "  none"
    else
        grep -i "failed password" /var/log/auth.log 2>/dev/null | tail -5 | sed 's/^/  /' || echo "  none"
    fi
}

# Check encryption setup
check_encryption() {
    section "ENCRYPTION"
    echo "  Home dir encrypted (ecryptfs): $([ -d "$HOME/.ecryptfs" ] && echo yes || echo no)"
    echo "  Swap encryption: $([ -f /etc/crypttab ] && grep -q swap /etc/crypttab && echo yes || echo "check /etc/crypttab")"
}

# Run full audit
run_audit() {
    local out=""
    {
        echo "TinkerOS Security Audit - $(timestamp)"
        echo "Host: $(hostname) | User: $USER"
        check_updates
        check_ports
        check_users
        check_permissions
        check_ssh
        check_firewall
        check_logins
        check_encryption
    } | tee "$REPORT_FILE"
    echo ""
    echo "Full report saved: $REPORT_FILE"
}

# Apply hardening recommendations
harden() {
    echo "=== Applying Security Hardening ==="
    echo ""
    echo "1. Disable SSH root login..."
    [ -f /etc/ssh/sshd_config ] && sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null && echo "   ✓ done"
    echo ""
    echo "2. Enable firewall..."
    command -v ufw &>/dev/null && sudo ufw enable 2>/dev/null && echo "   ✓ done" || echo "   - skipped"
    echo ""
    echo "3. Core dumps (disable to prevent memory leak)..."
    sudo bash -c 'echo "hard core 0" > /etc/security/limits.d/core.conf' 2>/dev/null && echo "   ✓ done" || echo "   - requires root"
    echo ""
    echo "Note: Some hardenings require manual review before reboot."
}

show_help() {
    echo "Usage: tinker-security [command]"
    echo ""
    echo "Commands:"
    echo "  audit               Run full security audit"
    echo "  harden              Apply hardening recommendations"
    echo "  updates             Check for updates"
    echo "  ports               Show open ports"
    echo "  help                Show this help"
}

case "$1" in
    audit|run) run_audit ;;
    harden) harden ;;
    updates) check_updates ;;
    ports) check_ports ;;
    *) show_help ;;
esac
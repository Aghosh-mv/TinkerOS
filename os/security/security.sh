#!/bin/bash
# TinkerOS Security Suite - Main Controller

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_header() {
    clear
    echo "=========================================="
    echo "     TINKEROS SECURITY SUITE"
    echo "     macOS-like protection for Linux"
    echo "=========================================="
    echo ""
}

show_menu() {
    echo "Security Features:"
    echo ""
    echo "  1) Gatekeeper - App verification"
    echo "  2) FileVault - Disk encryption"
    echo "  3) Privacy - Permission controls"
    echo "  4) Firewall - Network protection"
    echo "  5) Biometric - Face/Fingerprint"
    echo "  6) Find My Device - Location tracking"
    echo "  7) SIP - System integrity"
    echo "  8) Security audit"
    echo "  9) Exit"
    echo ""
    read -p "Choose (1-9): " choice
    echo ""
    
    case $choice in
        1) bash "$SCRIPT_DIR/gatekeeper.sh" ;;
        2) bash "$SCRIPT_DIR/filevault.sh" ;;
        3) bash "$SCRIPT_DIR/privacy.sh" ;;
        4) bash "$SCRIPT_DIR/firewall.sh" ;;
        5) bash "$SCRIPT_DIR/biometric.sh" ;;
        6) bash "$SCRIPT_DIR/findmydevice.sh" ;;
        7) bash "$SCRIPT_DIR/sip.sh" ;;
        8) run_audit ;;
        9) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
}

run_audit() {
    echo "Running Security Audit..."
    echo ""
    
    # Check firewall
    if sudo ufw status 2>/dev/null | grep -q "active"; then
        echo "  [OK] Firewall is active"
    else
        echo "  [!] Firewall not active"
    fi
    
    # Check file permissions
    if [ -f /etc/shadow ]; then
        local perms=$(stat -c "%a" /etc/shadow 2>/dev/null)
        if [ "$perms" = "640" ] || [ "$perms" = "600" ]; then
            echo "  [OK] Shadow file permissions correct"
        else
            echo "  [!] Shadow file permissions: $perms"
        fi
    fi
    
    # Check SSH
    if [ -f /etc/ssh/sshd_config ]; then
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            echo "  [OK] SSH root login disabled"
        else
            echo "  [!] SSH root login enabled"
        fi
    fi
    
    echo ""
}

case "$1" in
    gatekeeper) bash "$SCRIPT_DIR/gatekeeper.sh" ;;
    filevault) bash "$SCRIPT_DIR/filevault.sh" ;;
    privacy) bash "$SCRIPT_DIR/privacy.sh" ;;
    firewall) bash "$SCRIPT_DIR/firewall.sh" ;;
    biometric) bash "$SCRIPT_DIR/biometric.sh" ;;
    findmydevice) bash "$SCRIPT_DIR/findmydevice.sh" ;;
    sip) bash "$SCRIPT_DIR/sip.sh" ;;
    audit) show_header; run_audit ;;
    *)
        show_header
        show_menu
        ;;
esac

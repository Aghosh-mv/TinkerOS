#!/bin/bash
# TinkerOS Biometric - Fingerprint and biometric authentication setup

set -e

# Check fingerprint backend
check_backend() {
    if command -v fprintd-enroll &>/dev/null || command -v fprintd-verify &>/dev/null; then
        echo "fprintd"
    elif command -v pam_fprintd &>/dev/null; then
        echo "fprintd"
    elif [ -d /etc/fprintd ]; then
        echo "fprintd"
    else
        echo "none"
    fi
}

# Show status
status() {
    local backend=$(check_backend)
    echo "=== Biometric Status (backend: $backend) ==="
    echo ""
    
    case $backend in
        fprintd)
            # List enrolled fingers
            echo "Enrolled fingerprints:"
            ls ~/.local/share/biometric 2>/dev/null | sed 's/^/  /'
            # Per-user
            local count=$(find /var/lib/fprint -name "*.dat" 2>/dev/null | wc -l || echo 0)
            echo "  Fingerprint data files: ${count:-0}"
            
            echo ""
            echo "PAM integration:"
            grep -l fprintd /etc/pam.d/* 2>/dev/null | sed 's/^/  /' || echo "  Not integrated with PAM"
            echo ""
            echo "  To integrate with login (requires sudo):"
            echo "    sudo pam-auth-update  # enable 'fprintd'"
            ;;
        none)
            echo "  No fingerprint backend (libfprintd) detected"
            echo "  Install: sudo apt install fprintd libpam-fprintd"
            ;;
    esac
}

# Enroll fingerprint
enroll() {
    local finger=${1:-right-index-finger}
    local backend=$(check_backend)
    
    case $backend in
        fprintd)
            echo "=== Enrolling Fingerprint ==="
            echo "  Finger: $finger"
            echo "  Follow the prompts and scan your $finger 3 times."
            echo ""
            if command -v fprintd-enroll &>/dev/null; then
                fprintd-enroll -f "$finger"
                echo "  ✓ Enrollment complete"
            else
                echo "  fprintd-enroll not found (install fprintd)"
            fi
            ;;
        none)
            echo "  No fingerprint backend. Install:"
            echo "    sudo apt install fprintd libpam-fprintd"
            ;;
    esac
}

# Verify fingerprint
verify() {
    echo "=== Verify Fingerprint ==="
    echo "  Scan your finger to verify..."
    if command -v fprintd-verify &>/dev/null; then
        fprintd-verify
        local rc=$?
        [ $rc -eq 0 ] && echo "  ✓ Fingerprint verified" || echo "  ✗ Verification failed"
    else
        echo "  fprintd-verify not found"
    fi
}

# List available fingers
list_fingers() {
    echo "=== Available Finger Names ==="
    echo ""
    echo "  left-thumb, left-index-finger, left-middle-finger,"
    echo "  left-ring-finger, left-little-finger,"
    echo "  right-thumb, right-index-finger, right-middle-finger,"
    echo "  right-ring-finger, right-little-finger"
    echo ""
    echo "  Also: any-finger, left-swipe, right-swipe"
}

# Delete fingerprints
clear_all() {
    echo "=== Removing All Fingerprints ==="
    echo ""
    echo "  This removes all enrolled fingerprints."
    read -p "  Continue? [y/N] " ans
    [ "${ans,,}" != "y" ] && { echo "Cancelled"; return; }
    
    if command -v fprintd-delete &>/dev/null; then
        fprintd-delete "$USER" 2>/dev/null && echo "  ✓ Removed all fingerprints"
    else
        echo "  fprintd-delete not found"
    fi
}

show_help() {
    echo "Usage: tinker-biometric [command]"
    echo ""
    echo "Commands:"
    echo "  status              Show biometric status"
    echo "  enroll [finger]     Enroll a fingerprint"
    echo "  verify              Verify a fingerprint"
    echo "  fingers             List finger names"
    echo "  clear               Remove all fingerprints"
    echo "  help                Show this help"
}

case "$1" in
    status) status ;;
    enroll|add) enroll "$2" ;;
    verify) verify ;;
    fingers) list_fingers ;;
    clear|remove) clear_all ;;
    *) show_help ;;
esac
#!/bin/bash
# TinkerOS Biometric Authentication

set -e

SECURITY_DIR="$HOME/.tinker/security"
mkdir -p "$SECURITY_DIR"

setup_fingerprint() {
    echo "Setting up Fingerprint Authentication..."
    
    if command -v fprintd >/dev/null 2>&1; then
        echo "Please place your finger on the reader..."
        fprintd-enroll
        
        if [ $? -eq 0 ]; then
            echo "Fingerprint enrolled!"
        else
            echo "Fingerprint enrollment failed"
        fi
    else
        echo "fprintd not found. Installing..."
        sudo apt install -y fprintd libpam-fprintd
        setup_fingerprint
    fi
}

verify_fingerprint() {
    echo "Place your finger on the reader..."
    
    if command -v fprintd-verify >/dev/null 2>&1; then
        fprintd-verify
        return $?
    fi
    
    return 1
}

setup_face() {
    echo "Setting up Face Recognition..."
    
    if command -v howdy >/dev/null 2>&1; then
        echo "Looking at the camera..."
        sudo howdy add
        
        if [ $? -eq 0 ]; then
            echo "Face data enrolled!"
        else
            echo "Face enrollment failed"
        fi
    else
        echo "howdy not found"
        echo "Install from: https://github.com/boltgolt/howdy"
    fi
}

list_biometrics() {
    echo "Biometric Devices:"
    echo ""
    
    if command -v fprintd-list >/dev/null 2>&1; then
        fprintd-list "$USER" 2>/dev/null || echo "No fingerprints enrolled"
    fi
}

remove_biometric() {
    echo "Removing biometric data..."
    
    if command -v fprintd-delete >/dev/null 2>&1; then
        fprintd-delete "$USER"
        echo "Fingerprint data removed"
    fi
}

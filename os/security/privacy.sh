#!/bin/bash
# TinkerOS Privacy Permissions

set -e

SECURITY_DIR="$HOME/.tinker/security"
PRIVACY_DB="$SECURITY_DIR/privacy.db"
mkdir -p "$SECURITY_DIR"

request_permission() {
    local app=$1
    local permission=$2
    
    if [ -f "$PRIVACY_DB" ] && grep -q "$app:$permission:granted" "$PRIVACY_DB"; then
        return 0
    fi
    
    echo ""
    echo "Privacy Permission Request"
    echo "  App: $app"
    echo "  wants: $permission"
    echo ""
    echo "  1) Allow  2) Deny  3) While using"
    echo ""
    read -p "  Choose (1-3): " choice
    
    local status="denied"
    case $choice in
        1) status="granted" ;;
        2) status="denied" ;;
        3) status="temporary" ;;
    esac
    
    echo "$app:$permission:$status:$(date -Iseconds)" >> "$PRIVACY_DB"
    [ "$status" = "granted" ] || [ "$status" = "temporary" ]
}

check_permission() {
    local app=$1
    local permission=$2
    if [ -f "$PRIVACY_DB" ]; then
        grep -q "^$app:$permission:granted\|^$app:$permission:temporary" "$PRIVACY_DB"
    else
        return 1
    fi
}

revoke_permission() {
    local app=$1
    local permission=$2
    sed -i "/^$app:$permission:/d" "$PRIVACY_DB" 2>/dev/null
    echo "Permission revoked"
}

show_permissions() {
    echo "Privacy Permissions:"
    echo ""
    if [ -f "$PRIVACY_DB" ]; then
        cat "$PRIVACY_DB"
    else
        echo "No permissions recorded."
    fi
}

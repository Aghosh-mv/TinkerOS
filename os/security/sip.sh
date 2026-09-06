#!/bin/bash
# TinkerOS System Integrity Protection

set -e

SECURITY_DIR="$HOME/.tinker/security"
SIP_LOG="$SECURITY_DIR/sip.log"
mkdir -p "$SECURITY_DIR"

check_integrity() {
    echo "Checking System Integrity..."
    echo ""
    
    local issues=0
    
    local critical_files=(
        "/bin/ls" "/bin/cat" "/bin/cp" "/bin/mv" "/bin/rm"
        "/usr/bin/sudo" "/usr/bin/passwd"
        "/etc/passwd" "/etc/shadow" "/etc/sudoers"
    )
    
    for file in "${critical_files[@]}"; do
        if [ -f "$file" ]; then
            local owner=$(stat -c "%U" "$file" 2>/dev/null)
            if [ "$owner" != "root" ]; then
                echo "  X $file - Wrong owner: $owner"
                issues=$((issues + 1))
            fi
        fi
    done
    
    if [ $issues -eq 0 ]; then
        echo "System integrity verified!"
    else
        echo "Found $issues integrity issues"
    fi
}

protect_system() {
    echo "Setting up System Integrity Protection..."
    
    local protected_dirs=("/bin" "/sbin" "/usr/bin" "/usr/sbin")
    
    for dir in "${protected_dirs[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -type f -executable -exec sudo chattr +i {} \; 2>/dev/null
            echo "Protected: $dir"
        fi
    done
    
    echo "System files protected"
}

show_status() {
    echo "System Integrity Protection Status:"
    echo ""
    
    if [ -d /bin ]; then
        local bin_immutable=$(lsattr /bin/ls 2>/dev/null | grep -c "i")
        if [ "$bin_immutable" -gt 0 ]; then
            echo "/bin: Protected"
        else
            echo "/bin: Not protected"
        fi
    fi
}

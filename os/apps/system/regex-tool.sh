#!/bin/bash
# TinkerOS Regex Tool - Test regex patterns

set -e

# Test regex
test_regex() {
    local pattern=$1
    local string=$2
    
    echo "Pattern: $pattern"
    echo "String: $string"
    echo ""
    
    if echo "$string" | grep -P "$pattern" >/dev/null 2>&1; then
        echo "MATCH!"
        echo "$string" | grep -Po "$pattern" 2>/dev/null
    else
        echo "No match"
    fi
}

# Interactive mode
interactive() {
    echo "Regex Tester (Ctrl+C to exit)"
    echo ""
    
    while true; do
        echo -n "Pattern: "
        read pattern
        echo -n "String: "
        read string
        
        test_regex "$pattern" "$string"
        echo ""
    done
}

# Common patterns
common() {
    echo "Common Regex Patterns:"
    echo ""
    echo "  Email:    ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    echo "  URL:      ^https?://[^\s]+$"
    echo "  IP:       ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
    echo "  Phone:    ^[0-9]{3}-[0-9]{3}-[0-9]{4}$"
    echo "  Date:     ^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
    echo "  Hex:      ^#?[0-9a-fA-F]{6}$"
}

show_help() {
    echo "Usage: tinker-regex [command]"
    echo ""
    echo "Commands:"
    echo "  test <pattern> <string>  Test regex"
    echo "  interactive             Interactive mode"
    echo "  common                  Common patterns"
    echo "  help                    Show this help"
}

case "$1" in
    test|check) test_regex "$2" "$3" ;;
    interactive|i) interactive ;;
    common) common ;;
    *) show_help ;;
esac

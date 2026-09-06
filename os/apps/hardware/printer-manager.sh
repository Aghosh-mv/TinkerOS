#!/bin/bash
# TinkerOS Printer Manager - Manage printers, print jobs, and queues

set -e

PM_DIR="$HOME/.tinker/printers"
mkdir -p "$PM_DIR"

# Detect backend
detect_backend() {
    if command -v lpstat &>/dev/null && [ -d /etc/cups ]; then echo "cups"
    elif [ -x /usr/sbin/cupsd ] || systemctl is-active cups 2>/dev/null | grep -q active; then echo "cups"
    else echo "none"
    fi
}

# List printers
list() {
    echo "=== Printers ==="
    echo ""
    local backend=$(detect_backend)
    
    case $backend in
        cups)
            if lpstat -p 2>/dev/null | grep -q .; then
                lpstat -p -d 2>/dev/null | sed 's/^/  /'
                echo ""
                echo "Default printer:"
                lpstat -d 2>/dev/null | sed 's/^/  /'
            else
                echo "  No printers configured"
            fi
            ;;
        none)
            echo "  CUPS not detected"
            ;;
    esac
}

# Show print jobs
jobs() {
    echo "=== Print Jobs ==="
    echo ""
    local backend=$(detect_backend)
    
    case $backend in
        cups)
            local jobs=$(lpstat -o 2>/dev/null)
            if [ -n "$jobs" ]; then
                echo "$jobs" | sed 's/^/  /'
                echo ""
                echo "Total jobs: $(echo "$jobs" | grep -c .)"
            else
                echo "  No active jobs"
            fi
            ;;
        none)
            echo "  CUPS not detected"
            ;;
    esac
}

# Test print
test() {
    echo "=== Test Print ==="
    echo ""
    local backend=$(detect_backend)
    
    case $backend in
        cups)
            if command -v lp &>/dev/null; then
                echo "Printing test page to default printer..."
                # Generate a test document
                local testdir="$PM_DIR/test"
                mkdir -p "$testdir"
                echo "TinkerOS Printer Test $1" > "$testdir/test.txt"
                echo "Date: $(date)" >> "$testdir/test.txt"
                echo "Printer test page for TinkerOS Control Center." >> "$testdir/test.txt"
                
                if command -v enscript &>/dev/null; then
                    enscript -p - "$testdir/test.txt" 2>/dev/null | lp - 2>&1 | sed 's/^/  /'
                else
                    lp "$testdir/test.txt" 2>&1 | sed 's/^/  /'
                fi
                echo "  Sent"
            else
                echo "  lp command not found (install cups-client)"
            fi
            ;;
        none)
            echo "  CUPS not detected"
            ;;
    esac
}

# Add printer
add() {
    echo "=== Add Printer ==="
    echo ""
    local backend=$(detect_backend)
    
    case $backend in
        cups)
            echo "Available printers/options:"
            echo "  - USB/connected:  lpadmin -p <name> -E -v <uri>"
            echo "  - Network:        lpadmin -p <name> -E -v socket://<ip>:9100"
            echo "  - IPP:            lpadmin -p <name> -E -v ipp://<host>/ipp/print"
            echo ""
            echo "Detected USB printers:"
            lpinfo -v 2>/dev/null | grep -iE "usb|socket|ipp" | sed 's/^/  /' || echo "  Try: lpinfo -v"
            echo ""
            echo "Usage: $0 add <name> <uri>"
            ;;
        none)
            echo "  CUPS not detected"
            ;;
    esac
}

# Get device URI from lpinfo
uris() {
    echo "=== Discovered Print Devices ==="
    echo ""
    local backend=$(detect_backend)
    case $backend in
        cups)
            if command -v lpinfo &>/dev/null; then
                lpinfo -v 2>/dev/null | sed 's/^/  /'
            else
                echo "  lpinfo not found (install cups-client)"
            fi
            ;;
        none)
            echo "  CUPS not detected"
            ;;
    esac
}

# Set default printer
set_default() {
    local name=$1
    [ -z "$name" ] && { list; echo "Usage: $0 set-default <printer>"; return 1; }
    lpadmin -d "$name" 2>&1 | sed 's/^/  /'
    echo "  Default set to $name"
}

# Cancel jobs
cancel() {
    local jobid=$1
    if [ -n "$jobid" ]; then
        cancel "$jobid" 2>&1 | sed 's/^/  /'
        echo "  Cancelled job $jobid"
    else
        echo "Cancelling all jobs..."
        cancel -a 2>&1 | sed 's/^/  /'
        echo "  All jobs cancelled"
    fi
}

# Show cups status
status() {
    echo "=== CUPS Status ==="
    echo ""
    if systemctl is-active cups 2>/dev/null | grep -q active; then
        echo "  CUPS: active (PID $(systemctl show -p MainPID cups 2>/dev/null | cut -d= -f2))"
        echo "  Web UI: http://localhost:631"
    else
        echo "  CUPS: inactive"
        echo "  Start: systemctl start cups"
    fi
}

show_help() {
    echo "Usage: tinker-printer [command]"
    echo ""
    echo "Commands:"
    echo "  list                List printers"
    echo "  jobs                Show print jobs"
    echo "  test                Print test page"
    echo "  add <name> <uri>    Add printer"
    echo "  uris                Discover printer devices"
    echo "  set-default <name>  Set default printer"
    echo "  cancel [id]         Cancel jobs"
    echo "  status              CUPS status"
    echo "  help                Show this help"
}

case "$1" in
    list) list ;;
    jobs) jobs ;;
    test) test ;;
    add) add ;;
    uris) uris ;;
    set-default) set_default "$2" ;;
    cancel) cancel "$2" ;;
    status) status ;;
    *) show_help ;;
esac
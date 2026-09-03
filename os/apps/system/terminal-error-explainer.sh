#!/bin/bash
# TinkerOS Terminal Error Explainer
# Explains common terminal/kernel error messages and suggests fixes.
# Complements the kernel's terminal/typo_corrector + error_explainer.

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

explain() {
    local err="$1" key
    key=$(echo "$err" | tr '[:upper:]' '[:lower:]')
    case "$key" in
        *"permission denied"*)
            echo -e "${RED}Permission denied${NC}"
            echo "  Cause: process lacks permission on the file/device."
            echo "  Fix:   sudo or add user to the owning group; check file perms (ls -l).";;
        *"command not found"*)
            echo -e "${RED}Command not found${NC}"
            echo "  Cause: binary not in PATH or not installed."
            echo "  Fix:   Install it; verify PATH; check for typos.";;
        *"no space left"*|*"enospc"*)
            echo -e "${RED}No space left on device${NC}"
            echo "  Fix:   df -h; clean /tmp, logs; resize partition.";;
        *"segmentation"*|*"segfault"*)
            echo -e "${RED}Segmentation fault${NC}"
            echo "  Cause: invalid memory access in program."
            echo "  Fix:   Rerun under gdb; update the app; check bug reports.";;
        *"cannot open shared object"*)
            echo -e "${RED}Missing shared library${NC}"
            echo "  Fix:   ldd the binary; install the missing lib package.";;
        *"not found"*)
            echo -e "${YELLOW}Generic 'not found'${NC}"
            echo "  Check the exact filename/path and casing.";;
        *"connection refused"*)
            echo -e "${RED}Connection refused${NC}"
            echo "  Fix:   Is the service running (systemctl status)? Firewall?";;
        *"killed"*)
            echo -e "${RED}Process killed (OOM likely)${NC}"
            echo "  Fix:   dmesg | tail for OOM; close apps or add swap.";;
        *)
            echo -e "${YELLOW}No built-in explanation for: $err${NC}"
            echo "  Hint:  run 'man' for the command, or check dmesg/journalctl.";;
    esac
}

echo -e "${BLUE}── TinkerOS Terminal Error Explainer ──${NC}"
if [ $# -ge 1 ]; then
    explain "$*"
    exit 0
fi
read -r -p "paste error text: " input
explain "$input"

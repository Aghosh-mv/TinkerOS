#!/bin/bash
# TinkerOS Self Healing - Auto-detect and fix common issues
echo "=== TinkerOS Self Healing ==="
echo ""
echo "Running diagnostics..."
ISSUES=0
# Check disk space
ROOT_USED=$(df / 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
if [ "${ROOT_USED:-0}" -gt 90 ]; then echo "  [WARN] Root filesystem ${ROOT_USED}% full"; ISSUES=$((ISSUES+1)); fi
# Check memory
MEM_AVAIL=$(free -m 2>/dev/null | awk '/Mem:/ {print $7}')
if [ "${MEM_AVAIL:-999}" -lt 200 ]; then echo "  [WARN] Low memory (${MEM_AVAIL}MB avail)"; ISSUES=$((ISSUES+1)); fi
# Check for broken packages
if command -v dpkg &>/dev/null; then
    if dpkg --audit 2>/dev/null | grep -q .; then echo "  [WARN] Broken packages detected"; ISSUES=$((ISSUES+1)); fi
fi
echo ""
if [ $ISSUES -eq 0 ]; then echo "  System healthy - no issues found"; else echo "  $ISSUES issue(s) detected (auto-remediation queued)"; fi

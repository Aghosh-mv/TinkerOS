#!/bin/bash
# TinkerOS Security Hardware Tuning - TPM, Secure Boot, IOMMU, CPU mitigations
case "${1:-status}" in
  status)
    echo "=== Security Hardware ==="
    echo "  TPM: $(ls /dev/tpm* 2>/dev/null | head -1 || echo not found)"
    echo "  Secure Boot: $(mokutil --sb-state 2>/dev/null || echo unknown)"
    echo "  IOMMU: $(dmesg 2>/dev/null | grep -i iommu | head -1 || echo unknown)"
    echo "  CPU mitigations: $(cat /sys/devices/system/cpu/vulnerabilities/* 2>/dev/null | head -5 | sed 's/^/    /')"
    ;;
  mitigations) echo "Current mitigations:"; cat /sys/devices/system/cpu/vulnerabilities/* 2>/dev/null | sed 's/^/  /' || echo "N/A" ;;
  *) echo "Usage: $0 {status|mitigations}";;
esac

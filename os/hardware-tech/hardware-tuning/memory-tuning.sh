#!/bin/bash
# TinkerOS Memory Tuning - swappiness, huge pages, KSM, zRAM, NUMA
case "${1:-status}" in
  status)
    echo "=== Memory Status ==="
    free -h | sed 's/^/  /'
    echo "  Swappiness: $(cat /proc/sys/vm/swappiness)"
    echo "  Huge pages: $(cat /proc/sys/vm/nr_hugepages)"
    echo "  KSM: $(cat /sys/kernel/mm/ksm/run 2>/dev/null | sed 's/1/on/; s/0/off/')"
    echo "  THP: $(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | head -1)"
    ;;
  swappiness) echo ${2:-60} | sudo tee /proc/sys/vm/swappiness > /dev/null 2>&1 && echo "Swappiness: ${2:-60}" ;;
  hugepages) echo ${2:-1024} | sudo tee /proc/sys/vm/nr_hugepages > /dev/null 2>&1 && echo "Huge pages: ${2:-1024}" ;;
  ksm) echo ${2:-1} | sudo tee /sys/kernel/mm/ksm/run > /dev/null 2>&1 && echo "KSM: ${2:-1}" ;;
  zram) sudo modprobe zram 2>/dev/null && sudo zramctl /dev/zram0 --algorithm lz4 --size ${2:-4G} 2>/dev/null && echo "zRAM: ${2:-4G}" || echo "Need root" ;;
  *) echo "Usage: $0 {status|swappiness <val>|hugepages <val>|ksm <0|1>|zram <size>}";;
esac

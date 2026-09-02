#!/bin/bash
# TinkerOS CPU Tuning - frequency scaling, core parking, turbo, governor, C-states
case "${1:-status}" in
  status)
    echo "=== CPU Status ==="
    echo "  Model: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
    echo "  Cores: $(nproc)"
    echo "  Current freq: $(cat /proc/cpuinfo | grep -m1 'cpu MHz' | cut -d: -f2 | xargs) MHz"
    echo "  Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unavailable)"
    echo "  Max freq: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo N/A)"
    echo "  Turbo: $(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null | sed 's/1/off/; s/0/on/' || echo unknown)"
    ;;
  governor) echo "${2:-powersave}" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 && echo "Governor: ${2:-powersave}" || echo "Need root" ;;
  cores) for i in $(seq ${2:-3} ${3:-7}); do echo 0 | sudo tee /sys/devices/system/cpu/cpu$i/online > /dev/null 2>&1; done && echo "Cores ${2:-3}-${3:-7} parked" ;;
  turbo) val=$( [ "$2" = "off" ] && echo 1 || echo 0 ); echo $val | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null 2>&1 && echo "Turbo $2" || echo "Need root" ;;
  *) echo "Usage: $0 {status|governor <name>|cores <from> <to>|turbo [on|off]}";;
esac

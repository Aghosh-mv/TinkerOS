#!/usr/bin/env bash
# korrinos-dashboard.sh — System Health Dashboard
# Real-time system stats, alerts, and health monitoring

set -euo pipefail

DASH_DIR="${HOME}/.config/korrinos/dashboard"
mkdir -p "$DASH_DIR"

# System health overview
cmd_health() {
  echo "╔══════════════════════════════════════════════╗"
  echo "║        KorrinOS System Health Dashboard      ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""

  # CPU
  local cpu_usage cpu_model cores
  cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' 2>/dev/null || echo "0")
  cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs 2>/dev/null || echo "Unknown")
  cores=$(nproc 2>/dev/null || echo "?")
  echo "  CPU: ${cpu_usage}% used | ${cores} cores"
  echo "       ${cpu_usage:-0}" | awk '{
    bar=""
    pct=$1+0
    filled=int(pct/5)
    for(i=0;i<filled;i++) bar=bar"█"
    for(i=filled;i<20;i++) bar=bar"░"
    printf "       [%s] %.0f%%\n", bar, pct
  }'
  echo "       ${cpu_model}"
  echo ""

  # Memory
  local mem_total mem_used mem_pct
  read -r mem_total mem_used _ <<< $(free -m | awk '/^Mem:/{print $2, $3}')
  mem_pct=$((mem_used * 100 / mem_total))
  echo "  RAM: ${mem_used}MB / ${mem_total}MB (${mem_pct}%)"
  printf "       ["
  for ((i=0; i<20; i++)); do
    [ $i -lt $((mem_pct / 5)) ] && printf "█" || printf "░"
  done
  printf "] %d%%\n" "$mem_pct"
  echo ""

  # Disk
  local disk_used disk_total disk_pct
  read -r disk_total disk_used disk_pct <<< $(df -h / | awk 'NR==2{print $2, $3, $5}' | tr -d '%')
  echo "  Disk: ${disk_used} / ${disk_total} (${disk_pct}%)"
  printf "       ["
  for ((i=0; i<20; i++)); do
    [ $i -lt $((disk_pct / 5)) ] && printf "█" || printf "░"
  done
  printf "] %d%%\n" "$disk_pct"
  echo ""

  # GPU (if NVIDIA)
  if command -v nvidia-smi &>/dev/null; then
    local gpu_pct gpu_mem gpu_temp
    gpu_pct=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "?")
    gpu_mem=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader 2>/dev/null | head -1 || echo "?")
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1 || echo "?")
    echo "  GPU: ${gpu_pct}% | ${gpu_mem} | ${gpu_temp}°C"
    echo ""
  fi

  # Network
  local net_up net_down
  net_up=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo "0")
  net_down=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo "0")
  echo "  Network: ↑ $(numfmt --to=iec $net_up 2>/dev/null || echo ${net_up}B) | ↓ $(numfmt --to=iec $net_down 2>/dev/null || echo ${net_down}B)"
  echo ""

  # Uptime
  local uptime_str
  uptime_str=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//')
  echo "  Uptime: ${uptime_str}"
  echo ""

  # Top processes
  echo "  Top Processes:"
  ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 | awk '{printf "    %-8s %5s%% CPU  %5s%% MEM  %s\n", $1, $3, $4, $11}' 2>/dev/null
  echo ""

  # Temperature sensors
  if command -v sensors &>/dev/null; then
    echo "  Temperatures:"
    sensors 2>/dev/null | grep -E "°C" | head -5 | sed 's/^/    /'
    echo ""
  fi

  # Alerts
  local alerts=0
  [ "$mem_pct" -gt 85 ] && echo "  ⚠ ALERT: Memory usage > 85%!" && alerts=$((alerts+1))
  [ "$disk_pct" -gt 90 ] && echo "  ⚠ ALERT: Disk usage > 90%!" && alerts=$((alerts+1))
  [ "${gpu_pct:-0}" -gt 90 ] 2>/dev/null && echo "  ⚠ ALERT: GPU usage > 90%!" && alerts=$((alerts+1))
  [ "$alerts" -eq 0 ] && echo "  ✓ All systems nominal"
}

# Real-time monitor mode
cmd_monitor() {
  local interval="${1:-2}"
  echo "KorrinOS Live Monitor (Ctrl+C to exit, refresh every ${interval}s)"
  echo ""
  while true; do
    clear
    cmd_health
    sleep "$interval"
  done
}

# Process monitor
cmd_top() {
  echo "=== KorrinOS Process Monitor ==="
  echo ""
  ps aux --sort=-%cpu | head -15 | awk 'NR==1{printf "%-10s %5s%%CPU %5s%%MEM %8s %s\n","USER","CPU","MEM","RSS","COMMAND"} NR>1{printf "%-10s %5s%% %5s%% %7sK %s\n",$1,$3,$4,$6,$11}'
}

# Disk usage
cmd_disk() {
  echo "=== Disk Usage ==="
  echo ""
  df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -v tmpfs | grep -v devtmpfs
  echo ""
  echo "Largest directories:"
  du -h --max-depth=1 / 2>/dev/null | sort -rh | head -10 | sed 's/^/  /'
}

# Network stats
cmd_network() {
  echo "=== Network Status ==="
  echo ""
  echo "Interfaces:"
  ip -br addr 2>/dev/null | sed 's/^/  /'
  echo ""
  echo "Connections:"
  ss -tuln 2>/dev/null | head -15 | sed 's/^/  /'
  echo ""
  echo "Traffic:"
  for iface in /sys/class/net/*/statistics; do
    local name
    name=$(echo "$iface" | cut -d/ -f5)
    [ "$name" = "lo" ] && continue
    local rx tx
    rx=$(cat "$iface/rx_bytes" 2>/dev/null || echo 0)
    tx=$(cat "$iface/tx_bytes" 2>/dev/null || echo 0)
    echo "  ${name}: ↓ $(numfmt --to=iec $rx 2>/dev/null || echo ${rx}B) | ↑ $(numfmt --to=iec $tx 2>/dev/null || echo ${tx}B)"
  done
}

# Battery status
cmd_battery() {
  echo "=== Battery Status ==="
  echo ""
  if [ -f /sys/class/power_supply/BAT0/capacity ]; then
    local cap=$(cat /sys/class/power_supply/BAT0/capacity)
    local status=$(cat /sys/class/power_supply/BAT0/status)
    local energy=$(cat /sys/class/power_supply/BAT0/energy_now 2>/dev/null || echo "?")
    local energy_full=$(cat /sys/class/power_supply/BAT0/energy_full 2>/dev/null || echo "?")
    echo "  Battery: ${cap}% (${status})"
    printf "  ["
    for ((i=0; i<20; i++)); do
      [ $i -lt $((cap / 5)) ] && printf "█" || printf "░"
    done
    printf "] %d%%\n" "$cap"
    [ "$energy" != "?" ] && echo "  Energy: ${energy} / ${energy_full} µWh"
  else
    echo "  No battery detected (desktop system)"
  fi
  echo ""
  # Power supply info
  if [ -d /sys/class/power_supply ]; then
    echo "  Power supplies:"
    for ps in /sys/class/power_supply/*/type; do
      local ps_name ps_type
      ps_name=$(echo "$ps" | cut -d/ -f5)
      ps_type=$(cat "$ps" 2>/dev/null)
      echo "    ${ps_name}: ${ps_type}"
    done
  fi
}

# Save snapshot for later review
cmd_snapshot() {
  local snap_file="$DASH_DIR/snapshot_$(date +%Y%m%d_%H%M%S).txt"
  cmd_health > "$snap_file" 2>&1
  echo "Snapshot saved: $snap_file"
}

# Alerts log
cmd_alerts() {
  echo "=== System Alerts ==="
  echo ""
  local alerts=0

  # Check various conditions
  local mem_pct=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
  local disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
  local load=$(cat /proc/loadavg | awk '{print $1}')

  [ "$mem_pct" -gt 85 ] && echo "  ⚠ HIGH MEMORY: ${mem_pct}% used" && alerts=$((alerts+1))
  [ "$disk_pct" -gt 90 ] && echo "  ⚠ LOW DISK: ${disk_pct}% used" && alerts=$((alerts+1))

  local cores=$(nproc)
  local load_int=$(echo "$load" | cut -d. -f1)
  [ "$load_int" -gt "$cores" ] && echo "  ⚠ HIGH LOAD: ${load} (>${cores} cores)" && alerts=$((alerts+1))

  # Check for OOM kills
  local oom=$(dmesg 2>/dev/null | grep -c "Out of memory" || echo 0)
  [ "$oom" -gt 0 ] && echo "  ⚠ OOM KILLS: ${oom} detected" && alerts=$((alerts+1))

  [ "$alerts" -eq 0 ] && echo "  ✓ No alerts — system healthy"
}

case "${1:-help}" in
  health)       cmd_health ;;
  monitor)      shift; cmd_monitor "$@" ;;
  top)          cmd_top ;;
  disk)         cmd_disk ;;
  network)      cmd_network ;;
  battery)      cmd_battery ;;
  snapshot)     cmd_snapshot ;;
  alerts)       cmd_alerts ;;
  *)
    echo "KorrinOS Dashboard"
    echo "Usage: korrinos-dashboard.sh <command>"
    echo ""
    echo "Commands:"
    echo "  health              System health overview"
    echo "  monitor [interval]  Live monitoring (default: 2s refresh)"
    echo "  top                 Process monitor"
    echo "  disk                Disk usage breakdown"
    echo "  network             Network status & traffic"
    echo "  battery             Battery/power status"
    echo "  snapshot            Save health snapshot"
    echo "  alerts              Check system alerts"
    ;;
esac

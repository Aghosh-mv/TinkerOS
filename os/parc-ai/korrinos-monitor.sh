#!/usr/bin/env bash
# korrinos-monitor.sh — Real-time System Monitor
# Live CPU, RAM, GPU, network, process monitoring with alerts

set -euo pipefail

MONITOR_DIR="${HOME}/.config/korrinos/monitor"
MONITOR_CONFIG="$MONITOR_DIR/config.json"
mkdir -p "$MONITOR_DIR"

# Default config
init_monitor() {
  if [ ! -f "$MONITOR_CONFIG" ]; then
    cat > "$MONITOR_CONFIG" << 'DEFAULTS'
{
  "refresh_rate": 2,
  "show_gpu": true,
  "show_network": true,
  "show_processes": true,
  "process_count": 10,
  "alert_cpu": 90,
  "alert_ram": 85,
  "alert_temp": 80,
  "alerts_enabled": true
}
DEFAULTS
    echo "Monitor config initialized"
  fi
}

# Get config
get_config() {
  local key="$1"
  local default="${2:-}"
  python3 -c "import json; print(json.load(open('$MONITOR_CONFIG')).get('$key', '$default'))" 2>/dev/null || echo "$default"
}

# Live monitor view
cmd_live() {
  local interval
  interval=$(get_config "refresh_rate" "2")
  local show_gpu
  show_gpu=$(get_config "show_gpu" "true")
  local show_net
  show_net=$(get_config "show_network" "true")
  local show_procs
  show_procs=$(get_config "show_processes" "true")
  local proc_count
  proc_count=$(get_config "process_count" "10")
  
  echo "KorrinOS Live System Monitor (Ctrl+C to exit)"
  echo ""
  
  while true; do
    clear
    
    # Header
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 KorrinOS System Monitor                     ║"
    echo "║                 $(date '+%Y-%m-%d %H:%M:%S')                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # CPU
    local cpu_pct
    cpu_pct=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' 2>/dev/null || echo "0")
    echo "  CPU Usage:"
    printf "    ["
    for ((i=0; i<30; i++)); do
      [ $i -lt $(echo "$cpu_pct" | cut -d. -f1 | head -1) ] && printf "█" || printf "░"
    done
    printf "] %s%%\n" "$cpu_pct"
    
    # Load average
    local load
    load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo "    Load: ${load}"
    echo ""
    
    # Memory
    local mem_total mem_used mem_pct
    read -r mem_total mem_used _ <<< $(free -m | awk '/^Mem:/{print $2, $3}')
    mem_pct=$((mem_used * 100 / mem_total))
    echo "  Memory:"
    printf "    ["
    for ((i=0; i<30; i++)); do
      [ $i -lt $((mem_pct * 30 / 100)) ] && printf "█" || printf "░"
    done
    printf "] %d%% (%dMB / %dMB)\n" "$mem_pct" "$mem_used" "$mem_total"
    echo ""
    
    # Swap
    local swap_total swap_used swap_pct
    read -r swap_total swap_used _ <<< $(free -m | awk '/^Swap:/{print $2, $3}')
    if [ "$swap_total" -gt 0 ]; then
      swap_pct=$((swap_used * 100 / swap_total))
      echo "  Swap:"
      printf "    ["
      for ((i=0; i<30; i++)); do
        [ $i -lt $((swap_pct * 30 / 100)) ] && printf "█" || printf "░"
      done
      printf "] %d%% (%dMB / %dMB)\n" "$swap_pct" "$swap_used" "$swap_total"
      echo ""
    fi
    
    # GPU
    if [ "$show_gpu" = "true" ] && command -v nvidia-smi &>/dev/null; then
      local gpu_pct gpu_mem gpu_temp
      gpu_pct=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "?")
      gpu_mem=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader 2>/dev/null | head -1 || echo "?")
      gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1 || echo "?")
      echo "  GPU:"
      printf "    ["
      if [ "$gpu_pct" != "?" ]; then
        for ((i=0; i<30; i++)); do
          [ $i -lt $((gpu_pct * 30 / 100)) ] && printf "█" || printf "░"
        done
        printf "] %s%% | %s | %s°C\n" "$gpu_pct" "$gpu_mem" "$gpu_temp"
      else
        printf "] N/A\n"
      fi
      echo ""
    fi
    
    # Network
    if [ "$show_net" = "true" ]; then
      local rx_prev tx_prev rx_curr tx_curr
      rx_prev=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo 0)
      tx_prev=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo 0)
      sleep 1
      rx_curr=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo 0)
      tx_curr=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo 0)
      local rx_rate=$(( (rx_curr - rx_prev) / 1024 ))
      local tx_rate=$(( (tx_curr - tx_prev) / 1024 ))
      echo "  Network:"
      echo "    ↓ ${rx_rate} KB/s | ↑ ${tx_rate} KB/s"
      echo ""
    fi
    
    # Disk I/O
    echo "  Disk I/O:"
    iostat -d 1 1 2>/dev/null | tail -n +4 | head -5 | awk '{printf "    %s: read %s MB/s, write %s MB/s\n", $1, $3, $4}' 2>/dev/null || echo "    (iostat not available)"
    echo ""
    
    # Top processes
    if [ "$show_procs" = "true" ]; then
      echo "  Top Processes (by CPU):"
      ps aux --sort=-%cpu 2>/dev/null | head -$((proc_count + 1)) | tail -$proc_count | awk '{printf "    %-8s %5s%%CPU %5s%%MEM %s\n", $1, $3, $4, $11}' 2>/dev/null
      echo ""
    fi
    
    # Alerts
    local alerts
    alerts=$(get_config "alerts_enabled" "true")
    if [ "$alerts" = "true" ]; then
      local alert_cpu alert_ram
      alert_cpu=$(get_config "alert_cpu" "90")
      alert_ram=$(get_config "alert_ram" "85")
      
      local cpu_int=${cpu_pct%%.*}
      if [ "${cpu_int:-0}" -gt "$alert_cpu" ] 2>/dev/null; then
        echo "  ⚠ ALERT: CPU usage > ${alert_cpu}%!"
      fi
      if [ "$mem_pct" -gt "$alert_ram" ]; then
        echo "  ⚠ ALERT: Memory usage > ${alert_ram}%!"
      fi
    fi
    
    sleep "$interval"
  done
}

# Quick status
cmd_status() {
  echo "=== KorrinOS System Status ==="
  echo ""
  
  # CPU
  local cpu_pct
  cpu_pct=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' 2>/dev/null || echo "0")
  echo "  CPU: ${cpu_pct}%"
  
  # Memory
  local mem_total mem_used mem_pct
  read -r mem_total mem_used _ <<< $(free -m | awk '/^Mem:/{print $2, $3}')
  mem_pct=$((mem_used * 100 / mem_total))
  echo "  RAM: ${mem_used}MB / ${mem_total}MB (${mem_pct}%)"
  
  # Disk
  local disk_pct
  disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
  echo "  Disk: ${disk_pct}%"
  
  # GPU
  if command -v nvidia-smi &>/dev/null; then
    local gpu_pct gpu_temp
    gpu_pct=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "?")
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1 || echo "?")
    echo "  GPU: ${gpu_pct}% | ${gpu_temp}°C"
  fi
  
  # Load
  local load
  load=$(cat /proc/loadavg | awk '{print $1}')
  echo "  Load: ${load}"
  
  # Uptime
  local uptime_str
  uptime_str=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//')
  echo "  Uptime: ${uptime_str}"
}

# Process tree
cmd_tree() {
  echo "=== Process Tree ==="
  echo ""
  ps auxf 2>/dev/null | head -50 | sed 's/^/  /'
}

# Kill process
cmd_kill() {
  local pid="$1"
  local signal="${2:-TERM}"
  
  echo "Killing PID ${pid} with signal ${signal}..."
  kill -"$signal" "$pid" 2>/dev/null && echo "  ✓ Sent ${signal} to ${pid}" || echo "  ✗ Failed to kill ${pid}"
}

# Monitor a specific process
cmd_watch() {
  local process="$1"
  echo "Watching: ${process} (Ctrl+C to stop)"
  echo ""
  
  while true; do
    clear
    echo "=== Watching: ${process} ==="
    echo "  $(date)"
    echo ""
    ps aux | grep "$process" | grep -v grep | awk '{printf "  PID: %s | CPU: %s%% | MEM: %s%% | RSS: %sKB\n", $2, $3, $4, $6}'
    echo ""
    echo "  Resource history:"
    ps aux | grep "$process" | grep -v grep | awk '{print $2}' | head -1 | xargs -I{} top -bn1 -p {} 2>/dev/null | tail -1 | sed 's/^/    /'
    sleep 2
  done
}

case "${1:-help}" in
  init)          init_monitor ;;
  live)          cmd_live ;;
  status)        cmd_status ;;
  tree)          cmd_tree ;;
  kill)          shift; cmd_kill "$@" ;;
  watch)         shift; cmd_watch "$@" ;;
  *)
    echo "KorrinOS Real-time System Monitor"
    echo "Usage: korrinos-monitor.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init              Initialize monitor config"
    echo "  live              Live monitoring dashboard"
    echo "  status            Quick system status"
    echo "  tree              Process tree view"
    echo "  kill <pid> [sig]  Kill process (default: SIGTERM)"
    echo "  watch <process>   Watch a specific process"
    ;;
esac

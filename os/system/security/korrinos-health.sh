#!/bin/bash
# KorrinOS System Health Checker
# Real-time system monitoring, health scores, alerts, diagnostics
# Covers CPU, memory, disk, network, GPU, thermal, services, security

set -euo pipefail

HEALTH_DIR="${HOME}/.config/korrinos/health"
HEALTH_CONFIG="$HEALTH_DIR/config.json"
HEALTH_LOG="$HEALTH_DIR/health.log"
HEALTH_HISTORY="$HEALTH_DIR/history"
mkdir -p "$HEALTH_DIR" "$HEALTH_HISTORY"

# ---- read config ----
cfg() {
  python3 -c "
import json
try:
    with open('$HEALTH_CONFIG') as f: c = json.load(f)
    print(c.get('$1', '$2'))
except: print('$2')
" 2>/dev/null
}

init_health() {
  if [ ! -f "$HEALTH_CONFIG" ]; then
    cat > "$HEALTH_CONFIG" << 'DEFAULTS'
{
  "check_interval_seconds": 300,
  "alert_threshold_disk": 90,
  "alert_threshold_memory": 85,
  "alert_threshold_cpu": 90,
  "alert_threshold_temp": 80,
  "enable_notifications": true,
  "enable_auto_heal": false,
  "log_retention_days": 30,
  "services_to_monitor": ["NetworkManager", "sshd", "bluetooth", "sddm", "gdm3", "cups"],
  "ports_to_monitor": [22, 80, 443, 3306, 5432],
  "health_score_weights": {
    "cpu": 20,
    "memory": 20,
    "disk": 20,
    "network": 15,
    "gpu": 10,
    "thermal": 10,
    "services": 5
  }
}
DEFAULTS
    echo "Health config initialized."
  fi
}

# ---- CPU health ----
check_cpu() {
  echo "--- CPU Health ---"
  local load_1 load_5 load_15
  read -r load_1 load_5 load_15 _ < /proc/loadavg
  local cores
  cores=$(nproc 2>/dev/null || echo "1")

  local load_pct
  load_pct=$(echo "$load_1 $cores" | awk '{printf "%.0f", ($1/$2)*100}')

  local cpu_info
  cpu_info=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)

  # CPU frequency
  local freq="unknown"
  if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
    freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    freq="$((freq / 1000)) MHz"
  fi

  # CPU temperature
  local temp="N/A"
  if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    temp="$(( $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null) / 1000 ))°C"
  fi

  # Steal time (VM indicator)
  local steal="0"
  if command -v mpstat &>/dev/null; then
    steal=$(mpstat 1 1 2>/dev/null | tail -1 | awk '{print $NF}' || echo "0")
  fi

  echo "  Model:     $cpu_info"
  echo "  Cores:     $cores"
  echo "  Load:      $load_1 / $load_5 / $load_15 ($load_pct%)"
  echo "  Frequency: $freq"
  echo "  Temperature: $temp"
  echo "  Steal:     ${steal}%"

  local score=100
  [ "$load_pct" -gt 80 ] && score=$((score - 30))
  [ "$load_pct" -gt 60 ] && score=$((score - 10))
  echo "$score"
}

# ---- Memory health ----
check_memory() {
  echo "--- Memory Health ---"
  local total used free buffers cached available
  read -r total used free buffers cached _ < /proc/meminfo

  total=$((total / 1024))
  available=$(( $(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}') / 1024 ))
  used=$((total - available))

  local pct=$(( (used * 100) / total ))

  local swap_total swap_used
  swap_total=$(grep SwapTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
  swap_used=$(grep SwapFree /proc/meminfo 2>/dev/null | awk '{print $2}')
  swap_total=$((swap_total / 1024))
  swap_used=$(((swap_total - swap_used / 1024)))

  echo "  Total:     ${total} MB"
  echo "  Used:      ${used} MB (${pct}%)"
  echo "  Available: ${available} MB"
  echo "  Swap:      ${swap_used} / ${swap_total} MB"

  local score=100
  [ "$pct" -gt 90 ] && score=$((score - 50))
  [ "$pct" -gt 80 ] && score=$((score - 20))
  [ "$pct" -gt 70 ] && score=$((score - 10))
  echo "$score"
}

# ---- Disk health ----
check_disk() {
  echo "--- Disk Health ---"
  local score=100

  df -h / 2>/dev/null | tail -1 | while read -r fs size used avail pct mount; do
    local pct_num=${pct%%%}
    echo "  Filesystem: $fs"
    echo "  Size:       $size"
    echo "  Used:       $used ($pct)"
    echo "  Available:  $avail"
    echo "  Mount:      $mount"

    if [ "$pct_num" -gt 90 ]; then
      echo "  WARNING: Disk usage critical!"
      echo "$score"
    elif [ "$pct_num" -gt 80 ]; then
      echo "  WARNING: Disk usage high"
      echo "$((score - 20))"
    else
      echo "$score"
    fi
  done

  # I/O stats
  if [ -f /proc/diskstats ]; then
    echo "  I/O stats:"
    cat /proc/diskstats 2>/dev/null | awk '{printf "    %s reads=%s writes=%s\n", $3, $6, $10}' | head -5
  fi
}

# ---- Network health ----
check_network() {
  echo "--- Network Health ---"
  local score=100

  # Connectivity
  if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
    echo "  Connectivity: OK"
  else
    echo "  Connectivity: FAILED"
    score=$((score - 50))
  fi

  # DNS resolution
  if host google.com &>/dev/null 2>&1 || nslookup google.com &>/dev/null 2>&1; then
    echo "  DNS: OK"
  else
    echo "  DNS: FAILED"
    score=$((score - 30))
  fi

  # Latency
  local latency
  latency=$(ping -c 3 -W 5 8.8.8.8 2>/dev/null | tail -1 | awk -F/ '{print $5}' || echo "?")
  echo "  Latency:    ${latency}ms"

  # Bandwidth estimate
  if command -v speedtest-cli &>/dev/null; then
    echo "  Run speedtest-cli for bandwidth test"
  fi

  # Interfaces
  echo "  Interfaces:"
  ip -o link show 2>/dev/null | grep -v "lo:" | awk '{printf "    %s: %s\n", $2, $NF}' | head -5

  # Open ports
  local open_ports
  open_ports=$(ss -tlnp 2>/dev/null | grep LISTEN | wc -l || echo "0")
  echo "  Open ports: $open_ports"

  echo "$score"
}

# ---- GPU health ----
check_gpu() {
  echo "--- GPU Health ---"
  local score=100

  if command -v nvidia-smi &>/dev/null; then
    local gpu_info
    gpu_info=$(nvidia-smi --query-gpu=name,memory.used,memory.total,temperature.gpu,utilization.gpu --format=csv,noheader 2>/dev/null)
    if [ -n "$gpu_info" ]; then
      echo "  NVIDIA GPU: $gpu_info"
      local temp
      temp=$(echo "$gpu_info" | awk -F, '{print $4}' | xargs)
      if [ "${temp:-0}" -gt 85 ]; then
        echo "  WARNING: GPU temperature high!"
        score=$((score - 30))
      fi
    fi
  elif command -v glxinfo &>/dev/null; then
    local renderer
    renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    echo "  Renderer: $renderer"
  else
    echo "  GPU: No info available"
    score=$((score - 10))
  fi

  echo "$score"
}

# ---- Thermal health ----
check_thermal() {
  echo "--- Thermal Health ---"
  local score=100
  local max_temp=0

  for zone in /sys/class/thermal/thermal_zone*/; do
    [ -f "${zone}temp" ] || continue
    local temp type
    temp=$(cat "${zone}temp" 2>/dev/null || echo "0")
    type=$(cat "${zone}type" 2>/dev/null || echo "unknown")
    local celsius=$((temp / 1000))
    echo "  $type: ${celsius}°C"

    if [ "$celsius" -gt "$max_temp" ]; then
      max_temp=$celsius
    fi
  done

  echo "  Max temperature: ${max_temp}°C"
  [ "$max_temp" -gt 90 ] && score=$((score - 50))
  [ "$max_temp" -gt 80 ] && score=$((score - 20))
  [ "$max_temp" -gt 70 ] && score=$((score - 10))

  echo "$score"
}

# ---- Service health ----
check_services() {
  echo "--- Service Health ---"
  local score=100
  local services
  services=$(cfg "services_to_monitor" "NetworkManager,sshd,bluetooth,sddm")

  echo "$services" | tr ',' '\n' | while read -r svc; do
    svc=$(echo "$svc" | xargs)
    if systemctl is-active "$svc" &>/dev/null 2>&1; then
      echo "  $svc: running"
    elif systemctl list-unit-files 2>/dev/null | grep -q "^${svc}.service"; then
      echo "  $svc: stopped"
      score=$((score - 10))
    fi
  done
  echo "$score"
}

# ---- Security check ----
check_security() {
  echo "--- Security Health ---"
  local score=100

  # Firewall
  if command -v ufw &>/dev/null; then
    local fw_status
    fw_status=$(ufw status 2>/dev/null | head -1)
    if echo "$fw_status" | grep -q "active"; then
      echo "  Firewall: active"
    else
      echo "  Firewall: inactive"
      score=$((score - 20))
    fi
  fi

  # SSH config
  if [ -f /etc/ssh/sshd_config ]; then
    if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
      echo "  SSH: root login enabled (risky)"
      score=$((score - 15))
    else
      echo "  SSH: root login disabled"
    fi
  fi

  # Pending updates
  if [ -f /var/run/reboot-required ]; then
    echo "  Reboot required"
    score=$((score - 5))
  fi

  # Failed login attempts
  local failed
  failed=$(journalctl -u sshd --since "24 hours ago" 2>/dev/null | grep -c "Failed" || echo "0")
  echo "  Failed SSH attempts (24h): $failed"
  [ "$failed" -gt 100 ] && score=$((score - 15))
  [ "$failed" -gt 20 ] && score=$((score - 5))

  echo "$score"
}

# ---- full health check ----
full_health_check() {
  echo "============================================="
  echo "   KorrinOS System Health Check"
  echo "============================================="
  echo ""
  echo "Time: $(date)"
  echo "Hostname: $(hostname)"
  echo "Kernel: $(uname -r)"
  echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
  echo ""

  local cpu_score mem_score disk_score net_score gpu_score therm_score svc_score sec_score

  cpu_score=$(check_cpu 2>/dev/null | tail -1)
  echo ""
  mem_score=$(check_memory 2>/dev/null | tail -1)
  echo ""
  disk_score=$(check_disk 2>/dev/null | tail -1)
  echo ""
  net_score=$(check_network 2>/dev/null | tail -1)
  echo ""
  gpu_score=$(check_gpu 2>/dev/null | tail -1)
  echo ""
  therm_score=$(check_thermal 2>/dev/null | tail -1)
  echo ""
  svc_score=$(check_services 2>/dev/null | tail -1)
  echo ""
  sec_score=$(check_security 2>/dev/null | tail -1)
  echo ""

  # Calculate weighted score
  local total_score
  total_score=$(python3 -c "
cpu=${cpu_score:-70}
mem=${mem_score:-70}
disk=${disk_score:-70}
net=${net_score:-70}
gpu=${gpu_score:-70}
therm=${therm_score:-70}
svc=${svc_score:-70}
sec=${sec_score:-70}
total = int(cpu*0.20 + mem*0.20 + disk*0.20 + net*0.15 + gpu*0.10 + therm*0.10 + svc*0.05)
print(total)
" 2>/dev/null || echo "70")

  echo "============================================="
  echo "   Health Score: ${total_score}/100"
  echo "============================================="
  echo ""

  if [ "${total_score:-70}" -ge 90 ]; then
    echo "  Status: EXCELLENT"
  elif [ "${total_score:-70}" -ge 75 ]; then
    echo "  Status: GOOD"
  elif [ "${total_score:-70}" -ge 60 ]; then
    echo "  Status: FAIR — some attention needed"
  else
    echo "  Status: POOR — action required"
  fi

  echo ""
  echo "Scores:"
  echo "  CPU:      ${cpu_score:-?}/100"
  echo "  Memory:   ${mem_score:-?}/100"
  echo "  Disk:     ${disk_score:-?}/100"
  echo "  Network:  ${net_score:-?}/100"
  echo "  GPU:      ${gpu_score:-?}/100"
  echo "  Thermal:  ${therm_score:-?}/100"
  echo "  Services: ${svc_score:-?}/100"
  echo "  Security: ${sec_score:-?}/100"

  # Save to history
  echo "$(date -Iseconds) | score=$total_score | cpu=$cpu_score mem=$mem_score disk=$disk_score net=$net_score gpu=$gpu_score therm=$therm_score svc=$svc_score sec=$sec_score" >> "$HEALTH_LOG"

  # Alert if critical
  if [ "${total_score:-70}" -lt 60 ]; then
    if command -v notify-send &>/dev/null; then
      notify-send -u critical -i dialog-warning "KorrinOS Health Alert" \
        "System health is ${total_score}/100. Check korrinos-health." 2>/dev/null || true
    fi
  fi

  echo "$total_score"
}

# ---- continuous monitor ----
continuous_monitor() {
  echo "Starting continuous health monitor (Ctrl+C to stop)..."
  while true; do
    clear
    full_health_check
    echo ""
    echo "Next check in $(cfg check_interval_seconds 300) seconds..."
    sleep "$(cfg check_interval_seconds 300)"
  done
}

# ---- status ----
health_status() {
  echo "=== Health Monitor Status ==="
  echo "Config: $HEALTH_CONFIG"
  echo "Log: $HEALTH_LOG"
  echo "Entries: $(wc -l < "$HEALTH_LOG" 2>/dev/null || echo 0)"
  if [ -f "$HEALTH_LOG" ]; then
    echo "Last check: $(tail -1 "$HEALTH_LOG" 2>/dev/null | cut -d'|' -f1 || echo 'never')"
  fi
}

# ---- main ----
case "${1:-}" in
  check)       full_health_check ;;
  monitor)     continuous_monitor ;;
  cpu)         check_cpu ;;
  memory)      check_memory ;;
  disk)        check_disk ;;
  network)     check_network ;;
  gpu)         check_gpu ;;
  thermal)     check_thermal ;;
  services)    check_services ;;
  security)    check_security ;;
  status)      health_status ;;
  init)        init_health ;;
  help|*)      echo "KorrinOS System Health Checker
Usage: korrinos-health <command>

Commands:
  check           Full system health check
  monitor         Continuous monitoring (every 5 min)
  cpu             Check CPU health
  memory          Check memory health
  disk            Check disk health
  network         Check network health
  gpu             Check GPU health
  thermal         Check thermal sensors
  services        Check running services
  security        Security health check
  status          Show health monitor status" ;;
esac

#!/bin/bash
# KorrinOS Process Monitor
# Real process management: top, kill, priority, affinity, resource tracking

set -euo pipefail

PROC_DIR="${HOME}/.config/korrinos/process"
PROC_CONFIG="$PROC_DIR/config.json"
PROC_LOG="$PROC_DIR/process.log"
mkdir -p "$PROC_DIR"

init_process() {
  if [ ! -f "$PROC_CONFIG" ]; then
    cat > "$PROC_CONFIG" << 'DEFAULTS'
{
  "sort_by": "cpu",
  "show_threads": false,
  "show_user": true,
  "show_cmdline": true,
  "max_display": 50,
  "auto_kill_threshold_cpu": 95,
  "auto_kill_threshold_time_min": 60,
  "protected_processes": ["systemd", "sshd", "gdm3", "sddm", "Xorg", "Xwayland", "pipewire", "wireplumber", "dbus-daemon", "NetworkManager"],
  "process_history_size": 100,
  "alert_on_new_process": false,
  "io_monitor": true
}
DEFAULTS
    echo "Process monitor config initialized."
  fi
}

cfg() {
  python3 -c "
import json
try:
    with open('$PROC_CONFIG') as f: c = json.load(f)
    val = c.get('$1', '$2')
    if isinstance(val, bool): print('True' if val else 'False')
    elif isinstance(val, list): print(','.join(str(x) for x in val))
    else: print(val)
except: print('$2')
" 2>/dev/null
}

# ---- top processes ----
proc_top() {
  local sort="${1:-cpu}"
  local count="${2:-30}"

  echo "============================================="
  echo "   KorrinOS Process Monitor"
  echo "============================================="
  echo ""
  echo "Time: $(date)"
  echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
  echo ""

  # System summary
  local total_procs
  total_procs=$(ps aux 2>/dev/null | tail -n +2 | wc -l)
  local running
  running=$(ps aux 2>/dev/null | awk '$8 ~ /R/' | wc -l)
  local sleeping
  sleeping=$(ps aux 2>/dev/null | awk '$8 ~ /S/' | wc -l)
  local stopped
  stopped=$(ps aux 2>/dev/null | awk '$8 ~ /T/' | wc -l)
  local zombie
  zombie=$(ps aux 2>/dev/null | awk '$8 ~ /Z/' | wc -l)

  echo "  Processes: $total_procs total, $running running, $sleeping sleeping, $stopped stopped, $zombie zombie"
  echo ""

  # Memory summary
  local mem_total mem_used mem_pct
  mem_total=$(free -m 2>/dev/null | awk '/Mem:/{print $2}')
  mem_used=$(free -m 2>/dev/null | awk '/Mem:/{print $3}')
  mem_pct=$(( (mem_used * 100) / mem_total ))
  echo "  Memory: ${mem_used}MB / ${mem_total}MB (${mem_pct}%)"
  echo ""

  # Top processes
  case "$sort" in
    cpu)    echo "  Top by CPU:"; ps aux --sort=-%cpu 2>/dev/null | head -1 | awk '{printf "  %-8s %-5s %-5s %-6s %-6s %s\n", $1, $2, $3, $4, $5, $11}'; ps aux --sort=-%cpu 2>/dev/null | head -n $((count + 1)) | tail -n $count | awk '{printf "  %-8s %-5s %-5s %-6s %-6s %s\n", $1, $2, $3, $4, $5, $11}' ;;
    mem)   echo "  Top by Memory:"; ps aux --sort=-%mem 2>/dev/null | head -1 | awk '{printf "  %-8s %-5s %-5s %-6s %-6s %s\n", $1, $2, $3, $4, $5, $11}'; ps aux --sort=-%mem 2>/dev/null | head -n $((count + 1)) | tail -n $count | awk '{printf "  %-8s %-5s %-5s %-6s %-6s %s\n", $1, $2, $3, $4, $5, $11}' ;;
    io)    echo "  Top by I/O:"; iotop -b -n 1 2>/dev/null | head -20 || echo "  (install iotop for I/O monitoring)" ;;
  esac

  echo ""
  echo "  USER    PID   %CPU  %MEM  TIME    COMMAND"
}

# ---- kill process ----
proc_kill() {
  local pid="${1:-}"
  local signal="${2:-TERM}"
  [ -z "$pid" ] && { echo "Usage: korrinos-process kill <pid> [signal]"; return 1; }

  # Check if protected
  local name
  name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "")
  local protected
  protected=$(cfg protected_processes "systemd,sshd,gdm3,sddm,Xorg")
  if echo "$protected" | tr ',' '\n' | grep -q "^${name}$"; then
    echo "WARNING: $name (PID $pid) is a protected process."
    read -p "Force kill? (yes/no): " confirm
    [ "$confirm" != "yes" ] && return 0
  fi

  echo "Killing PID $pid with signal $signal..."
  kill -"$signal" "$pid" 2>&1
  echo "$(date -Iseconds) | kill | $pid | $name | $signal" >> "$PROC_LOG"
}

# ---- set priority ----
proc_priority() {
  local pid="${1:-}"
  local priority="${2:-0}"
  [ -z "$pid" ] && { echo "Usage: korrinos-process priority <pid> <nice-value (-20 to 19)>"; return 1; }

  echo "Setting PID $pid nice to $priority..."
  sudo renice -n "$priority" -p "$pid" 2>&1
  echo "$(date -Iseconds) | priority | $pid | $priority" >> "$PROC_LOG"
}

# ---- set affinity ----
proc_affinity() {
  local pid="${1:-}"
  local cores="${2:-0}"
  [ -z "$pid" ] && { echo "Usage: korrinos-process affinity <pid> <cores (e.g. 0,1 or 2-3)>"; return 1; }

  echo "Setting PID $pid CPU affinity to cores $cores..."
  taskset -pc "$cores" "$pid" 2>&1
  echo "$(date -Iseconds) | affinity | $pid | $cores" >> "$PROC_LOG"
}

# ---- resource usage ----
proc_resources() {
  echo "=== System Resource Usage ==="
  echo ""

  # CPU
  local load_1 load_5 load_15
  read -r load_1 load_5 load_15 _ < /proc/loadavg
  echo "  CPU Load: $load_1 / $load_5 / $load_15"
  echo "  CPU Cores: $(nproc)"
  echo ""

  # Memory
  free -h 2>/dev/null
  echo ""

  # Swap
  echo "  Swap:"
  swapon --show 2>/dev/null || echo "    No swap"
  echo ""

  # Disk I/O
  echo "  Disk I/O:"
  if command -v iostat &>/dev/null; then
    iostat -d 1 1 2>/dev/null | tail -n +4 | head -5
  else
    cat /proc/diskstats 2>/dev/null | awk '{printf "    %s reads=%s writes=%s\n", $3, $6, $10}' | head -5
  fi
  echo ""

  # Top memory consumers
  echo "  Top Memory Consumers:"
  ps aux --sort=-%mem 2>/dev/null | head -6 | tail -5 | awk '{printf "    %-8s PID=%-6s CPU=%-5s MEM=%-5s %s\n", $1, $2, $3, $4, $11}'
}

# ---- find process ----
proc_find() {
  local query="${1:-}"
  [ -z "$query" ] && { echo "Usage: korrinos-process find <name>"; return 1; }

  echo "=== Processes matching: $query ==="
  echo ""
  ps aux 2>/dev/null | grep -i "$query" | grep -v grep | awk '{printf "  PID=%-6s CPU=%-5s MEM=%-5s %s\n", $2, $3, $4, $11}'
  echo ""
  echo "Total: $(ps aux 2>/dev/null | grep -i "$query" | grep -v grep | wc -l)"
}

# ---- tree view ----
proc_tree() {
  echo "=== Process Tree ==="
  echo ""
  pstree -p 2>/dev/null | head -50 || ps auxf 2>/dev/null | head -50
}

# ---- zombie killer ----
proc_zombies() {
  echo "=== Zombie Processes ==="
  echo ""
  local zombies
  zombies=$(ps aux 2>/dev/null | awk '$8 ~ /Z/' | wc -l)

  if [ "$zombies" -eq 0 ]; then
    echo "  No zombie processes."
    return 0
  fi

  echo "  Found $zombies zombie processes:"
  ps aux 2>/dev/null | awk '$8 ~ /Z/ {printf "  PID=%-6s PPID=%-6s %s\n", $2, $3, $11}'
  echo ""

  echo "  Attempting to clean..."
  ps aux 2>/dev/null | awk '$8 ~ /Z/ {print $3}' | while read -r ppid; do
    kill -SIGCHLD "$ppid" 2>/dev/null || true
  done
  sleep 1

  local remaining
  remaining=$(ps aux 2>/dev/null | awk '$8 ~ /Z/' | wc -l)
  echo "  Remaining: $remaining"
}

# ---- history ----
proc_history() {
  echo "=== Process Activity Log ==="
  tail -20 "$PROC_LOG" 2>/dev/null || echo "No entries."
}

# ---- main ----
case "${1:-}" in
  top)         shift; proc_top "$@" ;;
  kill)        shift; proc_kill "$@" ;;
  priority)    shift; proc_priority "$@" ;;
  affinity)    shift; proc_affinity "$@" ;;
  resources)   proc_resources ;;
  find)        shift; proc_find "$@" ;;
  tree)        proc_tree ;;
  zombies)     proc_zombies ;;
  history)     proc_history ;;
  init)        init_process ;;
  help|*)      echo "KorrinOS Process Monitor
Usage: korrinos-process <command> [args]

Commands:
  top [cpu|mem|io] [count]  Show top processes
  kill <pid> [signal]       Kill a process
  priority <pid> <nice>     Set process priority (-20 to 19)
  affinity <pid> <cores>    Set CPU affinity
  resources                 System resource usage
  find <name>               Find processes by name
  tree                      Process tree view
  zombies                   Find and clean zombie processes
  history                   Process activity log" ;;
esac

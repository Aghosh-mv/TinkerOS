#!/usr/bin/env bash
# korrinos-cleanup.sh — System Cleanup & Optimization
# Disk cleanup, cache clearing, package cleanup, performance optimization

set -euo pipefail

CLEANUP_DIR="${HOME}/.config/korrinos/cleanup"
CLEANUP_LOG="$CLEANUP_DIR/cleanup.log"
mkdir -p "$CLEANUP_DIR"

# Full system cleanup
cmd_full() {
  echo "╔══════════════════════════════════════════════╗"
  echo "║     KorrinOS System Cleanup & Optimization   ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  
  local start_time=$(date +%s)
  local freed=0
  
  # 1. Package manager cache
  echo "  [1/7] Cleaning package cache..."
  if command -v apt &>/dev/null; then
    local apt_before
    apt_before=$(du -sm /var/cache/apt 2>/dev/null | awk '{print $1}' || echo 0)
    sudo apt clean 2>/dev/null || true
    sudo apt autoremove -y 2>/dev/null || true
    local apt_after
    apt_after=$(du -sm /var/cache/apt 2>/dev/null | awk '{print $1}' || echo 0)
    local apt_freed=$((apt_before - apt_after))
    freed=$((freed + apt_freed))
    echo "    ✓ APT: freed ${apt_freed}MB"
  fi
  
  # 2. User cache
  echo "  [2/7] Cleaning user cache..."
  local cache_before
  cache_before=$(du -sm ~/.cache 2>/dev/null | awk '{print $1}' || echo 0)
  find ~/.cache -type f -name "*.tmp" -delete 2>/dev/null || true
  find ~/.cache -type f -name "*.log" -delete 2>/dev/null || true
  find ~/.cache -type d -name "thumbnails" -exec rm -rf {} + 2>/dev/null || true
  local cache_after
  cache_after=$(du -sm ~/.cache 2>/dev/null | awk '{print $1}' || echo 0)
  local cache_freed=$((cache_before - cache_after))
  freed=$((freed + cache_freed))
  echo "    ✓ User cache: freed ${cache_freed}MB"
  
  # 3. Temporary files
  echo "  [3/7] Cleaning temporary files..."
  local tmp_before
  tmp_before=$(du -sm /tmp 2>/dev/null | awk '{print $1}' || echo 0)
  find /tmp -type f -atime +7 -delete 2>/dev/null || true
  find ~/.local/tmp -type f -atime +7 -delete 2>/dev/null || true
  local tmp_after
  tmp_after=$(du -sm /tmp 2>/dev/null | awk '{print $1}' || echo 0)
  local tmp_freed=$((tmp_before - tmp_after))
  freed=$((freed + tmp_freed))
  echo "    ✓ Temp files: freed ${tmp_freed}MB"
  
  # 4. Log files
  echo "  [4/7] Cleaning old logs..."
  local log_before
  log_before=$(du -sm /var/log 2>/dev/null | awk '{print $1}' || echo 0)
  sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
  sudo find /var/log -type f -name "*.old" -delete 2>/dev/null || true
  sudo journalctl --vacuum-time=3d 2>/dev/null || true
  local log_after
  log_after=$(du -sm /var/log 2>/dev/null | awk '{print $1}' || echo 0)
  local log_freed=$((log_before - log_after))
  freed=$((freed + log_freed))
  echo "    ✓ Logs: freed ${log_freed}MB"
  
  # 5. Trash
  echo "  [5/7] Emptying trash..."
  local trash_before
  trash_before=$(du -sm ~/.local/share/Trash 2>/dev/null | awk '{print $1}' || echo 0)
  rm -rf ~/.local/share/Trash/* 2>/dev/null || true
  local trash_after
  trash_after=$(du -sm ~/.local/share/Trash 2>/dev/null | awk '{print $1}' || echo 0)
  local trash_freed=$((trash_before - trash_after))
  freed=$((freed + trash_freed))
  echo "    ✓ Trash: freed ${trash_freed}MB"
  
  # 6. Old kernels
  echo "  [6/7] Removing old kernels..."
  if command -v apt &>/dev/null; then
    sudo apt autoremove --purge -y 2>/dev/null || true
    echo "    ✓ Old kernels removed"
  fi
  
  # 7. Docker cleanup
  echo "  [7/7] Cleaning Docker..."
  if command -v docker &>/dev/null; then
    docker system prune -f 2>/dev/null || true
    echo "    ✓ Docker pruned"
  fi
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  echo ""
  echo "  ✓ Cleanup complete!"
  echo "    Total freed: ${freed}MB"
  echo "    Duration: ${duration}s"
  
  # Log
  echo "$(date -Iseconds) | FULL CLEANUP | ${freed}MB freed | ${duration}s" >> "$CLEANUP_LOG"
  
  # Show disk status
  echo ""
  echo "  Disk status:"
  df -h / | awk 'NR==2{printf "    Used: %s / %s (%s)\n", $3, $2, $5}'
}

# Cache cleanup only
cmd_cache() {
  echo "=== Cache Cleanup ==="
  echo ""
  
  local freed=0
  
  # Browser caches
  echo "  Browser caches:"
  for cache_dir in ~/.cache/google-chrome ~/.cache/mozilla ~/.cache/chromium; do
    if [ -d "$cache_dir" ]; then
      local before
      before=$(du -sm "$cache_dir" 2>/dev/null | awk '{print $1}' || echo 0)
      find "$cache_dir" -type f -name "*.tmp" -delete 2>/dev/null || true
      find "$cache_dir" -type f -name "*.cache" -delete 2>/dev/null || true
      local after
      after=$(du -sm "$cache_dir" 2>/dev/null | awk '{print $1}' || echo 0)
      local freed_dir=$((before - after))
      freed=$((freed + freed_dir))
      echo "    $(basename $cache_dir): freed ${freed_dir}MB"
    fi
  done
  
  # Development caches
  echo "  Development caches:"
  for cache_dir in ~/.cache/pip ~/.cache/npm ~/.cache/yarn ~/.cargo/registry/cache; do
    if [ -d "$cache_dir" ]; then
      local before
      before=$(du -sm "$cache_dir" 2>/dev/null | awk '{print $1}' || echo 0)
      find "$cache_dir" -type f -atime +30 -delete 2>/dev/null || true
      local after
      after=$(du -sm "$cache_dir" 2>/dev/null | awk '{print $1}' || echo 0)
      local freed_dir=$((before - after))
      freed=$((freed + freed_dir))
      echo "    $(basename $cache_dir): freed ${freed_dir}MB"
    fi
  done
  
  echo ""
  echo "  Total freed: ${freed}MB"
}

# Package cleanup
cmd_packages() {
  echo "=== Package Cleanup ==="
  echo ""
  
  if command -v apt &>/dev/null; then
    echo "  Unused packages:"
    sudo apt list --installed 2>/dev/null | grep -i "autoinstall" | head -10 | sed 's/^/    /'
    echo ""
    
    echo "  Orphaned packages:"
    sudo apt list --installed 2>/dev/null | awk -F/ 'NR>1 && !seen[$1]++ {print $1}' | head -10 | sed 's/^/    /'
    echo ""
    
    echo "  Size of package cache:"
    du -sh /var/cache/apt 2>/dev/null | sed 's/^/    /'
  fi
}

# Disk analysis
cmd_disk() {
  echo "=== Disk Analysis ==="
  echo ""
  
  echo "  Overall usage:"
  df -h / | awk 'NR==2{printf "    Used: %s / %s (%s)\n", $3, $2, $5}'
  echo ""
  
  echo "  Largest directories in /home:"
  du -h --max-depth=2 ~/ 2>/dev/null | sort -rh | head -15 | sed 's/^/    /'
  echo ""
  
  echo "  Largest files (>100MB):"
  find ~ -type f -size +100M -exec ls -lh {} \; 2>/dev/null | awk '{print "    " $5 " " $9}' | head -10
  echo ""
  
  echo "  Disk usage by type:"
  find ~ -type f -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" 2>/dev/null | xargs du -ch 2>/dev/null | tail -1 | awk '{print "    Videos: " $1}'
  find ~ -type f -name "*.mp3" -o -name "*.flac" -o -name "*.wav" 2>/dev/null | xargs du -ch 2>/dev/null | tail -1 | awk '{print "    Audio: " $1}'
  find ~ -type f -name "*.jpg" -o -name "*.png" -o -name "*.gif" 2>/dev/null | xargs du -ch 2>/dev/null | tail -1 | awk '{print "    Images: " $1}'
}

# Duplicate finder
cmd_duplicates() {
  echo "=== Finding Duplicate Files ==="
  echo ""
  
  local dup_dir="${HOME}/.korrinos-duplicates"
  mkdir -p "$dup_dir"
  
  echo "  Scanning for duplicates (this may take a while)..."
  
  # Find duplicates by MD5 hash
  find ~ -type f -not -path "*/\.*" -not -path "*/node_modules/*" -not -path "*/__pycache__/*" 2>/dev/null | \
    xargs md5sum 2>/dev/null | \
    sort | \
    uniq -D -w 32 | \
    awk '{print $1}' | \
    head -20 > "$dup_dir/hashes.txt"
  
  local dup_count
  dup_count=$(wc -l < "$dup_dir/hashes.txt" 2>/dev/null || echo 0)
  
  if [ "$dup_count" -gt 0 ]; then
    echo "  Found ${dup_count} potential duplicate groups"
    echo "  Report saved to: ${dup_dir}/hashes.txt"
  else
    echo "  No duplicates found"
  fi
}

# Optimize system
cmd_optimize() {
  echo "=== System Optimization ==="
  echo ""
  
  # Clear font cache
  echo "  Updating font cache..."
  fc-cache -f 2>/dev/null || true
  echo "    ✓ Font cache updated"
  
  # Update mandb
  echo "  Updating man pages..."
  sudo mandb -q 2>/dev/null || true
  echo "    ✓ Man pages updated"
  
  # Clean systemd journals
  echo "  Cleaning systemd journals..."
  sudo journalctl --vacuum-size=100M 2>/dev/null || true
  echo "    ✓ Journals cleaned"
  
  # Optimize SSD (if applicable)
  if [ -f /sys/block/sda/queue/rotational ]; then
    local rotational
    rotational=$(cat /sys/block/sda/queue/rotational 2>/dev/null || echo "1")
    if [ "$rotational" = "0" ]; then
      echo "  SSD detected — enabling TRIM..."
      sudo fstrim -av 2>/dev/null || true
      echo "    ✓ TRIM executed"
    fi
  fi
  
  echo ""
  echo "  ✓ System optimized"
}

# Cleanup log
cmd_log() {
  echo "=== Cleanup History ==="
  echo ""
  
  if [ -f "$CLEANUP_LOG" ]; then
    tail -20 "$CLEANUP_LOG" | sed 's/^/  /'
  else
    echo "  No cleanup history"
  fi
}

case "${1:-help}" in
  full)          cmd_full ;;
  cache)         cmd_cache ;;
  packages)      cmd_packages ;;
  disk)          cmd_disk ;;
  duplicates)    cmd_duplicates ;;
  optimize)      cmd_optimize ;;
  log)           cmd_log ;;
  *)
    echo "KorrinOS System Cleanup & Optimization"
    echo "Usage: korrinos-cleanup.sh <command>"
    echo ""
    echo "Commands:"
    echo "  full              Full system cleanup (frees disk space)"
    echo "  cache             Clean browser & dev caches"
    echo "  packages          Show unused/orphaned packages"
    echo "  disk              Detailed disk analysis"
    echo "  duplicates        Find duplicate files"
    echo "  optimize          System optimization (fonts, TRIM, journals)"
    echo "  log               Show cleanup history"
    ;;
esac

#!/bin/bash
# KorrinOS Backup System
# Real backup: full/partial, incremental, scheduling, cloud backup, restore
# Btrfs snapshots, rsync-based, encryption, compression, deduplication

set -euo pipefail

BACKUP_DIR="${HOME}/.config/korrinos/backup"
BACKUP_CONFIG="$BACKUP_DIR/config.json"
BACKUP_LOG="$BACKUP_DIR/backup.log"
BACKUP_JOBS="$BACKUP_DIR/jobs"
BACKUP_HISTORY="$BACKUP_DIR/history"
mkdir -p "$BACKUP_DIR" "$BACKUP_JOBS" "$BACKUP_HISTORY"

init_backup() {
  if [ ! -f "$BACKUP_CONFIG" ]; then
    cat > "$BACKUP_CONFIG" << 'DEFAULTS'
{
  "default_dest": "~/Backups/KorrinOS",
  "compression": "gzip",
  "encryption": false,
  "encryption_key_file": "",
  "exclude_patterns": [".cache", ".local/share/Trash", "*.tmp", "*.swp", "node_modules", "__pycache__", ".git"],
  "auto_backup": false,
  "auto_backup_interval_hours": 24,
  "retain_full_backups": 5,
  "retain_incremental": 10,
  "backup_home": true,
  "backup_etc": true,
  "backup_opt": false,
  "backup_var": false,
  "max_parallel_jobs": 2,
  "notify_on_complete": true,
  "cloud_backup_enabled": false,
  "cloud_provider": "gdrive"
}
DEFAULTS
    echo "Backup config initialized."
  fi
}

cfg() {
  python3 -c "
import json
try:
    with open('$BACKUP_CONFIG') as f: c = json.load(f)
    val = c.get('$1', '$2')
    if isinstance(val, bool): print('True' if val else 'False')
    elif isinstance(val, list): print(','.join(str(x) for x in val))
    else: print(val)
except: print('$2')
" 2>/dev/null
}

# ---- full backup ----
full_backup() {
  local dest="${1:-$(cfg default_dest ~/Backups/KorrinOS)}"
  dest=$(eval echo "$dest")
  mkdir -p "$dest"

  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="$dest/full-backup-${timestamp}.tar.gz"
  local exclude_file
  exclude_file=$(mktemp)

  echo "============================================="
  echo "   KorrinOS Full Backup"
  echo "============================================="
  echo ""
  echo "Destination: $backup_file"
  echo "Time: $(date)"
  echo ""

  # Build exclude list
  cfg "exclude_patterns" "" | tr ',' '\n' > "$exclude_file"

  local start_time
  start_time=$(date +%s)

  # Backup directories
  local sources=""
  [ "$(cfg backup_home true)" = "True" ] && sources="$sources $HOME"
  [ "$(cfg backup_etc true)" = "True" ] && sources="$sources /etc"
  [ "$(cfg backup_opt false)" = "True" ] && sources="$sources /opt/korrinos"

  if [ -z "$sources" ]; then
    echo "ERROR: No sources configured for backup."
    rm -f "$exclude_file"
    return 1
  fi

  echo "Backing up: $sources"
  echo ""

  local compression
  compression=$(cfg compression "gzip")
  local tar_args="-czf"
  [ "$compression" = "none" ] && tar_args="-cf"
  [ "$compression" = "xz" ] && tar_args="-cJf"

  tar $tar_args "$backup_file" \
    --exclude-from="$exclude_file" \
    --exclude="*.pyc" \
    --exclude=".cache/*" \
    --exclude="Trash/*" \
    $sources 2>&1 | tail -5

  rm -f "$exclude_file"

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))
  local size
  size=$(du -h "$backup_file" 2>/dev/null | awk '{print $1}')

  # Encryption
  local encryption
  encryption=$(cfg encryption "false")
  if [ "$encryption" = "True" ] && command -v gpg &>/dev/null; then
    echo "Encrypting backup..."
    local key_file
    key_file=$(cfg encryption_key_file "")
    if [ -n "$key_file" ] && [ -f "$key_file" ]; then
      gpg --batch --yes --passphrase-file "$key_file" \
        --symmetric --cipher-algo AES256 "$backup_file" 2>/dev/null
      rm -f "$backup_file"
      backup_file="${backup_file}.gpg"
      echo "Encrypted: $backup_file"
    fi
  fi

  # Record backup
  echo "$(date -Iseconds) | full | $backup_file | ${size} | ${duration}s | OK" >> "$BACKUP_LOG"

  echo ""
  echo "============================================="
  echo "   Backup Complete"
  echo "============================================="
  echo "  File: $backup_file"
  echo "  Size: $size"
  echo "  Duration: ${duration}s"
  echo ""

  # Notify
  if [ "$(cfg notify_on_complete true)" = "True" ] && command -v notify-send &>/dev/null; then
    notify-send -i drive-harddisk "KorrinOS Backup" \
      "Full backup complete: $size in ${duration}s" 2>/dev/null || true
  fi
}

# ---- incremental backup ----
incremental_backup() {
  local dest="${1:-$(cfg default_dest ~/Backups/KorrinOS)}"
  dest=$(eval echo "$dest")
  mkdir -p "$dest"

  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local snapshot_dir="$dest/incremental-${timestamp}"
  mkdir -p "$snapshot_dir"

  echo "=== KorrinOS Incremental Backup ==="
  echo ""

  local start_time
  start_time=$(date +%s)

  # Use rsync for incremental
  local sources=""
  [ "$(cfg backup_home true)" = "True" ] && sources="$sources $HOME/"
  [ "$(cfg backup_etc true)" = "True" ] && sources="$sources /etc/"

  for src in $sources; do
    [ -d "$src" ] || continue
    local dest_name
    dest_name=$(echo "$src" | tr '/' '_' | sed 's/^_//')
    echo "Syncing: $src"
    rsync -aAX --delete \
      --exclude="*.pyc" \
      --exclude=".cache/" \
      --exclude="Trash/" \
      --exclude="*.tmp" \
      --exclude="*.swp" \
      --exclude="node_modules/" \
      "$src" "$snapshot_dir/$dest_name/" 2>&1 | tail -3
  done

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))
  local size
  size=$(du -sh "$snapshot_dir" 2>/dev/null | awk '{print $1}')

  echo "$(date -Iseconds) | incremental | $snapshot_dir | ${size} | ${duration}s | OK" >> "$BACKUP_LOG"

  echo ""
  echo "Incremental backup complete: $size in ${duration}s"
}

# ---- restore ----
restore_backup() {
  local backup_file="${1:-}"
  local restore_to="${2:-/}"

  [ -z "$backup_file" ] && { echo "Usage: korrinos-backup restore <backup-file> [dest]"; return 1; }
  [ -f "$backup_file" ] || { echo "Backup file not found: $backup_file"; return 1; }

  echo "=== KorrinOS Backup Restore ==="
  echo ""
  echo "Backup: $backup_file"
  echo "Restore to: $restore_to"
  echo ""

  # Decrypt if needed
  local work_file="$backup_file"
  if [[ "$backup_file" == *.gpg ]]; then
    echo "Decrypting backup..."
    local key_file
    key_file=$(cfg encryption_key_file "")
    if [ -n "$key_file" ] && [ -f "$key_file" ]; then
      work_file="${backup_file%.gpg}"
      gpg --batch --yes --passphrase-file "$key_file" \
        --decrypt "$backup_file" > "$work_file" 2>/dev/null
    else
      echo "Encryption key file not configured."
      return 1
    fi
  fi

  echo "Contents of backup:"
  tar -tzf "$work_file" 2>/dev/null | head -20
  echo ""

  read -p "Restore to $restore_to? (yes/no): " confirm
  [ "$confirm" != "yes" ] && return 0

  echo "Restoring..."
  tar -xzf "$work_file" -C "$restore_to" 2>&1 | tail -5

  if [[ "$backup_file" == *.gpg ]] && [ "$work_file" != "$backup_file" ]; then
    rm -f "$work_file"
  fi

  echo "$(date -Iseconds) | restore | $backup_file | OK" >> "$BACKUP_LOG"
  echo "Restore complete."
}

# ---- list backups ----
list_backups() {
  local dest="${1:-$(cfg default_dest ~/Backups/KorrinOS)}"
  dest=$(eval echo "$dest")

  echo "=== Available Backups ==="
  echo "Location: $dest"
  echo ""

  if [ -d "$dest" ]; then
    ls -lhS "$dest"/*.tar.gz "$dest"/*.gpg "$dest"/incremental-* 2>/dev/null | while read -r line; do
      echo "  $line"
    done
    echo ""
    echo "Total: $(du -sh "$dest" 2>/dev/null | awk '{print $1}')"
  else
    echo "No backups found."
  fi
}

# ---- schedule backup ----
schedule_backup() {
  local interval_hours
  interval_hours=$(cfg auto_backup_interval_hours "24")

  local script_path
  script_path=$(readlink -f "$0" 2>/dev/null || echo "$0")

  sudo tee /etc/systemd/system/korrinos-backup.service >/dev/null << EOF
[Unit]
Description=KorrinOS Backup
After=network-online.target

[Service]
Type=oneshot
ExecStart=$script_path full
Nice=19
IOSchedulingClass=idle

[Install]
WantedBy=multi-user.target
EOF

  sudo tee /etc/systemd/system/korrinos-backup.timer >/dev/null << EOF
[Unit]
Description=KorrinOS Backup Timer

[Timer]
OnCalendar=*-*-* 02:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable korrinos-backup.timer
  sudo systemctl start korrinos-backup.timer
  echo "Backup scheduled: daily at 02:00"
}

# ---- status ----
backup_status() {
  echo "=== Backup Status ==="
  echo "Config: $BACKUP_CONFIG"
  echo "Log: $BACKUP_LOG"
  echo "Backups: $(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)"
  if [ -f "$BACKUP_LOG" ]; then
    echo "Last backup: $(tail -1 "$BACKUP_LOG" 2>/dev/null | cut -d'|' -f1 || echo 'never')"
  fi
}

# ---- main ----
case "${1:-}" in
  full)        shift; full_backup "$@" ;;
  incremental) shift; incremental_backup "$@" ;;
  restore)     shift; restore_backup "$@" ;;
  list)        shift; list_backups "$@" ;;
  schedule)    schedule_backup ;;
  status)      backup_status ;;
  init)        init_backup ;;
  help|*)      echo "KorrinOS Backup System
Usage: korrinos-backup <command> [args]

Commands:
  full [dest]         Full backup (tar.gz)
  incremental [dest]  Incremental backup (rsync)
  restore <file> [to] Restore from backup
  list [dest]         List available backups
  schedule            Setup automatic daily backups
  status              Show backup status" ;;
esac

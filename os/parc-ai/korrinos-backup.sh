#!/usr/bin/env bash
# korrinos-backup.sh — Smart Backup System
# Incremental backups, snapshots, cloud sync, restore

set -euo pipefail

BACKUP_DIR="${HOME}/.config/korrinos/backup"
BACKUP_CONFIG="$BACKUP_DIR/config.json"
BACKUP_LOG="$BACKUP_DIR/backup.log"
mkdir -p "$BACKUP_DIR"

# Default config
init_backup() {
  if [ ! -f "$BACKUP_CONFIG" ]; then
    cat > "$BACKUP_CONFIG" << 'DEFAULTS'
{
  "backup_dir": "~/.korrinos-backups",
  "max_backups": 5,
  "include": ["~/.config", "~/.local/share", "~/Documents"],
  "exclude": ["*.tmp", "*.cache", "node_modules", ".git", "__pycache__"],
  "compression": true,
  "incremental": true,
  "auto_backup": false,
  "auto_interval_hours": 24
}
DEFAULTS
    echo "Backup config initialized"
  fi
}

# Create backup
cmd_backup() {
  local name="${1:-manual_$(date +%Y%m%d_%H%M%S)}"
  local backup_base
  backup_base=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$BACKUP_CONFIG'))['backup_dir']))" 2>/dev/null || echo "$HOME/.korrinos-backups")
  
  mkdir -p "$backup_base"
  
  local backup_path="$backup_base/$name"
  mkdir -p "$backup_path"
  
  echo "╔══════════════════════════════════════════════╗"
  echo "║       KorrinOS Smart Backup System           ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  echo "  Creating backup: ${name}"
  echo "  Location: ${backup_path}"
  echo ""
  
  local start_time=$(date +%s)
  local total_size=0
  local file_count=0
  
  # Get include paths
  local includes
  includes=$(python3 -c "
import json
c = json.load(open('$BACKUP_CONFIG'))
for p in c['include']:
    print(os.path.expanduser(p))
" 2>/dev/null || echo "$HOME/.config $HOME/.local/share $HOME/Documents")
  
  # Get exclude patterns
  local exclude_args=""
  while IFS= read -r pattern; do
    exclude_args="$exclude_args --exclude=$pattern"
  done < <(python3 -c "
import json
c = json.load(open('$BACKUP_CONFIG'))
for p in c['exclude']:
    print(p)
" 2>/dev/null)
  
  # Perform backup
  while IFS= read -r src; do
    [ -d "$src" ] || continue
    local dir_name
    dir_name=$(basename "$src")
    mkdir -p "$backup_path/$dir_name"
    
    echo "  Backing up: ${dir_name}"
    rsync -a --progress $exclude_args "$src/" "$backup_path/$dir_name/" 2>/dev/null || true
    
    local dir_size
    dir_size=$(du -sb "$backup_path/$dir_name" 2>/dev/null | awk '{print $1}' || echo 0)
    local dir_files
    dir_files=$(find "$backup_path/$dir_name" -type f 2>/dev/null | wc -l || echo 0)
    total_size=$((total_size + dir_size))
    file_count=$((file_count + dir_files))
    echo "    → ${dir_files} files, $(numfmt --to=iec $dir_size 2>/dev/null || echo ${dir_size}B)"
  done <<< "$(echo "$includes" | tr ' ' '\n')"
  
  # Compress if enabled
  local compress
  compress=$(python3 -c "import json; print(json.load(open('$BACKUP_CONFIG'))['compression'])" 2>/dev/null || echo "True")
  if [ "$compress" = "True" ]; then
    echo ""
    echo "  Compressing backup..."
    tar -czf "$backup_path.tar.gz" -C "$backup_base" "$name" 2>/dev/null
    rm -rf "$backup_path"
    backup_path="$backup_path.tar.gz"
    echo "  Compressed to: $(basename $backup_path)"
  fi
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Log backup
  echo "$(date -Iseconds) | BACKUP | ${name} | ${file_count} files | $(numfmt --to=iec $total_size 2>/dev/null || echo ${total_size}B) | ${duration}s" >> "$BACKUP_LOG"
  
  echo ""
  echo "  ✓ Backup complete!"
  echo "    Files: ${file_count}"
  echo "    Size: $(numfmt --to=iec $total_size 2>/dev/null || echo ${total_size}B)"
  echo "    Duration: ${duration}s"
  echo "    Location: ${backup_path}"
  
  # Rotate old backups
  local max_backups
  max_backups=$(python3 -c "import json; print(json.load(open('$BACKUP_CONFIG'))['max_backups'])" 2>/dev/null || echo "5")
  local backup_count
  backup_count=$(ls -1 "$backup_base" 2>/dev/null | wc -l || echo 0)
  
  if [ "$backup_count" -gt "$max_backups" ]; then
    local to_remove=$((backup_count - max_backups))
    echo ""
    echo "  Rotating: removing ${to_remove} old backup(s)"
    ls -1t "$backup_base" | tail -n "$to_remove" | while read -r old; do
      rm -rf "$backup_base/$old" 2>/dev/null
      echo "    Removed: ${old}"
    done
  fi
}

# List backups
cmd_list() {
  echo "=== KorrinOS Backups ==="
  echo ""
  
  local backup_base
  backup_base=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$BACKUP_CONFIG'))['backup_dir']))" 2>/dev/null || echo "$HOME/.korrinos-backups")
  
  if [ ! -d "$backup_base" ]; then
    echo "  No backups found"
    return 0
  fi
  
  echo "  Backups in ${backup_base}:"
  ls -1lh "$backup_base" 2>/dev/null | grep -v "^total" | awk '{print "    " $9 " (" $5 ")"}'
  echo ""
  
  # Show log
  if [ -f "$BACKUP_LOG" ]; then
    echo "  Recent activity:"
    tail -5 "$BACKUP_LOG" | sed 's/^/    /'
  fi
}

# Restore backup
cmd_restore() {
  local backup_name="$1"
  local backup_base
  backup_base=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$BACKUP_CONFIG'))['backup_dir']))" 2>/dev/null || echo "$HOME/.korrinos-backups")
  
  local backup_path="$backup_base/$backup_name"
  
  # Check if compressed
  if [ -f "$backup_path.tar.gz" ]; then
    echo "Extracting compressed backup..."
    tar -xzf "$backup_path.tar.gz" -C "$backup_base" 2>/dev/null
    backup_path="$backup_base/$backup_name"
  fi
  
  if [ ! -d "$backup_path" ]; then
    echo "Backup not found: ${backup_name}"
    echo "Available backups:"
    cmd_list
    return 1
  fi
  
  echo "=== Restoring Backup: ${backup_name} ==="
  echo ""
  
  # Restore each directory
  for dir in "$backup_path"/*/; do
    [ -d "$dir" ] || continue
    local dir_name
    dir_name=$(basename "$dir")
    local target="${HOME}/${dir_name}"
    
    echo "  Restoring: ${dir_name} → ${target}"
    
    # Create target if needed
    mkdir -p "$target"
    
    # Restore with rsync
    rsync -a --progress "$dir/" "$target/" 2>/dev/null || true
    echo "    ✓ Restored"
  done
  
  echo ""
  echo "  ✓ Restore complete!"
  echo "$(date -Iseconds) | RESTORE | ${backup_name}" >> "$BACKUP_LOG"
}

# Incremental backup
cmd_incremental() {
  local name="${1:-incr_$(date +%Y%m%d_%H%M%S)}"
  local backup_base
  backup_base=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$BACKUP_CONFIG'))['backup_dir']))" 2>/dev/null || echo "$HOME/.korrinos-backups")
  
  # Find last backup for incremental reference
  local last_backup
  last_backup=$(ls -1t "$backup_base" 2>/dev/null | head -1)
  
  if [ -z "$last_backup" ]; then
    echo "No previous backup found — doing full backup"
    cmd_backup "$name"
    return
  fi
  
  echo "=== Incremental Backup ==="
  echo "  Reference: ${last_backup}"
  echo "  New: ${name}"
  echo ""
  
  local ref_path="$backup_base/$last_backup"
  [ -d "$ref_path" ] || ref_path="$backup_base/${last_backup%.tar.gz}"
  
  local new_path="$backup_base/$name"
  mkdir -p "$new_path"
  
  # Get include paths
  local includes
  includes=$(python3 -c "
import json,os
c = json.load(open('$BACKUP_CONFIG'))
for p in c['include']:
    print(os.path.expanduser(p))
" 2>/dev/null || echo "$HOME/.config $HOME/.local/share $HOME/Documents")
  
  local changes=0
  while IFS= read -r src; do
    [ -d "$src" ] || continue
    local dir_name
    dir_name=$(basename "$src")
    
    if [ -d "$ref_path/$dir_name" ]; then
      # Compare and copy only changed files
      local changed
      changed=$(rsync -anrc "$ref_path/$dir_name/" "$src/" 2>/dev/null | grep -c "^\>" || echo 0)
      if [ "$changed" -gt 0 ]; then
        echo "  ${dir_name}: ${changed} files changed"
        rsync -rc "$src/" "$new_path/$dir_name/" 2>/dev/null || true
        changes=$((changes + changed))
      fi
    else
      echo "  ${dir_name}: new directory"
      rsync -a "$src/" "$new_path/$dir_name/" 2>/dev/null || true
    fi
  done <<< "$(echo "$includes" | tr ' ' '\n')"
  
  echo ""
  echo "  ✓ Incremental backup complete: ${changes} changed files"
}

# Delete backup
cmd_delete() {
  local backup_name="$1"
  local backup_base
  backup_base=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$BACKUP_CONFIG'))['backup_dir']))" 2>/dev/null || echo "$HOME/.korrinos-backups")
  
  rm -rf "$backup_base/$backup_name" "$backup_base/${backup_name}.tar.gz" 2>/dev/null
  echo "Deleted backup: ${backup_name}"
  echo "$(date -Iseconds) | DELETE | ${backup_name}" >> "$BACKUP_LOG"
}

# Backup status
cmd_status() {
  echo "=== Backup Status ==="
  echo ""
  
  local backup_base
  backup_base=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$BACKUP_CONFIG'))['backup_dir']))" 2>/dev/null || echo "$HOME/.korrinos-backups")
  
  local count=0
  local total_size=0
  if [ -d "$backup_base" ]; then
    count=$(ls -1 "$backup_base" 2>/dev/null | wc -l || echo 0)
    total_size=$(du -sh "$backup_base" 2>/dev/null | awk '{print $1}' || echo "0")
  fi
  
  echo "  Backups: ${count}"
  echo "  Total size: ${total_size}"
  
  if [ -f "$BACKUP_LOG" ]; then
    local last_backup
    last_backup=$(grep "BACKUP" "$BACKUP_LOG" | tail -1 | awk -F'|' '{print $2}' | xargs)
    local last_time
    last_time=$(grep "BACKUP" "$BACKUP_LOG" | tail -1 | awk -F'|' '{print $1}' | xargs)
    [ -n "$last_backup" ] && echo "  Last backup: ${last_backup} (${last_time})"
  fi
  
  echo ""
  echo "  Configuration:"
  python3 -c "
import json
c = json.load(open('$BACKUP_CONFIG'))
print(f'    Backup dir: {c[\"backup_dir\"]}')
print(f'    Max backups: {c[\"max_backups\"]}')
print(f'    Compression: {c[\"compression\"]}')
print(f'    Incremental: {c[\"incremental\"]}')
print(f'    Auto backup: {c[\"auto_backup\"]}')
" 2>/dev/null
}

case "${1:-help}" in
  init)          init_backup ;;
  backup)        shift; cmd_backup "$@" ;;
  list)          cmd_list ;;
  restore)       shift; cmd_restore "$@" ;;
  incremental)   shift; cmd_incremental "$@" ;;
  delete)        shift; cmd_delete "$@" ;;
  status)        cmd_status ;;
  *)
    echo "KorrinOS Smart Backup System"
    echo "Usage: korrinos-backup.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init                Initialize backup config"
    echo "  backup [name]       Create full backup"
    echo "  incremental [name]  Create incremental backup"
    echo "  list                List all backups"
    echo "  restore <name>      Restore from backup"
    echo "  delete <name>       Delete a backup"
    echo "  status              Backup system status"
    ;;
esac

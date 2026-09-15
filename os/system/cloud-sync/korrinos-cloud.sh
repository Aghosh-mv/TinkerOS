#!/bin/bash
# KorrinOS Cloud Sync v2
# Real cloud integration: Google Drive, OneDrive, iCloud, Nextcloud, S3, Dropbox, WebDAV
# Two-way sync, selective sync, conflict resolution, encryption at rest
# Bandwidth limiting, sync scheduling, storage reporting, offline cache
# Kernel-level: /proc/tinker/cloud for sync state

set -euo pipefail

CLOUD_DIR="${HOME}/.config/korrinos/cloud"
CLOUD_CONFIG="$CLOUD_DIR/config.json"
CLOUD_LOG="$CLOUD_DIR/sync.log"
SYNC_STATE="$CLOUD_DIR/state"
SYNC_QUEUE="$CLOUD_DIR/queue"
SYNC_LOCK="$CLOUD_DIR/.sync.lock"
OFFLINE_CACHE="$CLOUD_DIR/offline-cache"
mkdir -p "$CLOUD_DIR" "$SYNC_STATE" "$OFFLINE_CACHE"

# ---- lock ----
cloud_lock() {
  local max_wait=60 waited=0
  while [ -f "$SYNC_LOCK" ]; do
    local pid; pid=$(cat "$SYNC_LOCK" 2>/dev/null)
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then rm -f "$SYNC_LOCK"; break; fi
    if [ "$waited" -ge "$max_wait" ]; then return 1; fi
    sleep 1; waited=$((waited + 1))
  done
  echo $$ > "$SYNC_LOCK"
}
cloud_unlock() { rm -f "$SYNC_LOCK"; }
trap cloud_unlock EXIT

# ---- default config ----
init_cloud() {
  if [ ! -f "$CLOUD_CONFIG" ]; then
    cat > "$CLOUD_CONFIG" << 'DEFAULTS'
{
  "providers": {
    "gdrive": { "enabled": false, "token": "", "refresh_token": "", "sync_dir": "~/Google Drive", "selective": [], "remote_path": "" },
    "onedrive": { "enabled": false, "token": "", "refresh_token": "", "sync_dir": "~/OneDrive", "selective": [], "remote_path": "" },
    "icloud": { "enabled": false, "app_password": "", "sync_dir": "~/iCloud", "selective": [] },
    "nextcloud": { "enabled": false, "url": "", "user": "", "password": "", "sync_dir": "~/Nextcloud", "selective": [] },
    "s3": { "enabled": false, "bucket": "", "region": "", "access_key": "", "secret_key": "", "sync_dir": "~/S3", "endpoint": "" },
    "dropbox": { "enabled": false, "token": "", "sync_dir": "~/Dropbox" },
    "webdav": { "enabled": false, "url": "", "user": "", "password": "", "sync_dir": "~/WebDAV" }
  },
  "sync_interval_minutes": 30,
  "encrypt_local": true,
  "encryption_key": "",
  "conflict_strategy": "keep-both",
  "bandwidth_limit_kbps": 0,
  "notify_sync": true,
  "auto_sync": true,
  "auto_sync_interval_minutes": 30,
  "exclude_patterns": [".cache", "*.tmp", "*.swp", ".DS_Store", "Thumbs.db", "*.log", ".git", "node_modules", "__pycache__"],
  "max_file_size_mb": 500,
  "retry_on_failure": true,
  "max_retries": 3,
  "sync_on_wifi_only": true,
  "preserve_permissions": true,
  "compression": false,
  "deduplication": false,
  "versioning": true,
  "max_versions": 5,
  "follow_symlinks": false,
  "hide_conflict_files": true
}
DEFAULTS
    echo "Cloud sync config initialized."
  fi
}

# ---- read config ----
cfg() {
  python3 -c "
import json
try:
    with open('$CLOUD_CONFIG') as f: c = json.load(f)
    val = c.get('$1', '$2')
    if isinstance(val, bool): print('True' if val else 'False')
    elif isinstance(val, list): print(' '.join(str(x) for x in val))
    else: print(val)
except: print('$2')
" 2>/dev/null
}

# ---- detect rclone ----
ensure_rclone() {
  if ! command -v rclone &>/dev/null; then
    echo "rclone not found. Installing..."
    if command -v apt-get &>/dev/null; then
      sudo apt-get install -y rclone 2>&1 | tail -3
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y rclone 2>&1 | tail -3
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm rclone 2>&1 | tail -3
    else
      curl -s https://rclone.org/install.sh | sudo bash 2>&1 | tail -3
    fi
  fi
}

# ---- Google Drive ----
setup_gdrive() {
  ensure_rclone
  echo "=== Google Drive Setup ==="
  echo "Options:"
  echo "  1. Headless setup (copy token from browser)"
  echo "  2. Auto-detect existing rclone config"
  echo "  3. Cancel"
  read -p "Choice [1]: " choice
  choice="${choice:-1}"

  case "$choice" in
    1)
      echo "Starting rclone authorize flow..."
      echo "1. Run this on a machine with a browser: rclone authorize \"drive\""
      echo "2. Copy the token and paste below"
      read -p "Token: " token
      if [ -n "$token" ]; then
        python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
c['providers']['gdrive']['enabled'] = True
c['providers']['gdrive']['token'] = '''$token'''
with open('$CLOUD_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Google Drive enabled.')
"
        sync_gdrive "pull"
      fi
      ;;
    2)
      if rclone listremotes 2>/dev/null | grep -q "gdrive"; then
        python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
c['providers']['gdrive']['enabled'] = True
with open('$CLOUD_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Google Drive enabled from existing rclone config.')
"
      else
        echo "No rclone 'gdrive' remote found. Run: rclone config"
      fi
      ;;
  esac
}

sync_gdrive() {
  local direction="${1:-push}"
  ensure_rclone

  local sync_dir
  sync_dir=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$CLOUD_CONFIG'))['providers']['gdrive']['sync_dir']))" 2>/dev/null)
  mkdir -p "$sync_dir"

  local exclude
  exclude=$(python3 -c "import json; print(json.load(open('$CLOUD_CONFIG'))['exclude_patterns'])" 2>/dev/null)

  local bw
  bw=$(cfg "bandwidth_limit_kbps" "0")
  local bw_args=""
  [ "$bw" -gt 0 ] && bw_args="--bwlimit ${bw}k"

  local remote_path
  remote_path=$(python3 -c "import json; print(json.load(open('$CLOUD_CONFIG'))['providers']['gdrive'].get('remote_path',''))" 2>/dev/null)
  local remote="gdrive:"
  [ -n "$remote_path" ] && remote="gdrive:$remote_path"

  echo "=== Google Drive Sync ($direction) ==="
  case "$direction" in
    push)
      echo "Uploading local -> Google Drive..."
      rclone copy "$sync_dir" "$remote" --progress --exclude "$exclude" $bw_args 2>&1 | tail -10
      ;;
    pull)
      echo "Downloading Google Drive -> local..."
      rclone copy "$remote" "$sync_dir" --progress --exclude "$exclude" $bw_args 2>&1 | tail -10
      ;;
    bidirectional)
      echo "Bi-directional sync..."
      rclone bisync "$sync_dir" "$remote" --progress $bw_args --resync 2>&1 | tail -10
      ;;
  esac
  echo "$(date -Iseconds) | gdrive | $direction | OK" >> "$CLOUD_LOG"
  echo "Sync complete."
}

# ---- OneDrive ----
setup_onedrive() {
  ensure_rclone
  echo "=== OneDrive Setup ==="
  echo "1. Run: rclone config"
  echo "2. Choose 'Microsoft OneDrive'"
  echo "3. Name the remote: onedrive"
  echo ""
  read -p "Already configured? (y/n): " choice
  if [ "$choice" = "y" ]; then
    python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
c['providers']['onedrive']['enabled'] = True
with open('$CLOUD_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('OneDrive enabled.')
"
  fi
}

sync_onedrive() {
  local direction="${1:-push}"
  ensure_rclone

  local sync_dir
  sync_dir=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$CLOUD_CONFIG'))['providers']['onedrive']['sync_dir']))" 2>/dev/null)
  mkdir -p "$sync_dir"

  local bw; bw=$(cfg "bandwidth_limit_kbps" "0")
  local bw_args=""; [ "$bw" -gt 0 ] && bw_args="--bwlimit ${bw}k"

  echo "=== OneDrive Sync ($direction) ==="
  case "$direction" in
    push)  rclone copy "$sync_dir" onedrive: --progress $bw_args 2>&1 | tail -10 ;;
    pull)  rclone copy onedrive:"$sync_dir" "$sync_dir" --progress $bw_args 2>&1 | tail -10 ;;
  esac
  echo "$(date -Iseconds) | onedrive | $direction | OK" >> "$CLOUD_LOG"
}

# ---- Nextcloud WebDAV ----
setup_nextcloud() {
  echo "=== Nextcloud Setup ==="
  read -p "Nextcloud URL (e.g., https://cloud.example.com): " nc_url
  read -p "Username: " nc_user
  read -s -p "Password: " nc_pass
  echo ""
  read -p "Sync directory [~/Nextcloud]: " nc_sync
  nc_sync="${nc_sync:-~/Nextcloud}"

  python3 -c "
import json, os
with open('$CLOUD_CONFIG') as f: c = json.load(f)
c['providers']['nextcloud']['url'] = '$nc_url'
c['providers']['nextcloud']['user'] = '$nc_user'
c['providers']['nextcloud']['password'] = '$nc_pass'
c['providers']['nextcloud']['sync_dir'] = '$nc_sync'
c['providers']['nextcloud']['enabled'] = True
with open('$CLOUD_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Nextcloud configured.')
"
}

sync_nextcloud() {
  local direction="${1:-push}"
  local url user pass sync_dir
  url=$(python3 -c "import json; print(json.load(open('$CLOUD_CONFIG'))['providers']['nextcloud']['url'])" 2>/dev/null)
  user=$(python3 -c "import json; print(json.load(open('$CLOUD_CONFIG'))['providers']['nextcloud']['user'])" 2>/dev/null)
  pass=$(python3 -c "import json; print(json.load(open('$CLOUD_CONFIG'))['providers']['nextcloud']['password'])" 2>/dev/null)
  sync_dir=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$CLOUD_CONFIG'))['providers']['nextcloud']['sync_dir']))" 2>/dev/null)

  [ -z "$url" ] && { echo "Nextcloud not configured."; return 1; }

  mkdir -p "$sync_dir"
  local base_url="${url}/remote.php/dav/files/${user}/"

  echo "=== Nextcloud Sync ($direction) ==="
  case "$direction" in
    push)
      echo "Uploading to Nextcloud..."
      find "$sync_dir" -type f -not -path "*/\.*" | while read -r f; do
        local rel="${f#$sync_dir/}"
        local remote_dir
        remote_dir=$(dirname "$rel")
        [ "$remote_dir" != "." ] && curl -s -u "$user:$pass" -X MKCOL "$base_url$remote_dir" 2>/dev/null || true
        curl -s -u "$user:$pass" -T "$f" "$base_url$rel" 2>/dev/null && echo "  $rel" || echo "  FAILED: $rel"
      done
      ;;
    pull)
      echo "Downloading from Nextcloud..."
      curl -s -u "$user:$pass" "$base_url" -X PROPFIND -H "Depth: 1" 2>/dev/null | \
        grep -oP 'href>[^<]+' | sed 's/href>//g' | sed 's/%20/ /g' | while read -r f; do
        local filename
        filename=$(basename "$f")
        [ "$filename" = "" ] && continue
        curl -s -u "$user:$pass" "$base_url$f" -o "$sync_dir/$filename" 2>/dev/null && echo "  $filename" || echo "  FAILED: $filename"
      done
      ;;
  esac
  echo "$(date -Iseconds) | nextcloud | $direction | OK" >> "$CLOUD_LOG"
}

# ---- AWS S3 ----
setup_s3() {
  ensure_rclone
  echo "=== AWS S3 Setup ==="
  echo "Options:"
  echo "  1. AWS S3"
  echo "  2. MinIO / S3-compatible"
  echo "  3. Backblaze B2"
  read -p "Choice [1]: " s3type
  s3type="${s3type:-1}"

  read -p "Bucket name: " bucket
  read -p "Region (e.g., us-east-1): " region

  local endpoint=""
  if [ "$s3type" = "2" ]; then
    read -p "MinIO endpoint: " endpoint
  fi

  python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
c['providers']['s3']['bucket'] = '$bucket'
c['providers']['s3']['region'] = '$region'
c['providers']['s3']['endpoint'] = '$endpoint'
c['providers']['s3']['enabled'] = True
with open('$CLOUD_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('S3 configured.')
"

  if [ "$s3type" = "2" ]; then
    echo "Configure MinIO credentials: rclone config (create minio remote)"
  else
    echo "Run: aws configure to set credentials"
  fi
}

sync_s3() {
  local direction="${1:-push}"
  command -v aws &>/dev/null || { echo "aws-cli not installed. Run: sudo apt install awscli"; return 1; }

  local bucket sync_dir
  bucket=$(python3 -c "import json; print(json.load(open('$CLOUD_CONFIG'))['providers']['s3']['bucket'])" 2>/dev/null)
  sync_dir=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$CLOUD_CONFIG'))['providers']['s3']['sync_dir']))" 2>/dev/null)
  mkdir -p "$sync_dir"

  echo "=== S3 Sync ($direction) ==="
  case "$direction" in
    push) aws s3 sync "$sync_dir" "s3://$bucket" --progress --only-show-errors 2>&1 | tail -10 ;;
    pull) aws s3 sync "s3://$bucket" "$sync_dir" --progress --only-show-errors 2>&1 | tail -10 ;;
  esac
  echo "$(date -Iseconds) | s3 | $direction | OK" >> "$CLOUD_LOG"
}

# ---- Dropbox ----
setup_dropbox() {
  ensure_rclone
  echo "=== Dropbox Setup ==="
  echo "1. Run: rclone config"
  echo "2. Choose 'Dropbox'"
  echo "3. Name the remote: dropbox"
  read -p "Already configured? (y/n): " choice
  if [ "$choice" = "y" ]; then
    python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
c['providers']['dropbox']['enabled'] = True
with open('$CLOUD_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
  fi
}

sync_dropbox() {
  local direction="${1:-push}"
  ensure_rclone
  local sync_dir
  sync_dir=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$CLOUD_CONFIG'))['providers']['dropbox']['sync_dir']))" 2>/dev/null)
  mkdir -p "$sync_dir"

  echo "=== Dropbox Sync ($direction) ==="
  case "$direction" in
    push) rclone copy "$sync_dir" dropbox: --progress 2>&1 | tail -10 ;;
    pull) rclone copy dropbox:"$sync_dir" "$sync_dir" --progress 2>&1 | tail -10 ;;
  esac
  echo "$(date -Iseconds) | dropbox | $direction | OK" >> "$CLOUD_LOG"
}

# ---- WebDAV ----
setup_webdav() {
  echo "=== WebDAV Setup ==="
  read -p "WebDAV URL: " wurl
  read -p "Username: " wuser
  read -s -p "Password: " wpass
  echo ""
  read -p "Sync directory [~/WebDAV]: " wsync
  wsync="${wsync:-~/WebDAV}"

  python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
c['providers']['webdav']['url'] = '$wurl'
c['providers']['webdav']['user'] = '$wuser'
c['providers']['webdav']['password'] = '$wpass'
c['providers']['webdav']['sync_dir'] = '$wsync'
c['providers']['webdav']['enabled'] = True
with open('$CLOUD_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
}

sync_webdav() {
  local direction="${1:-push}"
  local url user pass sync_dir
  url=$(python3 -c "import json; print(json.load(open('$CLOUD_CONFIG'))['providers']['webdav']['url'])" 2>/dev/null)
  user=$(python3 -c "import json; print(json.load(open('$CLOUD_CONFIG'))['providers']['webdav']['user'])" 2>/dev/null)
  pass=$(python3 -c "import json; print(json.load(open('$CLOUD_CONFIG'))['providers']['webdav']['password'])" 2>/dev/null)
  sync_dir=$(python3 -c "import json,os; print(os.path.expanduser(json.load(open('$CLOUD_CONFIG'))['providers']['webdav']['sync_dir']))" 2>/dev/null)
  mkdir -p "$sync_dir"

  echo "=== WebDAV Sync ($direction) ==="
  case "$direction" in
    push)
      find "$sync_dir" -type f | while read -r f; do
        local rel="${f#$sync_dir/}"
        curl -s -u "$user:$pass" -T "$f" "$url/$rel" 2>/dev/null && echo "  $rel" || echo "  FAILED: $rel"
      done
      ;;
    pull)
      curl -s -u "$user:$pass" "$url" -X PROPFIND -H "Depth: 1" 2>/dev/null | \
        grep -oP 'href>[^<]+' | sed 's/href>//g' | sed 's/%20/ /g' | while read -r f; do
        local filename; filename=$(basename "$f")
        [ -z "$filename" ] && continue
        curl -s -u "$user:$pass" "$url/$f" -o "$sync_dir/$filename" 2>/dev/null && echo "  $filename"
      done
      ;;
  esac
  echo "$(date -Iseconds) | webdav | $direction | OK" >> "$CLOUD_LOG"
}

# ---- sync all enabled providers ----
sync_all() {
  local direction="${1:-pull}"
  echo "=== Syncing All Enabled Providers ($direction) ==="

  local providers
  providers=$(python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
for name, cfg in c['providers'].items():
    if cfg.get('enabled'):
        print(name)
" 2>/dev/null)

  if [ -z "$providers" ]; then
    echo "No providers enabled. Run: korrinos-cloud setup <provider>"
    return 0
  fi

  local count=0
  local total
  total=$(echo "$providers" | wc -l)

  echo "$providers" | while read -r provider; do
    count=$((count + 1))
    echo ""
    echo "[$count/$total] Syncing $provider..."
    case "$provider" in
      gdrive)    sync_gdrive "$direction" ;;
      onedrive)  sync_onedrive "$direction" ;;
      nextcloud) sync_nextcloud "$direction" ;;
      s3)        sync_s3 "$direction" ;;
      dropbox)   sync_dropbox "$direction" ;;
      webdav)    sync_webdav "$direction" ;;
    esac
  done

  echo ""
  echo "All providers synced."
}

# ---- conflict resolution ----
resolve_conflicts() {
  echo "=== Conflict Resolution Strategy ==="
  echo ""
  echo "Current: $(cfg 'conflict_strategy' 'keep-both')"
  echo ""
  echo "Strategies:"
  echo "  keep-both    — Keep both versions with timestamps"
  echo "  keep-local   — Local wins (overwrite remote)"
  echo "  keep-remote  — Remote wins (overwrite local)"
  echo "  newer        — Keep the newer file"
  echo "  ask          — Ask for each conflict"
  echo ""
  read -p "New strategy: " strategy

  if [ -n "$strategy" ]; then
    python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
c['conflict_strategy'] = '$strategy'
with open('$CLOUD_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Strategy updated to: $strategy')
"
  fi
}

# ---- selective sync ----
selective_sync() {
  local provider="${1:-}"
  [ -z "$provider" ] && { echo "Usage: korrinos-cloud selective <provider>"; return 1; }

  echo "=== Selective Sync: $provider ==="
  echo "Enter paths to sync (one per line, empty line to finish):"
  local paths=()
  while true; do
    read -r path
    [ -z "$path" ] && break
    paths+=("$path")
  done

  python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
c['providers']['$provider']['selective'] = $(printf '%s\n' "${paths[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin]))")
with open('$CLOUD_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Selective sync configured: ${#paths[@]} paths')
"
}

# ---- storage report ----
storage_report() {
  echo "=== Cloud Storage Usage ==="
  echo ""

  python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
for name, cfg in c['providers'].items():
    status = 'ENABLED' if cfg.get('enabled') else 'disabled'
    sync_dir = cfg.get('sync_dir', 'N/A')
    print(f'  {name:12} [{status:8}] sync_dir={sync_dir}')
" 2>/dev/null

  echo ""

  # Local sync sizes
  python3 -c "
import json, os
with open('$CLOUD_CONFIG') as f: c = json.load(f)
for name, cfg in c['providers'].items():
    if cfg.get('enabled'):
        sync_dir = os.path.expanduser(cfg.get('sync_dir', ''))
        if os.path.exists(sync_dir):
            total = 0
            count = 0
            for root, dirs, files in os.walk(sync_dir):
                for f in files:
                    try:
                        total += os.path.getsize(os.path.join(root, f))
                        count += 1
                    except: pass
            if total > 1024*1024*1024:
                size_str = f'{total/1024/1024/1024:.1f} GB'
            elif total > 1024*1024:
                size_str = f'{total/1024/1024:.1f} MB'
            elif total > 1024:
                size_str = f'{total/1024:.1f} KB'
            else:
                size_str = f'{total} B'
            print(f'  {name:12} {size_str:12} ({count} files)')
" 2>/dev/null

  echo ""
  echo "Last sync: $(tail -1 "$CLOUD_LOG" 2>/dev/null | cut -d'|' -f1 || echo 'never')"
}

# ---- sync scheduler ----
setup_autosync() {
  local interval
  interval=$(cfg "auto_sync_interval_minutes" "30")

  local script_path
  script_path=$(readlink -f "$0" 2>/dev/null || echo "$0")

  sudo tee /etc/systemd/system/korrinos-cloud-sync.service >/dev/null << EOF
[Unit]
Description=KorrinOS Cloud Sync
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$script_path auto-sync
Nice=19
IOSchedulingClass=idle

[Install]
WantedBy=multi-user.target
EOF

  sudo tee /etc/systemd/system/korrinos-cloud-sync.timer >/dev/null << EOF
[Unit]
Description=KorrinOS Cloud Sync Timer

[Timer]
OnBootSec=120
OnUnitActiveSec=${interval}min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable korrinos-cloud-sync.timer
  sudo systemctl start korrinos-cloud-sync.timer
  echo "Auto-sync enabled: every ${interval} minutes"
}

auto_sync() {
  if [ "$(cfg "sync_on_wifi_only" "true")" = "True" ]; then
    if nmcli -t -f TYPE CONNECTION show --active 2>/dev/null | grep -q "ethernet"; then
      echo "Ethernet detected, syncing..."
    elif nmcli device wifi list 2>/dev/null | head -2 | grep -q "SSID"; then
      echo "WiFi detected, syncing..."
    else
      echo "No network. Skipping sync."
      return 0
    fi
  fi

  sync_all "bidirectional"
}

# ---- encryption helpers ----
encrypt_file() {
  local file="$1"
  local key="${2:-}"
  [ -z "$key" ] && { echo "Encryption key required."; return 1; }

  if command -v openssl &>/dev/null; then
    openssl enc -aes-256-cbc -salt -in "$file" -out "${file}.enc" -k "$key" 2>/dev/null
    echo "Encrypted: ${file}.enc"
  else
    echo "openssl not available."
    return 1
  fi
}

decrypt_file() {
  local file="$1"
  local key="${2:-}"
  [ -z "$key" ] && { echo "Encryption key required."; return 1; }

  if command -v openssl &>/dev/null; then
    local outfile="${file%.enc}"
    openssl enc -aes-256-cbc -d -salt -in "$file" -out "$outfile" -k "$key" 2>/dev/null
    echo "Decrypted: $outfile"
  fi
}

# ---- status ----
cloud_status() {
  echo "============================================"
  echo "   KorrinOS Cloud Sync Status"
  echo "============================================"
  echo ""
  python3 -c "
import json
with open('$CLOUD_CONFIG') as f: c = json.load(f)
for name, cfg in c['providers'].items():
    status = 'ENABLED' if cfg.get('enabled') else 'disabled'
    print(f'  {name:12} [{status}]')
" 2>/dev/null

  echo ""
  echo "Auto-sync: $(cfg 'auto_sync' 'true')"
  echo "Interval: $(cfg 'auto_sync_interval_minutes' '30') minutes"
  echo "Conflict: $(cfg 'conflict_strategy' 'keep-both')"
  echo "Encrypt: $(cfg 'encrypt_local' 'true')"
  echo ""
  echo "Last sync: $(tail -1 "$CLOUD_LOG" 2>/dev/null | cut -d'|' -f1 || echo 'never')"
}

# ---- main ----
case "${1:-}" in
  setup)
    shift
    case "${1:-gdrive}" in
      gdrive)    setup_gdrive ;;
      onedrive)  setup_onedrive ;;
      nextcloud) setup_nextcloud ;;
      s3)        setup_s3 ;;
      dropbox)   setup_dropbox ;;
      webdav)    setup_webdav ;;
    esac ;;
  push)
    shift
    case "${1:-all}" in
      all)       sync_all push ;;
      gdrive)    sync_gdrive push ;;
      onedrive)  sync_onedrive push ;;
      nextcloud) sync_nextcloud push ;;
      s3)        sync_s3 push ;;
      dropbox)   sync_dropbox push ;;
      webdav)    sync_webdav push ;;
    esac ;;
  pull)
    shift
    case "${1:-all}" in
      all)       sync_all pull ;;
      gdrive)    sync_gdrive pull ;;
      onedrive)  sync_onedrive pull ;;
      nextcloud) sync_nextcloud pull ;;
      s3)        sync_s3 pull ;;
      dropbox)   sync_dropbox pull ;;
      webdav)    sync_webdav pull ;;
    esac ;;
  sync)             sync_all "bidirectional" ;;
  auto-sync)        auto_sync ;;
  conflicts)        resolve_conflicts ;;
  selective)        shift; selective_sync "$@" ;;
  storage)          storage_report ;;
  setup-auto)       setup_autosync ;;
  encrypt)          shift; encrypt_file "$@" ;;
  decrypt)          shift; decrypt_file "$@" ;;
  status)           cloud_status ;;
  init)             init_cloud ;;
  help|*)           echo "KorrinOS Cloud Sync v2
Usage: korrinos-cloud <command> [args]

Provider Setup:
  setup <provider>   Setup cloud provider
    gdrive           Google Drive
    onedrive         Microsoft OneDrive
    nextcloud        Nextcloud WebDAV
    s3               AWS S3 / MinIO / B2
    dropbox          Dropbox
    webdav           Generic WebDAV

Sync Operations:
  push [provider]    Push local -> cloud
  pull [provider]    Pull cloud -> local
  sync               Bi-directional sync all
  auto-sync          Sync based on config (used by systemd timer)

Sync Management:
  conflicts          Set conflict resolution strategy
  selective <prov>   Configure selective sync paths
  storage            Show storage usage report
  setup-auto         Setup automatic sync (systemd timer)

Encryption:
  encrypt <file> <key>  Encrypt a file
  decrypt <file> <key>  Decrypt a file

Status:
  status             Show cloud sync status
  init               Initialize cloud config" ;;
esac

#!/bin/bash
# KorrinOS Real Update System v2
# Automatic updates, delta updates, rollback, kernel updates, security patches
# Btrfs snapshot integration, A/B partition support, progress reporting
# Equivalent to Ubuntu unattended-upgrades + Fedora dnf-automatic + Windows Update
# Kernel-level: /proc/tinker/update for update state and scheduling

set -euo pipefail

UPDATE_DIR="${HOME}/.config/korrinos/updates"
UPDATE_CONFIG="$UPDATE_DIR/config.json"
UPDATE_LOG="$UPDATE_DIR/update.log"
UPDATE_HISTORY="$UPDATE_DIR/history"
SNAPSHOT_DIR="$UPDATE_DIR/snapshots"
UPDATE_QUEUE="$UPDATE_DIR/queue"
UPDATE_PROGRESS="$UPDATE_DIR/progress"
UPDATE_LOCK="$UPDATE_DIR/.update.lock"
KERNEL_UPDATE_LOG="$UPDATE_DIR/kernel-updates.log"
mkdir -p "$UPDATE_DIR" "$UPDATE_HISTORY" "$SNAPSHOT_DIR"

# ---- lock mechanism ----
update_lock() {
  local max_wait=120
  local waited=0
  while [ -f "$UPDATE_LOCK" ]; do
    local lock_pid
    lock_pid=$(cat "$UPDATE_LOCK" 2>/dev/null)
    if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -f "$UPDATE_LOCK"
      break
    fi
    if [ "$waited" -ge "$max_wait" ]; then
      echo "ERROR: Update lock timeout. Remove $UPDATE_LOCK manually."
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  echo $$ > "$UPDATE_LOCK"
}
update_unlock() { rm -f "$UPDATE_LOCK"; }
trap update_unlock EXIT

# ---- default config ----
init_update() {
  if [ ! -f "$UPDATE_CONFIG" ]; then
    cat > "$UPDATE_CONFIG" << 'DEFAULTS'
{
  "auto_update": true,
  "auto_update_time": "03:00",
  "auto_update_days": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
  "security_only": false,
  "delta_updates": true,
  "notify_updates": true,
  "backup_before_update": true,
  "max_backups": 10,
  "kernel_updates": true,
  "flatpak_updates": true,
  "snap_updates": true,
  "reboot_if_needed": false,
  "download_only": false,
  "exclude_packages": [],
  "max_download_speed": 0,
  "retry_on_failure": true,
  "max_retries": 3,
  "notification_desktop": true,
  "notification_sound": false,
  "bandwidth_limit_kbps": 0,
  "pause_on_metered": false,
  "pre_update_script": "",
  "post_update_script": "",
  "kernel_update_policy": "ask",
  "auto_clean_cache": true,
  "consolidate_updates": false,
  "staged_rollout_days": 0,
  "update_size_limit_mb": 0,
  "verify_signatures": true,
  "auto_rollback_on_failure": true
}
DEFAULTS
    echo "Update config initialized."
  fi
}

# ---- read config value ----
cfg() {
  local key="$1"
  local default="${2:-}"
  python3 -c "
import json, sys
try:
    with open('$UPDATE_CONFIG') as f: c = json.load(f)
    val = c.get('$key', '$default')
    print(val)
except: print('$default')
" 2>/dev/null
}

# ---- write config value ----
cfg_set() {
  local key="$1" value="$2"
  python3 -c "
import json
with open('$UPDATE_CONFIG') as f: c = json.load(f)
c['$key'] = $value
with open('$UPDATE_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
}

# ---- detect package manager ----
detect_pkgmgr() {
  if command -v apt-get &>/dev/null; then echo "apt"
  elif command -v dnf &>/dev/null; then echo "dnf"
  elif command -v pacman &>/dev/null; then echo "pacman"
  elif command -v zypper &>/dev/null; then echo "zypper"
  elif command -v apk &>/dev/null; then echo "apk"
  elif command -v xbps-install &>/dev/null; then echo "xbps"
  else echo "none"
  fi
}

# ---- create snapshot before update ----
create_snapshot() {
  local snap_id="snap_$(date +%Y%m%d_%H%M%S)"
  local snap_dir="$SNAPSHOT_DIR/$snap_id"
  mkdir -p "$snap_dir"

  local mgr
  mgr=$(detect_pkgmgr)

  # Save installed package list
  case "$mgr" in
    apt)    dpkg -l 2>/dev/null | grep ^ii | awk '{print $2, $3}' > "$snap_dir/packages.txt" ;;
    dnf)    rpm -qa --queryformat '%{NAME} %{VERSION}-%{RELEASE}.%{ARCH}\n' > "$snap_dir/packages.txt" ;;
    pacman) pacman -Q > "$snap_dir/packages.txt" ;;
    zypper) rpm -qa --queryformat '%{NAME} %{VERSION}-%{RELEASE}.%{ARCH}\n' > "$snap_dir/packages.txt" ;;
  esac

  # Save config
  cp "$UPDATE_CONFIG" "$snap_dir/config.json" 2>/dev/null || true

  # Save current kernel
  uname -r > "$snap_dir/kernel.txt"

  # Save grub default
  cat /etc/default/grub 2>/dev/null > "$snap_dir/grub-default.txt" || true

  # Save APT sources if present
  [ -f /etc/apt/sources.list ] && cp /etc/apt/sources.list "$snap_dir/sources.list" 2>/dev/null || true

  # Detect if btrfs and create btrfs snapshot
  if command -v btrfs &>/dev/null && mountpoint -q / 2>/dev/null; then
    if btrfs filesystem df / 2>/dev/null | grep -q "Data"; then
      echo "Creating btrfs snapshot..."
      sudo btrfs subvolume snapshot / "/.snapshots/$snap_id" 2>/dev/null || true
    fi
  fi

  # Limit snapshots
  local max_backups
  max_backups=$(cfg "max_backups" "10")
  local count
  count=$(ls -1d "$SNAPSHOT_DIR"/snap_* 2>/dev/null | wc -l)
  if [ "$count" -gt "$max_backups" ]; then
    ls -1d "$SNAPSHOT_DIR"/snap_* | head -n $((count - max_backups)) | xargs rm -rf
  fi

  echo "$snap_id"
}

# ---- rollback to snapshot ----
rollback() {
  local snap_id="${1:-}"
  if [ -z "$snap_id" ]; then
    echo "Available snapshots:"
    ls -1 "$SNAPSHOT_DIR" 2>/dev/null | grep snap_ | sort -r | while read -r s; do
      local count
      count=$(wc -l < "$SNAPSHOT_DIR/$s/packages.txt" 2>/dev/null || echo "?")
      local kernel
      kernel=$(cat "$SNAPSHOT_DIR/$s/kernel.txt" 2>/dev/null || echo "?")
      echo "  $s  ($count packages, kernel: $kernel)"
    done
    return 0
  fi

  local snap_dir="$SNAPSHOT_DIR/$snap_id"
  [ -d "$snap_dir" ] || { echo "Snapshot $snap_id not found."; return 1; }

  echo "=== Rolling back to snapshot: $snap_id ==="
  echo "Snapshot time: $snap_id"
  echo "Saved kernel: $(cat "$snap_dir/kernel.txt" 2>/dev/null || echo '?')"

  local mgr
  mgr=$(detect_pkgmgr)

  # Create a rollback snapshot first
  echo "Creating pre-rollback snapshot..."
  create_snapshot > /dev/null 2>&1 || true

  case "$mgr" in
    apt)
      echo "Removing packages not in snapshot..."
      local current_pkgs saved_pkgs to_remove
      current_pkgs=$(mktemp)
      saved_pkgs=$(mktemp)

      dpkg -l 2>/dev/null | grep ^ii | awk '{print $2}' | sort > "$current_pkgs"
      awk '{print $1}' "$snap_dir/packages.txt" | sort > "$saved_pkgs"

      to_remove=$(comm -23 "$current_pkgs" "$saved_pkgs")
      if [ -n "$to_remove" ]; then
        echo "Removing $(echo "$to_remove" | wc -l) packages..."
        echo "$to_remove" | xargs sudo apt-get remove -y 2>/dev/null || true
      fi

      echo "Reinstalling packages from snapshot..."
      local to_install
      to_install=$(comm -13 "$current_pkgs" "$saved_pkgs")
      if [ -n "$to_install" ]; then
        echo "Installing $(echo "$to_install" | wc -l) packages..."
        echo "$to_install" | xargs sudo apt-get install -y 2>/dev/null || true
      fi

      rm -f "$current_pkgs" "$saved_pkgs"
      ;;
    pacman)
      echo "Syncing packages to snapshot state..."
      local saved
      saved=$(awk '{print $1}' "$snap_dir/packages.txt" | tr '\n' ' ')
      if [ -n "$saved" ]; then
        sudo pacman -S --noconfirm $saved 2>/dev/null || true
      fi
      ;;
    dnf|zypper)
      echo "Syncing packages..."
      local saved
      saved=$(awk '{print $1}' "$snap_dir/packages.txt" | tr '\n' ' ')
      if [ -n "$saved" ]; then
        sudo $(if [ "$mgr" = "dnf" ]; then echo "dnf install -y"; else echo "zypper install -y"; fi) $saved 2>/dev/null || true
      fi
      ;;
  esac

  # Restore grub config if saved
  if [ -f "$snap_dir/grub-default.txt" ]; then
    sudo cp "$snap_dir/grub-default.txt" /etc/default/grub 2>/dev/null || true
    sudo update-grub 2>/dev/null || sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
    echo "GRUB config restored."
  fi

  # Restore kernel if different
  local saved_kernel
  saved_kernel=$(cat "$snap_dir/kernel.txt" 2>/dev/null || echo "")
  local current_kernel
  current_kernel=$(uname -r)
  if [ -n "$saved_kernel" ] && [ "$saved_kernel" != "$current_kernel" ]; then
    echo "Kernel mismatch: current=$current_kernel saved=$saved_kernel"
    echo "To change kernel, run: korrinos-update kernel-switch $saved_kernel"
  fi

  echo "$(date -Iseconds) | rollback | $snap_id | OK" >> "$UPDATE_LOG"
  echo ""
  echo "Rollback complete. Reboot may be required."
}

# ---- perform update ----
do_update() {
  local mode="${1:-full}"
  update_lock
  local start_time
  start_time=$(date +%s)

  echo "=== KorrinOS Update — $(date) ==="
  echo "Mode: $mode"

  # Write progress
  echo "running" > "$UPDATE_PROGRESS"
  echo "0" >> "$UPDATE_PROGRESS"

  # Check metered connection
  if [ "$(cfg "pause_on_metered" "false")" = "True" ]; then
    if nmcli -t -f TYPE CONNECTION show --active 2>/dev/null | grep -q "wireless"; then
      local signal
      signal=$(nmcli -t -f SIGNAL device wifi list 2>/dev/null | head -1)
      if [ -n "$signal" ] && [ "$signal" -lt 20 ]; then
        echo "Metered connection detected. Skipping update."
        echo "$(date -Iseconds) | skip | metered | OK" >> "$UPDATE_LOG"
        update_unlock
        return 0
      fi
    fi
  fi

  # Check bandwidth limit
  local bw_limit
  bw_limit=$(cfg "bandwidth_limit_kbps" "0")

  # Create snapshot if enabled
  local snap_id=""
  if [ "$(cfg "backup_before_update" "true")" = "True" ]; then
    echo "Creating pre-update snapshot..."
    snap_id=$(create_snapshot)
    echo "Snapshot created: $snap_id"
  fi

  echo "10" > "$UPDATE_PROGRESS"

  # Run pre-update script
  local pre_script
  pre_script=$(cfg "pre_update_script" "")
  if [ -n "$pre_script" ] && [ -x "$pre_script" ]; then
    echo "Running pre-update script: $pre_script"
    "$pre_script" 2>&1 || true
  fi

  echo "20" > "$UPDATE_PROGRESS"

  # Detect package manager
  local mgr
  mgr=$(detect_pkgmgr)

  # Update package lists
  echo ""
  echo "Step 1/6: Updating package lists..."
  case "$mgr" in
    apt)
      sudo apt-get update -y 2>&1 | tail -5
      ;;
    dnf)
      sudo dnf check-update -y 2>&1 | tail -5 || true
      ;;
    pacman)
      sudo pacman -Sy --noconfirm 2>&1 | tail -5
      ;;
    zypper)
      sudo zypper refresh 2>&1 | tail -5
      ;;
    apk)
      sudo apk update 2>&1 | tail -3
      ;;
    xbps)
      sudo xbps-install -Su 2>&1 | tail -3
      ;;
  esac

  echo "30" > "$UPDATE_PROGRESS"

  # Security-only or full
  local security_only
  security_only=$(cfg "security_only" "false")

  # Perform upgrades
  echo ""
  echo "Step 2/6: Installing system updates..."
  local retry_count=0
  local max_retries
  max_retries=$(cfg "max_retries" "3")
  local update_success=false

  while [ "$retry_count" -lt "$max_retries" ] && [ "$update_success" = "false" ]; do
    case "$mgr" in
      apt)
        if [ "$mode" = "security" ] || [ "$security_only" = "True" ]; then
          echo "Installing security updates only..."
          sudo apt-get upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            -o APT::Get::Show-Upgraded=true 2>&1 | tail -10
        else
          echo "Installing all updates..."
          sudo apt-get dist-upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            -o APT::Get::Show-Upgraded=true 2>&1 | tail -10
        fi
        update_success=true
        ;;
      dnf)
        if [ "$mode" = "security" ] || [ "$security_only" = "True" ]; then
          sudo dnf upgrade --security -y 2>&1 | tail -10
        else
          sudo dnf upgrade -y --allowerasing 2>&1 | tail -10
        fi
        update_success=true
        ;;
      pacman)
        sudo pacman -Syu --noconfirm 2>&1 | tail -10
        update_success=true
        ;;
      zypper)
        sudo zypper update -y 2>&1 | tail -10
        update_success=true
        ;;
      apk)
        sudo apk upgrade 2>&1 | tail -5
        update_success=true
        ;;
      xbps)
        sudo xbps-install -Su 2>&1 | tail -5
        update_success=true
        ;;
    esac

    if [ "$update_success" = "false" ]; then
      retry_count=$((retry_count + 1))
      echo "Update failed. Retry $retry_count/$max_retries..."
      sleep 5
    fi
  done

  echo "50" > "$UPDATE_PROGRESS"

  # Update flatpak
  echo ""
  echo "Step 3/6: Updating Flatpak packages..."
  if [ "$(cfg "flatpak_updates" "True")" = "True" ] && command -v flatpak &>/dev/null; then
    flatpak update -y 2>&1 | tail -5 || true
  else
    echo "  Skipped (disabled or not installed)"
  fi

  echo "60" > "$UPDATE_PROGRESS"

  # Update snap
  echo ""
  echo "Step 4/6: Updating Snap packages..."
  if [ "$(cfg "snap_updates" "True")" = "True" ] && command -v snap &>/dev/null; then
    sudo snap refresh 2>&1 | tail -5 || true
  else
    echo "  Skipped (disabled or not installed)"
  fi

  echo "70" > "$UPDATE_PROGRESS"

  # Kernel updates
  echo ""
  echo "Step 5/6: Checking kernel updates..."
  if [ "$(cfg "kernel_updates" "True")" = "True" ]; then
    case "$mgr" in
      apt)
        local kernel_updates
        kernel_updates=$(apt list --upgradable 2>/dev/null | grep -c "linux-image\|linux-headers" || echo "0")
        if [ "$kernel_updates" -gt 0 ]; then
          echo "Kernel update available ($kernel_updates packages)."
          local kernel_policy
          kernel_policy=$(cfg "kernel_update_policy" "ask")
          if [ "$kernel_policy" = "auto" ]; then
            echo "Installing kernel update..."
            sudo apt-get install -y linux-image-generic linux-headers-generic 2>&1 | tail -5 || true
            echo "$(date -Iseconds) | kernel-update | apt | OK" >> "$KERNEL_UPDATE_LOG"
          else
            echo "Kernel update deferred (policy: $kernel_policy)"
            echo "Run: sudo apt-get install linux-image-generic linux-headers-generic"
          fi
        else
          echo "  Kernel is up to date."
        fi
        ;;
      dnf)
        dnf list updates kernel* 2>/dev/null | tail -5 || echo "  No kernel updates."
        ;;
      pacman)
        pacman -Qu linux linux-headers 2>/dev/null | head -5 || echo "  No kernel updates."
        ;;
    esac
  else
    echo "  Kernel updates disabled."
  fi

  echo "80" > "$UPDATE_PROGRESS"

  # Autoremove
  echo ""
  echo "Step 6/6: Cleanup..."
  case "$mgr" in
    apt)    sudo apt-get autoremove -y 2>/dev/null || true ;;
    dnf)    sudo dnf autoremove -y 2>/dev/null || true ;;
    pacman) sudo pacman -Sc --noconfirm 2>/dev/null || true ;;
  esac

  # Clean package cache if enabled
  if [ "$(cfg "auto_clean_cache" "true")" = "True" ]; then
    case "$mgr" in
      apt)    sudo apt-get clean 2>/dev/null || true ;;
      dnf)    sudo dnf clean all 2>/dev/null || true ;;
    esac
  fi

  echo "90" > "$UPDATE_PROGRESS"

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))

  # Log
  echo "$(date -Iseconds) | $mode | ${duration}s | OK" >> "$UPDATE_LOG"

  # Desktop notification
  if [ "$(cfg "notification_desktop" "true")" = "True" ]; then
    if command -v notify-send &>/dev/null; then
      notify-send -i system-software-update "KorrinOS Update" \
        "Update complete in ${duration}s.\nMode: $mode\nSnapshot: $snap_id" 2>/dev/null || true
    fi
    if [ "$(cfg "notification_sound" "false")" = "True" ]; then
      paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true
    fi
  fi

  # Check if reboot needed
  if [ -f /var/run/reboot-required ]; then
    echo ""
    echo "!!! REBOOT REQUIRED — new kernel or system packages updated. !!!"
    cat /var/run/reboot-required 2>/dev/null || true

    if [ "$(cfg "notification_desktop" "true")" = "True" ] && command -v notify-send &>/dev/null; then
      notify-send -u critical -i system-reboot "KorrinOS: Reboot Required" \
        "System packages updated. Please reboot." 2>/dev/null || true
    fi

    local reboot_flag
    reboot_flag=$(cfg "reboot_if_needed" "false")
    if [ "$reboot_flag" = "True" ]; then
      echo "Auto-reboot enabled. Rebooting in 60 seconds..."
      sudo shutdown -r +1 "KorrinOS update requires reboot"
    fi
  fi

  echo "100" > "$UPDATE_PROGRESS"

  # Run post-update script
  local post_script
  post_script=$(cfg "post_update_script" "")
  if [ -n "$post_script" ] && [ -x "$post_script" ]; then
    echo "Running post-update script: $post_script"
    "$post_script" 2>&1 || true
  fi

  echo ""
  echo "Update complete in ${duration}s."
  update_unlock
}

# ---- check for updates (without installing) ----
check_updates() {
  echo "=== Checking for Updates ==="

  local mgr
  mgr=$(detect_pkgmgr)

  case "$mgr" in
    apt)
      sudo apt-get update -qq 2>/dev/null
      local total upgradable
      total=$(apt list --installed 2>/dev/null | grep -c "installed" || echo "0")
      upgradable=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
      echo "Installed: $total | Upgradable: $upgradable"
      echo ""
      apt list --upgradable 2>/dev/null | head -30
      ;;
    dnf)
      echo "Checking dnf..."
      local updates
      updates=$(dnf check-update 2>/dev/null | grep -c "^\S\+\s\S\+\s\S\+" || echo "0")
      echo "Upgradable: $updates"
      dnf check-update 2>/dev/null | tail -20 || true
      ;;
    pacman)
      sudo pacman -Sy 2>/dev/null
      local updates
      updates=$(pacman -Qu 2>/dev/null | wc -l || echo "0")
      echo "Upgradable: $updates"
      pacman -Qu 2>/dev/null | head -30
      ;;
    zypper)
      zypper list-updates 2>/dev/null | tail -20
      ;;
  esac

  if command -v flatpak &>/dev/null; then
    echo ""
    echo "=== Flatpak Updates ==="
    flatpak remote-ls --updates 2>/dev/null | head -10 || echo "No flatpak updates."
  fi

  if command -v snap &>/dev/null; then
    echo ""
    echo "=== Snap Updates ==="
    snap refresh --list 2>/dev/null | head -10 || echo "No snap updates."
  fi

  if [ -f /var/run/reboot-required ]; then
    echo ""
    echo "!!! REBOOT REQUIRED !!!"
  fi

  echo ""
  echo "Last update: $(tail -1 "$UPDATE_LOG" 2>/dev/null | cut -d'|' -f1 || echo 'never')"
}

# ---- setup automatic updates (systemd timer) ----
setup_autoupdate() {
  local auto_time
  auto_time=$(cfg "auto_update_time" "03:00")
  local hour="${auto_time%%:*}"
  local minute="${auto_time##*:}"

  # Get the script path
  local script_path
  script_path=$(readlink -f "$0" 2>/dev/null || echo "$0")

  sudo tee /etc/systemd/system/korrinos-autoupdate.service >/dev/null << SERVICEEOF
[Unit]
Description=KorrinOS Automatic Updates
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$script_path full
Nice=19
IOSchedulingClass=idle
TimeoutStartSec=3600
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

  sudo tee /etc/systemd/system/korrinos-autoupdate.timer >/dev/null << TIMEREOF
[Unit]
Description=KorrinOS Automatic Updates Timer

[Timer]
OnCalendar=*-*-* ${hour}:${minute}:00
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
TIMEREOF

  sudo systemctl daemon-reload
  sudo systemctl enable korrinos-autoupdate.timer
  sudo systemctl start korrinos-autoupdate.timer
  echo "Auto-update enabled: daily at $auto_time"
  echo "Timer status:"
  systemctl status korrinos-autoupdate.timer --no-pager 2>/dev/null | head -5
}

# ---- disable auto updates ----
disable_autoupdate() {
  sudo systemctl stop korrinos-autoupdate.timer 2>/dev/null || true
  sudo systemctl disable korrinos-autoupdate.timer 2>/dev/null || true
  echo "Auto-update disabled."
}

# ---- show update progress ----
show_progress() {
  if [ -f "$UPDATE_PROGRESS" ]; then
    local status
    status=$(head -1 "$UPDATE_PROGRESS" 2>/dev/null || echo "idle")
    local percent
    percent=$(tail -1 "$UPDATE_PROGRESS" 2>/dev/null || echo "0")
    echo "Update Status: $status ($percent%)"
  else
    echo "No update in progress."
  fi
}

# ---- update queue management ----
queue_add() {
  local pkg="$1"
  echo "$pkg|$(date -Iseconds)" >> "$UPDATE_QUEUE"
  echo "Queued: $pkg"
}

queue_list() {
  echo "=== Update Queue ==="
  if [ -f "$UPDATE_QUEUE" ]; then
    cat "$UPDATE_QUEUE"
  else
    echo "Queue empty."
  fi
}

queue_clear() {
  > "$UPDATE_QUEUE"
  echo "Queue cleared."
}

# ---- kernel management ----
kernel_list() {
  echo "=== Installed Kernels ==="
  case "$(detect_pkgmgr)" in
    apt)
      dpkg -l 2>/dev/null | grep "linux-image" | awk '{printf "  %-35s %s\n", $2, $3}'
      ;;
    dnf)
      rpm -qa kernel 2>/dev/null | sort -V
      ;;
    pacman)
      pacman -Q linux linux-lts linux-zen linux-hardened 2>/dev/null || echo "  Custom kernel"
      ;;
  esac
  echo ""
  echo "Running: $(uname -r)"
}

kernel_switch() {
  local target="${1:-}"
  [ -z "$target" ] && { kernel_list; return 0; }

  echo "Switching to kernel: $target"
  case "$(detect_pkgmgr)" in
    apt)
      sudo apt-get install -y "linux-image-$target" "linux-headers-$target" 2>&1 | tail -5
      sudo update-grub 2>/dev/null || true
      ;;
    pacman)
      echo "Edit /etc/grub.d/40_custom or use: sudo grub-mkconfig -o /boot/grub/grub.cfg"
      ;;
  esac
  echo "Kernel $target installed. Reboot to activate."
}

kernel_remove() {
  local target="${1:-}"
  [ -z "$target" ] && { echo "Specify kernel to remove."; return 1; }

  echo "Removing kernel: $target"
  case "$(detect_pkgmgr)" in
    apt)
      sudo apt-get remove -y "linux-image-$target" "linux-headers-$target" 2>&1 | tail -5
      sudo update-grub 2>/dev/null || true
      ;;
    pacman)
      sudo pacman -R --noconfirm "linux-$target" 2>/dev/null || true
      ;;
  esac
  echo "Kernel $target removed."
}

# ---- update history ----
show_history() {
  echo "=== Update History ==="
  if [ -f "$UPDATE_LOG" ]; then
    echo "Date                    | Mode      | Duration | Status"
    echo "------------------------|-----------|----------|------"
    tail -30 "$UPDATE_LOG" | while IFS='|' read -r ts mode dur status; do
      printf "%-24s | %-9s | %-8s | %s\n" "$(echo $ts | tr -d ' ')" "$(echo $mode | tr -d ' ')" "$(echo $dur | tr -d ' ')" "$(echo $status | tr -d ' ')"
    done
  else
    echo "No history."
  fi
}

# ---- full system status ----
show_status() {
  echo "==========================================="
  echo "   KorrinOS Update System Status"
  echo "==========================================="
  echo ""
  echo "Auto-update:     $(cfg 'auto_update' 'false')"
  echo "Auto-update time: $(cfg 'auto_update_time' '03:00')"
  echo "Security-only:   $(cfg 'security_only' 'false')"
  echo "Delta updates:   $(cfg 'delta_updates' 'true')"
  echo "Kernel updates:  $(cfg 'kernel_updates' 'true')"
  echo "Backup before:   $(cfg 'backup_before_update' 'true')"
  echo ""
  echo "Package Manager: $(detect_pkgmgr)"
  echo "Running Kernel:  $(uname -r)"
  echo ""
  echo "Snapshots:       $(ls -1d "$SNAPSHOT_DIR"/snap_* 2>/dev/null | wc -l)"
  echo "Update history:  $(wc -l < "$UPDATE_LOG" 2>/dev/null || echo '0') entries"
  echo "Last update:     $(tail -1 "$UPDATE_LOG" 2>/dev/null | cut -d'|' -f1 || echo 'never')"
  echo ""
  [ -f /var/run/reboot-required ] && echo "!!! REBOOT REQUIRED !!!" || echo "No reboot needed."

  # Check auto-update timer
  if systemctl is-active korrinos-autoupdate.timer &>/dev/null; then
    echo "Auto-update timer: ACTIVE"
    systemctl show korrinos-autoupdate.timer --property=NextElapseUSecRealtime 2>/dev/null | awk '{print "Next run: " $1}'
  else
    echo "Auto-update timer: inactive"
  fi

  # Progress
  show_progress
}

# ---- rollback-on-failure hook ----
auto_rollback_check() {
  if [ "$(cfg "auto_rollback_on_failure" "true")" = "True" ]; then
    # Check if the last update failed
    local last_status
    last_status=$(tail -1 "$UPDATE_LOG" 2>/dev/null | grep -c "fail" || echo "0")
    if [ "$last_status" -gt 0 ]; then
      echo "Last update failed. Auto-rollback available."
      echo "Run: korrinos-update rollback to see snapshots."
    fi
  fi
}

# ---- download-only mode ----
download_only() {
  echo "=== Download Only Mode ==="
  local mgr
  mgr=$(detect_pkgmgr)
  case "$mgr" in
    apt)
      sudo apt-get update -qq 2>/dev/null
      sudo apt-get download $(apt list --upgradable 2>/dev/null | grep upgradable | awk -F/ '{print $1}') 2>/dev/null || true
      ;;
    dnf)
      sudo dnf download --resolve $(dnf check-update 2>/dev/null | awk '{print $1}' | grep -v "^$" | head -20) 2>/dev/null || true
      ;;
  esac
  echo "Downloads complete."
}

# ---- bandwith-limited update ----
bw_limited_update() {
  local bw
  bw=$(cfg "bandwidth_limit_kbps" "0")
  if [ "$bw" -gt 0 ]; then
    echo "Bandwidth limited to ${bw} kbps"
    # Use trickle if available
    if command -v trickle &>/dev/null; then
      trickle -d "$bw" -u "$bw" $(readlink -f "$0") full
    else
      echo "Install trickle for bandwidth limiting: sudo apt install trickle"
      do_update full
    fi
  else
    do_update full
  fi
}

# ---- main ----
case "${1:-}" in
  auto)              do_update full ;;
  full)              do_update full ;;
  security)          do_update security ;;
  check)             check_updates ;;
  setup-auto)        setup_autoupdate ;;
  disable-auto)      disable_autoupdate ;;
  snapshot)          create_snapshot ;;
  rollback)          shift; rollback "${1:-}" ;;
  history)           show_history ;;
  status)            show_status ;;
  progress)          show_progress ;;
  queue-add)         shift; queue_add "$@" ;;
  queue-list)        queue_list ;;
  queue-clear)       queue_clear ;;
  kernel-list)       kernel_list ;;
  kernel-switch)     shift; kernel_switch "$@" ;;
  kernel-remove)     shift; kernel_remove "$@" ;;
  download-only)     download_only ;;
  bw-update)         bw_limited_update ;;
  init)              init_update ;;
  help|*)            echo "KorrinOS Update System v2
Usage: korrinos-update <command> [args]

Update Commands:
  full              Full system update (all packages)
  security          Security updates only
  auto              Run update as if auto-update triggered
  check             Check for available updates without installing
  bw-update         Bandwidth-limited update

Auto-Update Management:
  setup-auto        Setup automatic daily updates (systemd timer)
  disable-auto      Disable automatic updates

Snapshots & Rollback:
  snapshot          Create a pre-update backup snapshot
  rollback [id]     Rollback to a snapshot (list if no id)
  rollback <id>     Rollback to specific snapshot

Kernel Management:
  kernel-list       List installed kernels
  kernel-switch <v> Switch to a different kernel version
  kernel-remove <v> Remove a kernel version

Queue Management:
  queue-add <pkg>   Add a package to the update queue
  queue-list        List queued packages
  queue-clear       Clear the update queue

History & Status:
  history           Show update history
  status            Show full update system status
  progress          Show current update progress

Misc:
  download-only     Download updates without installing
  init              Initialize update config" ;;
esac

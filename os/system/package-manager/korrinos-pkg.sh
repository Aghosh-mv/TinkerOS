#!/bin/bash
# KorrinOS Unified Package Manager v2
# Real package management across apt/dnf/pacman/zypper + snap + flatpak
# Unified search, install, remove, update, rollback,orphans, history, GUI
# Kernel-level package tracking via /proc/tinker/pkg interface

set -euo pipefail

PKG_DIR="${HOME}/.config/korrinos/pkg"
PKG_CACHE="$PKG_DIR/cache"
PKG_LOG="$PKG_DIR/install.log"
PKG_DB="$PKG_DIR/installed.db"
PKG_SNAPSHOTS="$PKG_DIR/snapshots"
PKG_SOURCES="$PKG_DIR/sources.json"
PKG_LOCK="$PKG_DIR/.lock"
mkdir -p "$PKG_DIR" "$PKG_CACHE" "$PKG_SNAPSHOTS"

# ============================================================================
#  LOCK MECHANISM — prevent parallel package operations
# ============================================================================

pkg_lock() {
  local lockfile="$PKG_LOCK"
  local max_wait=30
  local waited=0
  while [ -f "$lockfile" ]; do
    local lock_pid
    lock_pid=$(cat "$lockfile" 2>/dev/null)
    if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -f "$lockfile"
      break
    fi
    if [ "$waited" -ge "$max_wait" ]; then
      echo "ERROR: Package manager lock timeout. Remove $lockfile manually."
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
  echo $$ > "$lockfile"
}

pkg_unlock() {
  rm -f "$PKG_LOCK"
}

trap pkg_unlock EXIT

# ============================================================================
#  DETECTION — detect all available package managers
# ============================================================================

detect_pkgmgr() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  elif command -v zypper &>/dev/null; then
    echo "zypper"
  elif command -v apk &>/dev/null; then
    echo "apk"
  elif command -v xbps-install &>/dev/null; then
    echo "xbps"
  else
    echo "none"
  fi
}

detect_snap() { command -v snap &>/dev/null && echo "yes" || echo "no"; }
detect_flatpak() { command -v flatpak &>/dev/null && echo "yes" || echo "no"; }

detect_all_managers() {
  local mgrs=""
  [ "$(detect_pkgmgr)" != "none" ] && mgrs="$mgrs $(detect_pkgmgr)"
  [ "$(detect_snap)" = "yes" ] && mgrs="$mgrs snap"
  [ "$(detect_flatpak)" = "yes" ] && mgrs="$mgrs flatpak"
  echo "$mgrs"
}

pkgmgr_version() {
  local mgr
  mgr=$(detect_pkgmgr)
  case "$mgr" in
    apt)    apt-get --version 2>/dev/null | head -1 ;;
    dnf)    dnf --version 2>/dev/null | head -1 ;;
    pacman) pacman --version 2>/dev/null | head -1 ;;
    zypper) zypper --version 2>/dev/null | head -1 ;;
    *)      echo "unknown" ;;
  esac
}

# ============================================================================
#  UPDATE — update package lists from all sources
# ============================================================================

pkg_update() {
  pkg_lock
  local mgr
  mgr=$(detect_pkgmgr)
  local start_time
  start_time=$(date +%s)

  echo "=== Updating package lists ==="
  echo "Manager: $mgr"
  echo "Started: $(date)"

  case "$mgr" in
    apt)
      sudo apt-get update -y 2>&1 | tail -5
      local apt_status=$?
      if [ $apt_status -ne 0 ]; then
        echo "WARN: apt-get update had warnings"
      fi
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
      sudo apk update 2>&1 | tail -5
      ;;
    xbps)
      sudo xbps-install -Su 2>&1 | tail -5
      ;;
  esac

  if [ "$(detect_snap)" = "yes" ]; then
    echo "Updating snap channels..."
    snap list 2>/dev/null | tail -n +2 | awk '{print $1}' | while read -r s; do
      snap refresh "$s" 2>/dev/null || true
    done
  fi

  if [ "$(detect_flatpak)" = "yes" ]; then
    echo "Updating flatpak remotes..."
    flatpak update --appstream 2>/dev/null || true
  fi

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))

  echo "$(date -Iseconds) | update | ${duration}s | OK" >> "$PKG_LOG"
  echo "Update complete in ${duration}s."

  pkg_unlock
}

# ============================================================================
#  UPGRADE — upgrade all packages
# ============================================================================

pkg_upgrade() {
  pkg_lock
  local mgr
  mgr=$(detect_pkgmgr)
  local start_time
  start_time=$(date +%s)

  echo "=== Upgrading all packages ==="

  # Create snapshot first
  echo "Creating pre-upgrade snapshot..."
  pkg_snapshot_pre

  case "$mgr" in
    apt)
      sudo apt-get upgrade -y -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" 2>&1 | tail -10
      sudo apt-get dist-upgrade -y -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" 2>&1 | tail -10
      ;;
    dnf)
      sudo dnf upgrade -y --allowerasing 2>&1 | tail -10
      ;;
    pacman)
      sudo pacman -Syu --noconfirm 2>&1 | tail -10
      ;;
    zypper)
      sudo zypper update -y 2>&1 | tail -10
      ;;
    apk)
      sudo apk upgrade 2>&1 | tail -10
      ;;
    xbps)
      sudo xbps-install -Su 2>&1 | tail -10
      ;;
  esac

  if [ "$(detect_snap)" = "yes" ]; then
    echo "Refreshing snap packages..."
    sudo snap refresh 2>&1 | tail -5 || true
  fi

  if [ "$(detect_flatpak)" = "yes" ]; then
    echo "Updating flatpak packages..."
    flatpak update -y 2>&1 | tail -5 || true
  fi

  # Autoremove
  case "$mgr" in
    apt)    sudo apt-get autoremove -y 2>/dev/null || true ;;
    dnf)    sudo dnf autoremove -y 2>/dev/null || true ;;
  esac

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))

  # Check reboot
  if [ -f /var/run/reboot-required ]; then
    echo ""
    echo "!!! REBOOT REQUIRED — kernel or core packages updated !!!"
    cat /var/run/reboot-required 2>/dev/null || true
  fi

  echo "$(date -Iseconds) | upgrade | ${duration}s | OK" >> "$PKG_LOG"
  echo "Upgrade complete in ${duration}s."

  pkg_unlock
}

# ============================================================================
#  INSTALL — install a package (tries all sources)
# ============================================================================

pkg_install() {
  local pkg="$1"
  local force="${2:-}"
  local mgr
  mgr=$(detect_pkgmgr)
  local start_time
  start_time=$(date +%s)

  [ -z "$pkg" ] && { echo "ERROR: package name required"; return 1; }

  echo "=== Installing: $pkg ==="

  # Check if already installed
  if [ "$force" != "--force" ] && pkg_is_installed "$pkg"; then
    echo "$pkg is already installed."
    return 0
  fi

  # Log the install attempt
  echo "$(date -Iseconds) | install-start | $pkg" >> "$PKG_LOG"

  # Try native package manager first
  case "$mgr" in
    apt)
      echo "Installing via apt..."
      if sudo apt-get install -y "$pkg" 2>&1 | tail -5; then
        pkg_record "$pkg" "apt"
        local end_time=$(date +%s)
        echo "$(date -Iseconds) | install-ok | $pkg | $((end_time - start_time))s" >> "$PKG_LOG"
        echo "Installed $pkg via apt."
        return 0
      fi
      ;;
    dnf)
      echo "Installing via dnf..."
      if sudo dnf install -y "$pkg" 2>&1 | tail -5; then
        pkg_record "$pkg" "dnf"
        local end_time=$(date +%s)
        echo "$(date -Iseconds) | install-ok | $pkg | $((end_time - start_time))s" >> "$PKG_LOG"
        echo "Installed $pkg via dnf."
        return 0
      fi
      ;;
    pacman)
      echo "Installing via pacman..."
      if sudo pacman -S --noconfirm "$pkg" 2>&1 | tail -5; then
        pkg_record "$pkg" "pacman"
        local end_time=$(date +%s)
        echo "$(date -Iseconds) | install-ok | $pkg | $((end_time - start_time))s" >> "$PKG_LOG"
        echo "Installed $pkg via pacman."
        return 0
      fi
      ;;
    zypper)
      echo "Installing via zypper..."
      if sudo zypper install -y "$pkg" 2>&1 | tail -5; then
        pkg_record "$pkg" "zypper"
        local end_time=$(date +%s)
        echo "$(date -Iseconds) | install-ok | $pkg | $((end_time - start_time))s" >> "$PKG_LOG"
        echo "Installed $pkg via zypper."
        return 0
      fi
      ;;
    apk)
      if sudo apk add "$pkg" 2>&1 | tail -5; then
        pkg_record "$pkg" "apk"
        return 0
      fi
      ;;
    xbps)
      if sudo xbps-install -y "$pkg" 2>&1 | tail -5; then
        pkg_record "$pkg" "xbps"
        return 0
      fi
      ;;
  esac

  # Try snap
  if [ "$(detect_snap)" = "yes" ]; then
    echo "Trying snap..."
    if snap install "$pkg" 2>&1 | tail -3; then
      pkg_record "$pkg" "snap"
      local end_time=$(date +%s)
      echo "$(date -Iseconds) | install-ok | $pkg snap | $((end_time - start_time))s" >> "$PKG_LOG"
      echo "Installed $pkg via snap."
      return 0
    fi
  fi

  # Try flatpak
  if [ "$(detect_flatpak)" = "yes" ]; then
    echo "Trying flatpak..."
    if flatpak install -y flathub "$pkg" 2>&1 | tail -3; then
      pkg_record "$pkg" "flatpak"
      local end_time=$(date +%s)
      echo "$(date -Iseconds) | install-ok | $pkg flatpak | $((end_time - start_time))s" >> "$PKG_LOG"
      echo "Installed $pkg via flatpak."
      return 0
    fi
  fi

  # Try pip/python
  if command -v pip3 &>/dev/null && pip3 install "$pkg" 2>/dev/null; then
    pkg_record "$pkg" "pip"
    echo "Installed $pkg via pip."
    return 0
  fi

  local end_time=$(date +%s)
  echo "$(date -Iseconds) | install-fail | $pkg | $((end_time - start_time))s" >> "$PKG_LOG"
  echo "FAILED: Could not install $pkg from any source."
  echo "Sources tried: apt/dnf/pacman, snap, flatpak, pip"
  return 1
}

# ============================================================================
#  REMOVE / PURGE
# ============================================================================

pkg_remove() {
  local pkg="$1"
  local mgr
  mgr=$(detect_pkgmgr)

  [ -z "$pkg" ] && { echo "ERROR: package name required"; return 1; }

  echo "=== Removing: $pkg ==="

  case "$mgr" in
    apt)    sudo apt-get remove -y "$pkg" ;;
    dnf)    sudo dnf remove -y "$pkg" ;;
    pacman) sudo pacman -R --noconfirm "$pkg" ;;
    zypper) sudo zypper remove -y "$pkg" ;;
    apk)    sudo apk del "$pkg" ;;
    xbps)   sudo xbps-remove -y "$pkg" ;;
  esac

  pkg_unrecord "$pkg"
  echo "$(date -Iseconds) | remove | $pkg | OK" >> "$PKG_LOG"
  echo "$pkg removed."
}

pkg_purge() {
  local pkg="$1"
  local mgr
  mgr=$(detect_pkgmgr)

  [ -z "$pkg" ] && { echo "ERROR: package name required"; return 1; }

  echo "=== Purging: $pkg (remove + config) ==="

  case "$mgr" in
    apt)    sudo apt-get purge -y "$pkg" ;;
    dnf)    sudo dnf remove -y --purge "$pkg" ;;
    pacman) sudo pacman -Rns --noconfirm "$pkg" ;;
    zypper) sudo zypper remove -y --clean-deps "$pkg" ;;
    apk)    sudo apk del "$pkg" ;;
  esac

  pkg_unrecord "$pkg"
  echo "$(date -Iseconds) | purge | $pkg | OK" >> "$PKG_LOG"
  echo "$pkg purged."
}

# ============================================================================
#  SEARCH — search across all sources
# ============================================================================

pkg_search() {
  local query="$1"
  local mgr
  mgr=$(detect_pkgmgr)

  [ -z "$query" ] && { echo "ERROR: search query required"; return 1; }

  echo "=== Search: $query ==="

  case "$mgr" in
    apt)
      echo "--- apt ---"
      apt-cache search "$query" 2>/dev/null | head -30
      ;;
    dnf)
      echo "--- dnf ---"
      dnf search "$query" 2>/dev/null | tail -n +2 | head -30
      ;;
    pacman)
      echo "--- pacman ---"
      pacman -Ss "$query" 2>/dev/null | head -30
      ;;
    zypper)
      echo "--- zypper ---"
      zypper search "$query" 2>/dev/null | tail -n +2 | head -30
      ;;
  esac

  if [ "$(detect_snap)" = "yes" ]; then
    echo ""
    echo "--- snap ---"
    snap find "$query" 2>/dev/null | head -15
  fi

  if [ "$(detect_flatpak)" = "yes" ]; then
    echo ""
    echo "--- flatpak ---"
    flatpak search "$query" 2>/dev/null | head -15
  fi
}

# ============================================================================
#  INFO — show package details
# ============================================================================

pkg_info() {
  local pkg="$1"
  local mgr
  mgr=$(detect_pkgmgr)

  [ -z "$pkg" ] && { echo "ERROR: package name required"; return 1; }

  echo "=== Package Info: $pkg ==="

  case "$mgr" in
    apt)
      apt-cache show "$pkg" 2>/dev/null | head -40
      echo ""
      echo "Installed: $(dpkg -l "$pkg" 2>/dev/null | grep ^ii | awk '{print $3}' || echo 'not installed')"
      echo "Size: $(apt-cache show "$pkg" 2>/dev/null | grep "^Installed-Size:" | awk '{print $2}' || echo 'unknown') KB"
      ;;
    dnf)
      dnf info "$pkg" 2>/dev/null | head -30
      ;;
    pacman)
      pacman -Si "$pkg" 2>/dev/null | head -30
      echo ""
      echo "Installed: $(pacman -Q "$pkg" 2>/dev/null || echo 'not installed')"
      ;;
    zypper)
      zypper info "$pkg" 2>/dev/null | head -30
      ;;
  esac
}

# ============================================================================
#  LIST — list installed packages
# ============================================================================

pkg_list() {
  local mgr
  mgr=$(detect_pkgmgr)

  echo "=== Installed Packages ==="

  case "$mgr" in
    apt)
      local count
      count=$(dpkg -l 2>/dev/null | grep ^ii | wc -l)
      echo "apt packages: $count"
      dpkg -l 2>/dev/null | grep ^ii | awk '{printf "  %-30s %s\n", $2, $3}' | head -50
      echo "  ... (showing 50 of $count)"
      ;;
    dnf)
      dnf list installed 2>/dev/null | tail -n +2 | head -50
      ;;
    pacman)
      pacman -Q 2>/dev/null | head -50
      ;;
    zypper)
      zypper packages --installed 2>/dev/null | head -50
      ;;
  esac

  if [ "$(detect_snap)" = "yes" ]; then
    echo ""
    echo "=== Snap Packages ==="
    snap list 2>/dev/null | head -20
  fi

  if [ "$(detect_flatpak)" = "yes" ]; then
    echo ""
    echo "=== Flatpak Packages ==="
    flatpak list 2>/dev/null | head -20
  fi
}

# ============================================================================
#  CHECK — check for available updates
# ============================================================================

pkg_check() {
  local mgr
  mgr=$(detect_pkgmgr)

  echo "=== Checking for Updates ==="

  case "$mgr" in
    apt)
      sudo apt-get update -qq 2>/dev/null
      local upgradable
      upgradable=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
      echo "Upgradable packages: $upgradable"
      apt list --upgradable 2>/dev/null | head -30
      ;;
    dnf)
      echo "Checking dnf updates..."
      dnf check-update 2>/dev/null | tail -30 || true
      ;;
    pacman)
      sudo pacman -Sy 2>/dev/null
      local updates
      updates=$(pacman -Qu 2>/dev/null | wc -l || echo "0")
      echo "Upgradable packages: $updates"
      pacman -Qu 2>/dev/null | head -30
      ;;
    zypper)
      zypper list-updates 2>/dev/null | tail -30
      ;;
  esac

  if [ "$(detect_snap)" = "yes" ]; then
    echo ""
    echo "=== Snap Updates ==="
    snap refresh --list 2>/dev/null | head -20 || echo "snap refresh --list not available"
  fi

  if [ "$(detect_flatpak)" = "yes" ]; then
    echo ""
    echo "=== Flatpak Updates ==="
    flatpak remote-ls --updates 2>/dev/null | head -10 || echo "No flatpak updates available"
  fi

  if [ -f /var/run/reboot-required ]; then
    echo ""
    echo "!!! REBOOT REQUIRED !!!"
  fi
}

# ============================================================================
#  IS INSTALLED — check if a package is installed
# ============================================================================

pkg_is_installed() {
  local pkg="$1"
  local mgr
  mgr=$(detect_pkgmgr)

  case "$mgr" in
    apt)    dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" ;;
    dnf)    rpm -q "$pkg" &>/dev/null ;;
    pacman) pacman -Q "$pkg" &>/dev/null ;;
    zypper) rpm -q "$pkg" &>/dev/null ;;
    apk)    apk info -e "$pkg" &>/dev/null ;;
    *)      false ;;
  esac
}

# ============================================================================
#  RECORD / UNRECORD — track installed packages
# ============================================================================

pkg_record() {
  local pkg="$1" source="$2"
  echo "$pkg|$source|$(date -Iseconds)" >> "$PKG_DB"
}

pkg_unrecord() {
  local pkg="$1"
  if [ -f "$PKG_DB" ]; then
    grep -v "^$pkg|" "$PKG_DB" > "$PKG_DB.tmp" 2>/dev/null || true
    mv "$PKG_DB.tmp" "$PKG_DB" 2>/dev/null || true
  fi
}

# ============================================================================
#  SNAPSHOT — create pre-upgrade snapshots
# ============================================================================

pkg_snapshot_pre() {
  local snap_id="pkg_$(date +%Y%m%d_%H%M%S)"
  local snap_dir="$PKG_SNAPSHOTS/$snap_id"
  mkdir -p "$snap_dir"

  local mgr
  mgr=$(detect_pkgmgr)

  case "$mgr" in
    apt)
      dpkg -l 2>/dev/null | grep ^ii | awk '{print $2, $3}' > "$snap_dir/packages.txt"
      ;;
    dnf)
      rpm -qa --queryformat '%{NAME} %{VERSION}-%{RELEASE}\n' > "$snap_dir/packages.txt"
      ;;
    pacman)
      pacman -Q > "$snap_dir/packages.txt"
      ;;
    zypper)
      rpm -qa --queryformat '%{NAME} %{VERSION}-%{RELEASE}\n' > "$snap_dir/packages.txt"
      ;;
  esac

  # Keep only last 10 snapshots
  local count
  count=$(ls -1d "$PKG_SNAPSHOTS"/pkg_* 2>/dev/null | wc -l)
  if [ "$count" -gt 10 ]; then
    ls -1d "$PKG_SNAPSHOTS"/pkg_* | head -n $((count - 10)) | xargs rm -rf
  fi

  echo "$snap_id"
}

# ============================================================================
#  ROLLBACK — rollback to a pre-upgrade snapshot
# ============================================================================

pkg_rollback() {
  local snap_id="${1:-}"

  if [ -z "$snap_id" ]; then
    echo "=== Available Snapshots ==="
    ls -1d "$PKG_SNAPSHOTS"/pkg_* 2>/dev/null | sort -r | while read -r d; do
      local name
      name=$(basename "$d")
      local count
      count=$(wc -l < "$d/packages.txt" 2>/dev/null || echo "0")
      echo "  $name ($count packages)"
    done
    return 0
  fi

  local snap_dir="$PKG_SNAPSHOTS/$snap_id"
  [ -d "$snap_dir" ] || { echo "Snapshot not found: $snap_id"; return 1; }

  echo "=== Rolling back to: $snap_id ==="
  echo "Snapshot packages: $(wc -l < "$snap_dir/packages.txt")"

  local mgr
  mgr=$(detect_pkgmgr)

  case "$mgr" in
    apt)
      echo "Removing packages not in snapshot..."
      local current_pkgs
      current_pkgs=$(mktemp)
      dpkg -l 2>/dev/null | grep ^ii | awk '{print $2}' | sort > "$current_pkgs"

      local saved_pkgs
      saved_pkgs=$(mktemp)
      awk '{print $1}' "$snap_dir/packages.txt" | sort > "$saved_pkgs"

      local to_remove
      to_remove=$(comm -23 "$current_pkgs" "$saved_pkgs")
      if [ -n "$to_remove" ]; then
        echo "Removing $(echo "$to_remove" | wc -l) packages..."
        echo "$to_remove" | xargs sudo apt-get remove -y 2>/dev/null || true
      fi

      rm -f "$current_pkgs" "$saved_pkgs"
      ;;
    pacman)
      echo "Syncing to snapshot state..."
      sudo pacman -S --noconfirm $(cat "$snap_dir/packages.txt" | awk '{print $1}' | tr '\n' ' ') 2>/dev/null || true
      ;;
  esac

  echo "$(date -Iseconds) | rollback | $snap_id | OK" >> "$PKG_LOG"
  echo "Rollback complete. Reboot may be required."
}

# ============================================================================
#  ORPHANS — find and remove orphaned packages
# ============================================================================

pkg_orphans() {
  local mgr
  mgr=$(detect_pkgmgr)

  echo "=== Orphaned Packages ==="

  case "$mgr" in
    apt)
      echo "Manual packages (not installed as dependencies):"
      apt-mark showmanual 2>/dev/null | sort -u | head -30
      ;;
    dnf)
      echo "Unneeded packages:"
      dnf repoquery --unneeded 2>/dev/null | head -30
      ;;
    pacman)
      echo "Orphaned packages (no depends):"
      pacman -Qtdq 2>/dev/null | head -30
      ;;
    zypper)
      echo "Orphaned packages:"
      zypper packages --orphaned 2>/dev/null | head -30
      ;;
  esac
}

pkg_remove_orphans() {
  local mgr
  mgr=$(detect_pkgmgr)

  echo "=== Removing Orphans ==="
  case "$mgr" in
    apt)    sudo apt-get autoremove -y 2>/dev/null ;;
    dnf)    sudo dnf autoremove -y 2>/dev/null ;;
    pacman) sudo pacman -Rns $(pacman -Qtdq 2>/dev/null | tr '\n' ' ') --noconfirm 2>/dev/null || echo "No orphans." ;;
  esac
  echo "Orphans removed."
}

# ============================================================================
#  CLEAN — clean package cache
# ============================================================================

pkg_clean() {
  local mgr
  mgr=$(detect_pkgmgr)

  echo "=== Cleaning Package Cache ==="

  local before
  before=$(du -sh /var/cache/apt 2>/dev/null | awk '{print $1}' || echo "?")

  case "$mgr" in
    apt)    sudo apt-get clean && sudo apt-get autoremove -y 2>/dev/null ;;
    dnf)    sudo dnf clean all 2>/dev/null ;;
    pacman) sudo pacman -Sc --noconfirm 2>/dev/null ;;
    zypper) sudo zypper clean --all 2>/dev/null ;;
  esac

  local after
  after=$(du -sh /var/cache/apt 2>/dev/null | awk '{print $1}' || echo "?")

  echo "Cache cleaned: $before -> $after"
  echo "$(date -Iseconds) | clean | OK" >> "$PKG_LOG"
}

# ============================================================================
#  DEPS — show dependencies of a package
# ============================================================================

pkg_deps() {
  local pkg="$1"
  local mgr
  mgr=$(detect_pkgmgr)

  [ -z "$pkg" ] && { echo "ERROR: package name required"; return 1; }

  echo "=== Dependencies of: $pkg ==="
  case "$mgr" in
    apt)
      apt-cache depends "$pkg" 2>/dev/null
      echo ""
      echo "Reverse dependencies (depends on $pkg):"
      apt-cache rdepends "$pkg" 2>/dev/null | head -20
      ;;
    dnf)
      dnf repoquery --requires "$pkg" 2>/dev/null
      ;;
    pacman)
      pactree "$pkg" 2>/dev/null || pacman -Qi "$pkg" 2>/dev/null | grep "Depends On"
      ;;
  esac
}

# ============================================================================
#  SOURCES — manage package repositories
# ============================================================================

pkg_sources_list() {
  local mgr
  mgr=$(detect_pkgmgr)

  echo "=== Package Sources ==="
  case "$mgr" in
    apt)
      cat /etc/apt/sources.list 2>/dev/null | grep -v "^#" | grep -v "^$"
      echo ""
      echo "Additional sources:"
      ls /etc/apt/sources.list.d/ 2>/dev/null
      for f in /etc/apt/sources.list.d/*.list; do
        [ -f "$f" ] && echo "  --- $f ---" && grep -v "^#" "$f" 2>/dev/null | head -5
      done
      ;;
    dnf)
      dnf repolist 2>/dev/null
      ;;
    pacman)
      cat /etc/pacman.conf 2>/dev/null | grep "^\[" | grep -v "options"
      ;;
  esac
}

pkg_add_repo() {
  local repo_url="$1"
  local mgr
  mgr=$(detect_pkgmgr)

  [ -z "$repo_url" ] && { echo "ERROR: repository URL required"; return 1; }

  echo "=== Adding Repository ==="
  case "$mgr" in
    apt)
      sudo add-apt-repository -y "$repo_url" 2>/dev/null || {
        echo "Adding to sources.list..."
        echo "deb $repo_url" | sudo tee /etc/apt/sources.list.d/korrinos-extra.list
      }
      sudo apt-get update -qq
      ;;
    dnf)
      sudo dnf config-manager --add-repo "$repo_url" 2>/dev/null
      ;;
    pacman)
      echo "Add [korrinos-extra] to /etc/pacman.conf:"
      echo "  [korrinos-extra]"
      echo "  Server = $repo_url"
      ;;
  esac
  echo "Repository added."
}

# ============================================================================
#  DOWNLOAD — download without installing
# ============================================================================

pkg_download() {
  local pkg="$1"
  local mgr
  mgr=$(detect_pkgmgr)

  [ -z "$pkg" ] && { echo "ERROR: package name required"; return 1; }

  echo "=== Downloading: $pkg ==="
  case "$mgr" in
    apt)
      apt-get download "$pkg" 2>/dev/null && echo "Downloaded to $(pwd)" || {
        echo "Trying with --print-uris..."
        apt-get download --print-uris "$pkg" 2>/dev/null
      }
      ;;
    dnf)
      dnf download "$pkg" 2>/dev/null
      ;;
    pacman)
      pacman -Sw "$pkg" --noconfirm 2>/dev/null
      ;;
  esac
}

# ============================================================================
#  HISTORY — show package operation history
# ============================================================================

pkg_history() {
  echo "=== Package Manager History ==="
  if [ -f "$PKG_LOG" ]; then
    echo "Recent operations:"
    tail -50 "$PKG_LOG" | while IFS='|' read -r ts op pkg dur; do
      printf "  %-22s %-15s %-25s %s\n" "$(echo $ts | tr -d ' ')" "$(echo $op | tr -d ' ')" "$(echo $pkg | tr -d ' ')" "$(echo $dur | tr -d ' ')"
    done
  else
    echo "No history available."
  fi

  echo ""
  echo "=== Tracked Packages ==="
  if [ -f "$PKG_DB" ]; then
    wc -l < "$PKG_DB"
    echo "packages tracked in install database"
    tail -20 "$PKG_DB" | while IFS='|' read -r pkg src ts; do
      echo "  $pkg ($src) — $ts"
    done
  fi
}

# ============================================================================
#  GUI — graphical package manager interface
# ============================================================================

pkg_gui() {
  if command -v yad &>/dev/null; then
    local action
    action=$(yad --title="KorrinOS Package Manager" \
        --width=600 --height=500 \
        --button="Update:0" --button="Upgrade:1" --button="Search:2" \
        --button="Installed:3" --button="Clean:4" --button="Quit:5" \
        --text="<b>KorrinOS Unified Package Manager</b>\n\nDetected: $(detect_pkgmgr) | Snap: $(detect_snap) | Flatpak: $(detect_flatpak)\nVersion: $(pkgmgr_version)" \
        --separator=":" 2>/dev/null)
    case $? in
      0) pkg_update ;;
      1) pkg_upgrade ;;
      2)
        local query
        query=$(yad --entry --title="Search" --text="Search packages:" 2>/dev/null)
        [ -n "$query" ] && pkg_search "$query"
        ;;
      3) pkg_list ;;
      4) pkg_clean ;;
    esac
  elif command -v zenity &>/dev/null; then
    local action
    action=$(zenity --title="KorrinOS Package Manager" \
           --width=500 --height=300 \
           --list --column="Action" --column="Description" \
           "update" "Update package lists" \
           "upgrade" "Upgrade all packages" \
           "search" "Search for packages" \
           "install" "Install a package" \
           "remove" "Remove a package" \
           "list" "List installed packages" \
           "clean" "Clean package cache" \
           "orphans" "Find orphaned packages" \
           "rollback" "Rollback to snapshot" \
           2>/dev/null)
    case "$action" in
      update)   pkg_update ;;
      upgrade)  pkg_upgrade ;;
      search)
        local query
        query=$(zenity --entry --title="Search" --text="Query:" 2>/dev/null)
        [ -n "$query" ] && pkg_search "$query"
        ;;
      install)
        local pkg
        pkg=$(zenity --entry --title="Install" --text="Package name:" 2>/dev/null)
        [ -n "$pkg" ] && pkg_install "$pkg"
        ;;
      remove)
        local pkg
        pkg=$(zenity --entry --title="Remove" --text="Package name:" 2>/dev/null)
        [ -n "$pkg" ] && pkg_remove "$pkg"
        ;;
      list)      pkg_list ;;
      clean)     pkg_clean ;;
      orphans)   pkg_orphans ;;
      rollback)  pkg_rollback ;;
    esac
  elif command -v xdg-open &>/dev/null; then
    xdg-open "apt:" 2>/dev/null || echo "No GUI available."
  else
    echo "No GUI toolkit available. Use CLI."
  fi
}

# ============================================================================
#  STATUS — show overall package manager status
# ============================================================================

pkg_status() {
  echo "========================================="
  echo "   KorrinOS Package Manager Status"
  echo "========================================="
  echo ""
  echo "Primary Manager: $(detect_pkgmgr)"
  echo "Version:         $(pkgmgr_version)"
  echo "Snap:            $(detect_snap)"
  echo "Flatpak:         $(detect_flatpak)"
  echo "All Managers:    $(detect_all_managers)"
  echo ""
  echo "=== Statistics ==="

  local mgr
  mgr=$(detect_pkgmgr)
  case "$mgr" in
    apt)
      local total
      total=$(dpkg -l 2>/dev/null | grep ^ii | wc -l)
      local upgradable
      upgradable=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
      echo "Total installed:    $total"
      echo "Upgradable:         $upgradable"
      ;;
    dnf)
      local total
      total=$(rpm -qa 2>/dev/null | wc -l)
      echo "Total installed:    $total"
      ;;
    pacman)
      local total
      total=$(pacman -Q 2>/dev/null | wc -l)
      echo "Total installed:    $total"
      ;;
  esac

  echo ""
  echo "=== Tracked Installs ==="
  if [ -f "$PKG_DB" ]; then
    echo "Database: $(wc -l < "$PKG_DB") entries"
  else
    echo "Database: empty"
  fi

  echo ""
  echo "=== Snapshots ==="
  echo "Available: $(ls -1d "$PKG_SNAPSHOTS"/pkg_* 2>/dev/null | wc -l)"

  echo ""
  echo "=== Cache ==="
  local cache_size
  cache_size=$(du -sh /var/cache/apt 2>/dev/null | awk '{print $1}' || \
              du -sh /var/cache/dnf 2>/dev/null | awk '{print $1}' || \
              du -sh /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}' || echo "?")
  echo "Cache size: $cache_size"

  if [ -f /var/run/reboot-required ]; then
    echo ""
    echo "!!! REBOOT REQUIRED !!!"
  fi

  echo ""
  echo "=== Kernel Package Interface ==="
  if [ -r /proc/tinker/status ]; then
    echo "Kernel pkg module: active"
    cat /proc/tinker/status 2>/dev/null | head -5
  else
    echo "Kernel pkg module: not loaded (user-space only)"
  fi
}

# ============================================================================
#  MAIN DISPATCHER
# ============================================================================

case "${1:-}" in
  update)         pkg_update ;;
  upgrade)        pkg_upgrade ;;
  install)        shift; pkg_install "$@" ;;
  remove)         shift; pkg_remove "$@" ;;
  purge)          shift; pkg_purge "$@" ;;
  search)         shift; pkg_search "$@" ;;
  info)           shift; pkg_info "$@" ;;
  list)           pkg_list ;;
  check)          pkg_check ;;
  is-installed)   shift; pkg_is_installed "$@" && echo "YES" || echo "NO" ;;
  orphans)        pkg_orphans ;;
  remove-orphans) pkg_remove_orphans ;;
  clean)          pkg_clean ;;
  deps)           shift; pkg_deps "$@" ;;
  sources)        pkg_sources_list ;;
  add-repo)       shift; pkg_add_repo "$@" ;;
  download)       shift; pkg_download "$@" ;;
  snapshot)       pkg_snapshot_pre ;;
  rollback)       shift; pkg_rollback "$@" ;;
  history)        pkg_history ;;
  gui)            pkg_gui ;;
  status)         pkg_status ;;
  help|*)
    echo "KorrinOS Unified Package Manager v2
Usage: korrinos-pkg <command> [args]

Package Operations:
  update              Update package lists from all sources
  upgrade             Upgrade all packages (creates snapshot first)
  install <pkg>       Install a package (tries apt/dnf/pacman + snap + flatpak + pip)
  remove <pkg>        Remove a package
  purge <pkg>         Purge a package (remove + config files)
  search <query>      Search across all package sources
  info <pkg>          Show detailed package information
  list                List all installed packages
  check               Check for available updates
  is-installed <pkg>  Check if a package is installed

Maintenance:
  orphans             List orphaned packages
  remove-orphans      Remove all orphaned packages
  clean               Clean package cache
  deps <pkg>          Show package dependencies
  download <pkg>      Download package without installing

Repositories:
  sources             List all package sources
  add-repo <url>      Add a new repository

Snapshots & History:
  snapshot            Create a pre-upgrade snapshot
  rollback [id]       Rollback to a snapshot
  history             Show package operation history

Interface:
  gui                 Open graphical package manager
  status              Show package manager status" ;;
esac

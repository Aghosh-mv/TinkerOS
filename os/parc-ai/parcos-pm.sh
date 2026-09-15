#!/usr/bin/env bash
# korrinos-pm.sh — KorrinOS Package Manager (ParcPM)
# CLI + backend for app installation, updates, and removal

set -euo pipefail

PM_DIR="${HOME}/.config/korrinos/packages"
PM_CACHE="${HOME}/.cache/korrinos/packages"
PM_DB="$PM_DIR/installed.json"
PM_REPO="https://packages.korrinos.dev"

mkdir -p "$PM_DIR" "$PM_CACHE"

# Initialize package database
pm_init() {
  if [ ! -f "$PM_DB" ]; then
    echo '{"packages":[]}' > "$PM_DB"
    echo "Package database initialized"
  fi
}

# Search for packages
pm_search() {
  local query="$1"
  echo "Searching for '$query'..."
  
  # Search apt
  if command -v apt-cache &>/dev/null; then
    echo ""
    echo "=== APT Packages ==="
    apt-cache search "$query" 2>/dev/null | head -20
  fi
  
  # Search flatpak
  if command -v flatpak &>/dev/null; then
    echo ""
    echo "=== Flatpak Packages ==="
    flatpak search "$query" 2>/dev/null | head -20
  fi
  
  # Search snap
  if command -v snap &>/dev/null; then
    echo ""
    echo "=== Snap Packages ==="
    snap find "$query" 2>/dev/null | head -20
  fi
}

# Install a package
pm_install() {
  local pkg="$1"
  local method="${2:-auto}"
  
  echo "Installing $pkg..."
  
  # Auto-detect method
  if [ "$method" = "auto" ]; then
    if apt-cache show "$pkg" &>/dev/null 2>&1; then
      method="apt"
    elif flatpak info "$pkg" &>/dev/null 2>&1; then
      method="flatpak"
    elif snap info "$pkg" &>/dev/null 2>&1; then
      method="snap"
    else
      echo "Package not found in any repository"
      return 1
    fi
  fi
  
  case "$method" in
    apt)
      sudo apt install -y "$pkg"
      ;;
    flatpak)
      flatpak install -y "$pkg"
      ;;
    snap)
      sudo snap install "$pkg"
      ;;
    appimage)
      echo "Download AppImage from: https://appimage.github.io/apps/$pkg"
      return 1
      ;;
    *)
      echo "Unknown method: $method"
      return 1
      ;;
  esac
  
  # Record installation
  python3 -c "
import json, datetime
with open('$PM_DB') as f: db = json.load(f)
db['packages'].append({
    'name': '$pkg',
    'method': '$method',
    'installed': datetime.datetime.now().isoformat()
})
with open('$PM_DB', 'w') as f: json.dump(db, f, indent=2)
"
  echo "$pkg installed successfully"
}

# Remove a package
pm_remove() {
  local pkg="$1"
  local purge="${2:-false}"
  
  echo "Removing $pkg..."
  
  # Try each method
  if dpkg -l "$pkg" &>/dev/null 2>&1; then
    if [ "$purge" = "true" ]; then
      sudo apt purge -y "$pkg"
    else
      sudo apt remove -y "$pkg"
    fi
  elif flatpak list | grep -i "$pkg" &>/dev/null 2>&1; then
    flatpak uninstall -y "$pkg"
  elif snap list "$pkg" &>/dev/null 2>&1; then
    sudo snap remove "$pkg"
  else
    echo "Package not found"
    return 1
  fi
  
  # Remove from database
  python3 -c "
import json
with open('$PM_DB') as f: db = json.load(f)
db['packages'] = [p for p in db['packages'] if p['name'] != '$pkg']
with open('$PM_DB', 'w') as f: json.dump(db, f, indent=2)
"
  echo "$pkg removed"
}

# Update all packages
pm_update() {
  echo "Updating all packages..."
  
  if command -v apt &>/dev/null; then
    sudo apt update && sudo apt upgrade -y
  fi
  
  if command -v flatpak &>/dev/null; then
    flatpak update -y
  fi
  
  if command -v snap &>/dev/null; then
    sudo snap refresh
  fi
  
  echo "All packages updated"
}

# List installed packages
pm_list() {
  echo "=== Installed Packages ==="
  
  if command -v apt &>/dev/null; then
    echo ""
    echo "--- APT ---"
    dpkg -l | grep "^ii" | awk '{print $2}' | head -30
    echo "... ($(dpkg -l | grep -c '^ii') total)"
  fi
  
  if command -v flatpak &>/dev/null; then
    echo ""
    echo "--- Flatpak ---"
    flatpak list --app 2>/dev/null | awk -F'\t' '{print $1}' | head -20
  fi
  
  if command -v snap &>/dev/null; then
    echo ""
    echo "--- Snap ---"
    snap list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -20
  fi
  
  echo ""
  echo "=== KorrinOS Managed ==="
  python3 -c "
import json
with open('$PM_DB') as f: db = json.load(f)
for p in db['packages']:
    print(f\"  {p['name']} ({p['method']}, installed {p['installed'][:10]})\")
if not db['packages']:
    print('  (none)')
"
}

# Show package info
pm_info() {
  local pkg="$1"
  
  if command -v apt-cache &>/dev/null; then
    apt-cache show "$pkg" 2>/dev/null | head -20
  elif command -v flatpak &>/dev/null; then
    flatpak info "$pkg" 2>/dev/null
  fi
}

# Check for updates
pm_check_updates() {
  echo "Checking for updates..."
  
  if command -v apt &>/dev/null; then
    apt list --upgradable 2>/dev/null | head -20
  fi
  
  if command -v flatpak &>/dev/null; then
    flatpak update --appstream 2>/dev/null
    flatpak update --dry-run 2>/dev/null | head -20
  fi
}

# Install curated app collections
pm_collection() {
  local collection="$1"
  
  case "$collection" in
    base)
      echo "Installing KorrinOS base collection..."
      sudo apt install -y \
        firefox vlc gimp libreoffice \
        htop neofetch git curl wget \
        build-essential python3-pip
      ;;
    dev)
      echo "Installing developer collection..."
      sudo apt install -y \
        code git docker.io \
        python3-pip nodejs npm rustc golang \
        tmux vim neovim
      ;;
    media)
      echo "Installing media collection..."
      sudo apt install -y \
        vlc gimp inkscape obs-studio \
        audacity handbrake kdenlive
      ;;
    gaming)
      echo "Installing gaming collection..."
      sudo apt install -y \
        steam lutris wine64 \
        gamemode mangohud
      ;;
    *)
      echo "Unknown collection: $collection"
      echo "Available: base, dev, media, gaming"
      ;;
  esac
}

case "${1:-help}" in
  init)           pm_init ;;
  search)         shift; pm_search "$@" ;;
  install)        shift; pm_install "$@" ;;
  remove)         shift; pm_remove "$@" ;;
  update)         pm_update ;;
  list)           pm_list ;;
  info)           shift; pm_info "$@" ;;
  check)          pm_check_updates ;;
  collection)     shift; pm_collection "$@" ;;
  *)
    echo "KorrinOS Package Manager (ParcPM)"
    echo "Usage: korrinos-pm.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init                  Initialize package database"
    echo "  search <query>        Search for packages"
    echo "  install <pkg>         Install a package"
    echo "  remove <pkg>          Remove a package"
    echo "  update                Update all packages"
    echo "  list                  List installed packages"
    echo "  info <pkg>            Show package info"
    echo "  check                 Check for updates"
    echo "  collection <name>     Install app collection (base/dev/media/gaming)"
    ;;
esac

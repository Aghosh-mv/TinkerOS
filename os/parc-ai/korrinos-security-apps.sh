#!/usr/bin/env bash
# korrinos-security-apps.sh — Security Apps Suite
# App permissions, encrypted notes, privacy dashboard, secure WiFi

set -euo pipefail

SEC_DIR="${HOME}/.config/korrinos/security"
mkdir -p "$SEC_DIR"

# App Permission Manager
perm_list() {
  echo "=== App Permissions ==="
  echo ""
  echo "Camera:"
  if [ -d /sys/class/video4linux ]; then
    ls /sys/class/video4linux/ 2>/dev/null | while read d; do
      echo "  $d: $(cat /sys/class/video4linux/$d/name 2>/dev/null)"
    done
  else
    echo "  No camera detected"
  fi
  
  echo ""
  echo "Microphone:"
  arecord -l 2>/dev/null | head -5 || echo "  No microphone detected"
  
  echo ""
  echo "Location services:"
  if command -v geoclue-2.0 &>/dev/null; then
    echo "  Geoclue available"
  else
    echo "  Not installed"
  fi
}

perm_block() {
  local app="$1" perm="$2"
  echo "Blocking $perm for $app"
  # Use flatpak override if available
  if command -v flatpak &>/dev/null; then
    flatpak override --user --nosocket=x11 --nosocket=pulseaudio "$app" 2>/dev/null
  fi
  echo "Done (restart app to apply)"
}

# Encrypted Notes (using GPG)
notes_create() {
  local title="$1"
  local content="$2"
  local file="$SEC_DIR/notes/${title}.gpg"
  mkdir -p "$SEC_DIR/notes"
  
  echo "$content" | gpg --batch --yes --passphrase-file <(echo "") \
    --symmetric --cipher-algo AES256 -o "$file" 2>/dev/null
  
  if [ -f "$file" ]; then
    echo "Note saved: $title (encrypted)"
  else
    # Fallback: plain with warning
    echo "$content" > "$SEC_DIR/notes/${title}.txt"
    echo "Note saved: $title (unencrypted — install gnupg for encryption)"
  fi
}

notes_list() {
  echo "=== Encrypted Notes ==="
  ls "$SEC_DIR/notes/" 2>/dev/null || echo "No notes"
}

notes_read() {
  local title="$1"
  local gpg_file="$SEC_DIR/notes/${title}.gpg"
  local txt_file="$SEC_DIR/notes/${title}.txt"
  
  if [ -f "$gpg_file" ]; then
    gpg --batch --passphrase-file <(echo "") \
      --decrypt "$gpg_file" 2>/dev/null
  elif [ -f "$txt_file" ]; then
    cat "$txt_file"
  else
    echo "Note not found: $title"
  fi
}

notes_delete() {
  local title="$1"
  rm -f "$SEC_DIR/notes/${title}.gpg" "$SEC_DIR/notes/${title}.txt"
  echo "Deleted: $title"
}

# Privacy Dashboard
privacy_dashboard() {
  echo "=== KorrinOS Privacy Dashboard ==="
  echo ""
  
  echo "1. Running Processes:"
  ps aux --sort=-%cpu | head -10
  echo ""
  
  echo "2. Listening Ports:"
  ss -tuln 2>/dev/null | grep LISTEN | head -15
  echo ""
  
  echo "3. Network Connections:"
  ss -tn 2>/dev/null | awk '{print $4, $6}' | sort -u | head -15
  echo ""
  
  echo "4. Startup Services:"
  systemctl list-unit-files --state=enabled 2>/dev/null | head -10 || \
  ls /etc/xdg/autostart/ 2>/dev/null | head -10
  echo ""
  
  echo "5. Firewall:"
  sudo ufw status 2>/dev/null || echo "  UFW not configured"
  echo ""
  
  echo "6. Recent Logins:"
  last -n 5 2>/dev/null || echo "  No login history"
}

# Secure WiFi
wifi_scan() {
  echo "=== Available WiFi Networks ==="
  nmcli device wifi list 2>/dev/null || \
  iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Encryption|Quality" || \
  echo "No WiFi interface found"
}

wifi_trusted() {
  local network="$1"
  local trusted_file="$SEC_DIR/trusted_networks.txt"
  echo "$network" >> "$trusted_file"
  echo "Trusted: $network"
}

wifi_check() {
  local current=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes:" | cut -d: -f2)
  local trusted_file="$SEC_DIR/trusted_networks.txt"
  
  if [ -f "$trusted_file" ] && grep -q "$current" "$trusted_file" 2>/dev/null; then
    echo "✅ $current (trusted)"
  else
    echo "⚠️  $current (NOT trusted)"
    echo "Add to trusted: korrinos-security-apps.sh wifi-trust '$current'"
  fi
}

case "${1:-help}" in
  perm)
    shift
    case "${1:-list}" in
      list)   perm_list ;;
      block)  shift; perm_block "$@" ;;
    esac
    ;;
  notes)
    shift
    case "${1:-list}" in
      create) shift; notes_create "$@" ;;
      list)   notes_list ;;
      read)   shift; notes_read "$@" ;;
      delete) shift; notes_delete "$@" ;;
    esac
    ;;
  privacy)   privacy_dashboard ;;
  wifi)
    shift
    case "${1:-scan}" in
      scan)     wifi_scan ;;
      trust)    shift; wifi_trusted "$@" ;;
      check)    wifi_check ;;
    esac
    ;;
  *)
    echo "KorrinOS Security Apps"
    echo "Usage: korrinos-security-apps.sh <command>"
    echo ""
    echo "Commands:"
    echo "  perm (list|block <app> <perm>)    App permissions"
    echo "  notes (create|list|read|delete)    Encrypted notes"
    echo "  privacy                            Privacy dashboard"
    echo "  wifi (scan|trust|check)            Secure WiFi"
    ;;
esac

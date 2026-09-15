#!/usr/bin/env bash
# korrinos-security.sh — Security Center for KorrinOS
# Firewall, encryption, privacy audit, password manager

set -euo pipefail

SECURITY_DIR="${HOME}/.config/korrinos/security"
PRIVACY_DB="$SECURITY_DIR/privacy.json"

mkdir -p "$SECURITY_DIR"

# Firewall management
sec_firewall_status() {
  echo "=== Firewall Status ==="
  if command -v ufw &>/dev/null; then
    sudo ufw status verbose
  elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --state
    firewall-cmd --list-all
  else
    echo "No firewall found. Install ufw: sudo apt install ufw"
  fi
}

sec_firewall_enable() {
  echo "Enabling firewall..."
  if command -v ufw &>/dev/null; then
    sudo ufw enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    echo "Firewall enabled (UFW)"
  else
    echo "Install ufw: sudo apt install ufw"
  fi
}

sec_firewall_disable() {
  echo "Disabling firewall..."
  if command -v ufw &>/dev/null; then
    sudo ufw disable
    echo "Firewall disabled"
  fi
}

sec_firewall_allow() {
  local port="$1"
  local proto="${2:-tcp}"
  if command -v ufw &>/dev/null; then
    sudo ufw allow "$port/$proto"
    echo "Allowed port $port/$proto"
  fi
}

sec_firewall_deny() {
  local port="$1"
  local proto="${2:-tcp}"
  if command -v ufw &>/dev/null; then
    sudo ufw deny "$port/$proto"
    echo "Denied port $port/$proto"
  fi
}

# Disk encryption
sec_check_encryption() {
  echo "=== Disk Encryption Status ==="
  if command -v lsblk &>/dev/null; then
    lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT | grep -E "crypt|luks"
  fi
  
  if command -v veracrypt &>/dev/null; then
    echo ""
    echo "VeraCrypt available"
  fi
}

sec_encrypt_folder() {
  local folder="$1"
  local name=$(basename "$folder")
  
  echo "Encrypting folder: $folder"
  
  if command -v veracrypt &>/dev/null; then
    veracrypt --text --create "$folder" --size 1G --encryption AES-Twofish --hash SHA-512
    echo "Encrypted volume created"
  else
    # Use gocryptfs
    if command -v gocryptfs &>/dev/null; then
      mkdir -p "${folder}_encrypted"
      gocryptfs -init "${folder}_encrypted"
      gocryptfs "${folder}_encrypted" "$folder"
      echo "Encrypted with gocryptfs"
    else
      echo "Install veracrypt or gocryptfs for encryption"
    fi
  fi
}

# Privacy audit
sec_privacy_audit() {
  echo "=== Privacy Audit ==="
  echo ""
  
  echo "1. Running Processes:"
  ps aux | grep -v grep | awk '{print $11}' | sort -u | head -20
  
  echo ""
  echo "2. Listening Ports:"
  ss -tuln 2>/dev/null | grep LISTEN
  
  echo ""
  echo "3. Startup Services:"
  systemctl list-unit-files --state=enabled 2>/dev/null | head -20
  
  echo ""
  echo "4. Browser Extensions:"
  if [ -d "$HOME/.mozilla/firefox" ]; then
    find "$HOME/.mozilla/firefox" -name "extensions.json" 2>/dev/null | head -5
  fi
  
  echo ""
  echo "5. Network Connections:"
  ss -tuln 2>/dev/null | awk '{print $5}' | sort -u
  
  echo ""
  echo "6. Crontab Entries:"
  crontab -l 2>/dev/null || echo "No crontab"
}

# Password audit
sec_password_audit() {
  echo "=== Password Audit ==="
  echo ""
  
  echo "Checking for weak passwords..."
  
  # Check /etc/shadow for weak hashes (needs root)
  if [ -r /etc/shadow ]; then
    awk -F: '($2 != "!" && $2 != "*" && $2 != "!!") {print $1, length($2)}' /etc/shadow | \
      awk '$2 < 10 {print "Weak password:", $1}'
  else
    echo "Cannot read /etc/shadow (run as root)"
  fi
  
  echo ""
  echo "Checking SSH keys..."
  if [ -d "$HOME/.ssh" ]; then
    ls -la "$HOME/.ssh/"*.pub 2>/dev/null || echo "No SSH public keys"
  fi
  
  echo ""
  echo "Checking GPG keys..."
  gpg --list-keys 2>/dev/null | head -10 || echo "No GPG keys"
}

# Network security
sec_network_audit() {
  echo "=== Network Security Audit ==="
  echo ""
  
  echo "1. Open Ports:"
  ss -tuln 2>/dev/null | grep LISTEN
  
  echo ""
  echo "2. Established Connections:"
  ss -tn 2>/dev/null | grep ESTAB | head -20
  
  echo ""
  echo "3. DNS Configuration:"
  cat /etc/resolv.conf 2>/dev/null | grep nameserver
  
  echo ""
  echo "4. Hosts File:"
  cat /etc/hosts 2>/dev/null | grep -v "^#" | head -10
  
  echo ""
  echo "5. IP Tables:"
  sudo iptables -L -n 2>/dev/null | head -20 || echo "Cannot read iptables"
}

# Secure delete
sec_secure_delete() {
  local file="$1"
  
  if command -v shred &>/dev/null; then
    shred -vfz -n 3 "$file"
    echo "Securely deleted: $file"
  else
    rm -f "$file"
    echo "Shred not available, using rm"
  fi
}

# Generate strong password
sec_generate_password() {
  local length="${1:-16}"
  
  if command -v pwgen &>/dev/null; then
    pwgen -s "$length" 1
  else
    openssl rand -base64 "$length" | head -c "$length"
    echo ""
  fi
}

case "${1:-help}" in
  firewall)
    shift
    case "${1:-status}" in
      status) sec_firewall_status ;;
      enable) sec_firewall_enable ;;
      disable) sec_firewall_disable ;;
      allow)  shift; sec_firewall_allow "$@" ;;
      deny)   shift; sec_firewall_deny "$@" ;;
    esac
    ;;
  encryption)  shift; sec_check_encryption ;;
  encrypt)     shift; sec_encrypt_folder "$@" ;;
  audit)
    shift
    case "${1:-privacy}" in
      privacy)  sec_privacy_audit ;;
      password) sec_password_audit ;;
      network)  sec_network_audit ;;
    esac
    ;;
  delete)      shift; sec_secure_delete "$@" ;;
  password)    shift; sec_generate_password "$@" ;;
  *)
    echo "KorrinOS Security Center"
    echo "Usage: korrinos-security.sh <command>"
    echo ""
    echo "Commands:"
    echo "  firewall (status|enable|disable|allow|deny)"
    echo "  encryption           Check disk encryption"
    echo "  encrypt <folder>     Encrypt a folder"
    echo "  audit (privacy|password|network)"
    echo "  delete <file>        Secure delete file"
    echo "  password [length]    Generate strong password"
    ;;
esac

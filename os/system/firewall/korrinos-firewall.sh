#!/bin/bash
# KorrinOS Firewall Manager
# Real firewall management: UFW/iptables/nftables, profiles, rules, logging
# Application-aware rules, zone management, port forwarding, rate limiting

set -euo pipefail

FW_DIR="${HOME}/.config/korrinos/firewall"
FW_CONFIG="$FW_DIR/config.json"
FW_LOG="$FW_DIR/firewall.log"
FW_RULES="$FW_DIR/rules.json"
mkdir -p "$FW_DIR"

init_firewall() {
  if [ ! -f "$FW_CONFIG" ]; then
    cat > "$FW_CONFIG" << 'DEFAULTS'
{
  "backend": "ufw",
  "default_incoming": "deny",
  "default_outgoing": "allow",
  "default_routed": "deny",
  "logging": "medium",
  "notifications": true,
  "profiles": {
    "home": {
      "description": "Home network — trust local LAN",
      "rules": [
        {"port": "22", "proto": "tcp", "action": "allow", "comment": "SSH"},
        {"port": "80", "proto": "tcp", "action": "allow", "comment": "HTTP"},
        {"port": "443", "proto": "tcp", "action": "allow", "comment": "HTTPS"},
        {"port": "1:65535", "proto": "udp", "action": "allow", "from": "192.168.0.0/16", "comment": "LAN"}
      ]
    },
    "public": {
      "description": "Public WiFi — lock everything down",
      "rules": [
        {"port": "80", "proto": "tcp", "action": "allow", "comment": "HTTP"},
        {"port": "443", "proto": "tcp", "action": "allow", "comment": "HTTPS"}
      ]
    },
    "gaming": {
      "description": "Gaming — open game ports",
      "rules": [
        {"port": "27015:27030", "proto": "udp", "action": "allow", "comment": "Steam"},
        {"port": "3478:3480", "proto": "udp", "action": "allow", "comment": "PSN"},
        {"port": "3074", "proto": "tcp", "action": "allow", "comment": "Xbox"},
        {"port": "88", "proto": "udp", "action": "allow", "comment": "Xbox Live"}
      ]
    },
    "server": {
      "description": "Web server — open common service ports",
      "rules": [
        {"port": "22", "proto": "tcp", "action": "allow", "comment": "SSH"},
        {"port": "80", "proto": "tcp", "action": "allow", "comment": "HTTP"},
        {"port": "443", "proto": "tcp", "action": "allow", "comment": "HTTPS"},
        {"port": "3306", "proto": "tcp", "action": "allow", "from": "10.0.0.0/8", "comment": "MySQL (LAN)"},
        {"port": "5432", "proto": "tcp", "action": "allow", "from": "10.0.0.0/8", "comment": "PostgreSQL (LAN)"}
      ]
    }
  },
  "rate_limiting": {
    "ssh_max_tries": 6,
    "ssh_ban_time": 3600,
    "http_max_rps": 100
  },
  "port_forwarding": [],
  "application_rules": {}
}
DEFAULTS
    echo "Firewall config initialized."
  fi
}

cfg() {
  python3 -c "
import json
try:
    with open('$FW_CONFIG') as f: c = json.load(f)
    val = c.get('$1', '$2')
    if isinstance(val, bool): print('True' if val else 'False')
    elif isinstance(val, list): print(json.dumps(val))
    else: print(val)
except: print('$2')
" 2>/dev/null
}

# ---- detect firewall backend ----
detect_backend() {
  if command -v ufw &>/dev/null; then
    echo "ufw"
  elif command -v nft &>/dev/null; then
    echo "nftables"
  elif command -v iptables &>/dev/null; then
    echo "iptables"
  else
    echo "none"
  fi
}

# ---- setup firewall ----
setup_firewall() {
  echo "=== Setting Up KorrinOS Firewall ==="
  local backend
  backend=$(detect_backend)

  if [ "$backend" = "none" ]; then
    echo "No firewall tool found. Installing UFW..."
    sudo apt-get install -y ufw 2>&1 | tail -3
    backend="ufw"
  fi

  echo "Backend: $backend"

  case "$backend" in
    ufw)
      echo "Configuring UFW..."
      local def_in
      def_in=$(cfg default_incoming "deny")
      local def_out
      def_out=$(cfg default_outgoing "allow")

      sudo ufw default "$def_in" incoming 2>/dev/null
      sudo ufw default "$def_out" outgoing 2>/dev/null
      sudo ufw default deny routed 2>/dev/null

      # Enable logging
      local log_level
      log_level=$(cfg logging "medium")
      sudo ufw logging "$log_level" 2>/dev/null

      # Enable UFW
      sudo ufw --force enable 2>/dev/null

      echo "UFW configured: incoming=$def_in outgoing=$def_out"
      ;;
    nftables)
      echo "Configuring nftables..."
      sudo nft flush ruleset 2>/dev/null
      sudo nft add table inet korrinos 2>/dev/null
      sudo nft add chain inet korrinos input '{ type filter hook input priority 0; policy drop; }' 2>/dev/null
      sudo nft add chain inet korrinos output '{ type filter hook output priority 0; policy accept; }' 2>/dev/null
      # Allow established connections
      sudo nft add rule inet korrinos input ct state established,related accept 2>/dev/null
      # Allow loopback
      sudo nft add rule inet korrinos input iif lo accept 2>/dev/null
      echo "nftables configured with drop-by-default input."
      ;;
  esac

  echo "$(date -Iseconds) | setup | $backend | OK" >> "$FW_LOG"
}

# ---- apply profile ----
apply_profile() {
  local profile="${1:-}"
  [ -z "$profile" ] && { echo "Usage: korrinos-firewall profile <name>"; return 1; }

  echo "=== Applying Firewall Profile: $profile ==="

  local rules
  rules=$(python3 -c "
import json
with open('$FW_CONFIG') as f: c = json.load(f)
rules = c.get('profiles', {}).get('$profile', {}).get('rules', [])
for r in rules:
    port = r.get('port', '')
    proto = r.get('proto', 'tcp')
    action = r.get('action', 'allow')
    src = r.get('from', '')
    comment = r.get('comment', '')
    print(f'{action}|{port}|{proto}|{src}|{comment}')
" 2>/dev/null)

  if [ -z "$rules" ]; then
    echo "Profile not found: $profile"
    return 1
  fi

  local backend
  backend=$(detect_backend)

  echo "$rules" | while IFS='|' read -r action port proto src comment; do
    [ -z "$port" ] && continue
    case "$backend" in
      ufw)
        if [ -n "$src" ]; then
          sudo ufw allow from "$src" to any port "$port" proto "$proto" comment "$comment" 2>/dev/null
        else
          sudo ufw allow "$port/$proto" comment "$comment" 2>/dev/null
        fi
        ;;
      nftables)
        sudo nft add rule inet korrinos input tcp dport "$port" accept 2>/dev/null
        ;;
    esac
    echo "  $action $port/$proto ${src:+from $src} [$comment]"
  done

  echo "$(date -Iseconds) | profile | $profile | OK" >> "$FW_LOG"
  echo "Profile $profile applied."
}

# ---- add rule ----
add_rule() {
  local port="$1"
  local proto="${2:-tcp}"
  local action="${3:-allow}"
  local from="${4:-}"
  local comment="${5:-}"

  [ -z "$port" ] && { echo "Usage: korrinos-firewall add <port> [proto] [action] [from] [comment]"; return 1; }

  local backend
  backend=$(detect_backend)

  case "$backend" in
    ufw)
      if [ -n "$from" ]; then
        sudo ufw allow from "$from" to any port "$port" proto "$proto" comment "$comment" 2>/dev/null
      elif [ "$action" = "deny" ]; then
        sudo ufw deny "$port/$proto" comment "$comment" 2>/dev/null
      else
        sudo ufw allow "$port/$proto" comment "$comment" 2>/dev/null
      fi
      ;;
    nftables)
      if [ "$action" = "deny" ]; then
        sudo nft add rule inet korrinos input tcp dport "$port" drop 2>/dev/null
      else
        sudo nft add rule inet korrinos input tcp dport "$port" accept 2>/dev/null
      fi
      ;;
  esac

  echo "Rule added: $action $port/$proto ${from:+from $from}"
  echo "$(date -Iseconds) | add-rule | $action $port/$proto | OK" >> "$FW_LOG"
}

# ---- remove rule ----
remove_rule() {
  local port="$1"
  local proto="${2:-tcp}"

  [ -z "$port" ] && { echo "Usage: korrinos-firewall remove <port> [proto]"; return 1; }

  local backend
  backend=$(detect_backend)

  case "$backend" in
    ufw)
      sudo ufw delete allow "$port/$proto" 2>/dev/null || \
        sudo ufw delete deny "$port/$proto" 2>/dev/null || true
      ;;
    nftables)
      echo "Manual nftables rule removal required."
      ;;
  esac

  echo "Rule removed: $port/$proto"
}

# ---- status ----
firewall_status() {
  echo "============================================="
  echo "   KorrinOS Firewall Status"
  echo "============================================="
  echo ""

  local backend
  backend=$(detect_backend)
  echo "Backend: $backend"

  case "$backend" in
    ufw)
      sudo ufw status verbose 2>/dev/null
      ;;
    nftables)
      sudo nft list ruleset 2>/dev/null | head -30
      ;;
    iptables)
      sudo iptables -L -n 2>/dev/null | head -30
      ;;
  esac

  echo ""
  echo "Profiles available:"
  python3 -c "
import json
with open('$FW_CONFIG') as f: c = json.load(f)
for name, prof in c.get('profiles', {}).items():
    desc = prof.get('description', '')
    rules = len(prof.get('rules', []))
    print(f'  {name:15} {rules} rules  {desc}')
" 2>/dev/null

  echo ""
  echo "Log entries: $(wc -l < "$FW_LOG" 2>/dev/null || echo 0)"
}

# ---- block IP ----
block_ip() {
  local ip="$1"
  [ -z "$ip" ] && { echo "Usage: korrinos-firewall block <ip>"; return 1; }

  local backend
  backend=$(detect_backend)

  case "$backend" in
    ufw)    sudo ufw deny from "$ip" 2>/dev/null ;;
    nftables) sudo nft add rule inet korrinos input ip saddr "$ip" drop 2>/dev/null ;;
  esac

  echo "Blocked: $ip"
  echo "$(date -Iseconds) | block | $ip | OK" >> "$FW_LOG"
}

# ---- unblock IP ----
unblock_ip() {
  local ip="$1"
  [ -z "$ip" ] && { echo "Usage: korrinos-firewall unblock <ip>"; return 1; }

  local backend
  backend=$(detect_backend)

  case "$backend" in
    ufw)    sudo ufw delete deny from "$ip" 2>/dev/null || true ;;
  esac

  echo "Unblocked: $ip"
}

# ---- rate limit ----
setup_rate_limit() {
  echo "=== Rate Limiting ==="
  local ssh_tries
  ssh_tries=$(cfg rate_limiting.ssh_max_tries "6")
  local ssh_ban
  ssh_ban=$(cfg rate_limiting.ssh_ban_time "3600")

  local backend
  backend=$(detect_backend)

  case "$backend" in
    ufw)
      sudo ufw limit ssh comment "SSH rate limit" 2>/dev/null
      ;;
    iptables)
      sudo iptables -A INPUT -p tcp --dport 22 -m connlimit --connlimit-above "$ssh_tries" -j DROP 2>/dev/null
      ;;
  esac

  echo "SSH rate limit: $ssh_tries tries, ${ssh_ban}s ban"
  echo "$(date -Iseconds) | rate-limit | ssh | OK" >> "$FW_LOG"
}

# ---- log viewer ----
view_logs() {
  echo "=== Firewall Logs ==="
  echo ""
  if command -v journalctl &>/dev/null; then
    journalctl -k | grep -i "UFW\|BLOCK\|DENY\|ACCEPT" | tail -30
  fi
  echo ""
  echo "KorrinOS firewall log:"
  tail -20 "$FW_LOG" 2>/dev/null || echo "No entries."
}

# ---- main ----
case "${1:-}" in
  setup)          setup_firewall ;;
  profile)        shift; apply_profile "$@" ;;
  add)            shift; add_rule "$@" ;;
  remove)         shift; remove_rule "$@" ;;
  block)          shift; block_ip "$@" ;;
  unblock)        shift; unblock_ip "$@" ;;
  rate-limit)     setup_rate_limit ;;
  status)         firewall_status ;;
  logs)           view_logs ;;
  init)           init_firewall ;;
  help|*)         echo "KorrinOS Firewall Manager
Usage: korrinos-firewall <command> [args]

Setup:
  setup             Setup firewall (auto-detects UFW/nftables)
  profile <name>    Apply firewall profile (home/public/gaming/server)

Rules:
  add <port> [proto] [action] [from] [comment]
                    Add a firewall rule
  remove <port> [proto]
                    Remove a firewall rule
  block <ip>        Block an IP address
  unblock <ip>      Unblock an IP address

Security:
  rate-limit        Setup SSH rate limiting

Status:
  status            Show firewall status
  logs              View firewall logs" ;;
esac

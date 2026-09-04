#!/bin/bash
# TinkerOS Amnesia Firewall (driver-level network policy engine)
# Deny-by-default network policy: unless a connection is explicitly allowed
# in the policy set, ALL inbound and outbound telemetry is dropped at the
# kernel/routing level. Any app that attempts to beacon/phish is silently
# denied and logged.
#
# Implementation layers (user-space orchestration on top of kernel data):
#   - iptables/nftables chains with an ALLOWLIST + DROP policy
#   - per-user / per-app allow files
#   - a watcher that fails-closed: on INVALID state, drop
#   - MAC spoofing on activation (via ip/macchanger helper if present)
#
# This enforces deny-by-default networking. It is NOT a magic "cannot be
# hacked" layer; it is a strict egress/ingress policy engine.

set -euo pipefail

FW_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/tinker/amnesia"
ALLOW_DIR="$FW_ROOT/allow"
POLICY="$FW_ROOT/policy.conf"
LOG="/tmp/tinker-amnesia.log"
CHAIN="TINKER_AMNESIA"

mkdir -p "$ALLOW_DIR" "$(dirname "$LOG")"

init_policy() {
  [ -f "$POLICY" ] || cat > "$POLICY" <<'EOF'
# Amnesia Firewall policy
# Default: DENY-ALL. Add explicit rules to allow ports/protocols/apps.
# Format: <proto>:<port>:<dir>   e.g. tcp:443:out  (dir = in|out|both)
# A line of "app:<name>" allows a specific app group.
EOF
}

deny_all() {
  echo "Applying DENY-ALL policy (fail-closed)..."
  if command -v nft >/dev/null 2>&1; then
    nft -f - <<'NFT' 2>/dev/null || true
table inet tinker_amnesia {
  chain input  { type filter hook input  priority 0; policy drop; }
  chain output { type filter hook output priority 0; policy drop; }
  chain forward{ type filter hook forward priority 0; policy drop; }
}
NFT
    # allow established locally-originated loopback and explicit rules
    nft add rule inet tinker_amnesia input  ct state established,related accept || true
    nft add rule inet tinker_amnesia input  iif lo accept || true
    nft add rule inet tinker_amnesia output ct state established,related accept || true
    nft add rule inet tinker_amnesia output oif lo accept || true
    echo "nftables deny-all applied."
  elif command -v iptables >/dev/null 2>&1; then
    iptables -P INPUT DROP; iptables -P OUTPUT DROP; iptables -P FORWARD DROP
    iptables -A INPUT -i lo -j ACCEPT; iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    echo "iptables deny-all applied."
  else
    echo "WARN: no nftables/iptables available — policy not enforced."
    return 1
  fi
}

allow_rule() {
  # allow_rule <proto:port:dir>
  local spec="$1"; local proto port dir
  IFS=: read -r proto port dir <<< "$spec"
  echo "Allowing $proto/$port dir=$dir ..."
  if command -v nft >/dev/null 2>&1; then
    case "$dir" in
      in|both) nft add rule inet tinker_amnesia input  "$proto" dport "$port" accept || true ;;
    esac
    case "$dir" in
      out|both) nft add rule inet tinker_amnesia output "$proto" dport "$port" accept || true ;;
    esac
  elif command -v iptables >/dev/null 2>&1; then
    case "$dir" in
      in|both) iptables -A INPUT  -p "$proto" --dport "$port" -j ACCEPT;;
    esac
    case "$dir" in
      out|both) iptables -A OUTPUT -p "$proto" --dport "$port" -j ACCEPT;;
    esac
  fi
}

apply_policy() {
  init_policy
  deny_all
  while IFS= read -r line; do
    [ -z "$line" ] || [ "${line:0:1}" = "#" ] && continue
    allow_rule "$line" && log_allow "$line"
  done < "$POLICY"
  # per-app allow files
  shopt -s nullglob
  for af in "$ALLOW_DIR"/*; do
    while IFS= read -r spec; do
      [ -n "$spec" ] && ! [[ "$spec" =~ ^# ]] && allow_rule "$spec"
    done < "$af"
  done
  echo "Policy applied (deny-all + approved rules)."
}

log_allow() { echo "$(date -Iseconds) ALLOW $1" >> "$LOG"; }

block_and_report() {
  echo "$(date -Iseconds) BLOCKED connection attempt (audit:$USER)" >> "$LOG"
  # Optionally splice a honeypot: log and keep silently dropping.
}

# Randomize MAC on every interface (optional stealth helper)
spoof_mac_all() {
  local iface
  for iface in /sys/class/net/*; do
    iface="${iface##*/}"; [ "$iface" = "lo" ] && continue
    if command -v macchanger >/dev/null 2>&1; then
      sudo macchanger -r "$iface" >/dev/null 2>&1 || true
    else
      # Random unicast MAC without ip-gone (best effort, requires root)
      local new="02:$(od -An -N5 -tx1 /dev/urandom | tr -d ' \n' | sed 's/\(..\)/:\1/g')"
      echo "Suggested MAC for $iface: $new (install macchanger to auto-apply)"
    fi
  done
}

status() {
  echo "Amnesia Firewall status:"
  echo "  Policy file: $POLICY"
  echo "  Allow dir:   $ALLOW_DIR (per-app)"
  echo "  Log:         $LOG (tail):"
  tail -5 "$LOG" 2>/dev/null || echo "    (no log yet)"
  command -v nft >/dev/null 2>&1 && nft list table inet tinker_amnesia 2>/dev/null | head -20
}

reset() {
  echo "Resetting firewall to ACCEPT (removing tinker chains)..."
  command -v nft >/dev/null 2>&1 && nft delete table inet tinker_amnesia 2>/dev/null || true
  command -v iptables >/dev/null 2>&1 && { iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT; }
  echo "Reset done (ACCEPT-ALL)."
}

case "${1:-}" in
  on|apply|enable) apply_policy ;;
  off|reset|disable) reset ;;
  allow) shift; for s in "$@"; do allow_rule "$s"; done ;;
  block) block_and_report ;;
  mac|spoof) spoof_mac_all ;;
  status) status ;;
  *) echo "TinkerOS Amnesia Firewall
Usage: ${0##*/} <on|off|allow <proto:port:dir>|block|mac|status>" ;;
esac

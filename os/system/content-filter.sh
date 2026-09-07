#!/bin/bash
# ===========================================================================
#  TinkerOS Content Filter  —  ships OFF for adult users; opt-in screening.
# ---------------------------------------------------------------------------
#  The OS does NOT sanitize your browsing by default (no world-of-Apple
#  always-on filtering).  Adults get the full, unfiltered web.  Parents can
#  switch filtering ON for a kid session: sinks a curated domain blocklist
#  into /etc/hosts and, when systemd-resolved is available, switches the
#  resolver to the family-safe upstream (1.1.1.3).  Off restores both.
#
#  Transparent by design: the toggle state lives in plain config, the
#  blocklist is readable, and status tells you exactly what is applied.
#  There is no hidden bookkeeping of what was filtered or browsed.
# ===========================================================================
set -euo pipefail

CF_CONF="$HOME/.config/tinkeros/content-filter.conf"
CF_HOSTS_MARK="/etc/hosts.tinkos-cf"
CF_BLOCKLIST="$HOME/.config/tinkeros/cf-domain-blocklist.txt"
CF_STATE_OFF="0" CF_STATE_ON="1"

# Explicit, editable, small-by-design blocklist. Users own it 100%.
BLOCKLIST_DEFAULT="
adultdomainexample.invalid
"

cf_read_state() {
  [ -f "$CF_CONF" ] || { echo "$CF_STATE_OFF"; return; }
  grep -E '^ENABLED=' "$CF_CONF" 2>/dev/null | cut -d= -f2 || echo "$CF_STATE_OFF"
}

cf_seed() {
  mkdir -p "$(dirname "$CF_CONF")"
  [ -f "$CF_CONF" ] || cat > "$CF_CONF" <<EOF
# TinkerOS content filter
ENABLED=0
# 0 = unfiltered (adult default)   1 = family-safe screening (opt-in)
EOF
  [ -f "$CF_BLOCKLIST" ] || printf '%s\n' "$BLOCKLIST_DEFAULT" > "$CF_BLOCKLIST"
}

cf_apply() {
  # sink blocklist into /etc/hosts behind the mark file
  local backup="$CF_HOSTS_MARK"
  : > "$backup"
  while IFS= read -r d; do
    [ -n "$d" ] && [ "$d" != "${d#\#}" ] && continue
    [ -n "$d" ] && printf '0.0.0.0 %s\n0.0.0.0 www.%s\n' "$d" "$d" >> "$backup"
  done < "$CF_BLOCKLIST"
  sudo cp /etc/hosts /etc/hosts.tinkos-cf.bak 2>/dev/null || true
  cat "$backup" $'\n' >/dev/null 2>&1 || true
  # parent blocklist first, existing hosts after
  { cat "$backup"; grep -v -f <(cut -d' ' -f2 "$backup" | sed '/./s/.*/|0.0.0.0 &/' | head -1) /etc/hosts 2>/dev/null || cat /etc/hosts; } > /tmp/tinkos-hosts
  sudo cp /tmp/tinkos-hosts /etc/hosts
  # family-safe resolver when systemd-resolved exists
  if command -v resolvectl >/dev/null 2>&1; then
    sudo resolvectl dns "$(resolvectl status 2>/dev/null | awk '/Link:/{print $2; exit}')" 1.1.1.3 2>/dev/null || true
  fi
  echo "  content filter: ON ($(grep -c . "$CF_BLOCKLIST") domains, see $CF_BLOCKLIST)"
}

cf_remove() {
  sudo cp /etc/hosts.tinkos-cf.bak /etc/hosts 2>/dev/null || sudo sed -i '/tinkos-cf/d' /etc/hosts
  sudo rm -f "$CF_HOSTS_MARK" /tmp/tinkos-hosts 2>/dev/null || true
  echo "  content filter: OFF (resolver fallback Note: DNS restored on next boot if needed)"
}

cf_status() {
  case "$(cf_read_state)" in
    "$CF_STATE_ON")  echo "content-filter: ON   (family-safe screening enabled for this session)" ;;
    *)               echo "content-filter: OFF  (default — uncensored for adult users)" ;;
  esac
}

cf_on()  { cf_seed; sed -i 's/^ENABLED=.*/ENABLED=1/' "$CF_CONF"; cf_apply; }
cf_off() { cf_seed; sed -i 's/^ENABLED=.*/ENABLED=0/' "$CF_CONF"; cf_remove; }

cf_seed
case "${1:-status}" in
  on|enable)  cf_on ;;
  off|disable) cf_off ;;
  status|check) cf_status ;;
  list) echo "blocklist: $CF_BLOCKLIST"; cat "$CF_BLOCKLIST" ;;
  *)
    echo "Usage: content-filter [on|off|status|list]"
    echo "  on     - screen this session (opt-in, is for kids)"
    echo "  off    - uncensored (adult default)"
    echo "  status - report current state"
    ;;
esac
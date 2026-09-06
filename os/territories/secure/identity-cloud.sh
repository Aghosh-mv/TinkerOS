#!/bin/bash
# TinkerOS Identity Cloud — locate/remote-identify your devices (SECURE territory)
# "Find My Device" + remote identity for TinkerOS gear. Local-first: your
# keychain + an optional self-hosted endpoint you control. No third-party
# data broker. On lock/theft, can report location to YOUR owned endpoint.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

ENDPOINT="${TINKER_CFG}/identity-endpoint.conf"
IDFILE="${TINKER_STATE}/device-id"
mkdir -p "$(dirname "$IDFILE")"

device_id() {  # stable per-machine id (anonymous)
  if [ -f "$IDFILE" ]; then cat "$IDFILE"; return; fi
  # derive from machine-id + mac, one-way hashed
  local raw
  raw=$( { cat /etc/machine-id 2>/dev/null; ip link 2>/dev/null | sed -n 's/.*ether //p' | head -1; } | tr -d '\n' )
  echo -n "$raw" | sha256sum | awk '{print $1}' | tee "$IDFILE"
}

set_endpoint() {  # set_endpoint <url> [token]
  local url="$1" tok="${2:-}"
  echo "endpoint=$url" > "$ENDPOINT"
  [ -n "$tok" ] && echo "token=$tok" >> "$ENDPOINT"
  echo "Identity endpoint set to $url (you own/control it)."
}

locate() {  # attempt to report current network location to your endpoint
  echo "[identity] Reporting network location to your owned endpoint..."
  local id; id="$(device_id)"
  local info
  info="host=$(hostname) ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo offline) uid=$id ts=$(date +%s)"
  if [ -f "$ENDPOINT" ]; then
    local url; url=$(grep '^endpoint=' "$ENDPOINT" | cut -d= -f2)
    curl -s --max-time 5 -X POST "$url" -d "device=$id&info=$info" >/dev/null 2>&1 \
      && echo "  reported to $url" || echo "  endpoint unreachable (offline/not yet set)."
  else
    echo "  no endpoint configured (set_endpoint <url>)."
    echo "  local view: $info"
  fi
}

status() {
  echo "Identity status:"
  echo "  Device id: $(device_id)"
  echo "  Endpoint: $(grep '^endpoint=' "$ENDPOINT" 2>/dev/null | cut -d= -f2 || echo 'not set')"
}

usage() { echo "TinkerOS Identity Cloud
Usage: ${0##*/} <id|set-endpoint <url> [token]|locate|status>
Find-your-device / identify via YOUR OWN endpoint. No third-party broker."; }

case "${1:-}" in
  id|device) device_id ;;
  set-endpoint|endpoint) shift; set_endpoint "$@" ;;
  locate|find) locate ;;
  status) status ;;
  *) usage ;;
esac

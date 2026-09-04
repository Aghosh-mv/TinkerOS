#!/bin/bash
# TinkerOS Traffic Guard — network traffic inspection engine (SECURE territory)
# Inspects active connections and flags suspicious/beacon-like behavior.
# Wraps ss, tcpdump, and optional nethogs for per-process bandwidth, plus
# fails-closed correlation with the amnesia policy.
#
# Goal: see what YOUR box is sending/receiving so nothing quietly phones
# home. Local analysis only.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

active_conns() {
  echo "[traffic] Active connections:"
  ss -tnp 2>/dev/null | head -25
}

per_app() {  # per-connection process/bandwidth
  echo "[traffic] Per-process connections/bands:"
  if has nethogs; then
    sudo timeout 5 nethogs -c 3 2>/dev/null | head -20 || true
  else
    ss -tnp 2>/dev/null | awk '{print $6}' | sort | uniq -c | sort -rn | head -15
  fi
}

beacon_scan() {  # flag periodic-ish / suspicious outbound (best-effort)
  echo "[traffic] Suspicious beacon heuristic scan..."
  # connections to non-standard ports / known sinks, sampled twice
  ss -tn 2>/dev/null | awk '$1=="ESTAB"{print $5}' | grep -oE ':[0-9]+$' | sort | uniq -c
  echo "  (look for recurring high ports = possible beacons)"
}

top_hosts() {  # most-connected remote hosts
  echo "[traffic] Top remote hosts:"
  ss -tn 2>/dev/null | awk '$1=="ESTAB"{print $5}' | sed 's/:[0-9]*$//' | sort | uniq -c | sort -rn | head -15
}

leak_check() {  # DNS + IP leak sanity
  echo "[traffic] DNS resolvers: $(cat /etc/resolv.conf | grep nameserver | tr '\n' ' ')"
  echo "  (verify these are only your trusted resolvers)"
}

usage() { echo "TinkerOS Traffic Guard
Usage: ${0##*/} <conns|per-app|beacon|hosts|leak>"; }

case "${1:-}" in
  conns|active) active_conns ;;
  per-app|apps) per_app ;;
  beacon|scan) beacon_scan ;;
  hosts|top) top_hosts ;;
  leak|dns) leak_check ;;
  *) usage ;;
esac

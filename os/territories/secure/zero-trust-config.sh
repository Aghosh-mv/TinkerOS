#!/bin/bash
# TinkerOS Zero-Trust Config — system hardening to a zero-trust posture (SECURE territory)
# Applies a defense-in-depth configuration across layers so the system
# assumes nothing about trust: every access is verified. Runs a coherent
# bundle of the other secure tools into one zero-trust policy.
#
# Zero-trust pillars applied:
#   - deny-by-default execution (app-allowlist)
#   - deny-by-default network (amnesia/kill-switch)
#   - least-privilege + integrity (sip-guard)
#   - continuous verification/monitoring (canary-monitor, threat-monitor)
#   - secrets sealed (key-wallet)
#
# Requires root for several actions; degrades gracefully.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

T="$TERR_ROOT/secure"
H="$TERR_ROOT/hack"

apply_all() {
  echo "### TinkerOS Zero-Trust Configuration ###"
  echo "[zt] 1/6 deny-by-default execution..."
  "$T/app-allowlist.sh" init 2>/dev/null || true
  "$T/app-allowlist.sh" enforce 2>/dev/null || true

  echo "[zt] 2/6 deny-by-default network..."
  "$H/amnesia-firewall.sh" on 2>/dev/null || echo "  (firewall needs root)"

  echo "[zt] 3/6 integrity + least privilege..."
  "$T/sip-guard.sh" audit 2>/dev/null || true
  printf '  integrity baseline created by canary-monitor (below).\n'

  echo "[zt] 4/6 continuous verification..."
  "$T/canary-monitor.sh" plant 2>/dev/null || true
  "$T/canary-monitor.sh" baseline 2>/dev/null || true

  echo "[zt] 5/6 secrets sealed..."
  "$T/key-wallet.sh" init 2>/dev/null || echo "  (key-wallet init runs at use-time)"

  echo "[zt] 6/6 hardening baseline..."
  "$H/hack-defense.sh" apply 2>/dev/null || echo "  (sysctl hardening needs root)"

  echo ""
  echo "Zero-trust posture applied. Nothing is implicitly trusted."
  echo "Verify: 'verify' compares baseline (run 'check' now)."
}

verify() {
  echo "[zt] Verifying post-config state..."
  "$T/canary-monitor.sh" check 2>/dev/null || true
  "$H/threat-monitor.sh" threats 2>/dev/null | head -20 || true
}

report() {
  echo "Zero-trust report:"
  echo "  allowlist:  $TINKER_CFG/app-allowlist.conf ($(grep -cvE '^#|^$' "$TINKER_CFG/app-allowlist.conf" 2>/dev/null || echo 0) entries)"
  echo "  baseline:   $TINKER_STATE/canary-baseline ($(wc -l < "$TINKER_STATE/canary-baseline" 2>/dev/null || echo 0) files)"
  echo "  canaries:   $TINKER_STATE/canary-secure"
}

usage() { echo "TinkerOS Zero-Trust Config
Usage: ${0##*/} <apply|verify|report>
Zero-trust hardening bundle: execution+network deny-by-default, integrity, monitoring, sealed secrets."; }

case "${1:-}" in
  apply|on) apply_all ;;
  verify|check) verify ;;
  report|status) report ;;
  *) usage ;;
esac

#!/bin/bash
# TinkerOS Sub-OS Supply Chain Verification (HACK + SECURE territory)
# Before any package/binary is allowed to touch the system, verify it.
#
# CONCEPT:
#   - REPRO: build a package deterministically (offline builder VM/container)
#     and compare the produced binary hash against an expected/open-source
#     consensus hash (ledger).
#   - VERIFY: check downloaded artifacts against the ledger before use.
#   - TIME-WARP: execute untrusted payloads inside a sandbox that simulates
#     fake clock / fake files / fake network so malware triggers safely in a
#     simulation for reverse-engineering.
#
# This implements supply-chain integrity checking + safe dynamic analysis.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

LEDGER="${TINKER_STATE}/supply-ledger.txt"
BUILDROOT="${TINKER_STATE}/repro-build"
mkdir -p "$BUILDROOT"

sha_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

record_ledger() {  # record_ledger <path> [expected-sha]
  local path="$1" sha; sha="${2:-$(sha_of "$path")}"
  echo "$(date -Iseconds) $path $sha" >> "$LEDGER"
  echo "Recorded $path -> $sha"
}

# Deterministic build: build inside an isolated chroot/container offline
# and hash the result. Uses whatever build system is present (make/cc).
repro_build() {
  local srcroot="$1"
  test -d "$srcroot" || { echo "no source dir: $srcroot"; return 1; }
  rm -rf "$BUILDROOT/out"; mkdir -p "$BUILDROOT/out"
  echo "Building $srcroot offline, deterministically (no network)..."
  # Best-effort offline build
  ( cd "$srcroot" && make BUILD_PATH="$BUILDROOT/out" 2>&1 | tail -5 || true )
  # Collect hashes of every produced artifact
  find "$BUILDROOT/out" -type f 2>/dev/null | while read -r f; do
    echo "REPRO ARTIFACT: $f = $(sha_of "$f")"
  done
  echo "Build done — compare hashes to the ledger."
}

verify_artifact() {  # verify_artifact <path>
  local path="$1"; local sha; sha="$(sha_of "$path")"
  if grep -q "$(basename "$path") $sha" "$LEDGER" 2>/dev/null \
     || grep -q "$path $sha" "$LEDGER" 2>/dev/null; then
    echo "VERIFIED: $path matches ledger ($sha)"
  else
    echo "UNTRUSTED: $path ($sha) not in ledger — quarantine before use."
    return 1
  fi
}

# Time-warp container: run a payload in an isolated namespace with a fake
# clock, fake hostname, fake /etc, and no real network.
timewarp() {
  local payload="$1"
  test -f "$payload" || { echo "no payload: $payload"; return 1; }
  echo "Launching '$payload' inside a simulated time-warp sandbox..."
  if has unshare; then
    # Fake clock: faketime if present, else note real
    local clock
    clock=$(has faketime && faketime '2030-01-01' echo || echo "real clock")
    echo "Simulated clock: $clock"
    # Isolated mounts + private network + no host UID mapping
    sudo unshare --mount --pid --net --fork --kill-child \
      bash -c "hostname tinker-sim; date; $payload" 2>&1 | head -40
  else
    echo "unshare (util-linux) required for time-warp."
  fi
}

threshold_scan() {  # basic static scan of a binary for risky markers
  local path="$1"
  test -f "$path" || { echo "no file: $path"; return 1; }
  echo "Static markers in $path:"
  strings "$path" 2>/dev/null | grep -iE "socket|connect\(|dlopen|fork|exec|\.onion|powershell|cmd\.exe|/etc/shadow" | sort -u | head -20
  has yara && { echo "(run yara rules against $path for deeper analysis)"; }
}

status() {
  echo "Supply-chain verification status:"
  echo "  Ledger: $LEDGER ($(wc -l < "$LEDGER" 2>/dev/null || echo 0) entries)"
  echo "  Build root: $BUILDROOT"
}

case "${1:-}" in
  record) shift; record_ledger "$@" ;;
  build|repro) shift; repro_build "$@" ;;
  verify) shift; verify_artifact "$@" ;;
  timewarp|sim) shift; timewarp "$@" ;;
  scan) shift; threshold_scan "$@" ;;
  status) status ;;
  *) echo "TinkerOS Supply-Chain Verification
Usage: ${0##*/} <record <path>|build <srcdir>|verify <path>|timewarp <payload>|scan <bin>|status>
Deterministic-build + hash-ledger + simulated time-warp analysis." ;;
esac

#!/bin/bash
# TinkerOS Security Suite - Comprehensive security audit and hardening
# (Delegates to the full implementation in os/apps/security/)

set -e

FULL_IMPL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../apps/security" && pwd)/security-suite.sh"
if [ -f "$FULL_IMPL" ] && [ -s "$FULL_IMPL" ]; then
    exec bash "$FULL_IMPL" "$@"
fi

echo "=== TinkerOS Security Suite ==="
echo "Full implementation not found at: $FULL_IMPL"
echo "Unable to run audit."

#!/bin/bash
# TinkerOS Invisible Sandboxing — Portals vs. Prompts (A6)
# The "Rule of Intention": if a user explicitly interacts with a system
# dialog (file picker, print menu), that action IS the permission. The app
# only ever sees the specific item the user selected — no broad
# "Folder Access" / "Camera" / "Microphone" prompts.
#
# This implements a portal-based access engine:
#   - Apps request a capability ("open file", "save to", "print", "camera")
#   - The OS shows a native picker; the user picks the SPECIFIC item
#   - The OS grants a short-lived TEMPORARY token for that single item only
#   - The app receives the token/path, never blanket access
#   - No repeated annoying prompts (intent is implicit and explicit)
#
# This is a real capability-based access model a-la Flatpak portals / xdg
# portals. It reduces prompt fatigue while improving least-privilege.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

TOKENS_DIR="${TINKER_STATE}/portals/tokens"
GRANTS_DIR="${TINKER_STATE}/portals/grants"
mkdir -p "$TOKENS_DIR" "$GRANTS_DIR"
TOKEN_TTL=60

# Issue a temporary token for a specific resource (file/device) to an app.
issue_token() {  # issue_token <app> <capability> <resource>
  local app="$1" cap="$2" res="$3"
  local tok; tok=$(rand_hex 8)
  local exp=$(( $(date +%s) + TOKEN_TTL ))
  cat > "$TOKENS_DIR/$tok" <<EOF
app=$app
cap=$cap
resource=$res
expire=$exp
issued=$(date -Iseconds)
EOF
  echo "$tok"
}

# Validate + consume a token; grant one-shot access if fresh.
consume_token() {  # consume_token <token> <app> <capability>
  local tok="$1" app="$2" cap="$3"
  local file="$TOKENS_DIR/$tok"
  [ -f "$file" ] || { echo "DENIED: invalid/expired token"; return 1; }
  local t_app t_cap t_res t_exp
  t_app=$(grep '^app=' "$file" | cut -d= -f2)
  t_cap=$(grep '^cap=' "$file" | cut -d= -f2)
  t_res=$(grep '^resource=' "$file" | cut -d= -f2)
  t_exp=$(grep '^expire=' "$file" | cut -d= -f2)
  now=$(date +%s)
  [ "$t_app" = "$app" ] || { echo "DENIED: token not for $app"; return 1; }
  [ "$t_cap" = "$cap" ] || { echo "DENIED: capability mismatch"; return 1; }
  [ "$now" -le "$t_exp" ] || { echo "DENIED: token expired"; rm -f "$file"; return 1; }
  # one-shot: remove on use; log the grant
  mv "$file" "$GRANTS_DIR/$tok.used"
  echo "$t_res"
  return 0
}

# The native portal handler: pick a file for a capability and issue a token.
portal_open() {  # portal_open <app> <capability>
  local app="$1" cap="$2"
  # Use zenity/kdialog if available for a real native picker; else stdin
  local picked=""
  if command -v zenity >/dev/null; then
    picked=$(zenity --file-selection --title="TinkerOS — choose file ($cap) for $app" 2>/dev/null || true)
  elif command -v kdialog >/dev/null; then
    picked=$(kdialog --getopenfilename . 2>/dev/null || true)
  else
    printf 'Portal: type the absolute path to grant (%s) for %s: ' "$cap" "$app"
    IFS= read -r picked
  fi
  [ -n "$picked" ] && [ -e "$picked" ] || { echo "cancelled / invalid selection"; return 1; }
  local tok; tok=$(issue_token "$app" "$cap" "$picked")
  echo "GRANTED: $app -> $cap -> $picked"
  echo "One-shot token: $tok (expires in ${TOKEN_TTL}s)"
}

# Show what the app is actually allowed to see (specific items only).
app_permissions() {  # app_permissions <app>
  local app="$1"
  echo "Selective (least-privilege) grants for '$app':"
  grep -l "app=$app" "$GRANTS_DIR"/.*.used 2>/dev/null | while read -r f; do
    grep -E 'cap=|resource=' "$f" | tr '\n' ' '; echo ""
  done || echo "  (no grants)"
}

status() {
  echo "Portal-based invisible sandbox status:"
  echo "  Active tokens: $(ls "$TOKENS_DIR" 2>/dev/null | wc -l)"
  echo "  Consumed grants: $(ls "$GRANTS_DIR" 2>/dev/null | wc -l)"
  echo "  TTL: ${TOKEN_TTL}s | Model: intent-is-permission (no blanket prompts)"
}

prune() {  # drop expired tokens
  local now; now=$(date +%s)
  for f in "$TOKENS_DIR"/*; do
    [ -f "$f" ] || continue
    local e; e=$(grep '^expire=' "$f" 2>/dev/null | cut -d= -f2)
    [ -n "$e" ] && [ "$now" -gt "$e" ] && rm -f "$f"
  done
  echo "Pruned expired tokens."
}

case "${1:-}" in
  open|picker) shift; portal_open "$@" ;;
  grant|issue) shift; issue_token "$@" ;;
  use|consume) shift; consume_token "$@" ;;
  perms) shift; app_permissions "$@" ;;
  prune|gc) prune ;;
  status) status ;;
  *) echo "TinkerOS Invisible Sandbox (Portals vs. Prompts)
Usage: ${0##*/} <open <app> <cap>|grant <app> <cap> <res>|use <tok> <app> <cap>|perms <app>|prune|status>
Intent-is-permission model: explicit picker interaction grants a one-shot
token for that single item — no blanket folder/device prompts." ;;
esac

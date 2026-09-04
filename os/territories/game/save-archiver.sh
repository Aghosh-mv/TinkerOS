#!/bin/bash
# TinkerOS Save Archiver / sync (GAME territory)
# Backs up, version-stamps, and (optionally, mirror-only) syncs game saves.
# Privacy-first: local archive, optional user-chosen cloud mirror.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

ARCHIVE="${TINKER_STATE}/save-archive"
mkdir -p "$ARCHIVE"

locate_saves() {
  echo "[saves] Typical save locations (if present):"
  for d in "$HOME/.local/share" "$HOME/.config"; do
    [ -d "$d" ] && find "$d" -maxdepth 2 -type d \( -name "saves" -o -name "savegames" -o -iname "*Save*" \) 2>/dev/null | head
  done
}

archive() {  # archive <game> <saves-dir>
  local game="$1" srcdir="$2"
  test -d "$srcdir" || { echo "no save dir: $srcdir"; return 1; }
  local ts; ts=$(date +%Y%m%d-%H%M%S)
  mkdir -p "$ARCHIVE/$game"
  tar -czf "$ARCHIVE/$game/$ts.tar.gz" -C "$srcdir" . 2>/dev/null
  echo "Archived $game saves -> $ARCHIVE/$game/$ts.tar.gz ($(du -h "$ARCHIVE/$game/$ts.tar.gz" | cut -f1))"
}

list_versions() {  # list_versions <game>
  local game="$1"
  echo "Saved versions for $game:"
  ls -1 "$ARCHIVE/$game" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
}

restore() {  # restore <game> <version-file>
  local game="$1" ver="$2" dest="${3:-$HOME}"
  local vf="$ARCHIVE/$game/$ver"
  test -f "$vf" || { echo "no version: $vf"; return 1; }
  mkdir -p "$dest/$game"
  tar -xzf "$vf" -C "$dest/$game" 2>/dev/null
  echo "Restored $game -> $dest/$game"
}

sync_mirror() {  # optional mirror to a user-specified rsync target
  local target="$1"
  [ -n "$target" ] || { echo "usage: sync <rsync-target>"; return 1; }
  echo "[saves] Mirroring archive to $target..."
  rsync -a --delete "$ARCHIVE/" "$target/" 2>&1 | tail -3
}

usage() { echo "TinkerOS Save Archiver
Usage: ${0##*/} <find|archive <game> <dir>|versions <game>|restore <game> <file> [dest]|sync <target>>"; }

case "${1:-}" in
  find|locate) locate_saves ;;
  archive|save) shift; archive "$@" ;;
  versions|list) shift; list_versions "$@" ;;
  restore) shift; restore "$@" ;;
  sync) shift; sync_mirror "$@" ;;
  *) usage ;;
esac

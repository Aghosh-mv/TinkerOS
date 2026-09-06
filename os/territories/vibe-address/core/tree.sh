#!/bin/bash
# ===========================================================================
#  core/tree.sh — DEEP CATEGORY TRIE
# ---------------------------------------------------------------------------
#  The category index is an actual on-disk trie (directories + files), which
#  gives us, for free: O(length) prefix lookups, structural preimages for
#  ancestor/descendant reasoning, and unlimited depth. Every event is
#  INSERTED into every node on its category path (redundant indexing) so
#  that recall from ANY ancestor is O(subtree list), not O(history).
#
#  Each leaf dir holds:
#     index       -> timestamp+path line list (the event references)
#     _meta       -> node statistics (count, last_seen, child refcount)
#     _syn        -> synonym/alias file (candidates arriving here)
#  Sub-nodes are sub-directories, recursively, without limit.
# ===========================================================================
set -euo pipefail

# ---- normalize a category path --------------------------------------------
ve_tree_normalize() {
  # split on : and / and . and space, collapse empties, lowercase
  local raw="$1"
  local parts=() seg
  for seg in $(tr ':/:.' '   ' <<<"${raw,,}"); do
    [ -n "$seg" ] && parts+=("$seg")
  done
  printf '%s' "${parts[@]:-misc}" | tr ' ' ':'
}

# ---- resolve a normalized path into an absolute trie dir -------------------
ve_tree_dir() {  # normpath -> abs dir (mkdir -p)
  local norm="$1" cur="$VIBE_TREE"
  IFS=':' read -ra segs <<<"$norm"
  local s
  for s in "${segs[@]:-misc}"; do
    cur="$cur/$s"
  done
  mkdir -p "$cur"
  echo "$cur"
}

# ---- insert an event path reference at a node + all ancestors -------------
ve_tree_insert() {
  # usage: path_ref  normpath  epoch
  local ref="$1" norm="$2" epoch="$3"
  local cur="$VIBE_TREE"
  IFS=':' read -ra segs <<<"$norm"
  local pathref="$ref"
  local level=0
  printf '%s %s %s\n' "$epoch" "$pathref" "$norm" >> "$cur/index" 2>/dev/null || true
  for s in "${segs[@]:-misc}"; do
    cur="$cur/$s"
    mkdir -p "$cur"
    level=$((level+1))
    printf '%s %s\n' "$epoch" "$pathref" >> "$cur/index"
    # node meta
    if [ -f "$cur/_meta" ]; then
      local c; c=$(awk -F'=' '/^count=/{print $2}' "$cur/_meta")
      sed -i "s/^count=.*/count=$((c+1))/;s/^last_seen=.*/last_seen=$epoch/" "$cur/_meta" 2>/dev/null || \
        cp /dev/null "$cur/_meta.swap"
    else
      printf 'count=1\nlast_seen=%s\nlevel=%s\n' "$epoch" "$level" > "$cur/_meta"
    fi
  done
}

# ---- collect all descendant events from a node (redundant index pays off) --
ve_tree_descend() {  # absdir -> sorted unique event refs
  local root="$1"
  [ -d "$root" ] || return 0
  # merge index files of root and all descendants; dedup by ref, keep latest
  local tmp; tmp=$(mktemp); local d
  while IFS= read -r -d '' d; do
    [ -f "$d/index" ] && cat "$d/index"
  done < <(find "$root" -type d -print0 2>/dev/null)
  sort -k1 -rn -u "$tmp" 2>/dev/null
  rm -f "$tmp"
}

# ---- find the subtree for a prefix path -------------------------------------
ve_tree_locate() {  # normpath -> abs dir (no mkdir); empty if absent
  local norm="$1" cur="$VIBE_TREE"
  IFS=':' read -ra segs <<<"$norm"
  local s
  for s in "${segs[@]:-misc}"; do
    [ -d "$cur/$s" ] || { echo ""; return 1; }
    cur="$cur/$s"
  done
  echo "$cur"
}

# ---- dynamic deepening (grow new sub branches from event) ------------------
ve_tree_deepen() {  # ref normpath epoch extra_segs...
  # sometimes the recorded catpath is too shallow; deepen it with derived segs
  local ref="$1" norm="$2" epoch="$3"; shift 3
  local derived_path="$norm"
  for extra in "$@"; do [ -n "$extra" ] && derived_path="$derived_path:$extra"; done
  ve_tree_insert "$ref" "$derived_path" "$epoch"
}

# ---- dump the trie (human readable) -----------------------------------------
ve_tree_dump() {
  local maxdepth="${1:-0}" cur dep
  ( cd "$VIBE_TREE" 2>/dev/null || { echo "(empty tree)"; return; }
    find . -mindepth 1 -type d -print | sort | while IFS= read -r d; do
      dep=$(printf '%s' "$d" | tr '/' ' ' | tr -cd ' ' | wc -c | tr -d ' ')
      printf '  %*s%s\n' $((dep*2)) "" "${d#./}"
    done )
}

# ---- depth of a given path --------------------------------------------------
ve_tree_depth() { IFS=':' read -ra s <<<"$1"; echo "${#s[@]}"; }

# ---- parent of a normpath ---------------------------------------------------
ve_tree_parent() { local n="$1"; local p="${n%:*}"; [ "$p" != "$n" ] && echo "$p" || echo ""; }

# ---- synonyms: attach acceptable alternate category names -------------------
ve_tree_add_syn() {  # normpath  -> alias
  local norm="$1" alias="$2"
  local d; d=$(ve_tree_dir "$norm")
  printf '%s\n' "$alias" >> "$d/_syn" 2>/dev/null || true
}

# resolve an alias to a real node (reverse of _syn)
ve_tree_resolve_alias() {
  local alias="$1" hit
  hit=$(find "$VIBE_TREE" -name _syn -exec grep -lE "(^|[^a-z])${alias}([^a-z]|$)" {} \; 2>/dev/null | head -1)
  if [ -n "$hit" ]; then
    local dir; dir=$(dirname "$hit")
    echo "${dir#$VIBE_TREE/}" | tr '/' ':'
  else
    echo ""
  fi
}

ve_tree=""
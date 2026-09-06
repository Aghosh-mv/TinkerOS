#!/bin/bash
# ===========================================================================
#  core/index.sh — INVERTED INDEX / FINGERPRINT TABLE / TIME BUCKETS
# ---------------------------------------------------------------------------
#  Three core data structures, all persisted on disk for resilience:
#
#  1) INVERTED INDEX  ($VIBE_INDEX/inv/)
#       file per token; each line = "fp epoch path"
#       built during ingest; queried by intersection during retrieval
#
#  2) TIME BUCKETS    ($VIBE_INDEX/time/)
#       sub-dirs by bucket level; each bucket holds event-fp lines
#       used for temporal pruning BEFORE inverted-index intersection
#
#  3) FINGERPRINT TABLE ($VIBE_INDEX/fp/)
#       one file per unique fingerprint; content = envelope line
#       the lookup table for full-envelope reconstruction
#
#  All lookups are: filesystem find + sort + intersect (pure algorithmic,
#  zero model).  Performance: for a million events the inverted index
#  makes any single-token query O(n/m) where m = matching-events, and
#  the temporal bucket O(events-in-time-window).  Intersection is
#  O(min(set_a,set_b)).
# ===========================================================================
set -euo pipefail

# ---- inverted index insert --------------------------------------------------
ve_index_insert() {
  # fp, nametokens, srctokens, typetokens, timetokens, catpath, epoch, path
  local fp="$1" nametokens="$2" srctokens="$3" typetokens="$4" \
        timetokens="$5" catpath="$6" epoch="$7" path="$8"
  local inv="$VIBE_INDEX/inv"
  mkdir -p "$inv"

  local alltok
  alltok=$(printf '%s\n%s\n%s\n%s\n%s\n' \
    "$nametokens" "$srctokens" "$typetokens" "$timetokens" \
    "$catpath" "$path" | tr ':/' '  ' | tr '[:upper:]' '[:lower:]' | \
    tr -cd 'a-z0-9 \n' | tr ' ' '\n' | sed '/^$/d' | sort -u)

  local tok
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    # sanitize filename (replace / _ with z__, etc.)
    local tfile="${tok//\//z__}"
    tfile="${tfile//_/z_}"
    printf '%s %s %s\n' "$fp" "$epoch" "$path" >> "$inv/$tfile"
  done <<< "$alltok"
}

# ---- temporal bucket insert -------------------------------------------------
ve_index_time_insert() {  # fp, epoch, bucket_m, bucket_h, ..., bucket_y
  local fp="$1" epoch="$2"
  shift 2
  local levels=(m h d w mo q y) bucket i
  local tb="$VIBE_INDEX/time"
  mkdir -p "$tb"
  for i in "${!levels[@]}"; do
    bucket="${levels[$i]}"
    local bval="${1}"
    shift
    [ -z "$bval" ] && continue
    local bdir="$tb/$bucket"
    mkdir -p "$bdir"
    printf '%s %s\n' "$epoch" "$fp" >> "$bdir/$bval"
  done
}

# ---- fingerprint table insert -----------------------------------------------
ve_index_fp_insert() {
  # canonical envelope: epoch|vtype|source|path|fp|catpath|meta
  local fp="$1" path="$2" vtype="$3" source="$4" catpath="$5" epoch="$6" meta="$7"
  local fpd="$VIBE_INDEX/fp"
  mkdir -p "$fpd"
  printf '%s|%s|%s|%s|%s|%s|%s\n' \
    "$epoch" "$vtype" "$source" "$path" "$fp" "$catpath" "$meta" >> "$fpd/$fp"
}

# ---- lookup: all fps matching a token (inverted index) -----------------------
ve_index_tokens_to_fps() {
  local tokens="$1" inv="$VIBE_INDEX/inv"
  [ -d "$inv" ] || { echo ""; return; }
  # split on whitespace so multi-word phrases are separated per-token
  local tfile tok tmp
  tmp=$(mktemp)
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    local t="${tok//\//z__}"; t="${t//_/z_}"
    if [ -f "$inv/$t" ]; then
      cut -d' ' -f1 "$inv/$t" | sort -u
    fi
  done <<< "$(echo "$tokens" | tr ' ' '\n' | sed '/^$/d')" > "$tmp" || true
  # intersect: fps appearing most often across tokens (fuzzy consensus)
  sort "$tmp" | uniq -c | sort -rn | head -50 | \
    awk -v n=$(echo "$tokens" | wc -w) \
        '{if (n==0 || $1 >= 1) print $2}'   # at least 1 token agreement
  rm -f "$tmp"
}

# ---- lookup: fps in a time bucket -------------------------------------------
ve_index_time_to_fps() {  # level, bucket_key -> fps
  local level="$1" key="$2" tb="$VIBE_INDEX/time/$level"
  [ -f "$tb/$key" ] && cut -d' ' -f2 "$tb/$key" || true
}

# ---- reconstruct full envelope from fingerprint -----------------------------
ve_index_fp_to_envelope() {
  local fp="$1"
  local fpd="$VIBE_INDEX/fp/$fp"
  [ -f "$fpd" ] && tail -1 "$fpd"
}

# ---- stats ------------------------------------------------------------------
ve_index_stats() {
  local inv="$VIBE_INDEX/inv" fpd="$VIBE_INDEX/fp" tb="$VIBE_INDEX/time"
  echo "Vibe Addressing Index Statistics"
  echo "  tokens (inverted index) : $(find "$inv" -type f 2>/dev/null | wc -l)"
  echo "  unique fp entries       : $(find "$fpd" -type f 2>/dev/null | wc -l)"
  echo "  time bucket files       : $(find "$tb" -type f 2>/dev/null | wc -l)"
  echo "  total log bytes         : $(du -sb "$VIBE_EVENTS" 2>/dev/null | cut -f1 || echo 0)"
}

# ---- compact: merge daily logs, rebuild inverted index ----------------------
ve_index_rebuild() {
  echo "Rebuilding inverted index (full scan)..."
  local inv="$VIBE_INDEX/inv" fpd="$VIBE_INDEX/fp"
  rm -rf "$inv" "$VIBE_INDEX/time"; mkdir -p "$inv"
  local line
  while IFS= read -r line; do
    local fp=$(echo "$line" | cut -d'|' -f5)
    [ -n "$fp" ] || continue
    echo "$line" > "$fpd/$fp"
    # re-insert tokens
    local catpath=$(echo "$line" | cut -d'|' -f6)
    local path=$(echo "$line" | cut -d'|' -f4)
    local epoch=$(echo "$line" | cut -d'|' -f1)
    local vtype=$(echo "$line" | cut -d'|' -f2)
    local meta=$(echo "$line" | cut -d'|' -f7)
    local nametokens; nametokens=$(ve_ingest_name_tokens "$path" "$meta")
    local alltok; alltok=$(printf '%s\n%s\n' "$nametokens" "$catpath" | tr ':/' ' ' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9 \n' | tr ' ' '\n' | sed '/^$/d' | sort -u)
    local tok
    while IFS= read -r tok; do
      [ -z "$tok" ] && continue
      local t="${tok//\//z__}"; t="${t//_/z_}"
      printf '%s %s %s\n' "$fp" "$epoch" "$path" >> "$inv/$t"
    done <<< "$alltok"
  done < <(cat "$VIBE_EVENTS"/*.log 2>/dev/null)
  echo "Rebuild complete."
}

ve_index=""
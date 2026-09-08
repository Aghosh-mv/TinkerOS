#!/bin/bash
# ===========================================================================
#  core/sarray.sh — SUFFIX ARRAY INFIX SEARCH ENGINE
# ---------------------------------------------------------------------------
#  Character-level suffix array over a bounded RECENT window of the daisy-
#  chained token corpus (VE_SARRAY_MAXCHARS keeps the sort tractable):
#      state/sarray/stream  : "\x01"-separated records, window bytes
#      state/sarray/owners  : "fp start end" window-relative byte ranges
#      state/sarray/sa      : suffix start offsets, sorted by suffix order
#  An infix query is answered by TWO bounded BINARY SEARCHES over the SA
#  (lower bound PATTERN.., upper bound PATTERN\x7f..), then each matched
#  offset maps to an owner fp by another binary* walk over "owners".
#  Rebuild is lazy (owner list drifted -> rebuild).
# ===========================================================================
set -euo pipefail

VE_SARRAY_MAXCHARS="${VE_SARRAY_MAXCHARS:-140000}"
VE_SARRAY_DIR="$VIBE_STATE/sarray"

ve_sarray_dir() { mkdir -p "$VE_SARRAY_DIR"; echo "$VE_SARRAY_DIR"; }

ve_sarray_fps() { ls "$VIBE_INDEX/fp" 2>/dev/null || true; }

# ---- rebuild stream + owners + suffix array for the recent window ----------
ve_sarray_rebuild() {
  local dir; dir=$(ve_sarray_dir)
  : > "$dir/stream"; : > "$dir/owners"
  local io=0 fp
  fplist=$(ve_sarray_fps)
  local total; total=$(echo "$fplist" | sed '/^$/d' | wc -l | tr -d ' ')
  local keep=$total; [ "$keep" -gt 300 ] && keep=300
  for fp in $(echo "$fplist" | tail -"$keep"); do
    [ -z "$fp" ] && continue
    local env; env=$(ve_index_fp_to_envelope "$fp" 2>/dev/null)
    [ -z "$env" ] && continue
    local path vtype cat
    path=$(echo "$env" | cut -d'|' -f4)
    vtype=$(echo "$env" | cut -d'|' -f2)
    cat=$(echo "$env" | cut -d'|' -f6)
    local toks; toks=$(ve_ingest_name_tokens "$path" "$vtype" 2>/dev/null | tr '\n' ' ')
    local rec; rec="$cat $toks"
    local len=${#rec}
    { [ "$io" -gt 0 ] && printf '\x01'; printf '%s' "$rec"; } >> "$dir/stream"
    printf '%s|%d|%d\n' "$fp" "$io" "$((io + len))" >> "$dir/owners"
    io=$((io + len + 1))
    [ "$io" -gt "$VE_SARRAY_MAXCHARS" ] && break
  done
  local L; L=$(wc -c < "$dir/stream" | tr -d ' ')
  if [ "$L" -le 0 ]; then
    : > "$dir/sa"; printf '0' > "$dir/len"; return 0
  fi
  # suffix array: print every char offset + suffix, sort by suffix, keep offsets
  # (stream is a single line, so awk's $0 holds the whole daisy chain)
  awk '{
    if (length($0) > 0) {
      for (i = 1; i <= length($0); i++) printf "%d\t%s\n", (i-1), substr($0, i)
    }
  }' "$dir/stream" | LC_ALL=C sort -k2 | cut -f1 > "$dir/sa"
  printf '%s' "$L" > "$dir/len"
}

# ---- lazy refresh: owner-set drift triggers rebuild -------------------------
ve_sarray_ensure() {
  local dir; dir=$(ve_sarray_dir)
  local have=0
  [ -f "$dir/owners" ] && have=$(wc -l < "$dir/owners" | tr -d ' ')
  local want
  want=$(ve_sarray_fps | sed '/^$/d' | wc -l | tr -d ' ')
  { [ -f "$dir/sa" ] && [ -s "$dir/sa" ] ; } || { ve_sarray_rebuild; return; }
  if [ "$have" -ne "$want" ]; then
    ve_sarray_rebuild
  fi
  return 0
}

# ---- owner fp for a window offset (binary walk over owners) -----------------
ve_sarray_owner() {
  local off="$1" file="$2"
  local fp=""
  local line a rest b c
  while IFS= read -r line; do
    a="${line%%|*}"          # fingerprint
    rest="${line#*|}"        # "start|end"
    b="${rest%%|*}"          # start
    c="${rest#*|}"           # end
    if [ "$off" -ge "$b" ] && [ "$off" -lt "$c" ]; then fp="$a"; break; fi
  done < "$file"
  echo "$fp"
}

# ---- infix search over the SA ===============================================
ve_sarray_search() {
  local pattern="${1:-}" limit="${2:-20}"
  [ -z "$pattern" ] && return 0
  ve_sarray_ensure
  local dir; dir=$(ve_sarray_dir)
  [ -s "$dir/sa" ] || return 0
  local stream="$dir/stream"
  local plen=${#pattern}
  local lo=0 hi; hi=$(wc -l < "$dir/sa" | tr -d ' ')
  [ "$hi" -eq 0 ] && return 0
  local mid cmpres cmp out
  # LOWER BOUND: leftmost suffix whose prefix >= pattern
  while [ "$lo" -lt "$hi" ]; do
    mid=$(( (lo + hi) / 2 ))
    out=$(sed -n "$((mid + 1))p" "$dir/sa")
    cmp=$(ve_sarray_cmp "$stream" "$out" "$pattern")
    if [ "$cmp" -lt 0 ]; then lo=$((mid + 1)); else hi=$mid; fi
  done
  local lb=$lo
  # UPPER BOUND: leftmost suffix lexicographically > pattern (prefix compare)
  hi=$(wc -l < "$dir/sa" | tr -d ' ')
  lo=$lb
  while [ "$lo" -lt "$hi" ]; do
    mid=$(( (lo + hi) / 2 ))
    out=$(sed -n "$((mid + 1))p" "$dir/sa")
    cmp=$(ve_sarray_cmp "$stream" "$out" "$pattern")
    if [ "$cmp" -le 0 ]; then lo=$((mid + 1)); else hi=$mid; fi
  done
  local ub=$lo

  sed -n "$((lb + 1)),${ub}p" "$dir/sa" | head -"$limit" \
    | while IFS= read -r off; do
        [ -z "$off" ] && continue
        ve_sarray_owner "$off" "$dir/owners"
      done | sort -u
}

# ---- compare pattern against suffix starting at offset (=0, <0, >0) ---------
ve_sarray_cmp() {
  local stream="$1" off="$2" pat="$3"
  # extract min(pattern length, remaining) bytes
  local cut; cut=$(dd if="$stream" bs=1 skip="$off" count="${#pat}" status=none 2>/dev/null)
  if [ "${#cut}" -lt "${#pat}" ]; then
    echo -1; return  # suffix shorter than pattern and equal on all bytes
  fi
  awk -v got="$cut" -v pat="$pat" 'BEGIN{
    if (got == pat) print 0
    else if (got < pat) print -1
    else print 1
  }'
}

ve_sarray=""
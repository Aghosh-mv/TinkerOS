#!/bin/bash
# ===========================================================================
#  core/cms.sh — COUNT-MIN SKETCH frequency oracle
# ---------------------------------------------------------------------------
#  A probabilistic frequency counter: estimate how often a token (or any
#  string) appears in the event stream without keeping a per-token counter
#  table.  d pairwise-independent hash rows x w counters each; updates and
#  queries are O(d).  Overestimates (never underestimates): estimate =
#  min over all d rows of that row's counter, so collisions only push the
#  value up.  The Searchie engine uses this as a cheap "is this token hot?"
#  oracle for ranking boosts and quantity normalization.
# ===========================================================================
set -euo pipefail

VIBE_CMS_D="${VIBE_CMS_D:-4}"     # rows (hash functions)
VIBE_CMS_W="${VIBE_CMS_W:-8192}"  # counters per row
VIBE_CMS_DELTA="${VIBE_CMS_DELTA:-0.01}"   # error bound
VIBE_CMS_EPS="${VIBE_CMS_EPS:-0.0001}"     # failure prob

ve_cms_dir() { echo "${VIBE_STATE:-$VIBE_HOME/state}/cms"; }
ve_cms_counters() { echo "$(ve_cms_dir)/counters"; }
ve_cms_seeds() { echo "$(ve_cms_dir)/seeds"; }

# ---- deterministic seed ring (W*D ascii chars) ------------------------------
ve_cms_seed_ring() {
  local ring="a3f9c1e7d2b84a0f5c6e9d1b7a3f0c2e8d5a6b9f1c4e7d0a3b8f2c5e1d9a6"
  local i out=""
  for i in $(seq 1 $((VIBE_CMS_D * 4))); do
    out="$out${ring:$(( (i * 7) % ${#ring} )):1}"
  done
  echo "$out"
}

ve_cms_init() {
  local d; d=$(ve_cms_dir)
  mkdir -p "$d"
  printf '%s\n' "$(ve_cms_seed_ring)" > "$d/seeds"
  local lines=0 bytes=0
  if [ -e "$d/counters" ]; then
    lines=$(wc -l < "$d/counters")
    bytes=$(wc -c < "$d/counters")
  fi
  if [ "$lines" != "$VIBE_CMS_D" ] || [ "$bytes" -eq 0 ]; then
    local i rowzero
    rowzero=$(awk -v n="$VIBE_CMS_W" 'BEGIN{ for(i=1;i<=n;i++) printf (i>1?",":"")"0"; print "" }')
    for i in $(seq 1 "$VIBE_CMS_D"); do echo "$rowzero"; done > "$d/counters"
  fi
}

# ---- hashes for one item across all d rows (two multiplication hashes) ------
ve_cms_positions() {
  local item="$1"
  # row i uses (a_i*b + c_i) mod w with per-row ints from the seed bytes
  local sbase; sbase=$(ve_cms_seed_ring)
  local v; v=$(printf '%s' "$item" | cksum | cut -d' ' -f1)
  local i a b c pos
  for i in $(seq 1 "$VIBE_CMS_D"); do
    a=$(( (16#${sbase:$(( (i*2) % ${#sbase} )):1} * 37 + i * 11) ))
    b=$(( (16#${sbase:$(( (i*3+1) % ${#sbase} )):1} * 53 + i * 17) ))
    c=$(( (16#${sbase:$(( (i*4+2) % ${#sbase} )):1} * 79 + i * 23) ))
    pos=$(( (a * v + b * v + c) % VIBE_CMS_W ))
    echo "$pos|$i"
  done
}

# ---- count an occurrence of item -------------------------------------------
ve_cms_add() {
  local item="$1"
  ve_cms_init
  local f; f=$(ve_cms_counters)
  local pd pos row
  while IFS= read -r pd; do
    pos=${pd%%|*}; row=${pd##*|}
    # counters file rows are D lines of W comma-values; bump one cell
    awk -v row="$row" -v pos="$pos" -v f="$f" '
      BEGIN { }
      { if (NR == row) { $0 = bump_cell($0, pos) } ; print }
      function bump_cell(line, p,   a, i) {
        split(line, a, ",");
        if (a[p] == "") a[p] = 0;
        a[p]++;
        return join(a);
      }
      function join(a,   r, i) { r=""; for (i=1; i<=length(a); i++) r = r (i>1?",":"") a[i]; return r }
    ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done <<< "$(ve_cms_positions "$item")"
}

# ---- estimate frequency of item --------------------------------------------
ve_cms_estimate() {
  local item="$1"
  ve_cms_init
  local f; f=$(ve_cms_counters)
  local min_est=""
  local pd pos row cell
  while IFS= read -r pd; do
    pos=${pd%%|*}; row=${pd##*|}
    cell=$(awk -v row="$row" -v pos="$pos" 'NR==row { split($0,a,","); print a[pos]+0 }' "$f")
    if [ -z "$min_est" ] || [ "$cell" -lt "$min_est" ]; then min_est=$cell; fi
  done <<< "$(ve_cms_positions "$item")"
  echo "${min_est:-0}"
}

ve_cms_flush() { : > "$(ve_cms_counters)"; }

ve_cms=""
#!/bin/bash
# ===========================================================================
#  core/lsh.sh — MINHASH + BANDED LSH NEAR-DUPLICATE DETECTOR
# ---------------------------------------------------------------------------
#  Every recorded envelope is projected to a fixed-length MinHash signature
#  (VE_LSH_ROWS independent 32-bit minima over its token/char shingles), then
#  stored two ways:
#      state/lsh/sig/<fp>   : signature "r1 r2 ... r8"
#      state/lsh/band/<n>/<b>: fp list per band bucket (n = band index)
#  The signature row bundles are *banded*: two items are candidate
#  near-dupes only if an entire band shares its bucket, so the similarity
#  search gathers from bands first and only then computes a full row-wise
#  Jaccard — the classic LSH speedup over an all-pairs scan.
#
#  Similarity between signatures = fraction of equal rows (true-set
#  Jaccard upper estimate); threshold gates the candidate stream.
# ===========================================================================
set -euo pipefail

VE_LSH_ROWS="${VE_LSH_ROWS:-8}"
VE_LSH_BANDS=2                        # each band covers ROWS/BANDS rows
VE_LSH_THRESH="${VE_LSH_THRESH:-5}"   # rows-equal out of 8 to surface

ve_lsh_dir()  { mkdir -p "$VIBE_STATE/lsh"; echo "$VIBE_STATE/lsh"; }
ve_lsh_sigdir()   { mkdir -p "$(ve_lsh_dir)/sig";   echo "$(ve_lsh_dir)/sig"; }
ve_lsh_banddir()  { local n="$1"; mkdir -p "$(ve_lsh_dir)/band/$n"; echo "$(ve_lsh_dir)/band/$n"; }

# ---- deterministic 32-bit mix (one cksum per shingle, rows via xorshift) ---
ve_lsh_mix() {
  local v="$1" j="$2"
  v=$(( (v ^ (v >> 16)) * 2246822519 % 4294967296 ))
  v=$(( (v ^ (v >> 13)) * 3266489917 % 4294967296 ))
  v=$(( (v ^ (v >> 16)) ^ j * 2654435761 ))
  echo $(( v & 0x7fffffff ))
}

# ---- shingle set for an envelope token stream (token- and char-shingles)  --
ve_lsh_shingles() {
  local tokens="$1"
  printf '%s\n' "$tokens" | tr ' :' '\n\n' | sed '/^$/d'
  # token bigrams
  printf '%s\n' "$tokens" | tr ' :' '\n\n' | sed '/^$/d' | paste -s -d' ' \
    | awk '{ for (i=1; i<NF; i++) print $i "~" $(i+1) }'
  # char trigrams of every token (content-level precision)
  printf '%s\n' "$tokens" | tr ' :' '\n\n' | sed '/^$/d' \
    | awk '{ n=length($0); if (n>=3) for (i=1; i<=n-2; i++) print "c:" substr($0,i,3); else print "c:" $0 }'
}

# ---- signature of a shingle stream ------------------------------------------
ve_lsh_signature() {
  local stream="$1"
  local -A min=()
  local s base v j row
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    base=$(printf '%s' "$s" | cksum | awk '{print $1}')
    for j in $(seq 1 "$VE_LSH_ROWS"); do
      v=$(ve_lsh_mix "$base" "$j")
      if [ -z "${min[$j]:-}" ] || [ "$v" -lt "${min[$j]}" ]; then min[$j]=$v; fi
    done
  done <<< "$stream"
  for j in $(seq 1 "$VE_LSH_ROWS"); do
    [ -n "${min[$j]:-}" ] && printf '%s ' "${min[$j]}"
  done | sed 's/ $//'
}

# ---- index one envelope: signature + band entries ----------------------------
ve_lsh_index() {
  local fp="$1" tokens="$2"
  [ -z "$fp" ] && return 0
  local sig; sig=$(ve_lsh_signature "$(ve_lsh_shingles "$tokens")")
  [ -z "$sig" ] && return 0
  local j bucket
  for j in $(seq 1 "$VE_LSH_BANDS"); do
    local lo=$(( (j-1)*VE_LSH_ROWS/VE_LSH_BANDS + 1 ))
    local hi=$(( j*VE_LSH_ROWS/VE_LSH_BANDS ))
    bucket=$(echo "$sig" | cut -d' ' -f$lo-$hi | tr ' ' ',' | cksum | awk '{print $1}')
    echo "$fp" >> "$(ve_lsh_banddir "$j")/$bucket"
  done
  echo "$sig" > "$(ve_lsh_sigdir)/$fp"
}

# ---- similar candidates: gather band buckets, compute row-wise jaccard ------
ve_lsh_candidates() {
  local fp="$1" thresh="${2:-$VE_LSH_THRESH}"
  [ -f "$(ve_lsh_sigdir)/$fp" ] || { echo "lsh: no signature for $fp" >&2; return 0; }
  local mysig; mysig=$(cat "$(ve_lsh_sigdir)/$fp")
  local -A seen=()
  local n=0 j
  local cand=""
  for j in $(seq 1 "$VE_LSH_BANDS"); do
    local lo=$(( (j-1)*VE_LSH_ROWS/VE_LSH_BANDS + 1 ))
    local hi=$(( j*VE_LSH_ROWS/VE_LSH_BANDS ))
    local bucket; bucket=$(echo "$mysig" | cut -d' ' -f$lo-$hi | tr ' ' ',' | cksum | awk '{print $1}')
    [ -f "$(ve_lsh_banddir "$j")/$bucket" ] || continue
    while IFS= read -r other; do
      [ -z "$other" ] || [ "$other" = "$fp" ] && continue
      [ "${seen[$other]:-0}" = "1" ] && continue
      seen[$other]=1
      [ -f "$(ve_lsh_sigdir)/$other" ] || continue
      local osig; osig=$(cat "$(ve_lsh_sigdir)/$other")
      local hit=0 i
      for i in $(seq 1 "$VE_LSH_ROWS"); do
        local a b
        a=$(echo "$mysig" | cut -d' ' -f$i)
        b=$(echo "$osig" | cut -d' ' -f$i)
        [ "$a" = "$b" ] && hit=$((hit + 1))
      done
      if [ "$hit" -ge "$thresh" ]; then
        echo "$other|$hit"
      fi
    done < "$(ve_lsh_banddir "$j")/$bucket"
  done | sort -u
}

# ---- store-wide duplicate scan: report "fpA|fpB|hits" pairs above thresh ----
ve_lsh_dupe_scan() {
  local thresh="${1:-$VE_LSH_THRESH}"
  local sigdir; sigdir=$(ve_lsh_sigdir)
  local -A done=()
  local fpa fpb line r a b hit
  for fpa in $(ls "$sigdir" 2>/dev/null); do
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      fpb="${line%%|*}"; hit="${line##*|}"
      [ "$fpb" = "$fpa" ] && continue
      key="$fpa>$fpb"; [ "${done[$key]:-0}" = 1 ] && continue
      done[$key]=1
      done["$fpb>$fpa"]=1
      if [ "$hit" -ge "$thresh" ] 2>/dev/null; then
        echo "$fpa|$fpb|$hit"
      fi
    done < <(ve_lsh_candidates "$fpa" "$thresh" 2>/dev/null)
  done
}

# ---- store-level count (for stats / optimize summary) ------------------------
ve_lsh_dupe_count() {
  ve_lsh_dupe_scan "${1:-}" 2>/dev/null | wc -l | tr -d ' '
}

# ---- quarantine exact-duplicate logical items (optimize --burn) --------------
# Near-dup pairs (all 8 LSH rows shared) whose NAME TOKENS are identical are
# the same logical item recorded twice under different fingerprints.  Each
# such second fp's event line is moved out of the live logs into a quarantine
# dir (never deleted outright), reporting the burned fingerprints.
ve_lsh_dupe_prune_burn() {
  local quardir="${1:-$VIBE_EVENTS/.dupes}"
  mkdir -p "$quardir"
  local burned=0 pair a b rows ea eb nama namb line log
  while IFS= read -r pair; do
    [ -z "$pair" ] && continue
    a="${pair%%|*}"
    local rest; rest="${pair#*|}"
    b="${rest%%|*}"; rows="${rest#*|}"
    [ "$rows" -lt 8 ] 2>/dev/null && continue
    ea=$(ve_index_fp_to_envelope "$a" 2>/dev/null)
    eb=$(ve_index_fp_to_envelope "$b" 2>/dev/null)
    { [ -z "$ea" ] || [ -z "$eb" ]; } && continue
    nama=$(ve_ingest_name_tokens "$(echo "$ea" | cut -d'|' -f4)" "$(echo "$ea" | cut -d'|' -f2)" 2>/dev/null)
    namb=$(ve_ingest_name_tokens "$(echo "$eb" | cut -d'|' -f4)" "$(echo "$eb" | cut -d'|' -f2)" 2>/dev/null)
    [ "$nama" = "$namb" ] || continue
    echo "  burn    duplicate logical item fp=$b (shares all $rows/8 rows with $a)"
    ve_lsh_dupe_quarantine_fp "$b" "$quardir"
    if [ "$?" -eq 0 ]; then
      burned=$((burned + 1))
    else
      echo "  burn    SKIP fp=$b (not found in live logs — already removed?)"
    fi
  done < <(ve_lsh_dupe_scan 2>/dev/null)
  echo "  burned $burned exact duplicate event(s) to $quardir"
}

# ---- move every live log line carrying fp into the quarantine dir -------------
ve_lsh_dupe_quarantine_fp() {
  local fp="$1" quardir="$2" found=0
  local -a tmp=()
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    tmp=("$f")
    grep -n "|$fp|" "$f" 2>/dev/null | while IFS=: read -r ln restline; do
      [ -z "$ln" ] && continue
      sed -n "${ln}p" "$f" >> "$quardir/burned_$fp.log"
      found=1
    done
    grep -v "|$fp|" "$f" 2>/dev/null > "$f.prune" || true
    [ -s "$f.prune" ] && mv "$f.prune" "$f"
    rm -f "$f.prune"
  done < <(find "$VIBE_EVENTS" -maxdepth 1 -name "*.log" -type f 2>/dev/null)
  return "$found"
}

ve_lsh=""
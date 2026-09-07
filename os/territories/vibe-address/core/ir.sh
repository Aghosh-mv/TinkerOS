#!/bin/bash
# ===========================================================================
#  core/ir.sh — CLASSICAL INFORMATION-RETRIEVAL CORE (Okapi BM25)
# ---------------------------------------------------------------------------
#  The vector matchers (lexical/fuzzy/phonetic) decide WHICH candidates to
#  keep.  BM25 decides how much those candidates deserve to be at the top.
#  This is the classical, battle-tested ranking function behind every
#  serious full-text engine (Lucene & friends use its descendants):
#
#    score(D,Q) = Σ over t in Q  IDF(t) · tf'(t,D)
#    tf'(t,D)     = tf · (k1+1) / ( tf + k1·(1 − b + b·|D|/avgdl) )
#    IDF(t)       = ln( (N − df(t) + 0.5) / (df(t) + 0.5) )     [floor ≥ 0]
#
#    k1 = 1.2 (term-frequency saturation), b = 0.75 (length normalisation)
#
#  Term-frequency saturation makes BM25 NON-LINEAR: reciting a word five
#  times earns far less than five distinct words — which is exactly the
#  behaviour a memory search wants.  Length normalisation stops huge paths
#  from dwarfing small ones.
#
#  Index structures (written at record time, all under $VIBE_INDEX):
#    dlen/<fp>            — document length (distinct tokens) for fp
#    post/<fp>            — "tok tf" lines  (the per-doc term postings)
#    df/<tok>             — one line per unique (fp:tok) = document frequency
#    doccount             — total documents N
#    totlen               — running sum of all doc lengths (avgdl build)
#
#  Pairs are deduplicated with the pair Bloom filter so df is an exact count
#  of distinct documents per term — the guarantee BM25's IDF needs.
# ===========================================================================
set -euo pipefail

VE_IR_K1=12    # 1.2  (stored ×10 so bash integer maths stays exact)
VE_IR_B=75     # 0.75 (×100)
VE_IR_K2=10    # 1.0  — FM3-style match bonus when tf matches query length

ve_ir_dir()   { echo "$VIBE_INDEX/ir"; }
ve_ir_dlen_f() { printf '%s/dlen/%s' "$(ve_ir_dir)" "$1"; }
ve_ir_post_f() { printf '%s/post/%s' "$(ve_ir_dir)" "$1"; }
ve_ir_df_f()   { printf '%s/df/%s' "$(ve_ir_dir)" "$1"; }

# ---- document-length + posting + df write (called from index insert) --------
ve_ir_add() {
  # fp, newline-or-space token stream (already normalized/deduplicated later)
  local fp="$1" tokens="$2"
  local dir; dir=$(ve_ir_dir)
  mkdir -p "$dir/dlen" "$dir/post" "$dir/df"

  # token frequency map (bash associative array is fast enough for ≤ 300 toks)
  local -A tf
  local tok
  for tok in $tokens; do
    [ -z "$tok" ] && continue
    tf["$tok"]=$(( ${tf["$tok"]:-0} + 1 ))
  done
  local len=${#tf[@]}
  [ "$len" -eq 0 ] && return 0

  local t
  local post="$dir/post/$fp"
  : > "$post"
  for t in "${!tf[@]}"; do
    # document-frequency: count pair (fp:t) only once
    local fresh; fresh=$(ve_bloom_pair_add "$fp:$t")
    if [ "$fresh" -eq 1 ]; then
      printf '%s\n' "$t" >> "$(ve_ir_df_f "$t")"
    fi
    printf '%s %s\n' "$t" "${tf[$t]}" >> "$post"
  done

  printf '%s\n' "$len" >> "$(ve_ir_dlen_f "$fp")"
  printf '%s\n' "$len" >> "$dir/totlen"
  printf '%s\n' "1" >> "$dir/doccount"
}

# ---- collection stats ----------------------------------------------------------
ve_ir_count()   { cat "$(ve_ir_dir)/doccount" 2>/dev/null | wc -l | tr -d ' '; }
ve_ir_avgdl() {
  local n; n=$(ve_ir_count); [ "$n" -eq 0 ] && { echo "1"; return; }
  local sum; sum=$(cat "$(ve_ir_dir)/totlen" 2>/dev/null | awk '{s+=$1} END{print s+0}')
  [ "$sum" -eq 0 ] && sum=1
  echo $(( sum / n ))
}
ve_ir_df() {
  local t="$1"
  cat "$(ve_ir_df_f "$t")" 2>/dev/null | wc -l | tr -d ' '
}

# ---- IDF with smoothing floor ----------------------------------------------------
ve_ir_idf() {
  local t="$1"
  local n; n=$(ve_ir_count)
  [ "$n" -eq 0 ] && { echo "0"; return; }
  local df; df=$(ve_ir_df "$t")
  [ "$df" -eq 0 ] && { echo "0"; return; }
  local num=$(( n - df + 1 ))
  # ln( (N−df+0.5)/(df+0.5) ) with floor 0: compute as integer log+rational
  local ratio_1000; ratio_1000=$(( num * 1000 / (df) ))
  local idf=0
  if [ "$ratio_1000" -gt 1000 ]; then
    # ln(x) ~ log2(x)*0.6931 ; log2 via integer loop
    local r=$ratio_1000 lo=0
    while [ "$r" -gt 1000 ]; do r=$(( (r*10)/20 )); lo=$((lo+9)); done
    # r in [1001..1999] -> log2 in [0..0.999]  → add fraction
    local frac=$(( (r-1000) * 1000 / 1000 ))
    lo=$(( lo + frac * 693 / 1000 ))
    idf=$lo
  fi
  echo "$idf"
}

# ---- single-term BM25 component ---------------------------------------------------
ve_ir_bm25_term() {
  # token, tf, doclen, avgdl -> integer ~ BM25 score (scaled)
  local tok="$1" tf="${2:-0}" dl="${3:-1}" avgdl="${4:-1}"
  [ "$tf" -eq 0 ] && { echo "0"; return; }
  local idf; idf=$(ve_ir_idf "$tok")
  [ "$idf" -eq 0 ] && { echo "0"; return; }
  local denom; denom=$(( 100*dl + VE_IR_K1*((100 - VE_IR_B) + VE_IR_B*100*dl/avgdl) ))
  [ "$denom" -eq 0 ] && denom=1
  local tfp; tfp=$(( tf * VE_IR_K2 ))   # ~ x*(1+1) tf attenuation boost
  # tf'(t,D) ≈ tf·(k1+1) / ( tf + k1·(1−b+b·|D|/avgdl) )   — exact integer form
  local term_freq_score=$(( 1000 * tf * (VE_IR_K1 + 10) / (tf*10 + VE_IR_K1*((100 - VE_IR_B) + VE_IR_B*100*dl/avgdl)/10) ))
  echo $(( idf * term_freq_score / 1000 ))
}

# ---- full BM25 score for one document against query tokens ------------------------
ve_ir_score() {
  # fp, space/newline query tokens -> accumulated BM25 (integer)
  local fp="$1" qtokens="$2"
  local dl; dl=$(tail -1 "$(ve_ir_dlen_f "$fp")" 2>/dev/null || echo 0)
  [ "$dl" -eq 0 ] 2>/dev/null && { echo "0"; return; }
  local avgdl; avgdl=$(ve_ir_avgdl)
  local post="$VIBE_INDEX/ir/post/$fp"
  [ -f "$post" ] || { echo "0"; return; }
  local total=0 tok tf
  while IFS= read -r tok tf; do
    case " $qtokens " in *" $tok "*) total=$(( total + $(ve_ir_bm25_term "$tok" "$tf" "$dl" "$avgdl") ));; esac
  done < "$post"
  echo "$total"
}

# ---- scaled 0..100 normalization ----------------------------------------------------
ve_ir_normalize() {
  local score="${1:-0}" qcount="${2:-1}"
  [ "$qcount" -lt 1 ] && qcount=1
  # cap per-term contribution at 25 → perfect match ≈ 25*qcount
  local cap=$(( 25 * qcount ))
  [ "$cap" -eq 0 ] && cap=1
  local s=$(( score * 100 / cap )); [ "$s" -gt 100 ] && s=100
  echo "$s"
}

# ---- IR contribution wrapped for the scorer (M9) -------------------------------------
ve_ir_component() {
  # fp, query tokens (space separated) -> 0..100
  local fp="$1" qtokens="$2"
  local qtok_count; qtok_count=$(echo "$qtokens" | wc -w | tr -d ' ')
  local raw; raw=$(ve_ir_score "$fp" "$qtokens")
  ve_ir_normalize "$raw" "$qtok_count"
}

ve_ir=""
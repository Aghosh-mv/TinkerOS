#!/bin/bash
# ===========================================================================
#  core/rank.sh — SCORING FUSION + RANKING
# ---------------------------------------------------------------------------
#  Takes raw per-candidate M1..M8 scores from match.sh and fuses them
#  into a single final score per candidate, then ranks.
#
#  Fusion model (no ML, pure weighted consensus):
#    Each matcher has a weight W1..W8 (persisted in $VIBE_STATE/weights)
#    adaptive weights shift based on which signals succeeded in past
#    successful recalls (see adapt.sh).
#
#  Final score = weighted_sum(Wi * Mi) + diversity_bonus + category_depth_bonus
#
#  Scoring pipeline:
#    1. Read raw candidate lines  (fp|m1|...|m8|envelope)
#    2. Apply adaptive weights    (from $VIBE_STATE/weights)
#    3. Compute weighted sum       (0..100 scale)
#    4. Diversity pass             (penalise over-represented categories)
#    5. Boost known-frequent paths (from $VIBE_STATE/path_boost)
#    6. Rank by final score        (stable sort)
#    7. Output top-K               (default K=8)
# ===========================================================================
set -euo pipefail

RANK_DEFAULT_K=8

# ---- load weights (or defaults) --------------------------------------------
ve_rank_weights() {
  local wfile="$VIBE_STATE/weights"
  if [ -f "$wfile" ]; then
    cat "$wfile"
  else
    # default weights: lexical most important, fuzzy second, time third
    echo "W1=35 W2=25 W3=20 W4=5 W5=15 W6=3 W7=10 W8=5"
  fi
}

# ---- parse weights from string into named vars ------------------------------
ve_rank_parse_weights() {
  local wstr; wstr=$(ve_rank_weights)
  eval "$wstr" 2>/dev/null || true
  # ensure all set
  W1=${W1:-35} W2=${W2:-25} W3=${W3:-20} W4=${W4:-5}
  W5=${W5:-15} W6=${W6:-3} W7=${W7:-10} W8=${W8:-5}
}

# ---- compute weighted final score (0..100) for one candidate ----------------
ve_rank_compute_score() {
  local m1="$1" m2="$2" m3="$3" m4="$4" m5="$5" m6="$6" m7="$7" m8="$8"
  ve_rank_parse_weights
  # weighted sum: weights sum to ~118 by default; normalise to 0..100
  local raw=$(( W1*m1 + W2*m2 + W3*m3 + W4*m4 + W5*m5 + W6*m6 + W7*m7 + W8*m8 ))
  local wtotal=$(( W1 + W2 + W3 + W4 + W5 + W6 + W7 + W8 ))
  [ "$wtotal" -eq 0 ] && { echo "0"; return; }
  echo $(( raw / wtotal ))
}

# ---- diversity pass: penalise over-represented top-categories ---------------
ve_rank_diversify() {
  # stdin: lines of "final_score|cat1|fp|rest..."
  # output: same lines with adjusted score
  # Count category hits first (simple loop, no associative arrays)
  local tmp; tmp=$(mktemp)
  cat > "$tmp"
  local line score cat1
  while IFS='|' read -r _score _cat1 _rest; do
    printf '%s\n' "$_cat1"
  done < "$tmp" | sort | uniq -c > "$tmp.cats"

  while IFS= read -r line; do
    score=$(echo "$line" | cut -d'|' -f1)
    cat1=$(echo "$line" | cut -d'|' -f2)
    local hits; hits=$(grep -E "\s+${cat1}$" "$tmp.cats" 2>/dev/null | awk '{print $1}' || echo 1)
    hits=${hits:-1}
    local penalty=0
    [ "$hits" -ge 2 ] && penalty=$(( hits * 15 ))
    local adjusted=$(( score - penalty ))
    [ "$adjusted" -lt 0 ] && adjusted=0
    echo "${adjusted}|${line#*|}"
  done < "$tmp"
  rm -f "$tmp" "$tmp.cats"
}

# ---- boost known-frequent paths ---------------------------------------------
ve_rank_apply_boosts() {
  # stdin: "score|fp|rest..."   boosts from $VIBE_STATE/path_boost
  local bfile="$VIBE_STATE/path_boost"
  local line
  while IFS= read -r line; do
    local score=$(echo "$line" | cut -d'|' -f1)
    local fp=$(echo "$line" | cut -d'|' -f2)
    if [ -f "$bfile" ]; then
      local boost; boost=$(grep "^$fp " "$bfile" 2>/dev/null | head -1 | awk '{print $2}')
      if [ -n "$boost" ] && [ "$boost" -gt 0 ] 2>/dev/null; then
        score=$(( score + boost ))
        [ "$score" -gt 100 ] && score=100
      fi
    fi
    echo "${score}|${line#*|}"
  done
}

# ---- top-K selection (stable sort) -----------------------------------------
ve_rank_topk() {
  local k="${1:-$RANK_DEFAULT_K}"
  sort -t'|' -k1 -rn | head -n "$k"
}

# ---- full ranking pipeline --------------------------------------------------
ve_rank_run() {
  # stdin: raw candidate lines from match.sh (fp|m1|m2|m3|m4|m5|m6|m7|envelope)
  # output: ranked lines with final_score, one per line
  local k="${1:-$RANK_DEFAULT_K}"
  local line ranked scored diversified boosted top
  local tmp_raw;  tmp_raw=$(mktemp)
  local tmp_score; tmp_score=$(mktemp)
  local tmp_div;  tmp_div=$(mktemp)

  cat > "$tmp_raw"

  # Step 1-2: compute weighted score
  while IFS= read -r line; do
    local fp=$(echo "$line" | cut -d'|' -f1)
    local m1=$(echo "$line" | cut -d'|' -f2)
    local m2=$(echo "$line" | cut -d'|' -f3)
    local m3=$(echo "$line" | cut -d'|' -f4)
    local m4=$(echo "$line" | cut -d'|' -f5)
    local m5=$(echo "$line" | cut -d'|' -f6)
    local m6=$(echo "$line" | cut -d'|' -f7)
    local m7=$(echo "$line" | cut -d'|' -f8)
    local m8=100  # neutral constant — real diversity applied separately
    local env=$(echo "$line" | cut -d'|' -f9-)
    local final; final=$(ve_rank_compute_score "$m1" "$m2" "$m3" "$m4" "$m5" "$m6" "$m7" "$m8")
    local cat1=$(echo "$env" | cut -d'|' -f4 | cut -d: -f1)
    printf '%s|%s|%s|%s\n' "$final" "$cat1" "$fp" "$env"
  done < "$tmp_raw" > "$tmp_score"

  # Step 3: diversity pass
  ve_rank_diversify < "$tmp_score" > "$tmp_div"

  # Step 4: boost known-frequent
  ve_rank_apply_boosts < "$tmp_div"

  # Step 5-6: top-K
  ve_rank_topk "$k"

  rm -f "$tmp_raw" "$tmp_score" "$tmp_div"
}

# ---- format result for human display ----------------------------------------
ve_rank_format_result() {
  # stdin: ranked lines from rank_run:
  #   "final|cat1|fp|epoch|type|source|path|fp2|catpath|meta"
  local rank=0
  while IFS='|' read -r score cat1 fp eepoch etype esource epath efp ecat emeta; do
    rank=$((rank + 1))
    local ago; ago=$(ve_rank_relative_time "$eepoch")
    printf '  %2d  [%3d%%] %s (%s)  %s\n' \
      "$rank" "$score" "$epath" "$ecat" "$ago"
  done
}

# ---- relative time ("3h ago", "yesterday", etc.) ----------------------------
ve_rank_relative_time() {
  local epoch="$1"
  local now; now=$(date +%s)
  local diff=$(( now - epoch ))
  if   [ "$diff" -lt 60   ]; then echo "just now"
  elif [ "$diff" -lt 3600  ]; then echo "$((diff/60))m ago"
  elif [ "$diff" -lt 86400 ]; then echo "$((diff/3600))h ago"
  elif [ "$diff" -lt 172800 ]; then echo "yesterday"
  elif [ "$diff" -lt 604800 ]; then echo "$((diff/86400))d ago"
  else echo "$((diff/604800))w ago"; fi
}

# ---- terse format for the Searchie overlay -----------------------------------
ve_rank_format_terse() {
  # stdin: ranked lines "final|cat1|fp|epoch|type|source|path|fp2|catpath|meta"
  local rank=0
  while IFS='|' read -r score cat1 fp eepoch etype esource epath efp ecat emeta; do
    rank=$((rank + 1))
    local ago; ago=$(ve_rank_relative_time "$eepoch")
    [ "$rank" -gt 12 ] && break
    printf 'RESULT|%s|%s|%s|%s\n' "$score" "$epath" "$ecat" "$ago"
  done
}

ve_rank=""
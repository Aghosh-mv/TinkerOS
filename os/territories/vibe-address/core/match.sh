#!/bin/bash
# ===========================================================================
#  core/match.sh — MULTIMODEL MATCHERS
# ---------------------------------------------------------------------------
#  Given a set of candidate fingerprints (from inverted index intersection
#  or time-bucket pruning), run several independent matching signals and
#  return per-candidate scores. Each matcher is pure algorithm:
#
#    M1  LEXICAL      token overlap between query and stored event
#    M2  FUZZY        Levenshtein-based token similarity
#    M3  CATEGORY     trie-depth path match (ancestor/descendant/sibling)
#    M4  SOURCE       source-host and type-matching score
#    M5  TEMPORAL     gaussian proximity to parsed time-window center
#    M6  DEPTH-DEPTH  how deep the user's recorded category tree was
#    M7  FINGERPRINT  n-gram Jaccard between event path and query text
#    M8  PHONE        phonetic consensus (soundex+metaphone+stem, phoneme.sh)
#                     — rescues misspellings and same-sounding words
#
#  Returns: fp, M1-M8 scores (0..100 each), raw line
#  This is the densest part of the engine.
# ===========================================================================
set -euo pipefail

# ---- Levenshtein distance (pure bash, O(n*m) but n,m<=40 tokens) -----------
ve_match_levenshtein() {
  local a="$1" b="$2"
  local la=${#a} lb=${#b}
  [ $((la * lb)) -eq 0 ] && echo "$((la + lb))" && return
  # single-row DP (O(min(la,lb)) space)
  local -a prev curr
  for ((i=0; i<=lb; i++)); do prev[$i]=$i; done
  for ((i=1; i<=la; i++)); do
    curr[0]=$i
    local ai="${a:$((i-1)):1}"
    for ((j=1; j<=lb; j++)); do
      local bj="${b:$((j-1)):1}"
      local cost=0; [ "$ai" != "$bj" ] && cost=1
      local del=$(( ${prev[$j]} + 1 ))
      local ins=$(( ${curr[$((j-1))]} + 1 ))
      local rep=$(( ${prev[$((j-1))]} + cost ))
      # min of three
      local m=$del; [ "$ins" -lt "$m" ] && m=$ins; [ "$rep" -lt "$m" ] && m=$rep
      curr[$j]=$m
    done
    prev=("${curr[@]}")
  done
  echo "${prev[$lb]}"
}

# ---- n-gram Jaccard (2-gram on token stream) -------------------------------
ve_match_ngram_jaccard() {
  local a="$1" b="$2"
  # generate 2-grams
  local -a na=() nb=()
  local i
  for ((i=0; i<${#a}-1; i++)); do na+=("${a:$i:2}"); done
  for ((i=0; i<${#b}-1; i++)); do nb+=("${b:$i:2}"); done
  [ ${#na[@]} -eq 0 ] || [ ${#nb[@]} -eq 0 ] && { echo "0"; return; }
  local inter=0
  local -A seen
  for g in "${na[@]}"; do seen["$g"]=1; done
  for g in "${nb[@]}"; do
    [ "${seen[$g]:-0}" -eq 1 ] && inter=$((inter + 1)) && seen["$g"]=0
  done
  local union=$(( ${#na[@]} + ${#nb[@]} - inter ))
  [ "$union" -eq 0 ] && { echo "0"; return; }
  # scale to 0..100
  echo $(( inter * 100 / union ))
}

# ---- M1: Lexical token overlap score (0..100) ------------------------------
ve_match_lexical() {
  # query_tokens (newline sep), event_tokens (newline sep)
  local qtok="$1" etok="$2"
  [ -z "$qtok" ] || [ -z "$etok" ] && { echo "0"; return; }
  local qcount ecount intersect=0
  qcount=$(echo "$qtok" | sed '/^$/d' | wc -l | tr -d ' ')
  ecount=$(echo "$etok" | sed '/^$/d' | wc -l | tr -d ' ')
  # build hash of event tokens
  local -A eh
  while IFS= read -r t; do [ -n "$t" ] && eh["$t"]=1; done <<<"$etok"
  while IFS= read -r t; do [ -n "$t" ] && [ "${eh[$t]:-0}" -eq 1 ] && intersect=$((intersect + 1)); done <<<"$qtok"
  local denom=$(( qcount > ecount ? qcount : ecount ))
  [ "$denom" -eq 0 ] && { echo "0"; return; }
  echo $(( intersect * 100 / denom ))
}

# ---- M2: Fuzzy score (mean Levenshtein-normalised similarity) ---------------
ve_match_fuzzy() {
  # newline-separated query tokens vs event tokens
  local qtok="$1" etok="$2"
  [ -z "$qtok" ] || [ -z "$etok" ] && { echo "0"; return; }
  local total=0 n=0
  while IFS= read -r qt; do
    [ -z "$qt" ] && continue
    local best=0
    while IFS= read -r et; do
      [ -z "$et" ] && continue
      local d; d=$(ve_match_levenshtein "$qt" "$et")
      local maxl=${#qt}; [ ${#et} -gt "$maxl" ] && maxl=${#et}
      local sim=0
      [ "$maxl" -gt 0 ] && sim=$(( (maxl - d) * 100 / maxl ))
      [ "$sim" -gt "$best" ] && best=$sim
    done <<<"$etok"
    total=$((total + best))
    n=$((n + 1))
  done <<<"$qtok"
  [ "$n" -eq 0 ] && { echo "0"; return; }
  echo $(( total / n ))
}

# ---- M3: Category-path match (0..100) --------------------------------------
ve_match_category() {
  # normpath of event, normpath of query
  local epath="$1" qpath="$2"
  [ -z "$epath" ] || [ -z "$qpath" ] && { echo "0"; return; }
  local -a ea=() qa=()
  IFS=':' read -ra ea <<<"$epath"
  IFS=':' read -ra qa <<<"$qpath"
  local depth_e=${#ea[@]} depth_q=${#qa[@]}
  # longest common prefix length
  local prefix=0
  local max=$depth_e; [ "$depth_q" -lt "$max" ] && max=$depth_q
  for ((i=0; i<max; i++)); do
    [ "${ea[$i]}" = "${qa[$i]}" ] && prefix=$((prefix + 1)) || break
  done
  # score: prefix length relative to path depths + bonus for exact match
  local score=0
  if [ "$depth_e" -eq "$depth_q" ] && [ "$prefix" -eq "$depth_e" ]; then
    score=100
  elif [ "$prefix" -gt 0 ]; then
    score=$(( prefix * 100 / (depth_e + depth_q - prefix) ))
    [ "$score" -gt 99 ] && score=99
  fi
  echo "$score"
}

# ---- M4: Source/type match (0..100) ----------------------------------------
ve_match_source() {
  local esrc="$1" qsrc="$2"
  [ -z "$esrc" ] || [ -z "$qsrc" ] && { echo "0"; return; }
  local d; d=$(ve_match_levenshtein "$esrc" "$qsrc")
  local maxl=${#esrc}; [ ${#qsrc} -gt "$maxl" ] && maxl=${#qsrc}
  [ "$maxl" -eq 0 ] && { echo "0"; return; }
  echo $(( (maxl - d) * 100 / maxl ))
}

# ---- M5: Temporal proximity (0..100) — gaussian decay ----------------------
ve_match_temporal() {
  # event_epoch, target_epoch, sigma (in seconds; default = 3h)
  local eepoch="$1" sigma="${3:-10800}"
  local tepoch="${2:-$eepoch}"
  local diff=$(( eepoch - tepoch )); [ "$diff" -lt 0 ] && diff=$((-diff))
  # gaussian: score = 100 * exp( -diff^2 / (2*sigma^2) )
  # pure integer approximation: use lookup table of common sigmas
  local ratio=$(( diff * 1000 / sigma ))
  # 1000 = diff/sigma * 1000  -> now score = 100 * exp(-ratio^2 / 2000000)
  local sq=$(( ratio * ratio ))
  local denom=$(( 2000000 ))
  # exp(-x) approximation for small x: 1 - x + x^2/2 (Taylor up to order 2)
  local x=$(( sq * 10000 / denom ))  # scaled by 10000
  local score=$(( 1000000 - x * 10000 / 100 + (x * x / 2) / 10000 ))
  [ "$score" -lt 0 ] && score=0
  [ "$score" -gt 1000000 ] && score=1000000
  echo $(( score / 10000 ))
}

# ---- M6: Depth bonus (deeper recorded category = more specific = better) ---
ve_match_depth() {
  local depth="${1:-1}"
  # reward depth up to a sweet-spot of 5, then plateau
  if [ "$depth" -le 5 ]; then
    echo $(( depth * 20 ))
  else
    echo 100
  fi
}

# ---- M7: Jaccard n-gram of full path strings -------------------------------
ve_match_path_ngram() {
  local epath="$1" qstring="$2"
  [ -z "$epath" ] || [ -z "$qstring" ] && { echo "0"; return; }
  ve_match_ngram_jaccard "$epath" "$qstring"
}

# ---- M8: Diversity penalty (0..100; 100 = fully diverse, no penalty) -------
# call after scoring all candidates; penalise results with same top-category
ve_match_diversify() {
  # stdin: score lines with cat1 field appended; output: adjusted scores
  #   format: "cat1 old_score fp rest..."
  local -A cat_count
  local total=0
  while IFS='|' read -r cat1 old_score rest; do
    [ -z "$cat1" ] && continue
    cat_count["$cat1"]=$(( ${cat_count["$cat1"]:-0} + 1 ))
    total=$((total + 1))
  done <<< "$(cat)"
  # now second pass would be complex; return the count map for rank.sh
  echo "${#cat_count[@]} categories in $total results"
}

# ---- combined per-candidate scoring -----------------------------------------
ve_match_score_candidate() {
  # fp, q_tokens_norm, q_catpath, q_time_center, q_source, event_envelope
  local fp="$1" qtok="$2" qcat="$3" qtime="${4:-0}" qsrc="$5" envelope="$6"
  # parse envelope
  local eepoch=$(echo "$envelope" | cut -d'|' -f1)
  local epath=$(echo "$envelope" | cut -d'|' -f4)
  local ecat=$(echo "$envelope" | cut -d'|' -f6)
  local etype=$(echo "$envelope" | cut -d'|' -f2)
  # extract event tokens from path
  local etok; etok=$(ve_ingest_name_tokens "$epath" "$etype")
  local depth; depth=$(ve_tree_depth "$ecat")
  local edepth; edepth=$(echo "$ecat" | tr ':' '\n' | wc -l | tr -d ' ')

  local m1 m2 m3 m4 m5 m6 m7
  m1=$(ve_match_lexical  "$qtok" "$etok")
  m2=$(ve_match_fuzzy    "$qtok" "$etok")
  m3=$(ve_match_category "$ecat" "$qcat")
  m4=$(ve_match_source   "$etype" "$qsrc")
  m5=$(ve_match_temporal "$eepoch" "$qtime")
  m6=$(ve_match_depth    "$edepth")
  m7=$(ve_match_path_ngram "$epath" "$qtok")
  m8=$(ve_phon_similarity "$qtok" "$etok")
  m9=$(ve_ir_component     "$fp" "$qtok")

  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$fp" "$m1" "$m2" "$m3" "$m4" "$m5" "$m6" "$m7" "$m8" "$m9" "$envelope"
}

ve_match=""
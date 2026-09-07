#!/bin/bash
# ===========================================================================
#  core/query.sh — QUERY PLANNER + EXECUTION ENGINE
# ---------------------------------------------------------------------------
#  The central orchestrator. When a user types a memory phrase into
#  Searchie (Tab+F7), this module:
#
#    1. TOKENIZER        split query into normalized tokens
#    2. INTENT CLASSIFIER determine which matchers to activate
#    3. TIME RESOLVER    parse any time-mention into an epoch window
#    4. CATEGORY RESOLVER detect any category mention, expand synonyms
#    5. PLAN BUILDER     assemble a ranked pipeline plan
#    6. CANDIDATE FETCH  pull fps from inverted index + time buckets
#    7. SCORE & RANK     run match.sh + rank.sh fusion
#    8. PRESENT          format top-K results
#    9. ADAPT            record which signals succeeded
# ===========================================================================
set -euo pipefail

QUERY_DEBUG="${QUERY_DEBUG:-0}"

# ---- canonical token iteration --------------------------------------------
# The engine carries token streams as SPACE-separated strings while the
# global IFS is deliberately $'\n\t' (no space).  Any `for t in $tokens`
# loop would therefore never split — every such loop must iterate through
# this helper instead, which normalises space+newline runs to newline-sep
# (trunk-delimited) so `while read` works under any IFS.
ve_query_token_iter() {
  printf '%s\n' "$1" | tr ' \n' '\n\n' | sed '/^[[:space:]]*$/d'
}

# ---- step 1: tokenizer -----------------------------------------------------
ve_query_tokenize() {
  ve_lex_tokenize "$1"
}

# ---- step 2: intent classifier ---------------------------------------------
# returns: time_mentioned=yes|no  category_mentioned=what  source_mentioned=what
ve_query_classify_intent() {
  local tokens="$1"
  local intent_time="no" intent_cat="" intent_source="" intent_type=""
  local time_phrases=("last night" "yesterday" "today" "this week" "last week" \
    "this month" "last month" "this quarter" "this year" "last year" \
    "morning" "afternoon" "evening" "night" "around" "between" \
    "first week" "second week" "tuesday" "wednesday" "thursday" "friday" \
    "saturday" "sunday" "monday" "recent" "old" "past")
  local cat_phrases=("image" "photo" "picture" "drawing" "video" "song" "music" \
    "game" "chat" "message" "email" "doc" "file" "code" "script" \
    "download" "upload" "tab" "browser" "search" "note" "clip" \
    "recipe" "recipe" "price" "link" "bookmark" "folder")
  local tp
  for tp in "${time_phrases[@]}"; do
    if [[ "$tokens" == *"$tp"* ]]; then intent_time="yes"; break; fi
  done
  local cp
  for cp in "${cat_phrases[@]}"; do
    if [[ "$tokens" == *"$cp"* ]]; then intent_cat="$cp"; break; fi
  done
  printf 'TIME=%s CAT=%s SOURCE=%s\n' "$intent_time" "$intent_cat" "$intent_source"
}

# ---- step 3: time resolution ------------------------------------------------
ve_query_resolve_time() {
  local tokens="$1"
  local now; now=$(date +%s)
  # try explicit quantity ("three weeks ago", "5 days back")
  local qty; qty=$(ve_lex_quantity "$tokens")
  if [ -n "$qty" ] && [ "$qty" -gt 0 ]; then
    if [[ "$tokens" == *"ago"* ]] || [[ "$tokens" == *"back"* ]] || [[ "$tokens" == *"last"* ]]; then
      echo "$(( now - qty )) $now"; return 0
    fi
    echo "$now $(( now + qty ))"; return 0
  fi
  # try era aliases first
  local window
  window=$(ve_time_era "$tokens") 2>/dev/null && { IFS=' ' read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
  # try weekday
  window=$(ve_time_weekday "$tokens") 2>/dev/null && { IFS=' ' read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
  # try "week of month"
  window=$(ve_time_week_of_month "$tokens") 2>/dev/null && { IFS=' ' read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
  # try time-of-day
  window=$(ve_time_hod "$tokens") 2>/dev/null && { IFS=' ' read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
  # try "between X and Y"
  window=$(ve_time_between "$tokens") 2>/dev/null && { IFS=' ' read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
  # default: last 30 days
  echo "$(( now - 2592000 )) $now"
}

# ---- step 4: category resolution -------------------------------------------
ve_query_resolve_cat() {
  local tokens="$1"
  local cat=""
  # direct category mention
  case "$tokens" in
    *"image"*|*"photo"*|*"picture"*|*"drawing"*) cat="files:image" ;;
    *"video"*|*"movie"*|*"clip"*)                 cat="media:video" ;;
    *"song"*|*"music"*|*"audio"*)                 cat="media:audio" ;;
    *"game"*|*"gaming"*|*"play"*)                 cat="media:game" ;;
    *"chat"*|*"message"*|*"text"*)                cat="mem:chat" ;;
    *"email"*|*"mail"*)                           cat="net:email" ;;
    *"doc"*|*"document"*|*"report"*)              cat="files:doc" ;;
    *"code"*|*"script"*|*"program"*)              cat="dev:code" ;;
    *"download"*|*"dl"*)                          cat="net:downloads" ;;
    *"tab"*|*"browser"*|*"web"*|*"page"*)        cat="net:tab" ;;
    *"search"*|*"query"*|*"looked"*)              cat="mem:search" ;;
    *"note"*|*"clip"*|*"saved"*)                  cat="mem:notes" ;;
    *"link"*|*"bookmark"*|*"saved link"*)         cat="net:bookmarks" ;;
    *"folder"*|*"dir"*|*"directory"*)             cat="files:folder" ;;
  esac
  # also try synonym resolution
  if [ -z "$cat" ]; then
    local alias; alias=$(ve_tree_resolve_alias "$tokens" 2>/dev/null)
    [ -n "$alias" ] && cat="$alias"
  fi
  echo "$cat"
}

# ---- step 5: plan builder ---------------------------------------------------
ve_query_plan() {
  local raw="${1:-}"
  local tokens; tokens=$(ve_query_tokenize "$raw")
  local intent; intent=$(ve_query_classify_intent "$tokens")
  local time_window; time_window=$(ve_query_resolve_time "$tokens")
  local cat; cat=$(ve_query_resolve_cat "$tokens")
  local ops; ops=$(ve_query_split_ops "$tokens")
  local pos;  pos=$(echo "$ops" | grep '^POS=' | cut -d= -f2-)
  local neg;  neg=$(echo "$ops" | grep '^NEG=' | cut -d= -f2-)

  echo "============================================"
  echo "  Searchie — Query Plan"
  echo "============================================"
  echo "  Raw query    : $raw"
  echo "  Tokens       : $pos"
  echo "  Excluded     : ${neg:-(none)}"
  echo "  Intent       : $intent"
  echo "  Time window  : $time_window"
  echo "  Category     : ${cat:-(any)}"
  echo "  Matchers     : M1(lexical) M2(fuzzy) M3(category) M4(source) M5(temporal) M6(depth) M7(ngram) M8(phoneme) M9(BM25)"
  echo "  Pipeline     : negation-parse -> time-prune -> inverted-index -> match-scores -> weighted-fusion -> negation-filter -> diversity -> top-K"
  echo "============================================"
}

# ---- boolean op parsing: split query into POSITIVE and NEGATIVE token sets ----
#   "cat not budget"       -> POS=cat   NEG=budget
#   "cat -budget -excel"   -> POS=cat   NEG=budget excel
#   "-budget"              -> POS=<any> NEG=budget   (negation-only = all but X)
ve_query_split_ops() {
  local tokens="$1" pos="" neg="" infix_not=0 w
  # operators are punctuation-level syntax: parse BEFORE any tokenization
  while IFS= read -r w; do
    case "$w" in
      -[a-z0-9._]*)
        neg="$neg ${w#-}" ;;
      -)
        continue ;;
      Not|NOT|not|Without|WITHOUT|without|Excluding|EXCLUDING|excluding|Minus|MINUS|minus)
        infix_not=1 ;;
      *)
        if [ "$infix_not" -eq 1 ]; then neg="$neg $w"; infix_not=0; else pos="$pos $w"; fi ;;
    esac
  done < <(ve_query_token_iter "$tokens")
  # a lone "not" with no following word can't name anything — drop it
  pos=$(echo "$pos" | sed 's/^ *//;s/ *$//')
  neg=$(echo "$neg" | sed 's/^ *//;s/ *$//')
  printf 'POS=%s\nNEG=%s\n' "$pos" "$neg"
}

# ---- negation filter: drop candidates that also mention an excluded term ------
ve_query_filter_negations() {
  local candidates="$1" negs="$2"
  [ -z "$negs" ] && { echo "$candidates"; return; }
  local ntok
  echo "$candidates" | while IFS= read -r env; do
    [ -z "$env" ] && continue
    local drop=0 ntok
    while IFS= read -r ntok; do
      [ -z "$ntok" ] && continue
      # tied to the bloom cascade: an absent token cannot possibly match.
      # keys are the SANITIZED inv filenames, so any raw token is sanitized
      # first — absence from bloom is exact (bloom has no false negatives).
      local nkey; nkey=$(ve_index_sanitize_token "$ntok")
      local inbloom; inbloom=$(ve_bloom_tok_contains "$nkey" 2>/dev/null || echo 0)
      [ "$inbloom" = "1" ] || continue
      local badfps; badfps=$(ve_index_tokens_to_fps "$ntok" 2>/dev/null)
      if echo "$badfps" | grep -qx "$(echo "$env" | cut -d'|' -f5)"; then
        drop=1; break
      fi
    done < <(ve_query_token_iter "$negs")
    [ "$drop" -eq 0 ] && echo "$env"
  done
}

# ---- step 6-8: execute the full query pipeline ------------------------------
ve_query_run() {
  local raw="${1:-}"
  local k="${2:-$RANK_DEFAULT_K}"

  # ---- boolean op parse runs on the RAW string ("-" and "not X" are
  #      operator syntax; a tokenizer would strip them before we saw them) --
  local ops; ops=$(ve_query_split_ops "$raw")
  local pos_raw; pos_raw=$(echo "$ops" | grep '^POS=' | cut -d= -f2-)
  local qneg_raw; qneg_raw=$(echo "$ops" | grep '^NEG=' | cut -d= -f2-)

  # tokenize the positive side (negation-only queries name nothing to find)
  local tokens; tokens=$(ve_query_tokenize "$pos_raw")
  local qneg; qneg=$(ve_query_tokenize "$qneg_raw")
  qneg=$(echo "$qneg" | sed 's/ *$//;s/^ *//')
  if [ -z "$tokens" ] && [ -n "$qneg" ]; then
    tokens=""          # "everything EXCEPT <thing>"
  elif [ -z "$tokens" ]; then
    echo "(empty query)"; return
  fi

  # classify
  local intent; intent=$(ve_query_classify_intent "$tokens")
  local intent_time; intent_time=$(echo "$intent" | grep -oP 'TIME=\K\S+' || true)
  local intent_cat;  intent_cat=$(echo "$intent" | grep -oP 'CAT=\K\S+' || true)
  local intent_src;  intent_src=$(echo "$intent" | grep -oP 'SOURCE=\K\S+' || true)

  # resolve time
  local time_window; time_window=$(ve_query_resolve_time "$tokens")
  IFS=' ' read -r tlo thi <<<"$time_window"
  tlo=${tlo%% *}; thi=${thi% *}
  tlo=${tlo//[^0-9]/}; thi=${thi//[^0-9]/}
  [ -z "$tlo" ] && tlo=0; [ -z "$thi" ] && thi=$(date +%s)
  tlo=$((tlo)); thi=$((thi))

  # resolve category
  local qcat; qcat=$(ve_query_resolve_cat "$tokens")

  # source tokens from query
  local qsrc=""
  case "$tokens" in
    *browser*|*tab*|*web*)   qsrc="browser" ;;
    *terminal*|*console*|*shell*) qsrc="terminal" ;;
    *file*|*folder*|*disk*)  qsrc="filesystem" ;;
  esac

  # time center for gaussian
  local tcenter=$(( (tlo + thi) / 2 ))

  if [ "$QUERY_DEBUG" = "1" ]; then
    ve_query_plan "$raw"
    echo
  fi

  if [ "${SEARCHIE_TERSE:-0}" != "1" ]; then
    echo "  query: $raw"
    echo
    echo "  scanning..."
  fi

  # --- STEP A: strict candidate fetch (exact inverted index) -----------------
  local candidates strict_count
  candidates=$(ve_query_fetch_candidates "$tokens" "$tlo" "$thi" "$qcat")
  strict_count=$(echo "$candidates" | sed '/^$/d' | wc -l | tr -d ' ')

  # --- STEP B: if too few strict hits, RELAX — always find the nearest -------
  #    relax levels (each broader):
  #      L0  strict (tokens ∩ index ∩ time ∩ cat)
  #      L1  drop stopwords, keep informative tokens
  #      L2  expand via substrings/synonyms (radius match)
  #      L3  category subtree + independent time window (ignore tokens)
  #      L4  whole store recency (last candidate on earth)
  local relax_level=0 fetched="$candidates"
  if [ "$strict_count" -lt 1 ]; then
    relax_level=1
    local infotok; infotok=$(ve_query_informative_tokens "$tokens")
    fetched=$(ve_query_fetch_candidates "$infotok" "$tlo" "$thi" "$qcat")
    if [ "$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 1 ]; then
      relax_level=2
      fetched=$(ve_query_fetch_expanded "$tokens" "$tlo" "$thi" "$qcat")
      if [ "$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 1 ]; then
        relax_level=3
        fetched=$(ve_query_fetch_by_category_or_time "$tokens" "$tlo" "$thi" "$qcat")
        if [ "$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 1 ]; then
          relax_level=4
          fetched=$(ve_query_fetch_recent_any)
        fi
      fi
    fi
  fi

  # dedup (an fp can surface via several inverted tokens or cascade levels)
  fetched=$(echo "$fetched" | sed '/^$/d' | sort -u)

  # ---- negation filter: drop anything matching an excluded term ------------
  if [ -n "$qneg" ]; then
    fetched=$(ve_query_filter_negations "$fetched" "$qneg")
    fetched=$(echo "$fetched" | sed '/^$/d' | sort -u)
  fi

  local cand_count; cand_count=$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')
  [ "${SEARCHIE_TERSE:-0}" != "1" ] && echo "  candidates: $cand_count  (strict=$strict_count relax=L$relax_level)"

  if [ "$cand_count" -eq 0 ]; then
    # genuinely empty store — the only honest answer
    if [ "${SEARCHIE_TERSE:-0}" = "1" ]; then
      echo "RESULT|0|||"
    else
      echo
      echo "  (Searchie memory is empty — the OS has not been observed yet.)"
      echo "  Press Tab+F7 again later; events are indexed the moment they happen."
    fi
    ve_adapt_record_query "$raw" "$intent_time" "$intent_cat" "$tlo" "$thi" "0"
    return
  fi

  # --- scoring ---------------------------------------------------------------
  [ "${SEARCHIE_TERSE:-0}" != "1" ] && echo "  scoring..."
  local scored
  scored=$(echo "$fetched" | while IFS= read -r cand; do
    local fp=$(echo "$cand" | cut -d'|' -f5)
    local envelope; envelope=$(ve_index_fp_to_envelope "$fp" 2>/dev/null)
    [ -z "$envelope" ] && continue
    ve_match_score_candidate "$fp" "$tokens" "$qcat" "$tcenter" "$qsrc" "$envelope"
  done)

  # --- ranking ---------------------------------------------------------------
  [ "${SEARCHIE_TERSE:-0}" != "1" ] && echo "  ranking..."
  local ranked
  ranked=$(echo "$scored" | ve_rank_run "$k")

  # --- verdict ----------------------------------------------------------------
  # strict match means the requested thing EXISTS; otherwise nearest-thing note
  if [ "${SEARCHIE_TERSE:-0}" = "1" ]; then
    # machine-readable stream for the searchie overlay
    echo "$ranked" | ve_rank_format_terse
    ve_adapt_record_query "$raw" "$intent_time" "$intent_cat" "$tlo" "$thi" "$cand_count"
    return
  fi
  echo
  if [ "$strict_count" -ge 1 ]; then
    echo "  top matches:"
  elif [ "$relax_level" -le 2 ]; then
    echo "  no exact thing like that is in memory — closest thing you have:"
  else
    echo "  nothing matching that is in memory — nearest thing found anywhere:"
  fi
  echo
  echo "$ranked" | ve_rank_format_result

  # --- adapt: record what worked (always, for future weight adjustment) ------
  ve_adapt_record_query "$raw" "$intent_time" "$intent_cat" "$tlo" "$thi" "$cand_count"
}

# ---- candidate fetch: time-prune then inverted-index ------------------------
ve_query_fetch_candidates() {
  local tokens="$1" tlo="$2" thi="$3" qcat="$4"
  local all_events=""

  # gather events from inverted index
  local fps; fps=$(ve_index_tokens_to_fps "$tokens" 2>/dev/null)

  # also grab from category subtree if specified
  if [ -n "$qcat" ]; then
    local catdir; catdir=$(ve_tree_locate "$qcat" 2>/dev/null)
    if [ -n "$catdir" ] && [ -d "$catdir" ]; then
      local catfps; catfps=$(ve_tree_descend "$catdir" 2>/dev/null | awk '{print $2}')
      fps=$(printf '%s\n%s\n' "$fps" "$catfps" | sort -u)
    fi
  fi

  # filter by time window
  while IFS= read -r fp; do
    [ -z "$fp" ] && continue
    local envelope; envelope=$(ve_index_fp_to_envelope "$fp" 2>/dev/null)
    [ -z "$envelope" ] && continue
    local eepoch; eepoch=$(echo "$envelope" | cut -d'|' -f1)
    if [ "$eepoch" -ge "$tlo" ] && [ "$eepoch" -le "$thi" ] 2>/dev/null; then
      echo "$envelope"
    fi
  done <<< "$fps"
}

# ---- time-bucket acceleration (future optimization) -------------------------
ve_query_time_prune() {
  # for very large indexes, first check time buckets before full scan
  local tlo="$1" thi="$2"
  local best_level="d"  # start at day level
  # find which day buckets overlap the window
  local tlo_day; tlo_day=$(date -u -d @$tlo +%Y-%m-%d)
  local thi_day; thi_day=$(date -u -d @$thi +%Y-%m-%d)
  local tb="$VIBE_INDEX/time/d"
  if [ -d "$tb" ]; then
    local f fps=""
    for f in "$tb"/*; do
      [ -f "$f" ] || continue
      local bname; bname=$(basename "$f")
      if [[ "$bname" > "$tlo_day" ]] && [[ "$bname" < "$thi_day" ]] || \
         [ "$bname" = "$tlo_day" ] || [ "$bname" = "$thi_day" ]; then
        fps=$(printf '%s\n%s\n' "$fps" "$(cut -d' ' -f2 "$f")")
      fi
    done
    echo "$fps" | sort -u
  fi
}

ve_query=""

# ===========================================================================
#  RELAXED-FETCH UTILITIES (always-find-nearest behavior)
#  Used by the L1..L4 relax cascade in ve_query_run and ve_action_delete.
# ===========================================================================

# ---- L1: drop stopwords -> keep informative tokens -------------------------
ve_query_informative_tokens() {
  local tokens="$1"
  ve_lex_stopfilter "$tokens"
}

# ---- L2: expanded fetch — synonyms + prefix/substring radius -----------------
ve_query_fetch_expanded() {
  # tokens, tlo, thi, qcat
  local tokens="$1" tlo="$2" thi="$3" qcat="$4"
  local inform; inform=$(ve_query_informative_tokens "$tokens")
  [ -z "$inform" ] && inform="$tokens"
  # branch 1: synonym-ring expansion (same words, different spellings)
  local ring; ring=$(ve_lex_expand_ring "$inform")
  # branch 2: radius tokens — for each informative word also try its stem prefix
  local rad tokens2="$ring"
  while IFS= read -r rad; do
    [ -z "$rad" ] && continue
    local stem; stem="${rad:0:3}"
    tokens2="$tokens2 $rad $stem"
  done < <(ve_query_token_iter "$inform")
  ve_query_fetch_candidates "$tokens2" "$tlo" "$thi" "$qcat"
}

# ---- L3: category-subtree OR time-window only (ignore words entirely) -------
ve_query_fetch_by_category_or_time() {
  local tokens="$1" tlo="$2" thi="$3" qcat="$4"
  local candidates=""

  # category subtree (strongest signal)
  if [ -n "$qcat" ]; then
    local catdir; catdir=$(ve_tree_locate "$qcat" 2>/dev/null)
    if [ -n "$catdir" ] && [ -d "$catdir" ]; then
      local catfps; catfps=$(ve_tree_descend "$catdir" 2>/dev/null | awk '{print $2}')
      candidates=$(echo "$catfps" | while IFS= read -r fp; do
        [ -z "$fp" ] && continue
        local env; env=$(ve_index_fp_to_envelope "$fp" 2>/dev/null)
        [ -z "$env" ] && continue
        echo "$env"
      done)
    fi
  fi

  # broad time-window fetch (fallback if still empty): most recent in window
  if [ -z "$candidates" ]; then
    candidates=$(ve_query_fetch_recent_any "$tlo" "$thi")
  fi
  echo "$candidates"
}

# ---- L4: recency-only — the nearest things ANYWHERE in the whole store ------
#   (ignores the query's time window on purpose: a user who says "last night"
#    but recorded it hours later still gets their thing, with a time note.)
ve_query_fetch_recent_any() {
  local tlo=0 thi; thi=$(date +%s)
  local count=0
  # walk fp table (all known fingerprints), pick those in time window
  for ff in "$VIBE_INDEX"/fp/*; do
    [ -f "$ff" ] || continue
    count=$((count + 1))
    [ "$count" -gt 300 ] && break   # cap so worst case stays fast
    local env; env=$(tail -1 "$ff" 2>/dev/null)
    [ -z "$env" ] && continue
    local eepoch; eepoch=$(echo "$env" | cut -d'|' -f1)
    if [ "$eepoch" -ge "$tlo" ] && [ "$eepoch" -le "$thi" ] 2>/dev/null; then
      echo "$env"
    fi
  done
}
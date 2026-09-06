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

# ---- step 1: tokenizer -----------------------------------------------------
ve_query_tokenize() {
  local raw="$1"
  # lowercase, strip punctuation except hyphens, collapse whitespace
  local norm
  norm=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | \
         tr -cd 'a-zA-Z0-9 -' | \
         sed 's/  */ /g; s/^ //; s/ $//')
  echo "$norm"
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
  # try era aliases first
  local window
  window=$(ve_time_era "$tokens") 2>/dev/null && { read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
  # try weekday
  window=$(ve_time_weekday "$tokens") 2>/dev/null && { read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
  # try "week of month"
  window=$(ve_time_week_of_month "$tokens") 2>/dev/null && { read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
  # try time-of-day
  window=$(ve_time_hod "$tokens") 2>/dev/null && { read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
  # try "between X and Y"
  window=$(ve_time_between "$tokens") 2>/dev/null && { read -r lo hi <<<"$window"; echo "$lo $hi"; return 0; }
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

  echo "============================================"
  echo "  Searchie — Query Plan"
  echo "============================================"
  echo "  Raw query    : $raw"
  echo "  Tokens       : $tokens"
  echo "  Intent       : $intent"
  echo "  Time window  : $time_window"
  echo "  Category     : ${cat:-(any)}"
  echo "  Matchers     : M1(lexical) M2(fuzzy) M3(category) M4(source) M5(temporal) M6(depth) M7(ngram) M8(diversity)"
  echo "  Pipeline     : time-prune -> inverted-index -> match-scores -> weighted-fusion -> diversity -> top-K"
  echo "============================================"
}

# ---- step 6-8: execute the full query pipeline ------------------------------
ve_query_run() {
  local raw="${1:-}"
  local k="${2:-$RANK_DEFAULT_K}"

  # tokenize
  local tokens; tokens=$(ve_query_tokenize "$raw")
  [ -z "$tokens" ] && { echo "(empty query)"; return; }

  # classify
  local intent; intent=$(ve_query_classify_intent "$tokens")
  local intent_time; intent_time=$(echo "$intent" | grep -oP 'TIME=\K\S+')
  local intent_cat;  intent_cat=$(echo "$intent" | grep -oP 'CAT=\K\S+')

  # resolve time
  local time_window; time_window=$(ve_query_resolve_time "$tokens")
  read -r tlo thi <<<"$time_window"
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

  echo "  query: $raw"
  echo
  echo "  scanning..."

  # --- candidate fetch -------------------------------------------------------
  local candidates; candidates=$(ve_query_fetch_candidates "$tokens" "$tlo" "$thi" "$qcat")
  local cand_count; cand_count=$(echo "$candidates" | sed '/^$/d' | wc -l | tr -d ' ')
  echo "  candidates: $cand_count"

  if [ "$cand_count" -eq 0 ]; then
    echo
    echo "  (no matches found)"
    return
  fi

  # --- scoring ---------------------------------------------------------------
  echo "  scoring..."
  local scored
  scored=$(echo "$candidates" | while IFS= read -r cand; do
    local fp=$(echo "$cand" | cut -d'|' -f5)
    local envelope; envelope=$(ve_index_fp_to_envelope "$fp" 2>/dev/null)
    [ -z "$envelope" ] && continue
    ve_match_score_candidate "$fp" "$tokens" "$qcat" "$tcenter" "$qsrc" "$envelope"
  done)

  # --- ranking ---------------------------------------------------------------
  echo "  ranking..."
  local ranked
  ranked=$(echo "$scored" | ve_rank_run "$k")

  # --- display ---------------------------------------------------------------
  echo
  echo "  top matches:"
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
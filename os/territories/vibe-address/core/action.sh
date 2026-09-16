#!/bin/bash
# ===========================================================================
#  core/action.sh — SEARCHIE ACTIONS (delete / open / reveal) + CONFIRM
# ---------------------------------------------------------------------------
#  Searchie is not just read-only memory: it can ACT on what it finds.
#  Every destructive action goes through a MANDATORY three-button review:
#
#        [ OK — do it ]     [ Cancel ]     [ Find another thing ]
#
#  Rules (non-negotiable, this is a PUBLIC OS):
#    * NEVER delete/overwrite without an explicit OK.
#    * Deletion removes BOTH the real file AND its memory traces
#      (fi from event log, category trie, inverted index, fp table)
#      so Searchie forgets it forever — like a real file manager.
#    * "Find another thing" re-runs the fetch with relaxation +1 to
#      surface the NEXT-most-likely memories.
#    * The real files are staged and shown (name, path, size, age)
#      BEFORE any OK is possible.
#
#  The 3 buttons are rendered by the TUI (searchie). This engine module
#  returns a machine-readable confirm prompt the TUI draws.
# ===========================================================================
set -euo pipefail

ACTION_CONFIRM_DIR="$VIBE_STATE/actions"
mkdir -p "$ACTION_CONFIRM_DIR"

# ---- parse a delete request -------------------------------------------------
ve_action_delete() {
  # usage: ve_action_delete "<memory phrase>"
  local phrase="${1:?delete what}"
  local tokens; tokens=$(ve_query_tokenize "$phrase")
  local time_window; time_window=$(ve_query_resolve_time "$tokens")
  IFS=' ' read -r tlo thi <<<"$time_window"
  tlo=${tlo//[^0-9]/}; thi=${thi//[^0-9]/}
  [ -z "$tlo" ] && tlo=0; [ -z "$thi" ] && thi=$(date +%s)
  local tcenter=$(( (tlo + thi) / 2 ))

  local qcat; qcat=$(ve_query_resolve_cat "$tokens")

  # ---- fetch candidates (strict, then relaxed cascade) -----------------------
  local fetched
  fetched=$(ve_query_fetch_candidates "$tokens" "$tlo" "$thi" "$qcat")
  if [ "$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 1 ]; then
    local infotok; infotok=$(ve_query_informative_tokens "$tokens")
    fetched=$(ve_query_fetch_candidates "$infotok" "$tlo" "$thi" "$qcat")
  fi
  if [ "$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 1 ]; then
    fetched=$(ve_query_fetch_expanded "$tokens" "$tlo" "$thi" "$qcat")
  fi
  if [ "$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 1 ]; then
    fetched=$(ve_query_fetch_by_category_or_time "$tokens" "$tlo" "$thi" "$qcat")
  fi

  local count; count=$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')
  if [ "$count" -lt 1 ]; then
    echo "DEXEMPT|nothing matching that is in memory — nothing could be deleted."
    return 0
  fi

  # ---- score + rank the candidates -------------------------------------------
  local scored ranked
  scored=$(echo "$fetched" | while IFS= read -r cand; do
    local fp=$(echo "$cand" | cut -d'|' -f5)
    local envelope; envelope=$(ve_index_fp_to_envelope "$fp" 2>/dev/null)
    [ -z "$envelope" ] && continue
    ve_match_score_candidate "$fp" "$tokens" "$qcat" "$tcenter" "" "$envelope"
  done)
  ranked=$(echo "$scored" | ve_rank_run 8)

  # ---- stage the target files -------------------------------------------------
  local pid; pid="d$$"
  local idfile="$ACTION_CONFIRM_DIR/$pid.targets"
  : > "$idfile"

  # walk ranked lines to collect REAL file paths (skip virtual/web memories)
  local line
  while IFS= read -r line; do
    local rfp rcat rpath
    rfp=$(echo "$line" | cut -d'|' -f3)
    # reconstruct path: envelope is at field 9+ of scored line; in ranked
    # line layout it is fields 4-10 of the appended env (epoch|type|source|path|fp2|catpath|meta)
    rpath=$(echo "$line" | cut -d'|' -f7)
    rcat=$(echo "$line"  | cut -d'|' -f9)
    if [ -n "$rpath" ] && [ -e "$rpath" ]; then
      local sz age
      sz=$(du -sh "$rpath" 2>/dev/null | cut -f1 || echo "?")
      age=$(ve_rank_relative_time "$(stat -c %Y "$rpath" 2>/dev/null || echo 0)")
      printf '%s|%s|%s|%s\n' "$rfp" "$rpath" "$sz" "$age" >> "$idfile"
    fi
  done <<< "$(echo "$ranked")" 2>/dev/null || true

  local realcount; realcount=$(wc -l < "$idfile" 2>/dev/null || echo 0)

  if [ "$realcount" -eq 0 ]; then
    # nothing real found; offer the memory entries as deletable-alternatives
    echo "DEXEMPT|Found memories but no actual files to delete."
    echo "REVIEW|$pid|$phrase"
    return 0
  fi

  # ---- render the review + 3 buttons -----------------------------------------
  echo "REVIEW|$pid|$phrase"
  echo "BUTTONS|ok-delete|cancel|find-another"
  local idx=0
  while IFS='|' read -r fp2 rpath2 sz2 age2; do
    idx=$((idx + 1))
    printf 'ITEM|%02d|%s|%s|%s\n' "$idx" "$rpath2" "$sz2" "$age2"
  done < "$idfile"
}

# ---- confirm + execute (called by TUI when OK pressed) ------------------------
ve_action_delete_confirm() {
  local pid="${1:?pid}"
  local idfile="$ACTION_CONFIRM_DIR/$pid.targets"
  echo "Deleting:"
  local total=i
  while IFS='|' read -r fp2 rpath2 sz2 age2; do
    if [ -e "$rpath2" ]; then
      rm -rf "$rpath2" && echo "  DELETED  $rpath2" || echo "  FAILED   $rpath2"
      # also forget from Searchie memory
      [ -n "$fp2" ] && ve_action_forget "$fp2"
    fi
  done < "$idfile"
  rm -f "$idfile"
  ve_store_optimize
  echo "Done."
}

# ---- forget one fingerprint from ALL memory structures -----------------------
ve_action_forget() {
  local fp="${1:?fp}"
  # 1) event logs
  find "$VIBE_EVENTS" -name '*.log' -type f -exec sed -i "/|$fp|/d" {} + 2>/dev/null || true
  # 2) category trie index files
  find "$VIBE_TREE" -name index -type f -exec sed -i "/ $fp$/d" {} + 2>/dev/null || true
  # 3) inverted index
  find "$VIBE_INDEX/inv" -type f -exec sed -i "/ ${fp} /d" {} + 2>/dev/null || true
  find "$VIBE_INDEX/inv" -type f -exec sed -i "/^${fp} /d" {} + 2>/dev/null || true
  # 4) time buckets
  find "$VIBE_INDEX/time" -type f -exec sed -i "/ ${fp}$/d" {} + 2>/dev/null || true
  # 5) fp table + dedup
  rm -f "$VIBE_INDEX/fp/$fp" 2>/dev/null || true
  sed -i "/^$fp /d" "$VIBE_INDEX/dedup.hash" 2>/dev/null || true
}

# ---- the TUI asks "find another" -> bump relaxation and restage --------------
ve_action_find_alternative() {
  local phrase="${1:?phrase}"
  # relax harder: any-token single match, then recency-only
  local tokens; tokens=$(ve_query_tokenize "$phrase")
  local time_window; time_window=$(ve_query_resolve_time "$tokens")
  IFS=' ' read -r tlo thi <<<"$time_window"
  tlo=${tlo//[^0-9]/}; thi=${thi//[^0-9]/}
  local qcat; qcat=$(ve_query_resolve_cat "$tokens")

  local fetched
  fetched=$(ve_query_fetch_by_category_or_time "$tokens" "$tlo" "$thi" "$qcat")
  if [ "$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 1 ]; then
    fetched=$(ve_query_fetch_recent_any "$tlo" "$thi")
  fi
  if [ "$(echo "$fetched" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 1 ]; then
    echo "DEXEMPT|No alternative memory found either."
    return 0
  fi
  echo "$fetched"

  echo "ALTERNATIVES|review below — choose which to delete, or ask differently"
}

ve_action=""
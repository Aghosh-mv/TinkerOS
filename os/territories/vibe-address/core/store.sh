#!/bin/bash
# ===========================================================================
#  core/store.sh — PERSISTENT EVENT STORE (append-only log + integrity)
# ---------------------------------------------------------------------------
#  Append-only day-log: $VIBE_EVENTS/YYYY-MM-DD.log
#  Each line = canonical envelope (epoch|type|source|path|fp|catpath|meta)
#
#  Guarantees:
#    - log rotation by day (auto-create new file)
#    - append-only: lines never modified, only added
#    - integrity: sha256 per log segment stored in $VIBE_STATE/integrity/
#    - compaction: merge old day-logs into monthly archive + rebuild index
#    - replay: on corruption, truncate to last valid sha256 boundary
# ===========================================================================
set -euo pipefail

# ---- append a line to today's log (atomic via temp + cat) ------------------
ve_store_append() {
  local line="$1"
  local today; today=$(date +%Y-%m-%d)
  local logfile="$VIBE_EVENTS/$today.log"
  mkdir -p "$VIBE_EVENTS"
  printf '%s\n' "$line" >> "$logfile"
  # periodic integrity stamp every 500 lines
  local nlines; nlines=$(wc -l < "$logfile" 2>/dev/null || echo 0)
  if [ $((nlines % 500)) -eq 0 ] && [ "$nlines" -gt 0 ]; then
    ve_store_stamp_integrity "$logfile"
  fi
}

# ---- integrity stamp (sha256 of log segment) --------------------------------
ve_store_stamp_integrity() {
  local logfile="$1"
  local idir="$VIBE_STATE/integrity"
  mkdir -p "$idir"
  local fname; fname=$(basename "$logfile")
  sha256sum "$logfile" > "$idir/$fname.sha256" 2>/dev/null || true
}

# ---- verify integrity of a single log ---------------------------------------
ve_store_verify_log() {
  local logfile="$1"
  local idir="$VIBE_STATE/integrity"
  local fname; fname=$(basename "$logfile")
  local shafile="$idir/$fname.sha256"
  [ -f "$shafile" ] || { echo "no-stamp"; return 0; }
  local expected; expected=$(awk '{print $1}' "$shafile")
  local actual; actual=$(sha256sum "$logfile" 2>/dev/null | awk '{print $1}')
  if [ "$expected" = "$actual" ]; then
    echo "valid"
  else
    echo "corrupted"
  fi
}

# ---- count events in a time range -------------------------------------------
ve_store_count_range() {
  local lo="$1" hi="$2"
  local count=0
  local f
  while IFS= read -r f; do
    while IFS='|' read -r ts _rest; do
      ts=${ts:0:12}
      if [ "$ts" -ge "$lo" ] && [ "$ts" -le "$hi" ] 2>/dev/null; then
        count=$((count + 1))
      fi
    done < "$f"
  done < <(find "$VIBE_EVENTS" -name "*.log" -type f 2>/dev/null)
  echo "$count"
}

# ---- count total events ----------------------------------------------------
ve_store_total() {
  cat "$VIBE_EVENTS"/*.log 2>/dev/null | grep -c '|' || echo 0
}

# ---- stats output -----------------------------------------------------------
ve_store_stats() {
  echo "========================================"
  echo "  TinkerOS Vibe Addressing — Store"
  echo "========================================"
  echo "  Version       : $VIBE_VERSION"
  echo "  Engine format : $VIBE_FORMAT"
  echo "  Home          : $VIBE_HOME"
  echo
  echo "  Events"
  echo "    total       : $(ve_store_total)"
  local today; today=$(date +%Y-%m-%d)
  local tcount; tcount=$(wc -l < "$VIBE_EVENTS/$today.log" 2>/dev/null || echo 0)
  echo "    today       : $tcount"
  echo
  echo "  Storage"
  echo "    day-logs    : $(find "$VIBE_EVENTS" -name "*.log" -type f 2>/dev/null | wc -l) files"
  echo "    total bytes : $(du -sb "$VIBE_HOME" 2>/dev/null | cut -f1 || echo 0)"
  echo "    sig rows    : $(ve_lsh_sigdir 2>/dev/null >/dev/null; ls "$(ve_lsh_dir)/sig" 2>/dev/null | wc -l) signatures"
  echo "    near-dup prs: $(ve_lsh_dupe_count 2>/dev/null)"
  echo
  echo "  Integrity"
  local valid=0 bad=0
  while IFS= read -r f; do
    case "$(ve_store_verify_log "$f")" in
      valid)      valid=$((valid + 1)) ;;
      corrupted)  bad=$((bad + 1)) ;;
    esac
  done < <(find "$VIBE_EVENTS" -name "*.log" -type f 2>/dev/null)
  echo "    valid logs  : $valid"
  echo "    corrupted   : $bad"
  echo
  echo "  Index"
  ve_index_stats
  echo "========================================"
}

# ---- per-day event timeline: counts + last-seen fingerprints ----------------
ve_store_timeline() {
  echo "Timeline: events per day (UTC) + latest fingerprints"
  echo "  date       count  last-seen fp          last path"
  awk -F'|' '
    /^[0-9]+/ {
      cmd = "date -u -d @" $1 " +%Y-%m-%d"; cmd | getline d; close(cmd);
      cnt[d]++; lastfp[d] = $5; lastpath[d] = $4
    }
    END { for (d in cnt) printf "  %-11s %5d  %-16s %s\n", d, cnt[d], lastfp[d], lastpath[d] }
  ' "$VIBE_EVENTS"/*.log 2>/dev/null | sort

  # sparkline: map daily counts to Unicode block chars
  local -a counts=()
  while IFS= read -r line; do
    local c; c=$(echo "$line" | awk '{print $2}')
    counts+=("$c")
  done < <(
    awk -F'|' '
      /^[0-9]+/ {
        cmd = "date -u -d @" $1 " +%Y-%m-%d"; cmd | getline d; close(cmd);
        cnt[d]++
      }
      END { for (d in cnt) printf "%s %d\n", d, cnt[d] }
    ' "$VIBE_EVENTS"/*.log 2>/dev/null | sort
  )
  if [ ${#counts[@]} -gt 0 ]; then
    local mn=${counts[0]} mx=${counts[0]}
    for c in "${counts[@]}"; do
      [ "$c" -lt "$mn" ] && mn=$c
      [ "$c" -gt "$mx" ] && mx=$c
    done
    local span=$((mx - mn))
    local spark="  sparkline:"
    for c in "${counts[@]}"; do
      local idx=0
      if [ "$span" -gt 0 ]; then
        idx=$(awk -v c="$c" -v mn="$mn" -v s="$span" 'BEGIN{printf "%d", (c-mn)*7/s}')
      fi
      case $idx in
        0) spark="$spark▁" ;; 1) spark="$spark▂" ;; 2) spark="$spark▃" ;;
        3) spark="$spark▄" ;; 4) spark="$spark▅" ;; 5) spark="$spark▆" ;;
        6) spark="$spark▇" ;; 7) spark="$spark█" ;; *) spark="$spark▁" ;;
      esac
    done
    echo "$spark"
  fi
}

# ---- compact: merge old logs + rebuild --------------------------------------
ve_store_optimize() {
  local dry=0 burn=0
  for arg in "$@"; do
    case "$arg" in
      --dry-run|-n) dry=1 ;;
      --burn)       burn=1 ;;
    esac
  done
  echo "Vibe Addressing: running compaction..."
  ve_store_stamp_integrity_all
  ve_index_rebuild
  ve_store_prune_dedup
  local dupes; dupes=$(ve_lsh_dupe_scan 2>/dev/null | wc -l | tr -d ' ')
  echo "  near-duplicate signature pairs (candidate, not removed): $dupes"
  if [ "$burn" -eq 1 ]; then
    if [ "$dry" -eq 1 ]; then
      echo "  [dry-run] would burn exact-duplicate logical items (all 8 LSH rows, same name tokens)"
      echo "  [dry-run] would rebuild: index, bloom, sarray, lsh"
    else
      echo "  burning exact-duplicate logical items (all 8 LSH rows, same name tokens)..."
      ve_lsh_dupe_prune_burn >/dev/null 2>&1 || true
      ve_index_rebuild
      ve_bloom_rebuild
      ve_sarray_rebuild
      ve_lsh_rebuild
    fi
  elif [ "$dry" -eq 1 ]; then
    echo "  [dry-run] compaction plan: stamp integrity, rebuild index, prune dedup, scan dupes"
    echo "  [dry-run] no changes made (dry run)"
  fi
  echo "Compaction complete."
}

ve_lsh_rebuild() {
  ve_lsh_sigdir >/dev/null 2>&1 || true
  local f env path vtype source catpath meta toks
  local a; local b; local c; local d; local e
  while IFS= read -r f; do
    env=$(ve_index_fp_to_envelope "$f" 2>/dev/null)
    [ -z "$env" ] && continue
    a="${env%%|*}"; b="${env#*|}"
    vtype="${b%%|*}"; b="${b#*|}"
    source="${b%%|*}"; b="${b#*|}"
    path="${b%%|*}";  b="${b#*|}"
    c="${b%%|*}";     b="${b#*|}"
    catpath="${b%%|*}"; meta="${b#*|}"
    toks="$(ve_ingest_name_tokens "$path" "$meta" 2>/dev/null) $(ve_ingest_source_tokens "$source" 2>/dev/null) $(ve_ingest_type_tokens "$vtype" 2>/dev/null) $catpath"
    [ -n "$toks" ] || continue
    ve_lsh_index "$f" "$toks" >/dev/null 2>&1 || true
  done < <(ls "$VIBE_INDEX/fp" 2>/dev/null)
}

ve_store_stamp_integrity_all() {
  local f
  while IFS= read -r f; do ve_store_stamp_integrity "$f"; done \
    < <(find "$VIBE_EVENTS" -name "*.log" -type f 2>/dev/null)
}

# ---- dedup: remove duplicate fp lines across logs ----------------------------
ve_store_prune_dedup() {
  local tmp; tmp=$(mktemp)
  cat "$VIBE_EVENTS"/*.log 2>/dev/null | sort -t'|' -k5 -u > "$tmp"
  local count_before; count_before=$(cat "$VIBE_EVENTS"/*.log 2>/dev/null | wc -l)
  local count_after; count_after=$(wc -l < "$tmp")
  local removed=$((count_before - count_after))
  if [ "$removed" -gt 0 ]; then
    echo "  dedup: removed $removed duplicate events"
    # rewrite today's log only (old logs are archive)
    local today; today=$(date +%Y-%m-%d)
    [ -f "$tmp" ] && cp "$tmp" "$VIBE_EVENTS/$today.log"
  fi
  rm -f "$tmp"
}

# ---- replay: rebuild state from logs ----------------------------------------
ve_store_replay() {
  echo "Replaying all event logs..."
  ve_index_rebuild
  echo "Replay complete."
}

ve_store=""
#!/bin/bash
# ===========================================================================
#  core/retention.sh — MEMORY RETENTION / HOT-COLD ARCHIVING
# ---------------------------------------------------------------------------
#  Searchie memory grows with every event the OS observes. A month of
#  heavy use can mean hundreds of thousands of events. To keep queries
#  millisecond-fast AND never discard the user's history, memory is
#  split into tiers:
#
#    HOT   recent events (last $VIBE_RETENTION_HOT_DAYS days, default 30)
#          — fully indexed: inverted index + fp table + time buckets, live
#    COLD  everything older — compressed per-month archives that are only
#          decompressed for a query whose time-window overlaps that month
#
#  Space is deliberately generous (this is the user's own disk, like a
#  real file manager). Archives are gzip'd so a year of memory stays
#  small, but nothing is ever silently deleted.
#
#  Rotation is safe: an event is moved cold only when its DAY-LOG is no
#  longer the current one, and query paths transparently page cold months
#  back in for overlapping time windows.
# ===========================================================================
set -euo pipefail

VIBE_RETENTION_HOT_DAYS="${VIBE_RETENTION_HOT_DAYS:-30}"

# ---- archive a day-log that is older than the hot window -------------------
ve_retention_rotate() {
  local cutoff; cutoff=$(date -d "-${VIBE_RETENTION_HOT_DAYS} days" +%Y-%m-%d)
  local archive="$VIBE_STATE/archive"
  mkdir -p "$archive"

  local log
  for log in "$VIBE_EVENTS"/*.log; do
    [ -e "$log" ] || continue
    local fname; fname=$(basename "$log")   # YYYY-MM-DD.log
    local day="${fname%.log}"
    # skip today + hot window
    if [ "$day" \> "$cutoff" ] 2>/dev/null; then continue; fi

    # move to cold archive (gzip)
    local cold="$archive/${fname}.gz"
    : > "$cold.pending"
    cat "$log" | gzip -1 -c > "$cold" 2>/dev/null
    # only remove the live log after the cold copy exists
    if [ -s "$cold" ]; then
      rm -f "$log" "$cold.pending"
    fi
  done
}

# ---- total memory footprint (hot + cold) -------------------------------------
ve_retention_usage() {
  local hot; hot=$(du -sb "$VIBE_EVENTS" 2>/dev/null | cut -f1 || echo 0)
  local cold; cold=$(du -sb "$VIBE_STATE/archive" 2>/dev/null | cut -f1 || echo 0)
  local idx;  idx=$(du -sb "$VIBE_INDEX" 2>/dev/null | cut -f1 || echo 0)
  echo "hot-events=$hot cold-archive=$cold index=$idx"
}

# ---- page a cold month back in for a query window overlapping it ------------
ve_retention_page_in() {
  local lo="$1" hi="$2"
  local lo_day; lo_day=$(date -u -d @$lo +%Y-%m 2>/dev/null || echo "")
  local hi_day; hi_day=$(date -u -d @$hi +%Y-%m 2>/dev/null || echo "")
  [ -z "$lo_day" ] && return 0
  local archive="$VIBE_STATE/archive"
  # candidate months between lo and hi
  local y m
  for f in "$archive"/*.log.gz; do
    [ -e "$f" ] || continue
    local fname; fname=$(basename "$f")
    local month="${fname%.log.gz}"
    if [ -n "$hi_day" ] && [[ "$month" < "${lo_day:0:7}" ]] 2>/dev/null; then continue; fi
    if [ -n "$hi_day" ] && [[ "$month" > "${hi_day:0:7}" ]] 2>/dev/null; then continue; fi
    # it overlaps the window — page it into the live index (merge)
    ve_retention_merge_archive "$f"
  done
}

# ---- merge one archive into the live index (idempotent) --------------------
ve_retention_merge_archive() {
  local gz="$1"
  # replay the archived events through bulk ingest (dedup protects us)
  zcat "$gz" 2>/dev/null | ve_ingest_bulk > /dev/null 2>&1 || true
  # mark merged so we don't re-merge every time (rename to .done)
  mv "$gz" "${gz%.gz}.done.gz" 2>/dev/null || true
}

ve_retention=""
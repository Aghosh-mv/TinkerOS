#!/bin/bash
# ===========================================================================
#  core/capacity.sh — STORAGE CAPACITY MANAGER (replaces half-life decay)
# ---------------------------------------------------------------------------
#  The user's rule: memory does NOT decay with time.  The only limit is the
#  disk budget it occupies.  When the store reaches its capacity the OS
#  does not silently age anything out — it surfaces warnings, then LOCKS
#  new writes at 100%.  The only allowed actions at full lock:
#      open existing things   and   clear/delete (frees space).
#  No event is ever auto-evicted.  This module tracks the footprint,
#  derives a utilisation percentage, persists a status marker, and emits
#  warnings when thresholds are crossed (once per level, not spam).
# ===========================================================================
set -euo pipefail

VIBE_CAP_WARN="${VIBE_CAP_WARN:-80}"
VIBE_CAP_CRIT="${VIBE_CAP_CRIT:-90}"
VIBE_CAP_FULL="${VIBE_CAP_FULL:-100}"
VIBE_CAP_BYTES="${VIBE_CAP_BYTES:-5368709120}"   # 5 GiB default memory budget
VIBE_CAP_POLL_MS="${VIBE_CAP_POLL_MS:-900}"      # min sweep interval (s)

ve_capacity_dir() { echo "${VIBE_STATE:-$VIBE_HOME/state}/cap"; }

# ---- total store footprint in bytes (events + index + archive + state) -------
ve_capacity_usage() {
  local total=0 b
  for b in "$VIBE_EVENTS" "$VIBE_INDEX" "$VIBE_STATE/archive" "$VIBE_STATE/bloom"; do
    local n; n=$(du -sb "$b" 2>/dev/null | cut -f1 || echo 0)
    total=$((total + n))
  done
  echo "$total"
}

# ---- utilisation percent (0..100), floored at 0, ceiling 100 ----------------
ve_capacity_pct() {
  local used; used=$(ve_capacity_usage)
  if [ "$used" -le 0 ]; then echo 0; return; fi
  awk -v u="$used" -v b="$VIBE_CAP_BYTES" 'BEGIN{
    if (u >= b) print 100; else printf "%d", int(u * 100 / b)
  }'
}

# ---- simple numeric label: ok / warn / crit / full ---------------------------
ve_capacity_level() {
  local p; p=$(ve_capacity_pct)
  if   [ "$p" -ge "$VIBE_CAP_FULL" ]; then echo full
  elif [ "$p" -ge "$VIBE_CAP_CRIT" ]; then echo crit
  elif [ "$p" -ge "$VIBE_CAP_WARN"  ]; then echo warn
  else echo ok; fi
}

# ---- can the store accept a new event? (1 = locked) --------------------------
ve_capacity_can_write() {
  [ "$(ve_capacity_level)" = "full" ] && return 1
  return 0
}

# ---- list of allowed actions at full lock -------------------------------------
ve_capacity_allowed_at_full() {
  local p; p=$(ve_capacity_pct)
  if [ "$p" -ge "$VIBE_CAP_FULL" ]; then
    echo "store is at ${p}% — locked for new memory. open existing things; clear/delete to free space"
  fi
}

# ---- persisted state: last level + first-crossing log ------------------------
ve_capacity_state() { echo "$(ve_capacity_dir)/level"; }
ve_capacity_events() { echo "$(ve_capacity_dir)/events"; }

ve_capacity_ingest() {  # bytes
  local bytes="$1"
  mkdir -p "$(ve_capacity_dir)"
  printf '%s %s %s\n' "$(date +%s)" "$bytes" "$(ve_capacity_pct)" >> "$(ve_capacity_events)"
}

# ---- sweep: recompute, cross thresholds ONCE, persist marker ----------------
ve_capacity_sweep() {
  local inc; inc="$(ve_capacity_dir)/.last"
  local now;  now=$(date +%s)
  mkdir -p "$(ve_capacity_dir)"
  if [ -f "$inc" ]; then
    local last; last=$(cat "$inc" 2>/dev/null || echo 0)
    if [ $((now - last)) -lt "$VIBE_CAP_POLL_MS" ]; then :; fi
  fi
  echo "$now" > "$inc"
  local p; p=$(ve_capacity_pct)
  local lvl; lvl=$(ve_capacity_level)
  local prev; prev=$(cat "$(ve_capacity_state)" 2>/dev/null || echo "")
  echo "$lvl" > "$(ve_capacity_state)"

  if [ -n "$prev" ] && [ "$prev" != "$lvl" ]; then
    local rank
    case "$lvl" in
      ok) rank=0;; warn) rank=1;; crit) rank=2;; full) rank=3;;
    esac
    case "$prev" in
      ok) prevrank=0;; warn) prevrank=1;; crit) prevrank=2;; full) prevrank=3;;
    esac
    if [ "$rank" -gt "$prevrank" ]; then
      printf 'WARN|capacity %s%% (%s | threshold crossed %s->%s)\n' \
        "$p" "$lvl" "$prev" "$lvl" >> "$(ve_capacity_events)"
    fi
  elif [ -z "$prev" ]; then
    printf 'INFO|capacity init %s%% (%s)\n' "$p" "$lvl" >> "$(ve_capacity_events)"
  fi

  echo "$p|$lvl|$(ve_capacity_usage)"
}

# ---- human banner for the ask/record surfaces --------------------------------
ve_capacity_banner() {
  local lvl; lvl=$(ve_capacity_level)
  [ "$lvl" = "ok" ] && return 0
  local p; p=$(ve_capacity_pct)
  echo "  [memory ${p}% — ${lvl}. $([ "$lvl" = full ] && echo 'locked: open/clear only' || echo 'free space or clear to drop this warning')]" >&2
}

ve_capacity_host() {  # status line for searchie overlay (WARN|... protocol)
  local lvl; lvl=$(ve_capacity_level)
  [ "$lvl" = "ok" ] && return 0
  local p; p=$(ve_capacity_pct)
  echo "WARN|memory ${p}% (${lvl})"
}

ve_capacity=""
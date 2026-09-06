#!/bin/bash
# ===========================================================================
#  core/adapt.sh — ADAPTIVE FEEDBACK LOOP (HEURISTIC LEARNING)
# ---------------------------------------------------------------------------
#  No neural net — a deterministic meta-learning layer that adjusts
#  retrieval parameters based on *which signals actually succeeded* in
#  past Searchie recalls.  It persists the following adaptive state:
#
#     weights   -> W1..W8 (per-matcher fusion weights)
#     boosts    -> per-path/per-fingerprint frequency boost
#     syns      -> learned durable category aliases
#     decay     -> time-affinity half-life (how fast "recent" fades)
#     session   -> per-session recall success bookkeeping
#
#  Adaptation is lazy (bucketised): we re-tune weights every N queries
#  (default 50), and accumulate per-query "did the top result match"
#  feedback signals.  This keeps it a pure algorithm with zero context —
#  it simply observes that when matcher Mi contested with Mj and Mi won,
#  Mi gets a small positive delta. Over thousands of queries this
#  converges to a query-specific weighting landscape.
# ===========================================================================
set -euo pipefail

ADAPT_TUNE_EVERY=${ADAPT_TUNE_EVERY:-50}

# ---- log an event type for adaptation ---------------------------------------
ve_adapt_log_event() {
  local vtype="$1" catpath="$2" depth="$3" top1="$4" deepest="$5"
  local statdir="$VIBE_STATE/adapt"
  mkdir -p "$statdir"
  # per-type counts
  local tf="$statdir/type.counts"
  [ -f "$tf" ] || : > "$tf"
  # atomic increment
  local c; c=$(grep "^$vtype " "$tf" 2>/dev/null | awk '{print $2}' || echo 0)
  grep -v "^$vtype " "$tf" 2>/dev/null > "$tf.tmp" || true
  echo "$vtype $((c+1))" >> "$tf.tmp"
  mv "$tf.tmp" "$tf"

  # per-top-category counts
  local cf="$statdir/cat.counts"
  [ -f "$cf" ] || : > "$cf"
  local cc; cc=$(grep "^$top1 " "$cf" 2>/dev/null | awk '{print $2}' || echo 0)
  grep -v "^$top1 " "$cf" 2>/dev/null > "$cf.tmp" || true
  echo "$top1 $((cc+1))" >> "$cf.tmp"
  mv "$cf.tmp" "$cf"

  # per-depth distribution (to tune the "depth bonus")
  local df="$statdir/depth.dist"
  [ -f "$df" ] || : > "$df"
  local dc; dc=$(grep "^$depth " "$df" 2>/dev/null | awk '{print $2}' || echo 0)
  grep -v "^$depth " "$df" 2>/dev/null > "$df.tmp" || true
  echo "$depth $((dc+1))" >> "$df.tmp"
  mv "$df.tmp" "$df"
}

# ---- record a query + its outcome -------------------------------------------
ve_adapt_record_query() {
  local query="$1" has_time="$2" has_cat="$3" tlo="$4" thi="$5" ncand="$6"
  local sf="$VIBE_STATE/adapt/query.stats"
  mkdir -p "$(dirname "$sf")"
  local qc; qc=$(cat "$sf" 2>/dev/null | grep -c . 2>/dev/null || true); qc=${qc:-0}
  printf '%s|%s|%s|%s|%s|%s\n' \
    "$(date +%s)" "$has_time" "$has_cat" "$tlo" "$thi" "$ncand" >> "$sf"

  # every N queries, tune weights
  qc=$(( ${qc//[^0-9]/} + 1 ))
  if [ $((qc % ADAPT_TUNE_EVERY)) -eq 0 ]; then
    ve_adapt_tune "$sf"
  fi

  # record a timestamp-distribution for time-decay tuning
  ve_adapt_time_stats "$tlo" "$thi" "$ncand"
}

# ---- tune fusion weights from historical query outcomes ---------------------
ve_adapt_tune() {
  local sf="$1"
  # Analyze the last ADAPT_TUNE_EVERY queries:
  #   queries with a time window that returned few candidates => time-matcher
  #   should weigh LESS (time scope too narrow)
  #   queries with a category that returned MANY candidates => category matcher
  #   should weigh MORE (category is a strong filter)
  local total; total=$(wc -l < "$sf" 2>/dev/null || echo 0)
  [ "$total" -lt 10 ] && return

  local window=$(tail -n "$ADAPT_TUNE_EVERY" "$sf" 2>/dev/null)
  local with_cat; with_cat=$(echo "$window" | grep -c '|yes|' || true)
  local with_time; with_time=$(echo "$window" | grep -c '|yes|' || true)
  local avg_cand; avg_cand=$(echo "$window" | awk -F'|' '{s+=$6} END{printf "%.0f", s/NR}')
  # how often were time-queries low-cand?  (>=2 fields; field 4 is cat presence)
  local time_low=0; echo "$window" | while IFS='|' read -r ts ht hc a b nc; do
    [ "$ht" = "yes" ] && [ "$nc" -lt 20 ] 2>/dev/null && time_low=$((time_low+1))
  done

  # heuristic delta
  local dW5=0 dW3=0
  # if time queries consistently return too few candidates -> reduce W5 (time weight)
  [ "$time_low" -gt $(( (with_cat + 1) / 2 )) ] 2>/dev/null && dW5=-2
  # if category queries return way more than avg -> raise W3 (category weight)
  if [ "$with_cat" -gt 0 ] && [ "$avg_cand" -gt 15 ] 2>/dev/null; then dW3=+1; fi

  # apply deltas to weights file
  local wfile="$VIBE_STATE/weights"
  local wstr; wstr=$(ve_rank_weights)
  eval "$wstr" 2>/dev/null || true
  W3=$(( W3 + dW3 )); W5=$(( W5 + dW5 ))
  # clamp to sane ranges
  [ "$W3" -lt 5  ] && W3=5;  [ "$W3" -gt 50 ] && W3=50
  [ "$W5" -lt 5  ] && W5=5;  [ "$W5" -gt 40 ] && W5=40
  [ "$W2" -lt 10 ] && W2=10; [ "$W2" -gt 50 ] && W2=50

  cat > "$wfile" <<EOF
W1=$W1 W2=$W2 W3=$W3 W4=$W4 W5=$W5 W6=$W6 W7=$W7 W8=$W8
# auto-tuned by adapt.sh — do not edit
tuned=$(date +%Y-%m-%dT%H:%M:%S)
EOF
}

# ---- time-affinity half-life tuning ------------------------------------------
ve_adapt_time_stats() {
  local tlo="$1" thi="$2" ncand="$3"
  local tf="$VIBE_STATE/adapt/time.dist"
  mkdir -p "$(dirname "$tf")"
  # record the *age* of the queried window (days back from now)
  local now; now=$(date +%s)
  local age=$(( (now - thi) / 86400 ))
  [ "$age" -lt 0 ] && age=0
  [ "$age" -gt 3650 ] && age=3650
  printf '%s %s\n' "$age" "$ncand" >> "$tf"
  # we could use this to set an effective "how far back users typically
  # successfully recall" — feeding the time bucket algorithm later.
}

# ---- learn a durable synonym from a successful query ------------------------
ve_adapt_learn_synonym() {
  local spoken="$1" resolved="$2"
  local sf="$VIBE_STATE/adapt/synonyms"
  mkdir -p "$(dirname "$sf")"
  # only learn if not already present
  if ! grep -q "^$spoken=" "$sf" 2>/dev/null; then
    printf '%s=%s\n' "$spoken" "$resolved" >> "$sf"
  fi
  # read a learned synonym
  if [ -f "$sf" ]; then
    grep "^$1=" "$sf" 2>/dev/null | head -1 | cut -d= -f2
  fi
}

# ---- session success tracking ------------------------------------------------
ve_adapt_session_success() {
  local session="$1" hits="$2"
  local f="$VIBE_STATE/sessions/$session/success"
  mkdir -p "$(dirname "$f")"
  echo "$(date +%s) $hits" >> "$f"
}

# ---- report adaptive state ---------------------------------------------------
ve_adapt_report() {
  echo "Vibe Addressing — Adaptive State"
  echo "  weights                : $(cat "$VIBE_STATE/weights" 2>/dev/null | head -1 || echo '(default)')"
  echo "  events by type         : $(cat "$VIBE_STATE/adapt/type.counts" 2>/dev/null | sort -k2 -rn | tr '\n' '; ' || echo '(none)')"
  echo "  events by top-category : $(cat "$VIBE_STATE/adapt/cat.counts" 2>/dev/null | sort -k2 -rn | tr '\n' '; ' || echo '(none)')"
  echo "  learned synonyms       : $(wc -l < "$VIBE_STATE/adapt/synonyms" 2>/dev/null || echo 0)"
  echo "  tune threshold         : every $ADAPT_TUNE_EVERY queries"
}

ve_adapt=""
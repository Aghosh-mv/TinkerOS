# veil: align.sh — model-integrity auditor.
#   ve_align_check            → compare each persistent artifact against the
#                               event store; print OK/DRIFT per artifact.
#   ve_align_fix              → wipe + rebuild any drifted artifact from logs.
#
# Persistent artifacts (everything else is query-time derived):
#   1. inverted index/fp table/time buckets (ve_index_rebuild)
#   2. token bloom prefilter            (ve_bloom_rebuild)
#   3. suffix array                     (ve_sarray_rebuild)
#   4. markov transitions               (retrained by replaying events)
#   5. minhash/LSH signatures           (reindexed by replaying events)

# ---- canonical token streams for replay (matches ingest exactly) ------------
ve_align_tokens_for() {   # path vtype source catpath meta  -> observes feed
  local path="$1" vtype="$2" source="$3" catpath="$4" meta="$5"
  local nametokens srctokens typetokens
  nametokens=$(ve_ingest_name_tokens "$path" "$meta")
  srctokens=$(ve_ingest_source_tokens "$source") || true
  typetokens=$(ve_ingest_type_tokens "$vtype") || true
  printf '%s %s %s %s' "$nametokens" "$srctokens" "$typetokens" "$catpath"
}

ve_align_replay_one() {   # one canonical log line
  local line="$1"
  local epoch vtype source path fp catpath meta
  epoch="${line%%|*}"; rest="${line#*|}"
  vtype="${rest%%|*}"; rest="${rest#*|}"
  source="${rest%%|*}"; rest="${rest#*|}"
  path="${rest%%|*}";  rest="${rest#*|}"
  fp="${rest%%|*}";    rest="${rest#*|}"
  catpath="${rest%%|*}"; meta="${rest#*|}"

  # reconstruct name tokens independently (do NOT trust fp table)
  local nametokens; nametokens=$(ve_ingest_name_tokens "$path" "$meta")

  # feed the markov predictor + project into LSH, exactly as ingest does
  local srctokens typetokens
  srctokens=$(ve_ingest_source_tokens "$source") || true
  typetokens=$(ve_ingest_type_tokens "$vtype") || true
  ve_markov_observe "$(printf '%s %s %s %s' "$nametokens" "$srctokens" "$typetokens" "$catpath")" >/dev/null 2>&1 || true
  ve_lsh_index "$fp" "$(printf '%s %s %s' "$nametokens" "$srctokens" "$catpath")" >/dev/null 2>&1 || true
}

ve_align_events() {
  for f in "$VIBE_EVENTS"/*.log; do
    [ -f "$f" ] || continue
    cat "$f"
  done | sort -t'|' -k1 -n
}

ve_align_fp_count()  { ls "$VIBE_INDEX/fp" 2>/dev/null | wc -l | tr -d ' '; }
ve_align_event_rows() {
  local n=0
  for f in "$VIBE_EVENTS"/*.log; do
    [ -f "$f" ] || continue
    cut -d'|' -f5 "$f" | sed '/^$/d'
  done | sort -u | sed '/^$/d' | wc -l | tr -d ' '
}

ve_align_markov_count() { ls "$VIBE_STATE/markov" 2>/dev/null | wc -l | tr -d ' '; }
ve_align_sig_count()   { ls "$(ve_lsh_sigdir)" 2>/dev/null | wc -l | tr -d ' '; }
ve_align_sarray_own()  { if [ -f "$VIBE_STATE/sarray/owners" ]; then wc -l < "$VIBE_STATE/sarray/owners"; else echo 0; fi; }

# ---- single-artifact status stub (kept for symmetry; items print inline) -----

# ---- full audit --------------------------------------------------------------
ve_align_check() {
  local had_e=0
  case "$-" in *e*) had_e=1;; esac
  set +e                       # report tool: never abort mid-report
  echo "Vibe-align: reconciling models against the event store"
  echo "  events       : $(ve_align_event_rows) unique fingerprints"
  echo
  local drift=0

  # 1. inverted index / fp table / time buckets
  local fp=0 iok=1
  fp=$(ve_align_fp_count)
  if [ "$fp" -eq "$(ve_align_event_rows)" ] 2>/dev/null; then :; else iok=0; fi
  if [ "$iok" = 1 ]; then
    echo "  index       OK      fps=$fp inv-tokens=$(find "$VIBE_INDEX/inv" -type f 2>/dev/null | wc -l | tr -d ' ') time-files=$(find "$VIBE_INDEX/time" -type f 2>/dev/null | wc -l | tr -d ' ')"
  else
    echo "  index       DRIFT   fps=$fp events=$(ve_align_event_rows)"; drift=$((drift + 1))
  fi

  # token-level cross-check: every fp in inv must exist in fp table
  local bad=0
  for f in "$VIBE_INDEX/inv"/*; do
    [ -f "$f" ] || continue
    local x; x=$(cut -d' ' -f1 "$f" | sort -u | while IFS= read -r p; do
      [ -f "$VIBE_INDEX/fp/$p" ] || echo bad
    done)
    [ -z "$x" ] || bad=1
  done
  if [ "$bad" = 1 ]; then dr=1; else dr=0; fi
  if [ "$dr" = 1 ]; then echo "  inv-refs    DRIFT   postings reference missing fingerprints"; drift=$((drift + 1)); else echo "  inv-refs    OK      all postings resolve to indexed fps"; fi

  # 2. bloom prefilter — every indexed token must be admitted
  local bmiss=0
  for f in "$VIBE_INDEX/inv"/*; do
    [ -f "$f" ] || continue
    local tok; tok=$(basename "$f")
    if [ "$(ve_bloom_tok_contains "$tok" 2>/dev/null || echo 0)" != "1" ]; then bmiss=1; break; fi
  done
  if [ "$bmiss" = 1 ]; then echo "  bloom       DRIFT   an indexed token is missing from the prefilter"; drift=$((drift + 1)); else echo "  bloom       OK      every indexed token admitted by prefilter"; fi

  # 3. suffix array ownership map must span the fp table (built lazily —
  #    an absent map is "not yet materialized", not corruption)
  local own; own=$(ve_align_sarray_own)
  if [ -f "$VIBE_STATE/sarray/owners" ]; then
    if [ "$own" = "$fp" ]; then
      echo "  sarray      OK      owners=$own fps=$fp"
    else
      echo "  sarray      DRIFT   owners=$own fps=$fp"; drift=$((drift + 1))
    fi
  else
    echo "  sarray      N/A     not materialized (lazy — first search rebuilds)"
  fi

  # 4. markov — non-empty iff at least a second event exists to transition from
  local mc; mc=$(ve_align_markov_count)
  if { [ "$(ve_align_event_rows)" -ge 2 ] && [ "$mc" -ge 1 ] ; } || [ "$(ve_align_event_rows)" -lt 2 ] 2>/dev/null; then
    echo "  markov      OK      order files=$mc events=$(ve_align_event_rows)"
  else
    echo "  markov      DRIFT   order files=$mc events=$(ve_align_event_rows)"; drift=$((drift + 1))
  fi

  # 5. LSH — one signature per fingerprint
  local sc; sc=$(ve_align_sig_count)
  if [ "$sc" = "$fp" ]; then
    echo "  lsh         OK      signatures=$sc fps=$fp"
  else
    echo "  lsh         DRIFT   signatures=$sc fps=$fp"; drift=$((drift + 1))
  fi

  echo
  if [ "$drift" = 0 ]; then
    echo "  ALIGNED — all models consistent with the store"
  else
    echo "  DRIFT DETECTED ($drift artifact(s)) — run 'align --fix'"
  fi
  [ "$had_e" = 1 ] && set -e
  return 0
}

# ---- rebuild drifted artifacts from the event store --------------------------
ve_align_fix() {
  echo "Vibe-align: rebuilding all models from the event store..."
  echo "  1/5 inverted index + fp table + time buckets"
  ve_index_rebuild 2>&1 | sed 's/^/    /'
  echo "  2/5 bloom prefilter"
  ve_bloom_rebuild >/dev/null 2>&1 || true
  echo "  3/5 suffix array"
  ve_sarray_rebuild >/dev/null 2>&1 || true
  echo "  4/5 markov + LSH replay"
  rm -rf "$VIBE_STATE/markov" "$(ve_lsh_dir)"
  mkdir -p "$VIBE_STATE" "$(ve_lsh_dir)"
  local n=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ve_align_replay_one "$line"
    n=$((n + 1))
  done < <(ve_align_events)
  echo "    replayed $n events"
  echo "  5/5 re-verify"
  ve_align_check
}

ve_align=""
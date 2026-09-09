#!/bin/bash
# ===========================================================================
#  vibe-address.sh — TinkerOS VIBE ADDRESSING ENGINE (dispatcher)
# ---------------------------------------------------------------------------
#  Pure-algorithm memory retrieval. NO AI. NO models. 5000+ lines of
#  deterministic software across an engine kernel:
#
#    core/tree.sh    deep category trie, dynamic deepening, path algebra
#    core/time.sh    temporal lattice, NL time parsing, fuzzy windows, decay
#    core/ingest.sh  event capture pipeline, normalization, dedup, snapshots
#    core/index.sh   inverted index (token->ids), fingerprint table, tries
#    core/match.sh   matchers: lexical / fuzzy / category / source / digest
#    core/rank.sh    multi-model scoring + fusion + winner-takes-all
#    core/query.sh   query planner: tokenize, synonym rings, intent, plan
#    core/adapt.sh   feedback loop: learns which signals mattered (heuristic)
#    core/store.sh   append-only log, compaction, integrity, replay
#
#  This file is ONLY the front door: env, sourcing, command dispatch, and
#  the Tab+F7 interactive query session.
# ===========================================================================
set -euo pipefail
IFS=$'\n\t'

# ---- installation layout (self-locating) ---------------------------------
VIBE_ENGINE="${VIBE_ENGINE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# ---- per-user state ------------------------------------------------------
VIBE_HOME="${VIBE_HOME:-$HOME/.local/share/tinkeros/vibe}"
VIBE_EVENTS="$VIBE_HOME/events"     # append-only day logs
VIBE_TREE="$VIBE_HOME/tree"         # category trie (dirs + index files)
VIBE_INDEX="$VIBE_HOME/index"       # inverted index + fingerprints
VIBE_STATE="$VIBE_HOME/state"       # adapt/learned weights, sessions
VIBE_CACHE="$VIBE_HOME/cache"       # precomputed parse artifacts
VIBE_CONFIG="${VIBE_CONFIG:-$HOME/.config/tinkeros/vibe.conf}"
mkdir -p "$VIBE_EVENTS" "$VIBE_TREE" "$VIBE_INDEX" "$VIBE_STATE" "$VIBE_CACHE"
mkdir -p "$(dirname "$VIBE_CONFIG")"

# ---- version / banner -----------------------------------------------------
VIBE_VERSION="0.4.0"
VIBE_FORMAT="VT4"           # event-log format tag
VIBE_MAX_DEPTH=0            # 0 = unlimited category depth

# ---------------------------------------------------------------------------
# source the engine kernel (each module provides namespaced functions)
# ---------------------------------------------------------------------------
for mod in adapt action audit auto align bloom bulk capacity cms dista index lsh markov prf sarray ingest ir lexin match phoneme rank query retention selftest store time tree; do
  m="$VIBE_ENGINE/core/$mod.sh"
  if [ -r "$m" ]; then
    # shellcheck disable=SC1090
    source "$m"
  else
    echo "vibe: ENGINE MODULE MISSING: $m (aborting)" >&2
    exit 1
  fi
done

# optional connectors (bootstrap sweep etc.)
if [ -r "$VIBE_ENGINE/connectors/bootstrap.sh" ]; then
  # shellcheck disable=SC1090
  source "$VIBE_ENGINE/connectors/bootstrap.sh"
fi

# ---------------------------------------------------------------------------
# global session registry (so --session X is remembered for Tab+F7 resumes)
# ---------------------------------------------------------------------------
ve_session_init() {
  local name="${1:-default}"
  local dir="$VIBE_STATE/sessions/$name"
  mkdir -p "$dir"
  if [ ! -f "$dir/meta.conf" ]; then
    echo "created=$(date +%s)"       > "$dir/meta.conf"
    echo "queries=0"                 >> "$dir/meta.conf"
    echo "recalls=0"                 >> "$dir/meta.conf"
    echo "last_query=none"           >> "$dir/meta.conf"
  fi
  printf '%s' "$name" > "$VIBE_STATE/current"
  echo "$dir" >&2
}

ve_session_bump() {  # what=queries|recalls
  local dir; dir="$VIBE_STATE/sessions/$(cat "$VIBE_STATE/current" 2>/dev/null || echo default)"
  local key="$1"; local now; now=$(grep -c . "/dev/null" 2>/dev/null; :; )
  if [ -f "$dir/meta.conf" ]; then
    local n; n=$(grep "^$key=" "$dir/meta.conf" 2>/dev/null | cut -d= -f2- | tr -dc '0-9' || echo 0)
    sed -i "s/^$key=.*/$key=$((n+1))/" "$dir/meta.conf" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
usage() {
  cat <<'USAGE'
TinkerOS Vibe Addressing Engine  (pure algorithms — no AI)

  record        TYPE SOURCE PATH [FP] [CATPATH] [META]
  watch         register an OS event connector (tab/download/search/file)
  ask           "memory phrase"  -> ranked results table (Tab+F7 session)
  planner       "memory phrase"  -> show the compiled query plan
  delete        "memory phrase"  -> stage matched files (REVIEW/ITEM/3 buttons)
  confirm       PID              -> execute a staged delete (only after OK)
  tree          [depth]          -> dump current category trie
  stats                          -> index/event/tree sizes + integrity check
  optimize                       -> compact logs, rebuild index, verify sha
  session       [name]           -> start/resume named query session
  bind_f7                       -> register Tab+F7 GNOME/xbindkeys shortcut

Engine modules:
  tree / time / ingest / index / match / rank / query / adapt / store /
  action / retention

USAGE
}

case "${1:-}" in
  record)
    shift
    if ! ve_capacity_can_write; then
      echo "Searchie: memory locked at full capacity — open existing things; clear/delete to free space" >&2
      exit 1
    fi
    ve_capacity_sweep >/dev/null 2>&1
    ve_ingest_record "$@" ;;
  bulk)
    shift
    if ! ve_capacity_can_write; then
      echo "Searchie: memory locked at full capacity" >&2
      exit 1
    fi
    ve_capacity_sweep >/dev/null 2>&1
    ve_ingest_bulk "$@" ;;
  watch)
    shift
    ve_connectors_run "$@" ;;
  bootstrap|sweep|seed)
    shift
    if [ -n "$(type -t ve_connectors_bootstrap 2>/dev/null)" ]; then
      ve_connectors_bootstrap "$@"
    else
      echo "Searchie: bootstrap connector not loaded" >&2
      exit 1
    fi
    ;;
  ask|find|query)
    shift
    ve_session_init
    ve_capacity_sweep >/dev/null 2>&1
    ve_query_run "${@:-<no query>}"
    ve_session_bump queries
    ;;
  delete|del)
    shift
    ve_session_init
    ve_retention_rotate
    ve_action_delete "$@"
    ;;
  confirm|commit)
    shift
    ve_session_init
    ve_action_delete_confirm "${1:-}"
    ;;
  planner|plan)
    shift
    ve_session_init
    ve_query_plan "$@"
    ;;
  cap|capacity|freemem)
    shift
    ve_session_init
    pct=$(ve_capacity_pct)
    lvl=$(ve_capacity_level)
    used=$(ve_capacity_usage)
    echo "Memory available:   $([ "$lvl" = full ] && echo FULL / LOCKED || echo $(awk -v u="$used" -v b="$VIBE_CAP_BYTES" 'BEGIN{ if (u<=b) printf "%d%% free", int((b-u)*100/b) }'))"
    echo "Memory used:        ${pct}%"
    echo "Footprint:          $used bytes"
    echo "State:              $lvl (warn=${VIBE_CAP_WARN}% crit=${VIBE_CAP_CRIT}% full=${VIBE_CAP_FULL}%)"
    ve_capacity_allowed_at_full
    ;;
  tree)
    shift
    ve_tree_dump "${1:-}"
    ;;
  stats)
    shift
    ve_store_stats
    ;;
  timeline)
    ve_store_timeline
    ;;
  optimize|compact)
    shift
    ve_store_optimize "${1:-}"
    ;;
  session)
    shift
    ve_session_init "$@"
    echo "session: $(cat "$VIBE_STATE/current" 2>/dev/null || echo default)"
    ;;
  markov)
    shift
    ve_session_init
    case "${1:-}" in
      predict) ve_markov_predict "${2:-}" ${3:-$VE_MARKOV_TOP} ;;
      chain)   ve_markov_chain "${2:-}" ${3:-$VE_MARKOV_MAXCHAIN} ;;
      complete) ve_markov_chain "${2:-}" ${3:-$VE_MARKOV_MAXCHAIN} ;;
      *) echo "usage: ve markov predict <context> | ve markov chain <start> [len] | ve markov complete <start> [len]" ;;
    esac
    ;;
  audit)
    shift
    ve_session_init
    ve_audit_event "${1:-}"
    ;;
  audit-query)
    shift
    ve_session_init
    ve_audit_query "${*:-}"
    ;;
  align)
    shift
    ve_session_init
    case "${1:-check}" in
      check|--check|-c)       ve_align_check ;;
      fix|--fix|-f)           ve_align_fix ;;
      dry|--dry|--dry-run|-n) ve_align_fix --dry-run ;;
      *) echo "usage: ve align check | ve align fix | ve align --dry-run" ;;
      *) echo "usage: ve align [check|--fix]" ;;
    esac
    ;;
  similar)
    shift
    ve_session_init
    ve_lsh_candidates "${1:-}" "${2:-$VE_LSH_THRESH}"
    ;;
  dupes)
    shift
    ve_session_init
    echo "LSH near-duplicate scan (≥${1:-$VE_LSH_THRESH}/$VE_LSH_ROWS signature rows):"
    local n=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local a b h
      a="${line%%|*}"; b="${line#*|}"; b="${b%%|*}"; h="${line##*|}"
      echo "  $a == $b  (rows $h/$VE_LSH_ROWS)"
      n=$((n + 1))
    done < <(ve_lsh_dupe_scan "${1:-}")
    echo "  total candidate pairs: $n"
    ;;
  bind_f7|install)
    ve_connectors_bind_f7 "$@"
    ;;
  --selftest|selftest|test)
    ve_selftest_run
    ;;
  --version|-v)
    echo "vibe-address $VIBE_VERSION (engine $VIBE_FORMAT)"
    ;;
  *)
    usage ;;
esac
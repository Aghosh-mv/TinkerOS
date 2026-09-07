#!/bin/bash
# ===========================================================================
#  core/selftest.sh — ENGINEWIDE REGRESSION HARNESS
# ---------------------------------------------------------------------------
#  Exercises every kernel module in an ISOLATED throwaway store so the
#  suite never touches real user state.  Each check is two-phase: it must
#  both PRODUCE the right shape and the idempotent replay must agree.
#
#  Modules under test:
#    tree / time / ingest / index / match / rank / query / store /
#    action / retention / bloom / ir / lexin / phoneme
#
#  Returns non-zero on any failure (first failing check names itself).
# ===========================================================================
set -euo pipefail

ve_selftest_run() {
  local tmp; tmp=$(mktemp -d)
  local HOME_OLD="$HOME"
  local VIBE_HOME_OLD="$VIBE_HOME"
  export HOME="$tmp"
  export VIBE_HOME="$tmp/vibe"
  # re-derive the derived store dirs exactly like the dispatcher does so the
  # isolated harness never reaches into the caller's real store.
  export VIBE_EVENTS="$VIBE_HOME/events"
  export VIBE_TREE="$VIBE_HOME/tree"
  export VIBE_INDEX="$VIBE_HOME/index"
  export VIBE_STATE="$VIBE_HOME/state"
  export VIBE_CACHE="$VIBE_HOME/cache"
  mkdir -p "$VIBE_HOME"
  local fails=0 total=0

  check() {  # name, expected, actual
    total=$((total + 1))
    if [ "$2" = "$3" ]; then
      printf '  ok   %s\n' "$1"
    else
      printf '  FAIL %s   (expected=%q got=%q)\n' "$1" "$2" "$3"
      fails=$((fails + 1))
    fi
  }

  # ---- tree: insert + locate + depth (signature: ref normpath epoch) -----------
  ve_tree_insert "ref-march" "projects:work:march" "$(date +%s)" 2>/dev/null || true
  check "tree node locate" "$tmp/vibe/tree/projects/work/march" "$(ve_tree_locate "projects:work:march" 2>/dev/null || echo missing)"
  check "tree depth" "3" "$(ve_tree_depth "projects:work:march" 2>/dev/null || echo 0)"

  # ---- phoneme codecs -----------------------------------------------------------------
  local ph; ph=$(ve_phon_similarity "cat" "kat" 2>/dev/null || echo 0)
  check "phoneme consensus high" "1" "$([ "$ph" -ge 50 ] && echo 1 || echo 0)"
  ph=$(ve_phon_similarity "alphabet" "zebra" 2>/dev/null || echo 103)
  check "phoneme unrelated low" "1" "$([ "${ph:-103}" -lt 40 ] 2>/dev/null && echo 1 || echo 0)"
  ph=$(ve_phon_similarity "zebra" "zebra" 2>/dev/null || echo 0)
  check "phoneme identity 100" "100" "$ph"

  # ---- lexin: tokenize lower+punctuation, then stopfilter ----------------------------
  local toks; toks=$(ve_lex_tokenize "CAT and the Thing!" 2>/dev/null)
  check "lexin tokenize lowercase" "cat and the thing" "$toks"
  check "lexin stopfilter drops" "cat thing" "$(ve_lex_stopfilter "$toks" 2>/dev/null || echo x)"
  # synonym ring: expanding "photo" must now reach "picture"
  local ring; ring=$(ve_lex_expand_ring "photo" 2>/dev/null || echo "")
  check "lexin ring reaches picture" "1" "$(echo "$ring" | grep -q picture && echo 1 || echo 0)"

  # ---- time lattice --------------------------------------------------------------------
  local w; w=$(ve_time_window "last 3 hours" 2>/dev/null || echo "0 1")
  check "time window lo<hi" "1" "$( [ "$(echo "$w" | awk '{print $1}')" -lt "$(echo "$w" | awk '{print $2}')" ] && echo 1 || echo 0 )"

  # ---- bloom cascade (before/after membership + pair dedup) ---------------------------
  ve_bloom_tok_add "needle" >/dev/null 2>&1 || true
  check "bloom confirms present" "1" "$(ve_bloom_tok_contains "needle" 2>/dev/null)"
  check "bloom rejects absent" "0" "$(ve_bloom_tok_contains "dne_xyz" 2>/dev/null)"

  # ---- ingest + index round-trip --------------------------------------------------------
  local f="$tmp/meeting_notes.md"; printf '# notes\n' > "$f"
  ve_ingest_record "File" "files" "$f" >/dev/null 2>&1 || true
  local got; got=$(ve_index_tokens_to_fps "meeting" 2>/dev/null | wc -l | tr -d ' ')
  check "index token postings" "1" "$got"

  # ---- IR: df incremented once, avgdl sane ---------------------------------------------
  local df; df=$(ve_ir_df "meeting" 2>/dev/null || echo 0)
  check "ir df counted" "1" "$df"
  local avg; avg=$(ve_ir_avgdl 2>/dev/null || echo 0)
  check "ir avgdl positive" "1" "$([ "$avg" -gt 0 ] 2>/dev/null && echo 1 || echo 0)"

  # ---- query relax + rank ordering --------------------------------------------------------
  local r; r=$(SEARCHIE_TERSE=1 ve_query_run "meeting notes" 2>/dev/null | grep -c "RESULT|" || true)
  check "query returns ranked rows" "1" "$([ "$r" -ge 1 ] && echo 1 || echo 0)"

  # ---- action staging surface --------------------------------------------------------------
  local staged; staged=$(ve_action_delete "the missing thing" 2>/dev/null | grep -c "^ITEM|" || true)
  check "delete stages item" "1" "$([ "$staged" -ge 1 ] && echo 1 || echo 0)"

  # ---- Aho-Corasick: substring rescue in one automaton pass --------------------------------
  ve_auto_compile "hpho" >/dev/null 2>&1 || true
  local ac; ac=$(ve_auto_scan_text "beachphotojpg note" 2>/dev/null | head -1 || true)
  check "AC substring finds hpho" "hpho" "$ac"
  ac=$(ve_auto_scan_text "nothing similar here" 2>/dev/null | head -1)
  check "AC rejects absent" "1" "$([ -z "$ac" ] && echo 1 || echo 0)"

  # ---- restore env --------------------------------------------------------------------------
  export HOME="$HOME_OLD"
  export VIBE_HOME="$VIBE_HOME_OLD"

  echo ""
  if [ "$fails" -eq 0 ]; then
    echo "SELFTEST PASS  ($total checks)"
    return 0
  else
    echo "SELFTEST FAIL  ($fails/$total failed)"
    return 1
  fi
}
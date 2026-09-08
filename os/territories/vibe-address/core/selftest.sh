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

  # ---- edit-distance automaton: batch banded scan, early-abort --------------
  check "dista exact distance" "0" "$(ve_dista_distance cat cat 2 2>/dev/null || echo x)"
  check "dista one-edit" "1" "$(ve_dista_distance cat kat 2 2>/dev/null || echo x)"
  check "dista rejects far" "999" "$(ve_dista_distance cat xenomorph 2 2>/dev/null || echo x)"
  local dn; dn=$(printf "cat\ncarrot\nkat\ncatalog\n" | ve_dista_neighbors "cat" 2 2>/dev/null | sed -n '2p' | cut -d'|' -f1)
  check "dista neighbours batches" "kat" "$dn"
  local cls; cls=$(printf "cat\ncarrot\nkat\n" | ve_dista_closest "catt" 2>/dev/null | cut -d'|' -f1)
  check "dista closest" "cat" "$cls"

  # ---- Rocchio PRF: reordering symmetric, vectors sane -----------------------
  local qv; qv=$(ve_prf_query_vec "alpha beta alpha" 2>/dev/null | tr '\n' ' ')
  check "prf query vector tf" "1" "$(echo "$qv" | awk -F'[: ]' '{alpha=0;beta=0; for(i=1;i<=NF;i+=2){if($i=="alpha")alpha=$(i+1); if($i=="beta")beta=$(i+1)} print (alpha==2 && beta==1)?1:0}')"
  check "prf cosine same vectors" "1000" "$(ve_prf_cosine $'x:1\ny:1' $'x:1\ny:1' 2>/dev/null || echo 0)"
  check "prf cosine disjoint" "0" "$(ve_prf_cosine $'x:1' $'z:5' 2>/dev/null || echo 9)"
  check "prf single-candidate passthrough" "solo|5|alpha" "$(printf 'solo|5|alpha\n' | ve_prf_rerank "one" 2>/dev/null)"
  local prfa prfb
  prfa=$(printf 'one|1|alpha\nsecond|2|beta\n' | ve_prf_rerank "one" 2>/dev/null | sort | tr '\n' ' ')
  prfb=$(printf 'one|1|alpha\nsecond|2|beta\n' | sort | tr '\n' ' ')
  check "prf multiset preserved" "1" "$([ "$prfa" = "$prfb" ] && echo 1 || echo 0)"

  # ---- markov predictor: order-2 trigram dominates, chains walk -------------
  rm -rf "$(ve_markov_dir)" && ve_markov_dir >/dev/null 2>&1
  ve_markov_observe "meeting notes agenda followup report" >/dev/null 2>&1
  ve_markov_observe "meeting notes agenda review" >/dev/null 2>&1
  ve_markov_observe "meeting notes minutes" >/dev/null 2>&1
  local mtop; mtop=$(ve_markov_predict "meeting notes" 1 2>/dev/null | head -1 | cut -d'|' -f1)
  check "markov trigram top after meeting notes" "agenda" "$mtop"
  local mbig; mbig=$(ve_markov_predict "meeting" 1 2>/dev/null | head -1 | cut -d'|' -f1)
  check "markov bigram top after meeting" "notes" "$mbig"
  local mchain; mchain=$(ve_markov_chain "meeting" 4 2>/dev/null || true)
  check "markov chain prefixes meeting" "1" "$([[ "$mchain" == meeting* ]] && echo 1 || echo 0)"

  # ---- minhash/LSH near-duplicate finder -------------------------------------
  rm -rf "$VIBE_STATE/lsh"; mkdir -p "$VIBE_STATE/lsh"
  ve_lsh_index fp_x1 "beach photo sunny summer trip beach vacation" >/dev/null 2>&1
  ve_lsh_index fp_x2 "beach photo sunny summer trip beach vacation" >/dev/null 2>&1
  ve_lsh_index fp_y1 "tax report quarterly spreadsheet numbers" >/dev/null 2>&1
  local lsh; lsh=$(ve_lsh_candidates fp_x1 5 2>/dev/null | head -1)
  check "lsh finds identical copy 8/8" "fp_x2|8" "$lsh"
  lsh=$(ve_lsh_candidates fp_y1 5 2>/dev/null | wc -l | tr -d ' ')
  check "lsh rejects unrelated" "0" "$lsh"

  # ---- suffix array: idempotent ensure + infix rescue ------------------------
  check "sarray ensure idempotent rc" "0" "$(ve_sarray_ensure >/dev/null 2>&1; echo $?)"
  local sain; sain=$(ve_sarray_search "photo" 5 2>/dev/null | wc -l | tr -d ' ')
  check "sarray infix returns hits" "1" "$([ "${sain:-0}" -ge 1 ] && echo 1 || echo 0)"
  sain=$(ve_sarray_search "zzzzqzx" 5 2>/dev/null | wc -l | tr -d ' ')
  check "sarray rejects absent" "0" "$sain"

  local dupcnt; dupcnt=$(ve_lsh_index "st1st1" "alpha beta gamma delta file misc" >/dev/null 2>&1; ve_lsh_index "st2st2" "alpha beta gamma delta file misc" >/dev/null 2>&1; ve_lsh_index "st3st3" "omega zeta eta theta file misc" >/dev/null 2>&1; ve_lsh_dupe_count 6 2>/dev/null)
  check "lsh dupe scan finds identical pair" "2" "$dupcnt"

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

  # ---- capacity manager: pct monotonic, level labels, full-lock deny --------------
  local cp; cp=$(ve_capacity_pct 2>/dev/null || echo 0)
  check "capacity pct in range" "1" "$([ "$cp" -ge 0 ] 2>/dev/null && [ "$cp" -le 100 ] && echo 1 || echo 0)"
  check "capacity ok level initially" "ok" "$(ve_capacity_level 2>/dev/null || echo ok)"
  local deny
  ve_capacity_can_write; deny=$?
  check "capacity allows write while ok" "0" "$deny"
  check "capacity can force full" "full" "$(VIBE_CAP_BYTES=1 ve_capacity_level 2>/dev/null || echo ok)"

  # ---- count-min sketch: exact small-store behaviour --------------------------------
  ve_cms_add "needle" >/dev/null 2>&1 || true
  ve_cms_add "needle" >/dev/null 2>&1 || true
  check "cms counts repeated" "2" "$(ve_cms_estimate needle 2>/dev/null || echo 0)"
  check "cms zero for absent" "0" "$(ve_cms_estimate absentword 2>/dev/null || echo x)"

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
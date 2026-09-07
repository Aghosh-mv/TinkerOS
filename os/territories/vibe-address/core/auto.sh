#!/bin/bash
# ===========================================================================
#  core/auto.sh — AHO-CORASICK FINITE AUTOMATON
# ---------------------------------------------------------------------------
#  Multi-pattern scan: ONE walk over event text finds every query-token
#  present.  Inverted-index intersect costs O(tokens · postings); the
#  Aho-Corasick automaton (keyed trie + failure links) is O(text).
#  The automaton is compiled on the fly inside awk from a pattern file —
#  patterns -> goto trie -> BFS failure links -> single-pass scan.
# ===========================================================================
set -euo pipefail

ve_auto_dir() { echo "${VIBE_STATE:-$VIBE_HOME/state}/auto"; }

# ---- write the pattern file (the automaton is compiled per scan) -------------
ve_auto_compile() {
  local pats="$1"
  local dir; dir=$(ve_auto_dir)
  mkdir -p "$dir"
  printf '%s\n' "$pats" | tr ' ' '\n' | sed '/^[[:space:]]*$/d' | sort -u \
    > "$dir/pats"
}

# ---- scan a text blob; echo matched patterns (one per line, sorted) ----------
ve_auto_scan_text() {
  local text="$1"
  local dir; dir=$(ve_auto_dir)
  local pf="$dir/pats"
  [ -f "$pf" ] || return 0
  printf '%s\n' "$text" | awk -v pf="$pf" '
    BEGIN {
      ns = 0;   # state count
      # --- 1. build goto trie: state 0 = root ----
      while ((getline pat < pf) > 0) {
        if (pat == "") continue;
        n = split(pat, chars, ""); s = 0;
        for (i = 1; i <= n; i++) {
          c = chars[i];
          if (!((s SUBSEP c) in go)) { ns++; go[s, c] = ns }
          s = go[s, c];
        }
        out[s] = out[s] == "" ? pat : out[s] "," pat;
      }
      close(pf);
      # --- 2. failure links via BFS over states 0..ns ----
      pending[1] = 0; ph = 1; pt = 1; fail[0] = 0;
      while (ph <= pt) {
        r = pending[ph++];
        for (key in go) {
          sep = index(key, SUBSEP);
          st = substr(key, 1, sep - 1) + 0;
          if (st != r) continue;
          c = substr(key, sep + 1);
          u = go[r, c];
          pending[++pt] = u;
          f = fail[r];
          while (f > 0 && !((f SUBSEP c) in go)) f = fail[f];
          if ((f SUBSEP c) in go) fm = go[f, c]; else fm = 0;
          fail[u] = (r == 0 ? 0 : fm);
          # merge the fail-[u] outputs into u
          x = out[fail[u]];
          if (x != "") { out[u] = out[u] == "" ? x : out[u] "," x; }
        }
      }
      # --- 3. single-pass scan (main block, per input line) ----
    }
    {
      n = split($0, chars, ""); s = 0;
      for (i = 1; i <= n; i++) {
        c = chars[i];
        while (s > 0 && !((s SUBSEP c) in go)) s = fail[s];
        if ((s SUBSEP c) in go) s = go[s, c]; else s = 0;
        if (out[s] != "" && !seen[s]++) {
          split(out[s], tags, ","); for (j in tags) print tags[j];
        }
      }
    }
  ' | sort -u
}

# ---- whole-store candidate pass: envelopes matching ANY pattern ---------------
ve_auto_candidates() {
  local tokens="$1" tlo="$2" thi="$3" qcat="$4"
  local dir; dir=$(ve_auto_dir)
  local pf="$dir/pats"
  rm -f "$pf"
  ve_auto_compile "$tokens"
  [ -f "$pf" ] || return 0
  local ff env
  for ff in "$VIBE_INDEX/fp"/*; do
    [ -f "$ff" ] || continue
    env=$(tail -1 "$ff" 2>/dev/null)
    [ -z "$env" ] && continue
    if [ -n "$(ve_auto_scan_text "$env")" ]; then
      echo "$env"
    fi
  done
}

ve_auto=""
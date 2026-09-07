#!/bin/bash
# ===========================================================================
#  core/dista.sh — EDIT-DISTANCE AUTOMATON (frontier/bounded Levenshtein)
# ---------------------------------------------------------------------------
#  The fuzzy matcher's plain DP is O(|a|*|b|) per pair, called in a nested
#  loop — expensive across many candidates.  This module instead runs a
#  BANDED dynamic program over the whole dictionary in ONE awk pass:
#    - cells outside the diagonal band (|i-j| <= maxd) are pruned, so each
#      row costs O(2*maxd+1) instead of O(|b|)   [Ukkonen frontier idea]
#    - length-gap > maxd rejects instantly (edit distance lower bound)
#    - a whole frontier row exceeding maxd aborts that word early
#  Result: exact Levenshtein within the band, LIKE computation, and a
#  0..100 similarity — all in a single compiled awk program.
# ===========================================================================
set -euo pipefail

VE_DISTA_TOK="${VE_DISTA_TOK:-2}"   # default tolerance (edits)
VE_DISTA_INF=999

# ---- single pair, banded, early-abort; echoes distance or 999 -----------------
ve_dista_distance() {
  local a="$1" b="$2" maxd="${3:-$VE_DISTA_TOK}"
  awk -v a="$a" -v b="$b" -v maxd="$maxd" 'BEGIN{
    m = length(a); n = length(b);
    if (m < n) { t=a; a=b; b=t; t=m; m=n; n=t }
    if (m - n > maxd) { print 999; exit }
    for (j = 0; j <= n; j++) row[j] = j;
    for (i = 1; i <= m; i++) {
      ai = substr(a, i, 1);
      lo = (i - maxd > 0 ? i - maxd : 0);
      hi = (i + maxd < n ? i + maxd : n);
      curr[lo - 1] = maxd + 1;           # sentinel outside band
      rowmin = maxd + 1;
      for (j = lo; j <= hi; j++) {
        del = row[j] + 1;
        ins = (j - 1 >= lo - 1 ? curr[j - 1] : maxd + 1) + 1;
        if (j == 0) ins = maxd + 2;
        bj = substr(b, j, 1);
        subv = (j - 1 >= lo - 1 ? row[j - 1] : maxd + 1) + (ai != bj);
        m3 = del < ins ? del : ins;
        curr[j] = m3 < subv ? m3 : subv;
        if (curr[j] < rowmin) rowmin = curr[j];
      }
      for (j = 0; j <= n; j++) row[j] = curr[j];
      if (i < m && rowmin > maxd) { print 999; exit }
    }
    print (row[n] > maxd ? 999 : row[n]);
  }'
}

# ---- similarity 0..100 from a known distance -----------------------------------
ve_dista_ratio() {
  local d="$1" maxl="$2"
  [ "$d" -ge "$VE_DISTA_INF" ] && { echo 0; return; }
  [ "$maxl" -le 0 ] && { echo 0; return; }
  echo $(( (maxl - d) * 100 / maxl ))
}

# ---- batch: dictionary on stdin, pattern=|1|, print "word|dist" within maxd ----
ve_dista_neighbors() {
  local pattern="$1" maxd="${2:-$VE_DISTA_TOK}"
  awk -v pat="$pattern" -v maxd="$maxd" '
    function ud(a, b,   m,n,i,j,row,curr,lo,hi,ai,bj,del,ins,subv,m3,rowmin,last) {
      m = length(a); n = length(b);
      if (m < n) { t=a; a=b; b=t; t=m; m=n; n=t }
      if (m - n > maxd) return 999;
      for (j = 0; j <= n; j++) row[j] = j;
      last = row[n];
      for (i = 1; i <= m; i++) {
        ai = substr(a, i, 1);
        lo = (i - maxd > 0 ? i - maxd : 0);
        hi = (i + maxd < n ? i + maxd : n);
        curr[lo - 1] = maxd + 1;
        rowmin = maxd + 1;
        for (j = lo; j <= hi; j++) {
          del = row[j] + 1;
          ins = (j - 1 >= lo - 1 ? curr[j - 1] : maxd + 1) + 1;
          if (j == 0) ins = maxd + 2;
          subv = (j - 1 >= lo - 1 ? row[j - 1] : maxd + 1) + (ai != substr(b, j, 1));
          m3 = del < ins ? del : ins;
          curr[j] = m3 < subv ? m3 : subv;
          if (curr[j] < rowmin) rowmin = curr[j];
        }
        for (j = 0; j <= n; j++) row[j] = curr[j];
        last = row[n];
        if (i < m && rowmin > maxd) return 999;
      }
      return (last > maxd ? 999 : last);
    }
    { w = $0; if (w == "") next; d = ud(pat, w); if (d < 999) print w "|" d; }
  ' | sort -t'|' -k2n -k1
}

# ---- best single neighbour over a dictionary stream ----------------------------
ve_dista_closest() {
  local pattern="$1" best=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local w="${line%%|*}" d="${line##*|}"
    if [ -z "$best" ]; then best="$w|$d"; else
      if [ "$d" -lt "${best##*|}" ]; then best="$w|$d"; fi
    fi
  done <<< "$(ve_dista_neighbors "$pattern" 2>/dev/null)"
  echo "$best"
}

ve_dista=""
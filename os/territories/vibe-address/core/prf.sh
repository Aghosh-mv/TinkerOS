#!/bin/bash
# ===========================================================================
#  core/prf.sh — ROCCHIO PSEUDO-RELEVANCE FEEDBACK RE-RANKER
# ---------------------------------------------------------------------------
#  Classic Rocchio query expansion: after the matchers produce a candidate
#  set, the top-N pseudo-relevant envelopes are assumed relevant and their
#  term vectors are folded back into a *new* query vector (query +
#  alpha*centroid of the feedback set).  Candidates are then re-scored by
#  cosine against the expanded vector and re-emitted in that order, so a
#  candidate sharing the *topics* of the winners can leapfrog a merely
#  word-identical one.
#
#  Input  : scored lines  fp|m1|..|m9|envelope (stdin)
#  Output : SAME lines, reordered by Rocchio cosine (no data loss)
# ===========================================================================
set -euo pipefail

VE_PRF_N="${VE_PRF_N:-3}"          # feedback set size (pseudo-relevant docs)
VE_PRF_K="${VE_PRF_K:-6}"          # expansion term budget drawn from centroid
VE_PRF_A="${VE_PRF_A:-0.5}"        # Rocchio alpha (centroid blend)
VE_PRF_TF_RANK=3                    # raw tf in the query vector

# ---- term vector -> "term:weight" stream from a candidate envelope ----------
ve_prf_doc_vec() {
  local fp="$1" envelope="$2"
  local epath=$(echo "$envelope" | cut -d'|' -f4)
  local etype=$(echo "$envelope" | cut -d'|' -f2)
  local ecat=$(echo "$envelope" | cut -d'|' -f6)
  local toks; toks=$(ve_ingest_name_tokens "$epath" "$etype" 2>/dev/null)
  # category segments + path tokens all count as surface terms
  printf '%s\n' "$toks" | sed '/^$/d' | tr ':' '\n' | sed '/^$/d' \
    | sort | uniq -c | awk '{ print $2 ":" $1 }'
  echo "$ecat" | tr ':' '\n' | sed '/^$/d' | sort | uniq -c | awk '{ print $2 ":" $1 }'
  echo "$etype" >> /dev/null
}

# ---- query vector from raw tokens (weighted by tf + small boost) ------------
ve_prf_query_vec() {
  echo "$1" | tr ' ' '\n' | sed '/^$/d' | sort | uniq -c | awk -v r="$VE_PRF_TF_RANK" \
    '{ w = 1 + (r - 1 > 0 ? ($1 > r ? r : $1) - 1 : 0); print $2 ":" w }'
}

# ---- cosine similarity between query vector stream and a doc vector stream ---
#  streams are "term:weight"; terms having only one side count 0 (sparse dot)
ve_prf_cosine() {
  local qterms="$1"
  local -A q=() d=()
  local t w
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    t="${l%%:*}"; w="${l##*:}"
    q["$t"]=$w
  done <<< "$qterms"
  local dstream="${2:-}"
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    t="${l%%:*}"; w="${l##*:}"
    d["$t"]=$w
  done <<< "$dstream"
  local dot=0 qs=0 ds=0
  for t in "${!q[@]}"; do
    qs=$(( qs + q["$t"] * q["$t"] ))
    if [ "${d["$t"]:-0}" -gt 0 ]; then dot=$(( dot + q["$t"] * d["$t"] )); fi
  done
  for t in "${!d[@]}"; do ds=$(( ds + d["$t"] * d["$t"] )); done
  if [ "$qs" -eq 0 ] || [ "$ds" -eq 0 ]; then echo 0
  else awk -v dot="$dot" -v qs="$qs" -v ds="$ds" 'BEGIN{ printf "%d", dot*1000/(sqrt(qs)*sqrt(ds)) + 0.5 }'
  fi
}


# ---- main: read scored lines, reorder by Rocchio cosine ------------------------
ve_prf_rerank() {
  local qtok="${1:-}"
  [ -z "$qtok" ] && return 0
  local -a scored=() fplist=()
  local l
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    scored+=("$l")
    fplist+=("${l%%|*}")
  done
  local n=${#scored[@]}
  [ "$n" -lt 2 ] && { printf '%s\n' "${scored[@]}"; return 0; }

  local qvec; qvec=$(ve_prf_query_vec "$qtok")

  # initial cosine ranking to *choose* the pseudo-relevant feedback set
  local -A docvec=()
  local i=0 idx sim
  for i in "${!scored[@]}"; do
    local env; env=$(echo "${scored[$i]}" | cut -d'|' -f11-)
    local dv; dv=$(ve_prf_doc_vec "${fplist[$i]}" "$env" 2>/dev/null)
    docvec[$i]=${dv}
    sim=$(ve_prf_cosine "$qvec" "$dv")
    echo "$i|$sim"
  done | sort -t'|' -k2nr > /tmp/PRF_ranked_$$

  # feedback set = top VE_PRF_N pseudo-relevant; aggregate their term counts
  local fbset=""
  while IFS= read -r idx; do
    [[ "$idx" =~ ^[0-9]+$ ]] || continue
    fbset=$(printf '%s\n%s\n' "$fbset" "${docvec[$idx]:-}")
  done < <(head -"$VE_PRF_N" /tmp/PRF_ranked_$$ | cut -d'|' -f1)

  # expansion terms: top-K aggregate terms (by summed weight) NEAREST to centroid
  local expansion
  expansion=$(echo "$fbset" | sed '/^$/d' | awk -F: '{cnt[$1]+=$2} END{for(t in cnt) print t":"cnt[t]}' \
    | sort -t: -k2nr | head -"$VE_PRF_K")

  # expanded query stream = qvec + alpha*expansion weights (Rocchio blend)
  local qexp; qexp=$(printf '%s\n%s\n' "$qvec" "$(echo "$expansion" | sed '/^$/d' | awk -F: -v a="$VE_PRF_A" '{print $1 ":" $2*a}')")
  rm -f /tmp/PRF_ranked_$$

  # re-score every candidate against the expanded vector, emit original lines
  (for i in "${!scored[@]}"; do
    local ns; ns=$(ve_prf_cosine "$qexp" "${docvec[$i]:-}")
    echo "$ns|${scored[$i]}"
  done) | sort -t'|' -k1nr | cut -d'|' -f2-
}

ve_prf=""

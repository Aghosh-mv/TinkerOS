#!/bin/bash
# ===========================================================================
#  core/markov.sh — MARKOV-CHAIN NEXT-TOKEN PREDICTOR
# ---------------------------------------------------------------------------
#  First- and second-order transition tables over the token stream observed
#  in recorded event envelopes:
#      state/markov/<o><sha16>   -> lines "suffix:count"
#  order-1 (bigram)  context key "1:<last token>"
#  order-2 (trigram) context key "2:<tok[-2]> <tok[-1]>"
#  Predictions merge both orders (higher-order weighted stronger), and a
#  greedy chain walker generates completion phrases for the TUI.  Each step
#  is a single file cat + awk — O(1) per context storage.
# ===========================================================================
set -euo pipefail

#  NOTE: the store dir is resolved LAZILY at call time (like bloom.sh) because
#  VIBE_STATE may be re-derived by the caller (dispatcher/selftest) after this
#  module is sourced; an eager binding would silently target the wrong store.
ve_markov_dir() { local d="${VIBE_STATE:-$VIBE_HOME/state}/markov"; mkdir -p "$d"; echo "$d"; }

VE_MARKOV_TOP="${VE_MARKOV_TOP:-3}"         # candidate surface in predict
VE_MARKOV_MAXCHAIN="${VE_MARKOV_MAXCHAIN:-12}"
VE_MARKOV_O1_DECAY=7                        # 0.7 weight for order-1 edges

# ---- deterministic bucket file for a (order, context) pair -------------------
ve_markov_keyfile() {
  local order="$1" ctx="$2"
  echo "$(ve_markov_dir)/${order}_$(printf '%s' "$ctx" | sha256sum | cut -c1-16)"
}

# ---- read a context file into "suffix:count" lines (empty if none) ----------
ve_markov_load() {
  local file="$1"
  { [ -f "$file" ] && cat "$file"; } || true
}

# ---- write back a merged map (suffix:count, sorted desc by count) ----------
ve_markov_save() {
  local file="$1" mapstream="$2"
  echo "$mapstream" | awk -F: '{c[$1]+=$2} END{for(s in c) print s ":" c[s]}' \
    | sort -t: -k2nr > "$file.tmp" && mv "$file.tmp" "$file"
}

# ---- observe: fold a token sequence into the transition tables --------------
ve_markov_observe() {
  local tokens="$1"
  local -a t=()
  local tok
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    t+=("$tok")
  done <<< "$(echo "$tokens" | tr ' ' '\n' | sed '/^$/d')"
  local n=${#t[@]}
  [ "$n" -lt 2 ] && return 0

  local -A incO1=() incO2=()
  local i a b
  for ((i=1; i<n; i++)); do
    a="${t[$((i-1))]}"; b="${t[$i]}"
    incO1["$a"]+=" $b:1"
    if [ "$i" -ge 2 ]; then
      incO2["${t[$((i-2))]} ${t[$((i-1))]}"]+=" $b:1"
    fi
  done

  local ctx delta key
  for ctx in "${!incO1[@]}"; do
    key=$(ve_markov_keyfile 1 "$ctx")
    delta=${incO1[$ctx]}
    ve_markov_merge "$key" "$delta"
  done
  for ctx in "${!incO2[@]}"; do
    key=$(ve_markov_keyfile 2 "$ctx")
    delta=${incO2[$ctx]}
    ve_markov_merge "$key" "$delta"
  done
}

# ---- merge a per-event increment stream into one context file --------------
ve_markov_merge() {
  local key="$1" delta="$2"
  local old; old=$(ve_markov_load "$key")
  ve_markov_save "$key" "$(printf '%s%s\n' "${old:+$old
}" "$(echo "$delta" | sed 's/^ //')")"
}

# ---- predict next tokens for a context phrase --------------------------------
ve_markov_predict() {
  local ctx="${1:-}" limit="${2:-$VE_MARKOV_TOP}"
  [ -z "$ctx" ] && return 0
  local -a ct=()
  local tok
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    ct+=("$tok")
  done <<< "$(echo "$ctx" | tr ' ' '\n' | sed '/^$/d')"
  local n=${#ct[@]}
  [ "$n" -eq 0 ] && return 0

  local o1="" o2=""
  if [ "$n" -ge 2 ]; then
    o2=$(ve_markov_load "$(ve_markov_keyfile 2 "${ct[$((n-2))]} ${ct[$((n-1))]}")")
  fi
  o1=$(ve_markov_load "$(ve_markov_keyfile 1 "${ct[$((n-1))]}")")

  # merge weighted: order-2 keeps full weight, order-1 decays to 0.7
  ( printf '%s\n' "${o2:+$o2}" | sed '/^$/d' | awk -F: '{print $1 ":" $2 ":2"}'
    printf '%s\n' "${o1:+$o1}" | sed '/^$/d' | awk -F: '{print $1 ":" $2 ":1"}' ) \
    | awk -F: -v d="$VE_MARKOV_O1_DECAY" '
        { w = ($3 == 2 ? $2 : $2 * d / 10); wsum[$1] += w; raw[$1] += $2 }
        END{
          tot = 0; for (s in wsum) tot += wsum[s]
          for (s in wsum) { p = (tot>0 ? (wsum[s]*100)/tot : 0); printf "%s|%d|%d\n", s, raw[s], p }
        }'
}

# ---- greedy chain: walk the top transition repeatedly ------------------------
ve_markov_chain() {
  local start="${1:-}" maxlen="${2:-$VE_MARKOV_MAXCHAIN}"
  [ -z "$start" ] && return 0
  local phrase="$start" cur="$start" next
  local steps=0
  while [ "$steps" -lt "$maxlen" ]; do
    next=$(ve_markov_predict "$cur" 1 2>/dev/null | head -1 | cut -d'|' -f1)
    [ -z "$next" ] && break
    phrase="$phrase $next"
    cur=$(echo "$cur" | awk -v w="$next" '{ if (NF>=2) sub(/^[^ ]+ /,""); print $0 " " w }')
    steps=$((steps + 1))
  done
  echo "$phrase"
}

# ---- confident chain: walk + show per-step confidence % ----------------------
ve_markov_chain_confident() {
  local start="${1:-}" maxlen="${2:-$VE_MARKOV_MAXCHAIN}"
  [ -z "$start" ] && return 0
  local phrase="$start" cur="$start" next
  local steps=0
  local -a words=()
  while [ "$steps" -lt "$maxlen" ]; do
    local pred; pred=$(ve_markov_predict "$cur" 1 2>/dev/null | head -1)
    next=$(echo "$pred" | cut -d'|' -f1)
    local pct=$(echo "$pred" | cut -d'|' -f3)
    [ -z "$next" ] && break
    words+=("$next:$pct")
    phrase="$phrase $next"
    cur=$(echo "$cur" | awk -v w="$next" '{ if (NF>=2) sub(/^[^ ]+ /,""); print $0 " " w }')
    steps=$((steps + 1))
  done
  local conf=""
  for w in "${words[@]}"; do
    conf="$conf $w"
  done
  echo "$phrase ($conf)"
}

ve_markov=""
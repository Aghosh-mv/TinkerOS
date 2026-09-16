#!/bin/bash
# ===========================================================================
#  core/bloom.sh — PROBABILISTIC MEMBERSHIP CASCADE
# ---------------------------------------------------------------------------
#  A Bloom filter answers "is X in the set?" in O(k) with a bounded false-
#  positive rate (and NO false negatives) — the classic space-time tradeoff.
#  Full arrays would be O(m) bytes; here the vector is kept as a SPARSE
#  byte-map (only bytes that have at least one set bit are materialised),
#  which makes thousands of updates cheap in bash while keeping the false
#  positive curve intact.
#
#  Structure: $VIBE_STATE/bloom/
#    vec.tok   — token PRESENCE filter      (key = a token string)
#    vec.pair  — (fp:token) PAIR filter     (key = "fp:token")
#
#  Two cascades for two decisions:
#    * fetch prefilter   — do NOT open the inverted-index file for a token
#                          that the tok filter says is absent (saves a stat
#                          + full read on store-wide misses).
#    * IR cardinality    — whether (fp:token) was already counted so the
#                          per-token document frequency (df) is incremented
#                          exactly once per unique pair.  Inflated df would
#                          crush IDF; under-counting via FPs is harmless.
#
#  Hash family: Kirsch–Mitzenmacher double hashing.
#    h_i(x) = (h1(x) + i*h2(x)) mod m      i = 1..k
#  Take two 24-bit seeds from sha256 of the key; k = 3 hashes, fpr ~
#  (1 - e^-(kn/m))^k.  With m = 1<<21 bits and ~1e5 keys, fpr ≈ 0.8%.
# ===========================================================================
set -euo pipefail

VE_BLOOM_BITS=2097152          # 2 Mbit ceiling per vector (1<<21)
VE_BLOOM_K=3
# NOTE: NO VE_BLOOM_DIR here — the store dir must be resolved LAZILY at call
# time.  VIBE_STATE is derived by the dispatcher (from VIBE_HOME) AFTER the
# core modules are sourced; binding it early yields a literal "/bloom" on the
# root filesystem and silently corrupts every freshness decision.

# ---- hash seeds --------------------------------------------------------------
ve_bloom_seeds() {
  # key -> "h1 h2 h3" where h_i are 24-bit values
  local key="$1"
  local hex; hex=$(printf '%s' "$key" | sha256sum | cut -d' ' -f1)
  if [ ${#hex} -lt 24 ]; then
    hex=$(printf '%s%s' "$hex" "$hex")
  fi
  local h1=$(( 16#${hex:0:6} )) h2=$(( 16#${hex:6:6} ))
  local h3=$(( (h1 + 2*h2) % 16777216 ))
  printf '%s %s %s\n' "$h1" "$h2" "$h3"
}

# ---- bit positions ------------------------------------------------------------
ve_bloom_positions() {
  # key -> three byte-offsets (double-hash family mapped into bit-space)
  local key="$1"
  local h1 h2 h3; IFS=' ' read -r h1 h2 h3 <<< "$(ve_bloom_seeds "$key")"
  local i p1 p2 p3
  for i in 1 2 3; do
    local p=$(( (h1 + i*h2) % VE_BLOOM_BITS ))
    printf '%s\n' "$p"
  done
}

# ---- sparse byte-map accessor --------------------------------------------------
ve_bloom_byte_get() {
  # mapfile, byteidx -> value (0..255); empty if absent.  Exits 0 even when
  # the grep misses so `set -euo pipefail` callers never abort on cold reads.
  local map="$1" idx="$2"
  grep "^$idx " "$map" 2>/dev/null | awk '{print $2}' | head -1 || true
}

ve_bloom_byte_set() {
  # mapfile, byteidx, value -> writes a "idx value" line (or updates)
  local map="$1" idx="$2" val="$3"
  local tmp; tmp="$map.tmp"
  sed "/^$idx /d" "$map" 2>/dev/null > "$tmp" || : > "$tmp"
  printf '%s %s\n' "$idx" "$val" >> "$tmp"
  mv -f "$tmp" "$map"
}

# ---- filter ops ------------------------------------------------------------------
ve_bloom_contains() {
  # filter_file, key -> prints 1 if (probably) present, 0 if definitely absent
  local f="$1" key="$2"
  [ -f "$f" ] || { echo 0; return; }
  local pos
  for pos in $(ve_bloom_positions "$key"); do
    local byte val
    byte=$(( pos / 8 ))
    val=$(ve_bloom_byte_get "$f" "$byte")
    [ -z "$val" ] && { echo 0; return; }
    local mask=$(( 1 << (pos % 8) ))
    if [ $(( val & mask )) -eq 0 ]; then
      echo 0; return
    fi
  done
  echo 1
}

ve_bloom_add() {
  # filter_file, key -> increments the vector, returns 1 if brand-new
  local f="$1" key="$2"
  mkdir -p "$(dirname "$f")"
  [ -f "$f" ] || : > "$f"
  local fresh=0 pos
  for pos in $(ve_bloom_positions "$key"); do
    local byte val mask newval
    byte=$(( pos / 8 ))
    val=$(ve_bloom_byte_get "$f" "$byte")
    [ -z "$val" ] && val=0
    [ "$val" -eq 0 ] && fresh=1
    mask=$(( 1 << (pos % 8) ))
    newval=$(( val | mask ))
    ve_bloom_byte_set "$f" "$byte" "$newval"
  done
  echo "$fresh"
}

# ---- store-scoped helpers ---------------------------------------------------------
ve_bloom_tok_filter() { echo "${VIBE_STATE:-$VIBE_HOME/state}/bloom/vec.tok"; }
ve_bloom_pair_filter() { echo "${VIBE_STATE:-$VIBE_HOME/state}/bloom/vec.pair"; }

ve_bloom_tok_add()    { ve_bloom_add "$(ve_bloom_tok_filter)" "$1"; }
ve_bloom_tok_contains() { ve_bloom_contains "$(ve_bloom_tok_filter)" "$1"; }
ve_bloom_pair_add()   { ve_bloom_add "$(ve_bloom_pair_filter)" "$1"; }
ve_bloom_pair_contains() { ve_bloom_contains "$(ve_bloom_pair_filter)" "$1"; }

# ---- rebuild from the inverted index (optimize path) ------------------------------
ve_bloom_rebuild() {
  ve_bloom_auto_size
  local inv="$VIBE_INDEX/inv"
  local tf; tf=$(ve_bloom_tok_filter); local pf; pf=$(ve_bloom_pair_filter)
  rm -f "$tf" "$pf"
  # token presence + pair presence recomputed from every index file
  local tfile
  for tfile in "$inv"/*; do
    [ -f "$tfile" ] || continue
    local tok; tok=$(basename "$tfile")
    ve_bloom_tok_add "$tok" >/dev/null
    # pairs: first token incurs a full scan (cold); pairs materialised lazily
    cut -d' ' -f1 "$tfile" | while IFS= read -r fp; do
      ve_bloom_pair_add "$fp:$tok" >/dev/null
    done
  done
}

# ---- auto-size bloom filter based on corpus token count ----------------------
ve_bloom_auto_size() {
  local inv="${VIBE_INDEX}/inv"
  if [ -d "$inv" ]; then
    local ntokens; ntokens=$(ls "$inv" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$ntokens" -gt 200000 ] 2>/dev/null; then
      VE_BLOOM_BITS=8388608
    elif [ "$ntokens" -gt 50000 ] 2>/dev/null; then
      VE_BLOOM_BITS=4194304
    fi
  fi
}

ve_bloom=""
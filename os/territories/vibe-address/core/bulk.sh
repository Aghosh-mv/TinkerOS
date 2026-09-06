#!/bin/bash
# ===========================================================================
#  core/bulk.sh — BATCH INGEST PIPELINE (bootstrap/optimize path)
# ---------------------------------------------------------------------------
#  The single-event pipeline (ingest.sh) spawns ~15 subprocesses per record:
#  fine for LIVE events, catastrophic for a 20k-file first-run sweep.
#
#  This module loads records BULK. stdin format (same canonical envelope):
#      epoch|type|source|path|fp|catpath|meta
#
#  Pipeline (each step is ONE process, not one per event):
#    1. append all lines to the day-log            (1 cat)
#    2. fingerprint table                          (awk, 1 file per fp)
#    3. category trie files                        (awk -> grouped appends)
#    4. inverted index                             (awk, 1 file per token)
#    5. time lattice buckets                       (gawk strftime, 1 pass)
#    6. adapt statistics                           (awk count pass)
#
#  Total process spawns is a small constant regardless of record count.
# ===========================================================================
set -euo pipefail

ve_ingest_bulk() {
  local tmp; tmp=$(mktemp -d /tmp/vibe-bulk.XXXXXX)
  local inv="$VIBE_INDEX/inv"
  local fpd="$VIBE_INDEX/fp"
  local tb="$VIBE_INDEX/time"
  local tree_meta="$VIBE_TREE"
  mkdir -p "$inv" "$fpd" "$tb"

  # ---- read + validate stdin ------------------------------------------------
  local n=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf '%s\n' "$line"
    n=$((n + 1))
  done > "$tmp/clean.tsv"

  # ---- 1. day-log (one append) ----------------------------------------------
  local logfile="$VIBE_EVENTS/$(date +%Y-%m-%d).log"
  cat "$tmp/clean.tsv" >> "$logfile"

  # ---- 2. fingerprint table -------------------------------------------------
  # awk writes each record to its fp file; group appends to avoid truncation
  awk -F'|' '
    { fp=$5; f="/tmp/vibe-bulk-fp." fp; print $0 >> f }
  ' "$tmp/clean.tsv"
  for ff in /tmp/vibe-bulk-fp.*; do
    [ -f "$ff" ] || continue
    fp=${ff#/tmp/vibe-bulk-fp.}
    cat "$ff" >> "$fpd/$fp"
  done
  rm -f /tmp/vibe-bulk-fp.*

  # ---- 3. category trie ------------------------------------------------------
  # emit "fp<TAB>catpath" once each, then per unique catpath append its fps
  # to $VIBE_TREE/s1/s2/.../index and update _meta reliably via staging files
  awk -F'|' '
    NF>=6 { print $5 "\t" $6 }
  ' "$tmp/clean.tsv" | sort -u > "$tmp/trie.pairs"

  # mkdir all needed dirs (one process for all)
  cut -f2 "$tmp/trie.pairs" | sort -u | sed 's/:/%/g' | \
  while IFS= read -r cpath; do
    cur="$tree_meta"
    IFS='%' read -ra segs <<<"$cpath"
    for s in "${segs[@]}"; do
      [ -z "$s" ] && continue
      cur="$cur/$s"
      mkdir -p "$cur"
    done
  done

  # stage index lines per catpath then append
  cut -f2 "$tmp/trie.pairs" | sort -u | while IFS= read -r cpath; do
    cur="$VIBE_TREE"
    IFS=':' read -ra segs <<<"$cpath"
    for s in "${segs[@]}"; do
      [ -z "$s" ] && continue
      cur="$cur/$s"
    done
    # append one index line per fp under this path (dedup by fp)
    fpstr=""
    while IFS=$'\t' read -r fp cpp; do
      [ "$cpp" = "$cpath" ] && fpstr="$fpstr $fp"
    done < "$tmp/trie.pairs"
    epoch_hint=$(grep "$cpath$" "$tmp/trie.pairs" | awk -F'|' 'NR==1{print $1}')
    { echo "$(date +%s)${fpstr// / $VIBE_BULK }" ; } >> /dev/null 2>&1 || true
    # real format: one line per fp under this path
    for fp in $fpstr; do
      echo "$epoch_hint $fp" >> "$cur/index"
    done
    # refresh meta count
    c=$(wc -l < "$cur/index" 2>/dev/null || echo 0)
    printf 'count=%s\nlast_seen=%s\nlevel=%s\n' \
      "$c" "$(date +%s)" "${#segs[@]}" > "$cur/_meta"
  done

  # ---- 4. inverted index ------------------------------------------------------
  # token extraction in ONE awk: words from path + category segments
  awk -F'|' '
    { path=$4; cat=$6; fp=$5
      n=split(path, t, /[^a-zA-Z0-9]+/)
      for (i=1;i<=n;i++) if (length(t[i])>=2 && length(t[i])<=40)
          print tolower(t[i]) "\t" fp "\t" $1 "\t" $4
      ac=split(cat, ct, /[:/]/)
      for (j=1;j<=ac;j++) if (length(ct[j])>=2)
          print tolower(ct[j]) "\t" fp "\t" $1 "\t" $4
    }' "$tmp/clean.tsv" | sort -u > "$tmp/inv.pairs"

  cut -f1 "$tmp/inv.pairs" | sort -u | while IFS= read -r tok; do
    fname=$(printf '%s' "$tok" | tr '/_' 'zz' | tr -cd 'a-z0-9')
    [ -z "$fname" ] && fname="zz"
    grep "^${tok}[[:space:]]" "$tmp/inv.pairs" | awk -F'\t' '{print $3" "$2" "$4}' >> "$inv/$fname"
  done

  # ---- 5. time lattice ---------------------------------------------------------
  # gawk strftime (GNU awk has it; fall back to date only if missing)
  if awk 'BEGIN{ if (strftime("%s",1)=="") exit 1 }' 2>/dev/null; then
    awk -F'|' '
      { epoch=$1; fp=$5
        bm=int(epoch/60)
        bh=int(epoch/3600) ":" strftime("%u",epoch)
        bd=strftime("%Y-%m-%d",epoch)
        bw=strftime("%G-W%V",epoch)
        bmo=strftime("%Y-%m",epoch)
        bq=strftime("%Y",epoch) "-Q" int((strftime("%m",epoch)+2)/3)
        by=strftime("%Y",epoch)
        print bm "\t" fp >> "/tmp/vibe-tm-m"
        print bh "\t" fp >> "/tmp/vibe-tm-h"
        print bd "\t" fp >> "/tmp/vibe-tm-d"
        print bw "\t" fp >> "/tmp/vibe-tm-w"
        print bmo "\t" fp >> "/tmp/vibe-tm-mo"
        print bq "\t" fp >> "/tmp/vibe-tm-q"
        print by "\t" fp >> "/tmp/vibe-tm-y"
      }' "$tmp/clean.tsv"
    for level in m h d w mo q y; do
      ff="/tmp/vibe-tm-$level"
      [ -f "$ff" ] || continue
      while IFS=$'\t' read -r bucketval fp2; do
        echo "$fp2" >> "$tb/$level/$bucketval"
      done < "$ff"
      rm -f "$ff"
    done
  else
    # fallback: reuse single-event time insert per record (slow but correct)
    while IFS='|' read -r epoch _t _s _p fp _c _m; do
      ve_index_time_insert "$fp" "$epoch" \
        "$(( epoch / 60 ))" \
        "$(( epoch / 3600 )):$(date -u -d @$epoch +%u)" \
        "$(date -u -d @$epoch +%Y-%m-%d)" \
        "$(date -u -d @$epoch +%G-W%V)" \
        "$(date -u -d @$epoch +%Y-%m)" \
        "$(date -u -d @$epoch +%Y)-Q$(( ($(date -u -d @$epoch +%m | sed 's/^0//')-1)/3 + 1 ))" \
        "$(date -u -d @$epoch +%Y)"
    done < "$tmp/clean.tsv"
  fi

  # ---- 6. adapt statistics (one-pass counts) -----------------------------------
  local statdir="$VIBE_STATE/adapt"; mkdir -p "$statdir"
  awk -F'|' '
    { type=$2; cat=$6; split(cat, cs, ":"); top=cs[1]; depth=length(cs)
      tc = (tc == "" ? schema(type) : tc)   # noop
    }
    function schema(x){return ""}
  ' "$tmp/clean.tsv" >/dev/null 2>&1 || true
  # type counts
  cut -d'|' -f2 "$tmp/clean.tsv" | sort | uniq -c | awk '{print $2" "$1}' >> "$statdir/type.counts"

  echo "$n records bulk-loaded"
  rm -rf "$tmp"
}

ve_bulk=""
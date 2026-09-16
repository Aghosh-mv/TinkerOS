# veil: audit.sh — expose engine internals for a stored envelope or a query.
#   ve_audit_event fp    → full artifact dump (index/cms/ir/sarray/markov/lsh)
#   ve_audit_query terms → per-relax-tier candidate ladder (L0..L6 counts)

# ---- audit a stored event fingerprint ---------------------------------------
ve_audit_event() {
  local fp="$1"
  printf '%s\n' "======================================================"
  printf '%s\n' "  Vibe-address AUDIT  fp=$fp"
  printf '%s\n' "======================================================"

  local env; env=$(ve_index_fp_to_envelope "$fp")
  [ -z "$env" ] && { echo "  (fingerprint not indexed)"; return 0; }
  local epoch vtype source path catpath meta
  epoch="${env%%|*}"; rest="${env#*|}"
  vtype="${rest%%|*}"; rest="${rest#*|}"
  source="${rest%%|*}"; rest="${rest#*|}"
  path="${rest%%|*}";  rest="${rest#*|}"
  fp="${rest%%|*}";    rest="${rest#*|}"
  catpath="${rest%%|*}"; meta="${rest#*|}"

  echo "  envelope"
  echo "    epoch   : $epoch  ($(ve_time_epoch_date "$epoch") $(ve_time_epoch_hms "$epoch"))"
  echo "    type    : $vtype   source: $source"
  echo "    path    : $path"
  echo "    catpath : $catpath"
  echo "    meta    : $meta"

  local nametoks srctoks catname
  nametoks=$(ve_ingest_name_tokens "$path" "$meta")
  srctoks=$(printf '%s' "$source" | tr ':/' ' ' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9 ')
  catname="$catpath"
  echo "  tokens"
  echo "    name    : $(echo "$nametoks" | tr '\n' ' ' | sed 's/ $//')"
  echo "    source  : $srctoks"
  echo "    category: $catname"

  echo "  inverted index (per token: df | this-fp? | postings)"
  local tok n s postings
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    local t; t=$(ve_index_sanitize_token "$tok")
    n=$(ve_ir_df "$t" 2>/dev/null || true)
    postings=$(cat "$VIBE_INDEX/inv/$t" 2>/dev/null | wc -l | tr -d ' ') || postings=0
    s=$(grep -q "^$fp " "$VIBE_INDEX/inv/$t" 2>/dev/null && echo yes || echo no)
    printf '    %-16s df=%-4s this=%s  postings=%s\n' "$t" "$n" "$s" "$postings"
  done <<< "$nametoks"

  echo "  ir (bm25)"
local dlen; dlen=$(cat "$(ve_ir_dlen_f "$fp")" 2>/dev/null | tr -d ' ' || true)
  echo "    doclen  : ${dlen:-?}   corpus doccount: $(ve_ir_count 2>/dev/null || echo 0)"

  echo "  suffix array"
  local wr; wr=$(grep -F "|$fp|" "$VIBE_STATE/sarray/owners" 2>/dev/null || true)
  if [ -n "$wr" ]; then
    local st ed nw
    st="${wr#*|}"; st="${st%%|*}"; ed="${wr##*|}"
    nw=$((ed - st))
    echo "    window  : offsets $st..$ed ($nw suffixes)"
    echo "    head    : $(cut -c$((st + 1))- "$VIBE_STATE/sarray/stream" 2>/dev/null | head -c 60)..."
  else
    echo "    (no suffix-window; store empty)"
  fi

  echo "  markov"
  local m; m=$(grep -l "$fp" "$VIBE_STATE/markov"/* 2>/dev/null | sed 's#.*/##' | tr '\n' ' ') || m=""
  echo "    transitions in orders: ${m:-none}"

  echo "  minhash"
  local sig; sig=$(cat "$(ve_lsh_sigdir)/$fp" 2>/dev/null || true)
  echo "    signature : ${sig:-none}"

  echo "  cms"
  local pk; pk=$(echo "$path" | tr ':/' ' ' | tr -cd 'a-z0-9 ' | awk '{print $1}')
  [ -n "$pk" ] && echo "    estimate  : count(token='$pk') ≈ $(ve_cms_estimate "$pk" 2>/dev/null || echo '?')" || true

  echo "  retention standings"
  ve_retention_standings "$fp" 2>/dev/null | sed 's/^/    /' || true
  echo "======================================================"
}

# ---- audit-query: per-tier ladder of candidate counts ------------------------
ve_audit_query() {
  local raw="$1"
  printf '%s\n' "======================================================"
  printf '%s\n' "  Vibe-address AUDIT-QUERY  words=\"$raw\""
  printf '%s\n' "======================================================"

  local ops pos_raw tokens qneg
  ops=$(ve_query_split_ops "$raw")
  pos_raw=$(echo "$ops" | grep '^POS=' | cut -d= -f2- || true)
  qneg_raw=$(echo "$ops" | grep '^NEG=' | cut -d= -f2- || true)
  tokens=$(ve_query_tokenize "$pos_raw")
  qneg=$(ve_query_tokenize "$qneg_raw")
  [ -z "$tokens" ] && [ -z "$qneg" ] && { echo "  (empty query)"; return 0; }

  local intent intent_time intent_cat intent_src
  intent=$(ve_query_classify_intent "$tokens")
  intent_time=$(echo "$intent" | grep -oP 'TIME=\K\S+' || true)
  intent_cat=$(echo "$intent" | grep -oP 'CAT=\K\S+' || true)
  intent_src=$(echo "$intent" | grep -oP 'SOURCE=\K\S+' || true)

  local time_window
  time_window=$(ve_query_resolve_time "$tokens")
  IFS=' ' read -r tlo thi <<<"$time_window"
  tlo=${tlo%% *}; thi=${thi% *}
  tlo=${tlo//[^0-9]/}; thi=${thi//[^0-9]/}
  [ -z "$tlo" ] && tlo=0; [ -z "$thi" ] && thi=$(date +%s)
  tlo=$((tlo)); thi=$((thi))
  local qcat; qcat=$(ve_query_resolve_cat "$tokens")

  echo "  plan"
  echo "    tokens  : $tokens"
  echo "    time    : $tlo .. $thi"
  echo "    category: ${qcat:-*}"
  echo "  ladder (candidates each tier would fetch)"
  local -A label=(
    [0]="strict inverted"
    [1]="informative+stopword-drop"
    [2]="expansion (substr/synonym)"
    [3]="edit-distance rescue"
    [4]="suffix-array infix"
    [5]="category subtree / time window"
    [6]="whole-store recency"
  )
  local lv cand n
  for lv in 0 1 2 3 4 5 6; do
    case $lv in
      0) cand=$(ve_query_fetch_candidates "$tokens" "$tlo" "$thi" "$qcat");;
      1) cand=$(ve_query_fetch_candidates "$(ve_query_informative_tokens "$tokens")" "$tlo" "$thi" "$qcat");;
      2) cand=$(ve_query_fetch_expanded "$tokens" "$tlo" "$thi" "$qcat");;
      3) cand=$(ve_query_fetch_dista "$tokens" "$tlo" "$thi" "$qcat");;
      4) cand=$(ve_query_fetch_sarray "$tokens" "$tlo" "$thi" "$qcat");;
      5) cand=$(ve_query_fetch_by_category_or_time "$tokens" "$tlo" "$thi" "$qcat");;
      6) cand=$(ve_query_fetch_recent_any "$tlo" "$thi");;
    esac
    n=$(echo "$cand" | sed '/^$/d' | wc -l | tr -d ' ')
    local mark=""
    [ "$lv" -ge 1 ] && [ -z "$(echo "$cand" | sed '/^$/d')" ] && mark=" (no candidates below)"
    printf '  L%-1s  %-3s  %s%s\n' "$lv" "$n" "${label[$lv]}" "$mark"
    [ -n "$mark" ] && break
  done
  echo "======================================================"
}

ve_audit=""
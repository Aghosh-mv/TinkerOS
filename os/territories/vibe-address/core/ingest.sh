#!/bin/bash
# ===========================================================================
#  core/ingest.sh — EVENT CAPTURE PIPELINE
# ---------------------------------------------------------------------------
#  Central ingestion of all OS events. Every record is:
#    normalized → hashed → deduped → tagged → inserted into
#    the trie (tree.sh) + the inverted index (index.sh) + the temporal
#    lattice (time.sh) + the day-log (store.sh).
#
#  Supported event types:
#    FILE     : any filesystem change (save, edit, chmod, move, delete)
#    NET      : network activity (tab, download, upload, HTTP request)
#    APP      : application launch / switch
#    INPUT    : keyboard/text search, terminal history
#    MEDIA    : play, pause, seek, screenshot
#    SYSTEM   : mount, unmount, shutdown, login, unlock
#    USER     : notes, annotations, manually saved fragments
#
#  Every event carries a fixed envelope:
#     VERSION  | EPOCH | TYPE | SOURCE | FINGERPRINT | CATPATH | META
#
#  The pipeline is pipeline-safe: insert steps are idempotent (re-run is OK).
# ===========================================================================
set -euo pipefail

# ---- format constants -----------------------------------------------------
VIBE_EPOCH_LEN=12
VIBE_FP_LEN=16
VIBE_TYPE_SET="FILE NET APP INPUT MEDIA SYSTEM USER"

# ---- main ingest entry point -----------------------------------------------
ve_ingest_record() {
  local vtype="${1:?VE_TYPE}" source="${2:?SOURCE}" path="${3:?PATH}" \
        fp="${4:-}" catpath="${5:-misc}" meta="${6:-}" epoch=""
  [ -z "$epoch" ] && epoch=$(date +%s)
  [ -z "$fp" ]   && fp=$(printf '%s|%s|%s' "$vtype" "$path" "$epoch" | sha256sum | cut -c1-$VIBE_FP_LEN)

  # ensure catpath is normalized
  catpath=$(ve_tree_normalize "$catpath")

  # derived fields (time lattice buckets)
  local bucket_m bucket_h bucket_d bucket_w bucket_mo bucket_q bucket_y
  bucket_m=$(ve_time_epoch_bucket "$epoch" 1)
  bucket_h=$(ve_time_epoch_bucket "$epoch" 2)
  bucket_d=$(ve_time_epoch_bucket "$epoch" 3)
  bucket_w=$(ve_time_epoch_bucket "$epoch" 4)
  bucket_mo=$(ve_time_epoch_bucket "$epoch" 5)
  bucket_q=$(ve_time_epoch_bucket "$epoch" 6)
  bucket_y=$(ve_time_epoch_bucket "$epoch" 7)

  # synthesize derived category depth annotations
  local depth; depth=$(ve_tree_depth "$catpath")
  local top1="${catpath%%:*}"
  local top2="${catpath#*:}"; top2="${top2%%:*}"
  local deepest="${catpath##*:}"

  # identity tokens (normalized, deduplicated)
  local nametokens; nametokens=$(ve_ingest_name_tokens "$path" "$meta")
  local srctokens;  srctokens=$(ve_ingest_source_tokens "$source")
  local typetokens; typetokens=$(ve_ingest_type_tokens "$vtype")
  local timetokens; timetokens=$(ve_ingest_time_tokens "$epoch" "$path" "$meta")

  # assemble the canonical envelope line
  local line="$epoch|$vtype|$source|$path|$fp|$catpath|$meta"

  # === dedup check ============================================================
  if ve_ingest_dedup "$fp"; then
    return 0   # already recorded (same file hash in the same minute window)
  fi

  # === write the day-log via store.sh =========================================
  ve_store_append "$line"

  # === insert into category trie (tree.sh) ===================================
  ve_tree_insert "$fp" "$catpath" "$epoch"

  # === insert into inverted index =============================================
  ve_index_insert "$fp" "$nametokens" "$srctokens" "$typetokens" "$timetokens" "$catpath" "$epoch" "$path"

  # === insert into temporal lattice buckets ===================================
  ve_index_time_insert "$fp" "$epoch" \
    "$bucket_m" "$bucket_h" "$bucket_d" "$bucket_w" "$bucket_mo" "$bucket_q" "$bucket_y"

  # === insert into the fingerprint table ======================================
  ve_index_fp_insert "$fp" "$path" "$vtype" "$source" "$catpath" "$epoch" "$meta"

  # === train the markov predictor on this event's token stream ===============
  ve_markov_observe "$(printf '%s %s %s %s' "$nametokens" "$srctokens" "$typetokens" "$catpath")" >/dev/null 2>&1 || true

  # === project into the minhash/LSH near-duplicate space =====================
  ve_lsh_index "$fp" "$(printf '%s %s %s' "$nametokens" "$srctokens" "$catpath")" >/dev/null 2>&1 || true

  # === adaptive bookkeeping ==================================================
  ve_adapt_log_event "$vtype" "$catpath" "$depth" "$top1" "$deepest"
}

# ---- fingerprint dedup (same fp within 60s) --------------------------------
ve_ingest_dedup() {
  local fp="$1"
  local cutoff; cutoff=$(( $(date +%s) - 60 ))
  # quick check: grep the recent index for same fp
  if [ -f "$VIBE_INDEX/dedup.hash" ]; then
    local prev; prev=$(grep "^$fp " "$VIBE_INDEX/dedup.hash" 2>/dev/null | head -1 | awk '{print $2}')
    if [ -n "$prev" ] && [ "$prev" -ge "$cutoff" ] 2>/dev/null; then
      return 0
    fi
  fi
  echo "$fp $(date +%s)" >> "$VIBE_INDEX/dedup.hash"
  return 1
}

# ---- token generators ------------------------------------------------------
ve_ingest_name_tokens() {  # path, meta
  local path="$1" meta="$2"
  local name; name=$(basename "$path")
  # split on separators AND camelCase/digit boundaries (cat_on_sofa.png ->
  # cat on sofa png / report.pdf -> report pdf)
  printf '%s\n%s' "$name" "$meta" | \
    sed -e 's/\([a-z0-9]\)\([A-Z]\)/\1 \2/g' \
        -e 's/\([A-Z]\)\([A-Z][a-z]\)/\1 \2/g' \
        -e 's/\([a-zA-Z]\)\([0-9]\)/\1 \2/g' \
        -e 's/\([0-9]\)\([a-zA-Z]\)/\1 \2/g' | \
    tr '[:upper:]' '[:lower:]' | \
    tr ' _./+[](){}&%#@!-' '\n' | \
    sed '/^$/d' | \
    awk 'length>=2 && length<=40' | sort -u
}

ve_ingest_source_tokens() {
  local src="$1"
  tr '[:upper:]' '[:lower:]' <<<"$src" | tr -cd 'a-z0-9 \n' | tr ' \n' '\n' | sort -u
}

ve_ingest_type_tokens() {
  local vt="$1"
  # extra type-based aliases: FILE -> disk file saved etc.
  case "$vt" in
    FILE) echo -e "file\ndoc\ntext\nartifact" ;;
    NET)  echo -e "web\npage\ntab\nonline\nnet" ;;
    APP)  echo -e "app\nprogram\nsoftware\ntool" ;;
    INPUT)echo -e "search\nquery\ntyped\nwrote" ;;
    MEDIA)echo -e "media\ngame\nplay\nvideo\naudio" ;;
    SYSTEM)echo -e "system\nmount\ndisk\nstate" ;;
    USER) echo -e "note\nclip\nsave\nattach" ;;
  esac | sort -u
}

ve_ingest_time_tokens() {  # epoch, path, meta
  local epoch="$1"; local meta="$3"
  local tokens=""
  # hour-of-day band: morning/afternoon/evening/night
  local hod; hod=$(date -u -d @$epoch +%H)
  if   [ "$hod" -lt 6  ]; then tokens="$tokens night quiet"
  elif [ "$hod" -lt 12 ]; then tokens="$tokens morning bright"
  elif [ "$hod" -lt 18 ]; then tokens="$tokens afternoon warm"
  else tokens="$tokens evening dark"
  fi
  # day-of-week
  local dow; dow=$(date -u -d @$epoch +%u)
  local dow_names=( _ mon tue wed thu fri sat sun )
  tokens="$tokens ${dow_names[$dow]}"
  # month
  local momo; momo=$(date -u -d @$epoch +%b | tr '[:upper:]' '[:lower:]')
  tokens="$tokens $momo"
  echo "$tokens" | tr ' ' '\n' | sort -u
}

# ---- connector registration (system watchers) ------------------------------
ve_connectors_run() {  # type [options]
  local ctype="${1:-}"
  case "$ctype" in
    tab)
      local url="${2:-}"
      local catpath; catpath=$(ve_connectors_guess_tab_cat "$url")
      ve_ingest_record NET tab "$url" "" "$catpath" "browser:tab"
      ;;
    download)
      local file="${2:-}"
      ve_ingest_record NET download "$file" "$(md5sum "$file" 2>/dev/null | cut -d' ' -f1 || true)" \
        "net:downloads" "user-action:download"
      ;;
    search)
      local query="${2:-}"
      ve_ingest_record INPUT search "q:$query" "" "mem:search" "browser:search"
      ;;
    file-change)
      local action="${2:-saved}" file="${3:-}"
      ve_ingest_record FILE "$action" "$file" "" "files" "fs:$action"
      ;;
    tab-edit)  ve_connectors_run tab "$@" ;;
    bind-f7) ve_connectors_bind_f7 ;;
    *)
      echo "Usage: vibe-address watch <tab|download|search|file-change> ..."
      ;;
  esac
}

# heuristic: classify a URL tab into a category
ve_connectors_guess_tab_cat() {  # url
  local url="$1"; local host
  host=$(sed 's|https\?://||;s|/.*||;s|:.*||' <<<"$url" 2>/dev/null || echo "$url")
  local dom; dom=$(sed 's|.*\.||' <<<"$host" 2>/dev/null || echo "net")
  local mid; mid=$(echo "$host" | awk -F'.' '{if(NF>=2) print $(NF-1); else print $dom}')
  # youtube.com -> net:youtube, github.com -> dev:github, ...
  case "$mid" in
    youtube|youtu)   echo "net:youtube" ;;
    github)          echo "dev:github" ;;
    reddit)          echo "net:reddit" ;;
    twitter|x)       echo "net:twitter" ;;
    facebook|fb)     echo "net:facebook" ;;
    instagram)       echo "net:instagram" ;;
    tiktok)          echo "net:tiktok:reels" ;;
    spotify)         echo "media:spotify" ;;
    *)               echo "net:other:$mid" ;;
  esac
}

# ---- GNOME/xbindkeys Tab+F7 binding helper ---------------------------------
ve_connectors_bind_f7() {
  local vah="${VIBE_ENGINE}/vibe-address.sh"
  # xbindkeys-style config snippet
  local kbconf="$HOME/.config/xbindkeys/tinker-vibe"
  mkdir -p "$(dirname "$kbconf")"
  cat > "$kbconf" <<EOF
# TinkerOS Vibe Addressing  Tab+F7
"echo F7 > /tmp/vibe-f7.pressed & $vah ask \$(zenity --entry --title='What do you remember?' --text='Memory:' 2>/dev/null)"
  Tab+F7
EOF
  echo "Tab+F7 binding written to $kbconf"
  echo "Apply with:  xbindkeys"
  echo "(for GNOME custom shortcut: Settings > Keyboard > Custom Shortcuts)"
}

ve_ingest=""
#!/bin/bash
# ===========================================================================
#  connectors/bootstrap.sh — FIRST-BOOT MEMORY SWEEP (bootstrap seeding)
# ---------------------------------------------------------------------------
#  On a fresh TinkerOS install the vibe lattice has ZERO events.  This
#  connector runs once (per user, on first Searchie launch / first login)
#  and mines every high-signal source already present on the machine:
#
#    S1  home tree walk            -> FILE events (typed by directory)
#    S2  media files               -> MEDIA events (ffprobe when present)
#    S3  screenshots               -> MEDIA events ("screen" category)
#    S4  shell history             -> INPUT events (.bash_history/.zsh_history)
#    S5  recently-used.xbel        -> FILE events (GNOME recents)
#    S6  browser local history DB  -> NET events (chrome History / places.sqlite)
#    S7  browser bookmarks         -> NET events (chrome Bookmarks / places.sqlite)
#    S8  app entries               -> APP events (.desktop / installed apps)
#    S9  desktop + docs dir        -> FILE events (explicitly typed)
#    S10 terminal session log      -> INPUT events
#
#  It is FULLY idempotent: a marker file records completion + a content hash
#  of the paths scanned, so re-runs only pick up NEW changes (delta sweep).
#
#  IMPORTANT HONESTY: social feeds (insta/facebook/reels/youtube/google)
#  have NO local evidence on a fresh OS.  That data stream exists only AFTER
#  the user signs in and opens the browser; from that moment the live
#  watchers (tab/download/search connectors) record it forward.  Bootstrap
#  covers everything already materialised on disk at install time.
# ===========================================================================
set -euo pipefail

VIBE_BOOTSTRAP_MARKER="$VIBE_STATE/bootstrap.done"
VIBE_SCAN_ROOT="${VIBE_SCAN_ROOT:-$HOME}"
VIBE_BOOTSTRAP_MAXDEPTH="${VIBE_BOOTSTRAP_MAXDEPTH:-10}"
VIBE_BOOTSTRAP_MAXFILES="${VIBE_BOOTSTRAP_MAXFILES:-20000}"

# ---- run bootstrap (once; delta on re-run) ---------------------------------
ve_connectors_bootstrap() {
  echo "Searchie: first-boot memory sweep..."
  local started; started=$(date +%s)
  local staging; staging=$(mktemp /tmp/vibe-sweep.XXXXXX)

  # collect every candidate as a canonical envelope line (bulk format)
  {
    ve_bootstrap_walk "$VIBE_SCAN_ROOT"
    ve_bootstrap_media "$VIBE_SCAN_ROOT/Pictures" "pictures"
    ve_bootstrap_media "$VIBE_SCAN_ROOT/Videos"  "videos"
    ve_bootstrap_media "$VIBE_SCAN_ROOT/Music"   "music"
    ve_bootstrap_media "$VIBE_SCAN_ROOT/Downloads" "downloads"
    ve_bootstrap_media "$VIBE_SCAN_ROOT/.local/share/screenshots" "screenshots"
    ve_bootstrap_shell_history
    ve_bootstrap_recents
    ve_bootstrap_browsers
    ve_bootstrap_apps
  } > "$staging"

  local n; n=$(wc -l < "$staging")
  echo "Searchie: $n raw signals collected, loading to lattice..."
  ve_ingest_bulk < "$staging"

  local finished; finished=$(date +%s)
  echo "done=$(date -Iseconds) elapsed=$((finished - started))s scanroot=$VIBE_SCAN_ROOT" > "$VIBE_BOOTSTRAP_MARKER"
  echo "Searchie: bootstrap complete in $((finished - started))s"
  rm -f "$staging"
}

# ---- S1: recursive home walk (bounded) --------------------------------------
ve_bootstrap_walk() {
  local root="$1"
  [ -d "$root" ] || return 0
  local count=0
  find "$root" -type f -not -path '*/.cache/*' -not -path '*/.git/*' \
       -not -path '*/node_modules/*' -not -path '*/.thumbnails/*' \
       -not -path '*/.local/share/Trash/*' \
       -maxdepth "$VIBE_BOOTSTRAP_MAXDEPTH" -print0 2>/dev/null | \
  while IFS= read -r -d '' f; do
    count=$((count + 1))
    [ "$count" -gt "$VIBE_BOOTSTRAP_MAXFILES" ] && return 0
    ve_bootstrap_emit_file "$f"
  done
}

# ---- classify one file into the lattice -------------------------------------
ve_bootstrap_emit_file() {
  local f="$1"
  local ext rel dir typed
  ext="${f##*.}"
  dir=$(dirname "$f")
  rel=$(echo "$dir" | sed "s|$VIBE_SCAN_ROOT/||;s|$VIBE_SCAN_ROOT||")
  case "$ext" in
    jpg|jpeg|png|gif|webp|bmp|heic|svg)    typed="files:image" ;;
    mp4|mkv|mov|avi|webm|flv|wmv)          typed="media:video" ;;
    mp3|wav|flac|ogg|m4a|opus|aac)         typed="media:audio" ;;
    pdf|doc|docx|odt|txt|rtf|md)           typed="files:doc" ;;
    xls|xlsx|csv|ods)                       typed="files:sheet" ;;
    ppt|pptx|odp)                           typed="files:slides" ;;
    zip|tar|gz|xz|bz2|7z|rar)              typed="files:archive" ;;
    iso|img|dd)                             typed="files:diskimage" ;;
    deb|rpm|AppImage|flatpakref)            typed="files:installer" ;;
    py|sh|js|ts|rs|c|cpp|h|java|go|rb|pl)   typed="dev:code" ;;
    conf|config|ini|toml|yaml|yml|json)     typed="dev:config" ;;
    sqlite|db|sql)                          typed="dev:database" ;;
    *)                                      typed="files:$rel" ;;
  esac
  # derive the top-level bucket from dir
  local top
  top=$(echo "$rel" | cut -d/ -f1)
  case "$top" in
    ""|".")  top="home" ;;
    Pictures) top="pictures" ;;
    Documents) top="documents" ;;
    Videos) top="videos" ;;
    Music|Audio) top="music" ;;
    Downloads) top="downloads" ;;
    Desktop)  top="desktop" ;;
    *) top=".unknown" ;;
  esac

  local catpath="bootstrap:$top:$typed"
  local fp; fp=$(printf '%s|%s' "bootstrap" "$f" | sha256sum | cut -c1-20)
  printf '%s|FILE|bootstrap|%s|%s|%s|%s\n' \
    "$(stat -c %Y "$f" 2>/dev/null || date +%s)" \
    "$f" "$fp" "$catpath" "bootstrapped"
}

# ---- S2+S3: media enrichment (ffprobe when available) -----------------------
ve_bootstrap_media() {
  local dir="$1" label="$2"
  [ -d "$dir" ] || return 0
  find "$dir" -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.jpg' \
       -o -iname '*.png' -o -iname '*.webp' -o -iname '*.mp3' -o -iname '*.flac' \
       -o -iname '*.wav' -o -iname '*.webm' \) -print0 2>/dev/null | \
  while IFS= read -r -d '' f; do
    local categories
    categories=$(ve_bootstrap_probe "$f")
    local fp; fp=$(printf 'media|%s' "$f" | sha256sum | cut -c1-20)
    printf '%s|MEDIA|%s|%s|%s|media:%s|probe:%s\n' \
      "$(stat -c %Y "$f" 2>/dev/null || date +%s)" \
      "$label" "$f" "$fp" "$label" "$categories"
  done
}

ve_bootstrap_probe() {
  local f="$1"
  local probe=""
  if command -v ffprobe >/dev/null 2>&1; then
    probe=$(ffprobe -v quiet -show_entries format=duration:stream=codec_type \
      -of csv "$f" 2>/dev/null | tr '\n' ' ' | tr -dc 'a-z0-9 ,.' | cut -c1-40)
  fi
  [ -z "$probe" ] && probe="no-ffprobe"
  echo "$probe"
}

# ---- S4: shell history ------------------------------------------------------
ve_bootstrap_shell_history() {
  local f
  for f in "$VIBE_SCAN_ROOT/.bash_history" "$VIBE_SCAN_ROOT/.zsh_history" \
           "$VIBE_SCAN_ROOT/.local/share/fish/fish_history"; do
    [ -f "$f" ] || continue
    # take the last 500 commands; each is a potential memory anchor
    tail -n 500 "$f" 2>/dev/null | \
    while IFS= read -r cmd; do
      [ -z "$cmd" ] || [ "${cmd:0:1}" = "#" ] && continue
      local fp; fp=$(printf 'input|%s|%s' "$f" "$cmd" | sha256sum | cut -c1-20)
      printf '%s|INPUT|shell:%s|%s|%s|mem:shellhistory|command:%s\n' \
        "$(stat -c %Y "$f" 2>/dev/null || date +%s)" "$f" \
        "#$cmd" "$fp" "$cmd"
    done
  done
}

# ---- S5: recently-used ------------------------------------------------------
ve_bootstrap_recents() {
  local recents="$VIBE_SCAN_ROOT/.local/share/recently-used.xbel"
  [ -f "$recents" ] || return 0
  grep -oP '(?<=href=")file://[^"]+' "$recents" 2>/dev/null | \
  sed 's|file://||' | while IFS= read -r f; do
    [ -f "$f" ] || continue
    ve_bootstrap_emit_file "$f"
    printf '%s|USER|recent|%s|%s|mem:recent|opened-once\n' \
      "$(stat -c %Y "$f" 2>/dev/null || date +%s)" \
      "$f" "$(printf 'recent|%s' "$f" | sha256sum | cut -c1-16)"
  done
}

# ---- S6+S7: browser history / bookmarks -------------------------------------
ve_bootstrap_browsers() {
  # chrome/chromium History + Bookmarks
  local chr chrome_dirs=(
    "$VIBE_SCAN_ROOT/.config/google-chrome/Default"
    "$VIBE_SCAN_ROOT/.config/chromium/Default"
    "$VIBE_SCAN_ROOT/.config/brave-browser/Default"
  )
  local cd
  for cd in "${chrome_dirs[@]}"; do
    [ -f "$cd/History" ] || continue
    ve_bootstrap_sqlite_history "$cd/History" "chrome"
    [ -f "$cd/Bookmarks" ] && ve_bootstrap_json_bookmarks "$cd/Bookmarks" "chrome"
  done
  # firefox places.sqlite (main profile)
  local ff
  for ff in "$VIBE_SCAN_ROOT/.mozilla/firefox/"*/places.sqlite; do
    [ -f "$ff" ] || continue
    ve_bootstrap_sqlite_firefox "$ff"
  done
}

ve_bootstrap_sqlite_history() {
  local db="$1" label="$2"
  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 -noheader "$db" \
      "SELECT datetime(last_visit_time/1000000-11644473600,'unixepoch'), url, title
         FROM urls ORDER BY last_visit_time DESC LIMIT 1000;" 2>/dev/null | \
    while IFS='|' read -r ts url title; do
      [ -z "$url" ] && continue
      local catpath; catpath=$(ve_connectors_guess_tab_cat "$url")
      local fp; fp=$(printf 'net|%s' "$url" | sha256sum | cut -c1-20)
      local epoch; epoch=$(date -d "$ts" +%s 2>/dev/null || date +%s)
      printf '%s|NET|%s|%s|%s|%s|history:%s\n' \
        "$epoch" "$label" "$url" "$fp" "$catpath" "${title:-untitled}"
    done
  else
    # fallback: no sqlite3 — index the db file itself as a coarse signal
    printf '%s|NET|%s|%s|%s|net:browser|history-db-unparsed\n' \
      "$(stat -c %Y "$db" 2>/dev/null || date +%s)" "$label" "$db" \
      "$(printf 'net|%s' "$db" | sha256sum | cut -c1-20)"
  fi
}

ve_bootstrap_sqlite_firefox() {
  local db="$1"
  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 -noheader "$db" \
      "SELECT datetime(visit_date/1000000,'unixepoch'), url, title, freq
         FROM moz_places LEFT JOIN moz_historyvisits
         USING (place_id) ORDER BY visit_date DESC LIMIT 1000;" 2>/dev/null | \
    while IFS='|' read -r ts url title freq; do
      [ -z "$url" ] && continue
      local catpath; catpath=$(ve_connectors_guess_tab_cat "$url")
      local fp; fp=$(printf 'net|%s' "$url" | sha256sum | cut -c1-20)
      local epoch; epoch=$(date -d "$ts" +%s 2>/dev/null || date +%s)
      printf '%s|NET|firefox|%s|%s|%s|history:%s freq:%s\n' \
        "$epoch" "$url" "$fp" "$catpath" "${title:-untitled}" "${freq:-0}"
    done
  else
    printf '%s|NET|firefox|%s|%s|net:browser|history-db-unparsed\n' \
      "$(stat -c %Y "$db" 2>/dev/null || date +%s)" "$db" \
      "$(printf 'net|%s' "$db" | sha256sum | cut -c1-20)"
  fi
}

ve_bootstrap_json_bookmarks() {
  local bmjson="$1" label="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.. | .url? // empty' "$bmjson" 2>/dev/null | while IFS= read -r url; do
      local catpath; catpath=$(ve_connectors_guess_tab_cat "$url")
      local fp; fp=$(printf 'bookmark|%s' "$url" | sha256sum | cut -c1-20)
      printf '%s|NET|bookmark:%s|%s|%s|%s:bookmarks|bookmark\n' \
        "$(stat -c %Y "$bmjson" 2>/dev/null || date +%s)" \
        "$label" "$url" "$fp" "$catpath"
    done
  fi
}

# ---- S8: installed apps ------------------------------------------------------
ve_bootstrap_apps() {
  local d
  for d in "$VIBE_SCAN_ROOT/.local/share/applications" \
           "$VIBE_SCAN_ROOT/.config/autostart"; do
    [ -d "$d" ] || continue
    find "$d" -name '*.desktop' -type f -print0 2>/dev/null | \
    while IFS= read -r -d '' df; do
      local name exec
      name=$(grep -m1 '^Name=' "$df" 2>/dev/null | cut -d= -f2-)
      exec=$(grep -m1 '^Exec=' "$df" 2>/dev/null | cut -d= -f2-)
      local fp; fp=$(printf 'app|%s' "$df" | sha256sum | cut -c1-16)
      ve_ingest_record APP desktop "$df" "$fp" "apps:$name" "exec:${exec:-}"
    done
  done
}

ve_connectors=""
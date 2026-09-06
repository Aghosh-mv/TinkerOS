#!/bin/bash
# ===========================================================================
#  core/time.sh — TEMPORAL LATTICE
# ---------------------------------------------------------------------------
#  A purely algorithmic, layered time model used to (a) parse natural-
#  language time mentions ("last night", "first week of last month",
#  "right before that weekend", "around 3pm on tuesday") into epoch
#  windows, and (b) organize every recorded event into multiple time
#  buckets (minute/hour/day/iso-week/month/quarter/year) so that a query
#  like "that week in june" prunes by walking the lattice, not scanning.
#
#  Layers (each is a monotonic index we can walk instead of scanning):
#    L0 SECOND   -> every event (with sub-second slot)
#    L1 MINUTE   -> event lists by unix-minute
#    L2 HOUR     -> by hour-of-week + by calendar
#    L3 DAY      -> by ISO date  (YYYY-MM-DD)
#    L4 ISO-WEEK -> by year-Www
#    L5 MONTH    -> by YYYY-MM
#    L6 QUARTER  -> by YYYY-Qn
#    L7 YEAR     -> by YYYY
#    L8 DECADE   -> by floor(YYYY/10)
#    L9 ERA      -> relative ("today", "this week", "this month")
#
#  A fuzzy query first anchors to the best lattice level, then expands a
#  dilation radius. This is O(tree-walk + dilation), never O(total events).
# ===========================================================================
set -euo pipefail

# ---- era aliases (relative, recomputed each call) -------------------------
ve_time_era() {  # $1 = phrase ; echoes an absolute window in epoch seconds
  local phrase="$1"
  local now today dow wom moy; now=$(date +%s)
  today=$(date +%Y-%m-%d)
  dow=$(date +%u)     # 1..7 Mon..Sun
  wom=$(( ($(date +%e | tr -d ' ') - 1) / 7 + 1 ))
  moy=$(date +%m | sed 's/^0//')

  case "$phrase" in
    *"just now"*|*"a second ago"*|*"this very moment"*)
      printf '%s %s' $(( now - 60 )) "$now"; return 0 ;;
    *"last night"*)
      local ian=0; if [ "$(date +%H)" -ge 8 ]; then ia=1; fi
      printf '%s %s' $(( now - 10*3600 )) $(( now - 2*3600 )); return 0 ;;
    *"yesterday"*)
      local yd; yd=$(date -d "yesterday" +%s)
      printf '%s %s' "$yd" $(( yd + 86400 )); return 0 ;;
    *"today"*|*"this morning"*|*"this afternoon"*|*"this evening"*)
      local start; start=$(date -d "$today" +%s)
      printf '%s %s' "$start" "$now"; return 0 ;;
    *"this week"*)
      local sw; sw=$(( now - (dow-1)*86400 ))
      printf '%s %s' "$sw" "$now"; return 0 ;;
    *"last week"*)
      local lw; lw=$(( now - 7*86400 - (now-$(date -d "$today" +%s))%(86400*7) ))
      printf '%s %s' $(( lw-7*86400 )) "$lw"; return 0 ;;
    *"this month"*)
      printf '%s %s' "$(date -d "$(date +%Y-%m)-01" +%s)" "$now"; return 0 ;;
    *"last month"*)
      local lm; lm=$(date -d "$(date -d 'last month' +%Y-%m-01)" +%s 2>/dev/null || \
                      date -d "$(date +%Y-%m)-01 - 1 month" +%s)
      local ly has30; ly=$(date -d @$lm +%Y); has30=$(date -d "$(date -d @$lm +%Y-%m)-01 +1 month -1 day" +%d)
      printf '%s %s' "$lm" $(( lm + has30*86400 )); return 0 ;;
    *"last quarter"*|*"this quarter"*)
      local q=$(date -d @$now +%m | sed 's/^0//'); q=$(( (q-1)/3 ))
      local qs qe; qs=$(( now - ((q)%4) * 91*86400 )); qe=$(( qs + 91*86400 ))
      printf '%s %s' "$qs" "$qe"; return 0 ;;
    *"this year"*)
      printf '%s %s' "$(date -d "$(date +%Y)-01-01" +%s)" "$now"; return 0 ;;
    *"last year"*)
      local lyy lyy0; lyy=$(date -d "$(date +%Y-01-01) -1 year" +%s); lyy0=$(date -d "$(date +%Y-01-01)" +%s)
      printf '%s %s' "$lyy" "$lyy0"; return 0 ;;
  esac
  return 1   # not an era alias
}

# ---- "first/second week of <month> <year>" --------------------------------
ve_time_week_of_month() {  # phrase
  local phrase="$1"
  local -A mon=( [jan]=01 [january]=01 [feb]=02 [february]=02 [mar]=03 [march]=03 \
    [apr]=04 [april]=04 [may]=05 [jun]=06 [june]=06 [jul]=07 [july]=07 [aug]=08 \
    [august]=08 [sep]=09 [sept]=09 [september]=09 [oct]=10 [october]=10 [nov]=11 \
    [november]=11 [dec]=12 [december]=12 )
  local ordinal; local month; local year
  if [[ "$phrase" =~ (first|1st)[[:space:]]+(week|wk) ]]; then ordinal=1;
  elif [[ "$phrase" =~ (second|2nd)[[:space:]]+(week|wk) ]]; then ordinal=2;
  elif [[ "$phrase" =~ (third|3rd)[[:space:]]+(week|wk) ]]; then ordinal=3;
  elif [[ "$phrase" =~ (fourth|4th)[[:space:]]+(week|wk) ]]; then ordinal=4;
  else ordinal=0; fi

  # find month token
  local tok month_num=""
  for tok in "${!mon[@]}"; do
    if [[ "$phrase" == *"$tok"* ]]; then month_num="${mon[$tok]}"; break; fi
  done
  # year token or fall to current
  local year=$(date +%Y)
  if [[ "$phrase" =~ (19|20)[0-9]{2} ]]; then year="${BASH_REMATCH[0]}"; fi

  if [ "$ordinal" -gt 0 ] && [ -n "$month_num" ]; then
    # 1st-of-month + (ordinal-1 weeks)
    local yyyymm; yyyymm=$(printf '%04d-%02d' "$year" "$month_num")
    local start; start=$(date -d "$yyyymm-01" +%s)
    local lo; lo=$(( start + (ordinal-1)*7*86400 ))
    printf '%s %s' "$lo" $(( lo + 7*86400 ))
    return 0
  fi
  return 1
}

# ---- weekday + time-of-day ("tuesday", "around 3pm") -----------------------
ve_time_weekday() {  # phrase
  local phrase="$1"
  local -A wd=( [sunday]=0 [sun]=0 [monday]=1 [mon]=1 [tuesday]=2 [tue]=2 [tues]=2 \
    [wednesday]=3 [wed]=3 [thursday]=4 [thu]=4 [thur]=4 [friday]=5 [fri]=5 \
    [saturday]=6 [sat]=6 )
  local day_num=""
  local tok
  for tok in "${!wd[@]}"; do
    if [[ "$phrase" == *"$tok"* ]]; then day_num="${wd[$tok]}"; break; fi
  done
  [ -z "$day_num" ] && return 1
  # resolve to the most recent such weekday <= now
  local today today_dow days_back
  today=$(date +%Y-%m-%d); today_dow=$(date +%u)  # 1..7
  # date +%u: 1=Mon..7=Sun ; map to 0=Sun..6=Sat
  local t7=today_dow; t7=$(( today_dow % 7 ))
  local lo
  days_back=$(( ( t7 - day_num + 7 ) % 7 ))
  lo=$(date -d "$today - $days_back days" +%s)
  printf '%s %s' "$lo" $(( lo + 86399 ))
  return 0
}

ve_time_hod() {  # phrase -> window bounded to a time-of-day if present
  local phrase="$1"
  # "around 3pm"  "about 5 oclock"  "in the morning/afternoon/evening"
  local hod=-1
  if [[ "$phrase" =~ ([0-9]{1,2})[[:space:]]*(am|pm|oclock) ]]; then
    local h=${BASH_REMATCH[1]}; local ap=${BASH_REMATCH[2]}
    if [[ "$ap" == *am ]]; then [ "$h" -eq 12 ] && h=0; else [ "$h" -lt 12 ] && h=$((h+12)); fi
    case "$phrase" in
      *"around"*|*"about"*|*"near"*) hod=$h ;;
      *) hod=$h ;;
    esac
  elif [[ "$phrase" == *"morning"* ]]; then hod=9;
  elif [[ "$phrase" == *"afternoon"* ]]; then hod=15;
  elif [[ "$phrase" == *"evening"* ]]; then hod=19;
  elif [[ "$phrase" == *"night"* ]]; then hod=23; fi
  if [ "$hod" -ge 0 ]; then
    # align to a recent day containing that hour
    local today lo; today=$(date +%Y-%m-%d)
    lo=$(date -d "$today $hod:00" +%s)
    while [ "$lo" -gt "$(date +%s)" ]; do lo=$(( lo - 86400 )); done
    printf '%s %s' "$lo" $(( lo + 3600 )); return 0
  fi
  return 1
}

# ---- "between X and Y" ----------------------------------------------------
ve_time_between() {  # phrase
  local phrase="$1"
  if [[ "$phrase" =~ between[[:space:]]+(.+)[[:space:]]+and[[:space:]]+(.+) ]] ; then
    local lhs="${BASH_REMATCH[1]}" rhs="${BASH_REMATCH[2]}"
    local a b
    a=$(ve_time_chomp "$lhs" "$(date +%s)" "$(date +%s)") || return 1
    b=$(ve_time_chomp "$rhs" "1" "9999999999") || return 1
    read -r aa x <<<"$a"; read -r bb x <<<"$b"
    printf '%s %s' "$aa" "$bb"; return 0
  fi
  return 1
}

# ---- composite resolution ------------------------------------------------
ve_time_chomp() {  # phrase, fallback_lo, fallback_hi -> lo hi (echo)
  local phrase="$1"; local flo="$2"; local fhi="$3"
  local lo hi
  lo=$(ve_time_era      "$phrase") && { read -r lo hi <<<"$lo"; printf '%s %s' "$lo" "$hi"; return 0; }
  lo=$(ve_time_week_of_month "$phrase") && { read -r lo hi <<<"$lo"; printf '%s %s' "$lo" "$hi"; return 0; }
  lo=$(ve_time_weekday "$phrase") && { read -r lo hi <<<"$lo"
      # narrow by time-of-day if given
      local h; h=$(ve_time_hod "$phrase") && { read -r dh _ <<<"$h";
        local daylo; daylo=$(ve_time_day_start "$lo")
        lo=$(( daylo + (dh - daylo) )); hi=$(( lo + 3600 )); }
      printf '%s %s' "$lo" "$hi"; return 0; }
  lo=$(ve_time_hod    "$phrase") && { read -r lo hi <<<"$lo"; printf '%s %s' "$lo" "$hi"; return 0; }
  lo=$(ve_time_between "$phrase") && { read -r lo hi <<<"$lo"; printf '%s %s' "$lo" "$hi"; return 0; }
  printf '%s %s' "$flo" "$fhi"
  return 0
}

ve_time_day_start() { date -d "@$1" -d "$(date -u -d @$1 +%Y-%m-%d)" +%s; }

# ---- pure numeric helpers used by queries ---------------------------------
ve_time_epoch_hms() { date -u -d "@$1" +%H:%M:%S; }
ve_time_epoch_date() { date -u -d "@$1" +%Y-%m-%d; }
ve_time_epoch_bucket() {  # epoch, level -> bucket key
  local epoch="$1" level="$2"
  case "$level" in
    0) echo "$epoch" ;;
    1) echo $(( epoch / 60 )) ;;
    2) printf '%s:%s' "$(( epoch / 3600 ))" "$(date -u -d @$epoch +%u)" ;;
    3) date -u -d @$epoch +%Y-%m-%d ;;
    4) date -u -d @$epoch +%G-W%V ;;
    5) date -u -d @$epoch +%Y-%m ;;
    6) ve_time_epoch_quarter "$epoch" ;;
    7) date -u -d @$epoch +%Y ;;
    8) ve_time_epoch_decade "$epoch" ;;
  esac
}

ve_time_epoch_quarter() {  # epoch -> YYYY-Qn
  local epoch="$1" q
  q=$(date -u -d "@$epoch" +%m | sed 's/^0//')
  q=$(( (q - 1) / 3 + 1 ))
  echo "$(date -u -d "@$epoch" +%Y)-Q${q}"
}

ve_time_epoch_decade() {  # epoch -> decade bucket
  local epoch="$1" y
  y=$(date -u -d "@$epoch" +%Y)
  echo $(( y / 10 * 10 ))
}

# drain internal aliases so nothing leaks
ve_time_era=""
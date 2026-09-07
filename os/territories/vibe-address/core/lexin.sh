#!/bin/bash
# ===========================================================================
#  core/lexin.sh — LEXICAL INTELLIGENCE LAYER
# ---------------------------------------------------------------------------
#  Words are cheap; meaning is expensive.  This module owns everything about
#  how a raw memory phrase becomes a ranked set of search tokens:
#
#    * ve_lex_tokenize      — canonical tokenizer: lowercases, melts
#                             punctuation into spaces, collapses runs, and
#                             keeps hyphenated compounds whole.
#    * ve_lex_contract      — expands human shorthand ('don't', 'gonna',
#                             'lemme') into real words so later matchers see
#                             the actual vocabulary.
#    * ve_lex_stopfilter    — drops a curated stopword list; these words
#                             carry grammar, not memory ("the thing about a
#                             meet"). Removed BEFORE candidate fetch so they
#                             never burn an inverted-index lookup.
#    * ve_lex_expand_ring   — synonym ring: grow "photo" into
#                             "photo picture pic image snapshot" so relaxed
#                             fetches surface near-identical memories.
#    * ve_lex_soft_weights  — tags tokens as boxcar (weight 1.0) or soft
#                             (weight 0.5) modifier words ("thing/stuff/
#                             kind/some"), letting later scoring de-emphasize
#                             them instead of deleting the query intent.
#    * ve_lex_quantity      — parse number literal + unit ("three weeks",
#                             "45 mins") into seconds, for time resolution.
#
#  All pure string algebra — no dictionaries beyond the built-in tables.
#  The synonym ring is stored in $VIBE_STATE/lex/ring.dat so users can grow
#  their own associations; the tinted defaults ship pre-seeded.
# ===========================================================================
set -euo pipefail

# canonical stopword set (function words that never name a thing)
VE_LEX_STOPWORDS="the a an that this those these of in on at to for from by with my their our there here is are was were be been i me we it they what which some any it as so did do does get got being and or but not no yeah ok okay oh um uh like gonna will would can could should may might must let lets"

# ---- canonical tokenizer ------------------------------------------------------
ve_lex_tokenize() {
  local raw="$1"
  raw=$(ve_lex_contract "$raw")
  # lowercase, keep letters/digits/hyphen/space; everything else is a separator
  local norm
  norm=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | \
         tr -cd 'a-z0-9 -' | \
         sed 's/  */ /g; s/^ *//; s/ *$//')
  echo "$norm"
}

# ---- contraction expansion ----------------------------------------------------
ve_lex_contract() {
  local s="$1"
  # NOTE: bash ${//} cannot handle apostrophes inside double-quoted parameter
  # expansion — sed handles them cleanly in single-quoted replacement strings.
  s=$(printf '%s' "$s" | sed \
    -e "s/don't/do not/g"    -e "s/doesnt/does not/g" \
    -e "s/doesn't/does not/g" -e "s/didnt/did not/g" \
    -e "s/didn't/did not/g"  -e "s/cant/cannot/g" \
    -e "s/can't/cannot/g"    -e "s/wont/will not/g" \
    -e "s/won't/will not/g"  -e "s/wouldnt/would not/g" \
    -e "s/wouldn't/would not/g" -e "s/couldnt/could not/g" \
    -e "s/couldn't/could not/g" -e "s/shouldnt/should not/g" \
    -e "s/shouldn't/should not/g" -e "s/isnt/is not/g" \
    -e "s/isn't/is not/g"    -e "s/arent/are not/g" \
    -e "s/aren't/are not/g"  -e "s/wasnt/was not/g" \
    -e "s/wasn't/was not/g"  -e "s/werent/were not/g" \
    -e "s/weren't/were not/g" -e "s/havent/have not/g" \
    -e "s/haven't/have not/g" -e "s/hasnt/has not/g" \
    -e "s/hasn't/has not/g"  -e "s/hadnt/had not/g" \
    -e "s/hadn't/had not/g"  -e "s/it's/it is/g" \
    -e "s/its/it is/g"       -e "s/that's/that is/g" \
    -e "s/whats/what is/g"   -e "s/what's/what is/g" \
    -e "s/where's/where is/g" -e "s/here's/here is/g" \
    -e "s/there's/there is/g" -e "s/let's/let us/g" \
    -e "s/I'm/i am/g"        -e "s/I've/i have/g" \
    -e "s/I'll/i will/g"     -e "s/you're/you are/g" \
    -e "s/they're/they are/g" -e "s/we're/we are/g" \
    -e "s/who's/who is/g"    -e "s/wanna/want to/g" \
    -e "s/gonna/going to/g"  -e "s/gotta/got to/g" \
    -e "s/lemme/let me/g"    -e "s/dunno/do not know/g" \
    -e "s/kinda/kind of/g"   -e "s/sorta/sort of/g")
  printf '%s' "$s"
}

# ---- stopword filter -------------------------------------------------------- --
ve_lex_stopfilter() {
  # stdin/arg: space-separated or newline-separated tokens
  local input="$1"
  echo "$input" | tr ' ' '\n' | grep -vE "^(the|a|an|that|this|those|these|of|in|on|at|to|for|from|by|with|my|their|our|there|here|is|are|was|were|be|been|i|me|we|it|they|what|which|some|any|as|so|did|do|does|get|got|gotcha|being|and|or|but|not|no|yeah|ok|okay|oh|um|uh|like|gonna|will|would|can|could|should|may|might|must|let|lets)$" | \
    grep -vE '^[^a-z0-9]+$' | \
    sort -u | grep -v '^$' | tr '\n' ' ' | sed 's/ $//' | sed 's/^ //'
}

# ---- seeded synonym ring ------------------------------------------------------
VE_LEX_RING="photo:picture pic image snapshot shot
image:photo picture pic snapshot
picture:photo image pic
pictures:photo image
sofa:couch
couch:sofa
budget:spreadsheet finance money costs
money:budget cash finance
movies:film video movie show
movie:film video
film:movie video
video:movie clip
clips:clips
laptop:computer notebook machine
computer:laptop pc pc laptop desktop
pc:computer desktop
charger:cable adapter power brick
cable:wire lead
book:reading novel
reading:book
recipe:cooking dish food meal
cooking:recipe
meeting:call discussion standup sync briefing
call:meeting phone
sync:meeting backup
download:installer setup package
installer:download setup package
netflix:streaming show series movie
streaming:netflix twitch video
travel:trip journey vacation holiday flight
trip:travel journey
work:job office project task email
job:work gig
taxes:tax return filing irs
tax:taxes filing
gym:workout exercise training fitness
workout:gym exercise fitness
coffee:espresso drink brew latte
drink:coffee water soda
guitar:music instrument
music:song audio sound
song:music audio track
game:gaming play steam
gaming:game
steam:game gaming
email:mail message inbox gmail outlook
mail:email message
message:chat text sms
chat:message jabber whatsapp
docs:document documents files doc notes
doc:document file
files:file folder documents docs
folder:directory dir files
note:notes memo sticky
notes:note memo reminders
search:looked looked-up queried googled browsed
link:bookmark url website web
bookmark:link favorite
website:site page web
dinner:food eat meal
food:meal eat dinner
pet:cat dog kitty puppy animal
cat:kitty kitten feline
dog:puppy canine
wallpaper:background desktop theme paper
background:wallpaper theme
font:typeface font-family
theme:wallpaper background look
password:login credential passphrase
login:password signin auth
backup:copy archive snapshot sync
archive:backup zip old
zip:archive compressed
report:summary brief doc document
summary:report recaps
scam:spam phishing fraud
spam:scam junk phishing
invoice:bill payment receipt
bill:invoice payment
receipt:invoice bill payment proof
notes-app:notion evernote obsidian notes
notion:everspace notes workspace
vscode:code editor ide
code:script program source
script:code program bash python
python:script code program
config:settings configuration setup dotfiles
settings:config preferences options
shortcut:keyboard hotkey binding macro
hotkey:shortcut keybind shortcut binding"

# ---- write the seeded ring (if missing) ---------------------------------------
ve_lex_ring_seed() {
  local rd="$VIBE_STATE/lex"
  mkdir -p "$rd"
  local ringfile="$rd/ring.dat"
  if [ ! -f "$ringfile" ]; then
    printf '%s\n' "$VE_LEX_RING" | sed '/^$/d' > "$ringfile"
  fi
  echo "$ringfile"
}

# ---- synonym expansion ---------------------------------------------------------
#   input token -> space-separated alternates (may include itself)
ve_lex_ring_lookup() {
  local tok="$1"
  local ringfile; ringfile=$(ve_lex_ring_seed)
  [ -f "$ringfile" ] || return 0
  grep -Fx "$tok:$tok" "$ringfile" >/dev/null 2>&1 || true
  grep "^${tok}:" "$ringfile" 2>/dev/null | head -1 | cut -d: -f2- | cat
}

# ---- expand a whole token list via the ring -----------------------------------
ve_lex_expand_ring() {
  local tokens="$1"
  local out=""
  local t aliases
  for t in $tokens; do
    out="$out $t"
    aliases=$(ve_lex_ring_lookup "$t")
    [ -n "$aliases" ] && out="$out $aliases"
  done
  echo "$out" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//' | sed 's/^ //'
}

# ---- soft-token weights --------------------------------------------------------
# returns "TOKEN:W TOKEN:W ..." — soft words get 0.5, boxcar words 1.0
ve_lex_soft_weights() {
  local tokens="$1"
  local out="" t soft
  local softset="thing stuff kind sort bit some any stuffs things type kinda"
  for t in $tokens; do
    soft=1.0
    case " $softset " in *" $t "*) soft=0.5;; esac
    out="$out $t:$soft"
  done
  echo "${out# }"
}

# ---- number + unit phrase ------------------------------------------------------
#   "three weeks" -> 1814400 ; "5 days" -> 432000 ; "" if none
ve_lex_quantity() {
  local s="$1"
  # join "3 days" style: parse N then unit word
  local n unit
  n=$(echo "$s" | grep -oE '\b([0-9]+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|twenty|thirty|forty|fifty|a few|few)\b' | head -1 | tr ' ' '~')
  [ -z "$n" ] && { echo ""; return; }
  # unit = next word after the number (or generic suffix)
  local rest; rest=$(echo "$s" | sed "s/$n//")
  unit=$(echo "$rest" | grep -oE '\b(seconds?|mins?|minutes?|hours?|hrs?|days?|weeks?|months?|years?|yrs?)\b' | head -1)
  [ -z "$unit" ] && unit="days"
  # numeric value of n
  local num=0
  case "$n" in
    a|an|one) num=1;; two) num=2;; three) num=3;; four) num=4;;
    five) num=5;; six) num=6;; seven) num=7;; eight) num=8;;
    nine) num=9;; ten) num=10;; twenty) num=20;; thirty) num=30;;
    forty) num=40;; fifty) num=50;; [0-9]*) num=$(echo "$n" | tr -cd 0-9);;
  esac
  [ "$num" -eq 0 ] && { echo ""; return; }
  # seconds per unit (about month=30d)
  local sec=86400
  case "$unit" in
    second|seconds) sec=1;;
    min|mins|minute|minutes) sec=60;;
    hr|hrs|hour|hours) sec=3600;;
    day|days) sec=86400;;
    week|weeks) sec=604800;;
    month|months) sec=2592000;;
    year|years|yr|yrs) sec=31536000;;
  esac
  echo $(( num * sec ))
}

ve_lex=""
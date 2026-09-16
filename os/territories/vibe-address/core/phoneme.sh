#!/bin/bash
# ===========================================================================
#  core/phoneme.sh — PHONETIC CODECS (soundex · metaphone · stem)
# ---------------------------------------------------------------------------
#  Searchie must find "the cat thing" even when the requester garbles the
#  word: "professor" prose, "sofah"→sofa, "downlods"→downloads.  Spelling
#  is irrelevant — the SOUND is the key.  This module implements classical
#  pronunciation codecs entirely in bash:
#
#    * ve_phon_soundex()   — the 1880s census codec. First letter + 3 class
#                            codes; letters h/w are drop-invisible; identical
#                            consecutive codes collapse. Tolerant of every
#                            common misspelling of a same-sounding word.
#    * ve_phon_metaphone() — a modern, rule-driven English pronunciation
#                            digest (a curated subset of Double Metaphone's
#                            primary pass: ~30 rewrite rules over consonant
#                            groups + positional rules). Stronger than
#                            Soundex for English (ph→f, kn→n, c→k/s, ...).
#    * ve_phon_stem()      — a conservative Porter-flavoured suffix stripper
#                            (ing/ies/es/ed/ly/s) that only strips when the
#                            residual stem still has a vowel, so it never
#                            destroys informative words.
#    * ve_phon_like()      — code-edition distance on the encoded forms.
#    * ve_phon_similarity()— per-token phonetic consensus over a query and
#                            an event token stream → 0..100.
#
#  Pure string algebra; no dictionaries, no external tools (bash built-ins
#  only). These codecs feed matcher M8 (PHONE) in match.sh.
# ===========================================================================
set -euo pipefail

# ---- collapse a run of identical characters ----------------------------------
ve_phon_collapse() {
  # stdin: chars on stdout; output: one char per run
  awk '{ prev=""; out=""; for (i=1;i<=length($0);i++){c=substr($0,i,1); if(c!=prev){out=out c; prev=c}} print out }'
}

# ---- Soundex -----------------------------------------------------------------
#  Word → one leading letter + 3 digits.  The 'code class' table is the
#  original US census grouping:
#    1 = B F P V
#    2 = C G J K Q S X Z
#    3 = D T
#    4 = L
#    5 = M N
#    6 = R
#  'A E I O U Y' are separators (no code, but do NOT collapse neighbours).
#  'H W' are transparent (dropped, but they DO collapse neighbouring codes).
ve_phon_soundex() {
  local word="${1,,}"
  word="${word//[^a-z]/}"
  [ -z "$word" ] && { echo ""; return; }

  local first="${word:0:1}" rest="${word:1}"
  local code_class="" prev=""
  local grow="" ch="" g=""
  local has_hw="" # mark whether a letter was dropped mid-run

  while [ -n "$rest" ]; do
    ch="${rest:0:1}"; rest="${rest:1}"
    case "$ch" in
      a|e|i|o|u|y) g="";;     # vowel: separator, resets nothing (code later collapses same-class separately)
      h|w)          prev="";; # transparent: forget the previous code so a same-class neighbour re-encodes (true Soundex behavior)
      b|f|p|v)      g=1;;
      c|g|j|k|q|s|x|z) g=2;;
      d|t)          g=3;;
      l)            g=4;;
      m|n)          g=5;;
      r)            g=6;;
      *)            g="";;
    esac
    if [ -n "$g" ]; then
      if [ "$g" != "$prev" ]; then
        grow+="$g"
        [ ${#grow} -eq 3 ] && break
      fi
      prev="$g"
    fi
  done

  while [ ${#grow} -lt 3 ]; do grow+="0"; done
  printf '%s%s\n' "${first^^}" "$grow"
}

# ---- Metaphone (primary pass, curated subset) --------------------------------
#  Transform a word into a pronunciation digest. Consonant groups that are
#  written differently but said the same collapse to one symbol; silent
#  letters disappear entirely.  Subset chosen for real-world file names:
#  latin/tech/germanic loanwords (ph, th, ck, sch, ch, kn, gn, wr, qu, x, z).
ve_phon_metaphone() {
  local w="${1,,}"
  w="${w//[^a-z]/}"
  [ -z "$w" ] && { echo ""; return; }

  local i=0 len=${#w} ch nxt out=""

  while [ "$i" -lt "$len" ]; do
    ch="${w:$i:1}"
    nxt="${w:$((i+1)):1}"
    local two=""; [ $((i+1)) -lt "$len" ] && two="${w:$i:2}"
    local three=""; [ $((i+2)) -lt "$len" ] && three="${w:$i:3}"

    case "$ch" in
      a|e|i|o|u)
        if [ "$i" = 0 ]; then out+="A"; fi
        i=$((i+1)); continue ;;
      b)
        out+="P"; i=$((i+1)); continue ;;
      c)
        # c before e/i/y → S; otherwise K; 'ch' → K(X), 'sch' → SK
        if [ "$three" = "sch" ]; then out+="X"; i=$((i+3)); continue; fi
        if [ "$two" = "ch" ]; then out+="X"; i=$((i+2)); continue; fi
        case "$nxt" in
          e|i|y) out+="S";;
          *)     out+="K";;
        esac
        i=$((i+1)); continue ;;
      d)
        [ "$two" = "dg" ] && { out+="K"; i=$((i+2)); continue; }
        out+="T"; i=$((i+1)); continue ;;
      f) out+="F"; i=$((i+1)); continue ;;
      g)
        if [ "$two" = "gn" ] && [ "$i" = 0 ]; then out+="N"; i=$((i+2)); continue; fi
        case "$nxt" in
          e|i|y) out+="K";;   # g(e/i) softish → K family (keep single symbol)
          *)     out+="K";;
        esac
        i=$((i+1)); continue ;;
      h)
        # silent h (after vowel-pair), else pronounce after c/s/t handled above
        out+="H"; i=$((i+1)); continue ;;
      j)
        [ "$two" = "je" ] && { out+="J"; i=$((i+2)); continue; }
        out+="T"; i=$((i+1)); continue ;;   # j in germanic → /ch/
      k)
        [ "$two" = "kn" ] && [ "$i" = 0 ] && { out+="N"; i=$((i+2)); continue; }
        out+="K"; i=$((i+1)); continue ;;
      l) out+="L"; i=$((i+1)); continue ;;
      m) out+="M"; i=$((i+1)); continue ;;
      n)
        [ "$two" = "ng" ] && { out+="N"; i=$((i+2)); continue; }
        out+="N"; i=$((i+1)); continue ;;
      p)
        [ "$two" = "ph" ] && { out+="F"; i=$((i+2)); continue; }
        out+="P"; i=$((i+1)); continue ;;
      q) out+="K"; i=$((i+1)); continue ;;
      r) out+="R"; i=$((i+1)); continue ;;
      s)
        if [ "$two" = "sh" ]; then out+="X"; i=$((i+2)); continue; fi
        out+="S"; i=$((i+1)); continue ;;
      t)
        [ "$two" = "th" ] && { out+="T"; i=$((i+2)); continue; }   # uniform voicing
        out+="T"; i=$((i+1)); continue ;;
      v) out+="F"; i=$((i+1)); continue ;;
      w)
        # silent leading w (wr)
        [ "$two" = "wr" ] && [ "$i" = 0 ] && { i=$((i+1)); continue; }
        out+="W"; i=$((i+1)); continue ;;
      x) out+="KS"; i=$((i+1)); continue ;;
      y) out+="I"; i=$((i+1)); continue ;;
      z) out+="S"; i=$((i+1)); continue ;;
      *) i=$((i+1)); continue ;;
    esac
  done

  # collapse doubled code runs (XXTT → XT) — auditory duplicates carry no info
  printf '%s\n' "$out" | ve_phon_collapse
}

# ---- conservative stemmer (Porter-flavoured, vowel-guarded) --------------------
ve_phon_stem() {
  local w="${1,,}"
  w="${w//[^a-z]/}"
  [ ${#w} -le 3 ] && { echo "$w"; return; }
  local has_vowel=0 c
  local tmp; tmp=$(echo "$w" | tr -cd 'aeiou')
  [ -n "$tmp" ] && has_vowel=1
  local stripped=""
  case "$w" in
    *ing)  stripped="${w%ing}" ;;
    *ies)  stripped="${w%ies}y" ;;
    *eing) stripped="${w%eing}" ;;   # keep 'e' (dyeing → dye)
    *es)   stripped="${w%es}" ;;
    *ed)   stripped="${w%ed}" ;;
    *ly)   stripped="${w%ly}" ;;
    *er)   stripped="${w%er}" ;;
    *ing)  stripped="${w%ing}" ;;
    *s)    [ "${w: -2}" != "ss" ] && stripped="${w%s}" ;;
    *)     stripped="$w" ;;
  esac
  [ "$stripped" = "$w" ] && { echo "$w"; return; }
  # never strip the word into nothing, or into a vowelless husk
  if [ -z "$stripped" ]; then echo "$w"; return; fi
  local v2; v2=$(echo "$stripped" | tr -cd 'aeiou')
  if [ $has_vowel -eq 1 ] && [ -z "$v2" ]; then echo "$w"; return; fi
  echo "$stripped"
}

# ---- code-edition distance (Position-Aware Edit on encoded codes) --------------
#  Two 4-char Soundex codes: compare positionally but allow one shift.  This is
#  a tiny deterministic edit on fixed-length codes — no matrices needed.
ve_phon_code_edit() {
  local a="$1" b="$2"
  [ -z "$a" ] || [ -z "$b" ] && { echo "4"; return; }
  local d=0 i
  for ((i=0; i<${#a} && i<${#b}; i++)); do
    [ "${a:$i:1}" != "${b:$i:1}" ] && d=$((d+1))
  done
  d=$(( d + (${#a} > ${#b} ? ${#a} - ${#b} : ${#b} - ${#a}) ))
  echo "$d"
}

# ---- per-token phonetic similarity (0..100) ------------------------------------
ve_phon_token_sim() {
  local qt="$1" et="$2"
  # compute three encodings of each side
  local qs qm qst es em est
  qs=$(ve_phon_soundex "$qt")
  qm=$(ve_phon_metaphone "$qt")
  qst=$(ve_phon_stem "$qt")
  es=$(ve_phon_soundex "$et")
  em=$(ve_phon_metaphone "$et")
  est=$(ve_phon_stem "$et")

  # three independent agreement signals accumulate (union of evidence)
  local score=0
  [ "$qst" = "$est" ]                        && score=$((score+40))
  [ -n "$qs" ] && [ "$qs" = "$es" ]          && score=$((score+35))
  [ -n "$qm" ] && [ "$qm" = "$em" ]          && score=$((score+25))

  # partial credit: even when codes differ, how far apart are they?
  local ed; ed=$(ve_phon_code_edit "$qs" "$es")
  local partial=$(( 100 - ed*22 )); [ "$partial" -lt 0 ] && partial=0

  # complementary fusion: full evidence takes precedence, partial fills gaps
  local sim=$(( score + partial * (100 - score) / 100 ))

  # metaphone prefix agreement (2 leading phonemes) is a strong nudge
  if [ ${#qm} -ge 2 ] && [ ${#em} -ge 2 ] && [ "${qm:0:2}" = "${em:0:2}" ]; then
    sim=$((sim + 8)); [ "$sim" -gt 100 ] && sim=100
  fi
  echo "$sim"
}

# ---- phonetic consensus over token streams --------------------------------------
ve_phon_similarity() {
  local qtok="$1" etok="$2"
  [ -z "$qtok" ] || [ -z "$etok" ] && { echo "0"; return; }
  local total=0 n=0
  while IFS= read -r qt; do
    [ -z "$qt" ] && continue
    [ ${#qt} -lt 3 ] && continue     # 1-2 letter tokens carry no phonology
    local best=0
    while IFS= read -r et; do
      [ -z "$et" ] && continue
      local s; s=$(ve_phon_token_sim "$qt" "$et")
      [ "$s" -gt "$best" ] && best=$s
    done <<< "$etok"
    total=$((total + best))
    n=$((n + 1))
  done <<< "$qtok"
  [ "$n" -eq 0 ] && { echo "0"; return; }
  echo $(( total / n ))
}

ve_phon=""
#!/bin/bash
# TinkerOS Long-Press Accent Picker
# Inserts diacritics (â, á, ë...) by typing the base letter + trigger char.
# A helper that mimics a long-press accent menu in a terminal.

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# accent maps per base letter
accents_a="á à â ä ã å ā"
accents_e="é è ê ë ē ę"
accents_i="í ì î ï ī"
accents_o="ó ò ô ö õ ō ø"
accents_u="ú ù û ü ū"
accents_c="ç ć č"
accents_n="ñ ń"

pick() {
    local letter="$1"
    local list
    case "$letter" in
        a|A) list=$accents_a;; e|E) list=$accents_e;; i|I) list=$accents_i;;
        o|O) list=$accents_o;; u|U) list=$accents_u;;
        c|C) list=$accents_c;; n|N) list=$accents_n;;
        *) echo -e "${YELLOW}No accents for '$letter'${NC}"; return 1;;
    esac
    echo -e "${BLUE}Accents for '${letter}':${NC}"
    local i=1
    for a in $list; do
        echo "  $i) $a"
        i=$((i+1))
    done
    read -r -p "choose number (Enter=base): " sel
    if [ -n "$sel" ] && [ "$sel" -ge 1 ]; then
        echo "Picked: $(echo $list | cut -d' ' -f$sel)"
    fi
}

echo -e "${BLUE}── TinkerOS Long-Press Accent Picker ──${NC}"
if [ $# -ge 1 ]; then
    pick "$1"
else
    read -r -p "base letter: " letter
    pick "$letter"
fi

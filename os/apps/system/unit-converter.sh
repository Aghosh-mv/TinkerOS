#!/bin/bash
# TinkerOS Unit Converter
# Quick converter between common unit families (length, mass, temp,
# data, time, currency-rates placeholder). Interactive TUI.

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# length factor to meters
len_to_m() {
    case "$1" in
        m) echo "1";; km) echo "1000";; cm) echo "0.01";; mm) echo "0.001";;
        mi) echo "1609.34";; yd) echo "0.9144";; ft) echo "0.3048";; in) echo "0.0254";;
        *) echo "";;
    esac
}

# mass factor to kg
mass_to_kg() {
    case "$1" in
        kg) echo "1";; g) echo "0.001";; mg) echo "0.000001";;
        lb) echo "0.453592";; oz) echo "0.0283495";; t) echo "1000";;
        *) echo "";;
    esac
}

convert_unit() {
    local value="$1" from="$2" to="$3" kind="$4" factor_from factor_to result
    if [ "$kind" = "temp" ]; then
        case "$from-$to" in
            c-f) result=$(echo "scale=4; $value * 9/5 + 32" | bc);;
            f-c) result=$(echo "scale=4; ($value - 32) * 5/9" | bc);;
            c-k) result=$(echo "scale=4; $value + 273.15" | bc);;
            k-c) result=$(echo "scale=4; $value - 273.15" | bc);;
            *) echo "Unsupported temp pair"; return 1;;
        esac
        echo "$result"
        return 0
    fi
    case "$kind" in
        length) factor_from=$(len_to_m "$from"); factor_to=$(len_to_m "$to");;
        mass)   factor_from=$(mass_to_kg "$from"); factor_to=$(mass_to_kg "$to");;
        *) echo "Unsupported kind"; return 1;;
    esac
    if [ -z "$factor_from" ] || [ -z "$factor_to" ]; then
        echo "Unknown unit: $from -> $to"; return 1
    fi
    result=$(echo "scale=6; $value * $factor_from / $factor_to" | bc)
    echo "$result"
}

interactive() {
    echo -e "${BLUE}── TinkerOS Unit Converter ──${NC}"
    echo "Kinds: length (m km cm mm mi yd ft in) | mass (kg g mg lb oz t) | temp (c f k)"
    echo "Example: 100 km mi   or  1 km 2 (m/2)"
    read -r -p "value from to : " input
    [ -z "$input" ] && return
    local value from to kind found=""
    read -r value from to <<< "$input"
    for kind in length mass temp; do
        case "$kind" in
            length) if len_to_m "$from" >/dev/null; then found="$kind"; fi;;
            mass) if mass_to_kg "$from" >/dev/null; then found="$kind"; fi;;
            temp) case "$from" in c|f|k) found="$kind";; esac;;
        esac
        [ -n "$found" ] && break
    done
    if [ -z "$found" ]; then
        echo -e "${YELLOW}Unknown from-unit: $from${NC}"
    else
        echo -e "${GREEN}$value $from = $(convert_unit "$value" "$from" "$to" "$found") $to${NC}"
    fi
}

# CLI: unit-converter 100 km mi
if [ $# -ge 3 ]; then
    kind=""
    for k in length mass temp; do
        case "$k" in
            length) len_to_m "$2" >/dev/null && kind="$k";;
            mass) mass_to_kg "$2" >/dev/null && kind="$k";;
            temp) case "$2" in c|f|k) kind="$k";; esac;;
        esac
        [ -n "$kind" ] && break
    done
    echo "$1 $2 = $(convert_unit "$1" "$2" "$3" "$kind") $3"
else
    interactive
fi

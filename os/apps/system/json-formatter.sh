#!/bin/bash
# TinkerOS JSON Formatter - Format/validate JSON

set -e

# Format JSON
format() {
    local file=$1
    
    if [ -f "$file" ]; then
        python3 -m json.tool "$file" 2>/dev/null || echo "Invalid JSON"
    else
        echo "File not found: $file"
    fi
}

# Validate JSON
validate() {
    local file=$1
    
    if [ -f "$file" ]; then
        if python3 -m json.tool "$file" >/dev/null 2>&1; then
            echo "Valid JSON"
        else
            echo "Invalid JSON"
            python3 -m json.tool "$file" 2>&1 | tail -5
        fi
    else
        echo "File not found: $file"
    fi
}

# Minify JSON
minify() {
    local file=$1
    
    if [ -f "$file" ]; then
        python3 -c "import json; print(json.dumps(json.load(open('$file')), separators=(',', ':')))"
    else
        echo "File not found: $file"
    fi
}

# Pretty print
pretty() {
    local file=$1
    
    if [ -f "$file" ]; then
        python3 -c "import json; print(json.dumps(json.load(open('$file')), indent=2))"
    else
        echo "File not found: $file"
    fi
}

# Convert from JSON to CSV
to_csv() {
    local file=$1
    
    if [ -f "$file" ]; then
        python3 -c "
import json, csv, sys
data = json.load(open('$file'))
if isinstance(data, list) and len(data) > 0:
    writer = csv.DictWriter(sys.stdout, fieldnames=data[0].keys())
    writer.writeheader()
    writer.writerows(data)
"
    else
        echo "File not found: $file"
    fi
}

show_help() {
    echo "Usage: tinker-json [command]"
    echo ""
    echo "Commands:"
    echo "  format <file>     Format JSON"
    echo "  validate <file>   Validate JSON"
    echo "  minify <file>     Minify JSON"
    echo "  pretty <file>     Pretty print JSON"
    echo "  to-csv <file>     Convert to CSV"
    echo "  help              Show this help"
}

case "$1" in
    format|fmt) format "$2" ;;
    validate|check) validate "$2" ;;
    minify|min) minify "$2" ;;
    pretty|pp) pretty "$2" ;;
    to-csv|csv) to_csv "$2" ;;
    *) show_help ;;
esac

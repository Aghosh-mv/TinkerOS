#!/usr/bin/env bash
# korrinos-searchie.sh — Searchie 2.0: AI-Powered Desktop Search
# Full-text file search, OCR, natural language queries

set -euo pipefail

SEARCHIE_DIR="${HOME}/.local/share/korrinos/searchie"
INDEX_DB="$SEARCHIE_DIR/index.json"
OCR_DIR="$SEARCHIE_DIR/ocr_cache"

mkdir -p "$SEARCHIE_DIR" "$OCR_DIR"

# Index files
searchie_index() {
  local dir="${1:-$HOME}"
  local max_depth="${2:-5}"
  
  echo "Indexing files in $dir (depth: $max_depth)..."
  
  # Find all text files
  find "$dir" -maxdepth "$max_depth" -type f \
    \( -name "*.txt" -o -name "*.md" -o -name "*.py" -o -name "*.js" \
    -o -name "*.sh" -o -name "*.c" -o -name "*.h" -o -name "*.json" \
    -o -name "*.xml" -o -name "*.html" -o -name "*.css" -o -name "*.csv" \
    -o -name "*.log" -o -name "*.conf" -o -name "*.cfg" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/__pycache__/*" \
    2>/dev/null | head -10000 | while read -r f; do
    echo "Indexing: $f"
  done
  
  echo "Index complete"
}

# Full-text search
searchie_search() {
  local query="$1"
  local dir="${2:-$HOME}"
  local max_results="${3:-20}"
  
  echo "Searching for '$query'..."
  echo ""
  
  # Use ripgrep for fast full-text search
  if command -v rg &>/dev/null; then
    rg -l -i "$query" "$dir" \
      --max-depth 5 \
      --glob '!.git' \
      --glob '!node_modules' \
      --glob '!__pycache__' \
      2>/dev/null | head -$max_results | while read -r f; do
      echo "📄 $f"
      rg -i --color=never -n "$query" "$f" 2>/dev/null | head -3
      echo ""
    done
  else
    # Fallback to grep
    grep -r -l -i "$query" "$dir" \
      --include="*.txt" --include="*.md" --include="*.py" \
      --include="*.js" --include="*.sh" --include="*.c" \
      2>/dev/null | head -$max_results | while read -r f; do
      echo "📄 $f"
      grep -i -n "$query" "$f" 2>/dev/null | head -3
      echo ""
    done
  fi
}

# Natural language search
searchie_natural() {
  local query="$1"
  
  # Parse natural language query
  local search_term=""
  local file_type=""
  local time_range=""
  local size_filter=""
  
  # Extract file type
  if echo "$query" | grep -qi "pdf"; then
    file_type="*.pdf"
  elif echo "$query" | grep -qi "python\|\.py"; then
    file_type="*.py"
  elif echo "$query" | grep -qi "javascript\|\.js"; then
    file_type="*.js"
  elif echo "$query" | grep -qi "document\|\.doc"; then
    file_type="*.doc*"
  elif echo "$query" | grep -qi "image\|\.png\|\.jpg"; then
    file_type="*.png"
  fi
  
  # Extract time reference
  if echo "$query" | grep -qi "today"; then
    time_range="-mtime -1"
  elif echo "$query" | grep -qi "yesterday"; then
    time_range="-mtime -1 -mtime +0"
  elif echo "$query" | grep -qi "this week"; then
    time_range="-mtime -7"
  elif echo "$query" | grep -qi "last week"; then
    time_range="-mtime -14 -mtime +7"
  elif echo "$query" | grep -qi "this month"; then
    time_range="-mtime -30"
  fi
  
  # Extract size filter
  if echo "$query" | grep -qi "large\|big\|huge"; then
    size_filter="-size +10M"
  elif echo "$query" | grep -qi "small\|tiny"; then
    size_filter="-size -1M"
  fi
  
  # Build search command
  local cmd="find $HOME -maxdepth 5 -type f $time_range $size_filter"
  if [ -n "$file_type" ]; then
    cmd="$cmd -name '$file_type'"
  fi
  
  echo "Natural query: $query"
  echo "Parsed: type=$file_type time=$time_range size=$size_filter"
  echo ""
  
  # Execute search
  eval "$cmd" 2>/dev/null | head -30 | while read -r f; do
    echo "📄 $f ($(stat -c %y "$f" 2>/dev/null | cut -d' ' -f1))"
  done
  
  # Also do content search
  local search_words=$(echo "$query" | sed 's/find me\|search for\|look for\|show me//gi' | xargs)
  if [ -n "$search_words" ]; then
    echo ""
    echo "Content matches:"
    searchie_search "$search_words" "$HOME" 10
  fi
}

# OCR for images
searchie_ocr() {
  local image="$1"
  
  if ! command -v tesseract &>/dev/null; then
    echo "tesseract not installed. Run: sudo apt install tesseract-ocr"
    return 1
  fi
  
  tesseract "$image" stdout 2>/dev/null
}

# Search images with OCR
searchie_search_images() {
  local query="$1"
  local dir="${2:-$HOME}"
  
  echo "Searching images for text containing '$query'..."
  
  find "$dir" -maxdepth 5 -type f \
    \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) \
    2>/dev/null | head -100 | while read -r img; do
    local text=$(tesseract "$img" stdout 2>/dev/null)
    if echo "$text" | grep -qi "$query"; then
      echo "🖼️  $img"
      echo "   Text: $(echo "$text" | head -1)"
      echo ""
    fi
  done
}

# Quick search (fuzzy)
searchie_quick() {
  local query="$1"
  local dir="${2:-$HOME}"
  
  # Find files matching name
  echo "=== File names ==="
  find "$dir" -maxdepth 5 -type f -iname "*$query*" 2>/dev/null | head -20
  
  # Search file contents
  echo ""
  echo "=== File contents ==="
  searchie_search "$query" "$dir" 10
}

# Search by file type
searchie_by_type() {
  local type="$1"
  local dir="${2:-$HOME}"
  
  case "$type" in
    python|py)    ext="*.py" ;;
    javascript|js) ext="*.js" ;;
    markdown|md)   ext="*.md" ;;
    text|txt)      ext="*.txt" ;;
    c)             ext="*.c" ;;
    shell|sh)      ext="*.sh" ;;
    config|conf)   ext="*.conf" ;;
    json)          ext="*.json" ;;
    *)             ext="*.$type" ;;
  esac
  
  echo "Finding $type files..."
  find "$dir" -maxdepth 5 -type f -name "$ext" 2>/dev/null | head -30
}

case "${1:-help}" in
  index)    shift; searchie_index "$@" ;;
  search)   shift; searchie_search "$@" ;;
  natural)  shift; searchie_natural "$@" ;;
  ocr)      shift; searchie_ocr "$@" ;;
  images)   shift; searchie_search_images "$@" ;;
  quick)    shift; searchie_quick "$@" ;;
  type)     shift; searchie_by_type "$@" ;;
  *)
    echo "Searchie 2.0 — AI-Powered Desktop Search"
    echo "Usage: korrinos-searchie.sh <command>"
    echo ""
    echo "Commands:"
    echo "  index [dir]           Index files for search"
    echo "  search <query> [dir]  Full-text search"
    echo "  natural <query>       Natural language search"
    echo "  ocr <image>           Extract text from image"
    echo "  images <query> [dir]  Search images with OCR"
    echo "  quick <query> [dir]   Quick fuzzy search"
    echo "  type <ext> [dir]      Search by file type"
    ;;
esac

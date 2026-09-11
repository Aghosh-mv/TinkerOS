#!/usr/bin/env bash
# web.sh — web search, URL fetching, data extraction, fact-checking

# Search the web (uses curl + DuckDuckGo lite)
ai_web_search() {
  local query="$1" n="${2:-5}"
  local encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))" 2>/dev/null)
  curl -s "https://lite.duckduckgo.com/lite/?q=$encoded" 2>/dev/null | python3 -c "
import sys, re
html = sys.stdin.read()
# Extract result snippets
results = re.findall(r'class=\"result-snippet\">(.*?)</td>', html, re.S)
links = re.findall(r'class=\"result-link\"[^>]*>(.*?)</a>', html, re.S)
titles = re.findall(r'class=\"result-title\"[^>]*>.*?<a[^>]*>(.*?)</a>', html, re.S)
count = 0
for i in range(min($n, len(titles))):
    count += 1
    title = re.sub(r'<[^>]+>', '', titles[i]).strip() if i < len(titles) else 'Result'
    snippet = re.sub(r'<[^>]+>', '', results[i]).strip()[:200] if i < len(results) else ''
    print(f'{count}. {title}')
    if snippet: print(f'   {snippet}')
    print()
if count == 0:
    print('No results found.')
" 2>/dev/null || echo "Search unavailable (check network)"
}

# Fetch URL content
ai_web_fetch() {
  local url="$1"
  curl -sL "$url" 2>/dev/null | python3 -c "
import sys, re, html as h
text = sys.stdin.read()
# Strip HTML tags
text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.S)
text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.S)
text = re.sub(r'<[^>]+>', ' ', text)
text = h.unescape(text)
text = re.sub(r'\s+', ' ', text).strip()
print(text[:3000])
" 2>/dev/null || echo "Failed to fetch URL"
}

# Extract structured data from text (emails, phones, dates, URLs)
ai_web_extract() {
  local text="$1"
  echo "=== Extracted Data ==="
  echo "Emails:"
  echo "$text" | grep -oP '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | sort -u | sed 's/^/  /'
  echo "URLs:"
  echo "$text" | grep -oP 'https?://[^\s<>"]+' | sort -u | sed 's/^/  /'
  echo "Phone numbers:"
  echo "$text" | grep -oP '\+?[0-9]{1,4}[-.\s]?[0-9]{1,4}[-.\s]?[0-9]{1,9}' | sort -u | sed 's/^/  /'
  echo "IP addresses:"
  echo "$text" | grep -oP '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u | sed 's/^/  /'
  echo "Dates:"
  echo "$text" | grep -oP '[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}' | sort -u | sed 's/^/  /'
}

# Simple fact-check: search for claims and report confidence
ai_web_factcheck() {
  local claim="$1"
  echo "Fact-checking: $claim"
  echo "---"
  local results=$(ai_web_search "$claim" 3 2>/dev/null)
  if [ -n "$results" ]; then
    echo "Search results suggest:"
    echo "$results"
    echo "---"
    echo "Confidence: Based on web search results (manual verification recommended)"
  else
    echo "Could not verify — no search results found"
    echo "Confidence: Unknown"
  fi
}

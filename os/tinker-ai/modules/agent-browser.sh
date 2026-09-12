#!/usr/bin/env bash
# agent-browser.sh — browser agent: manage tabs, parse history, open URLs

# Get browser history (parses SQLite databases)
agent_browser_history() {
  local days="${1:-1}" browser="${2:-auto}"
  local history_files=()
  
  # Auto-detect browser
  if [ "$browser" = "auto" ]; then
    [ -f "$HOME/.mozilla/firefox/*/places.sqlite" ] && browser="firefox"
    [ -f "$HOME/.config/google-chrome/Default/History" ] && browser="chrome"
    [ -f "$HOME/.config/chromium/Default/History" ] && browser="chromium"
    [ -f "$HOME/.config/BraveSoftware/Brave-Browser/Default/History" ] && browser="brave"
  fi
  
  case "$browser" in
    firefox)
      local db=$(find "$HOME/.mozilla/firefox" -name "places.sqlite" 2>/dev/null | head -1)
      if [ -n "$db" ]; then
        python3 -c "
import sqlite3, datetime
db = sqlite3.connect('$db')
c = db.cursor()
since = (datetime.datetime.now() - datetime.timedelta(days=$days)).strftime('%s')
c.execute('SELECT url, title, visit_count, last_visit_date FROM moz_places WHERE last_visit_date > ? ORDER BY last_visit_date DESC LIMIT 50', (int(since),))
for url, title, count, visited in c.fetchall():
    print(f'{visited} | {title[:60] or \"(no title)\"} | {url}')
" 2>/dev/null
      fi
      ;;
    chrome|chromium|brave)
      local db_path=""
      case "$browser" in
        chrome) db_path="$HOME/.config/google-chrome/Default/History" ;;
        chromium) db_path="$HOME/.config/chromium/Default/History" ;;
        brave) db_path="$HOME/.config/BraveSoftware/Brave-Browser/Default/History" ;;
      esac
      if [ -f "$db_path" ]; then
        cp "$db_path" /tmp/browser_history.db 2>/dev/null
        python3 -c "
import sqlite3, datetime
db = sqlite3.connect('/tmp/browser_history.db')
c = db.cursor()
since = (datetime.datetime.now() - datetime.timedelta(days=$days)).strftime('%s')
c.execute('SELECT url, title, visit_count, last_visit_time FROM urls WHERE last_visit_time > ? ORDER BY last_visit_time DESC LIMIT 50', (int(since)*1000000+11644473600000000,))
for url, title, count, visited in c.fetchall():
    print(f'{title[:60] or \"(no title)\"} | {url}')
" 2>/dev/null
      fi
      ;;
    *)
      echo "Browser not detected. Supported: firefox, chrome, chromium, brave"
      ;;
  esac
}

# Open specific URLs in browser
agent_browser_open() {
  local urls="$1"
  for url in $urls; do
    xdg-open "$url" 2>/dev/null &
    echo "Opened: $url"
    sleep 0.5
  done
}

# Open browser with tabs from history (replay a day)
agent_browser_replay() {
  local date_str="${1:-today}" browser="${2:-auto}"
  local urls=""
  
  # Get history from that date
  case "$browser" in
    firefox)
      local db=$(find "$HOME/.mozilla/firefox" -name "places.sqlite" 2>/dev/null | head -1)
      if [ -n "$db" ]; then
        urls=$(python3 -c "
import sqlite3, datetime
db = sqlite3.connect('$db')
c = db.cursor()
if '$date_str' == 'today':
    start = datetime.datetime.now().replace(hour=0, minute=0)
else:
    start = datetime.datetime.strptime('$date_str', '%Y-%m-%d')
end = start + datetime.timedelta(days=1)
c.execute('SELECT url FROM moz_places WHERE last_visit_date BETWEEN ? AND ? ORDER BY last_visit_date', (int(start.timestamp()), int(end.timestamp())))
for (url,) in c.fetchall():
    print(url)
" 2>/dev/null)
      fi
      ;;
  esac
  
  if [ -n "$urls" ]; then
    echo "Opening tabs from $date_str..."
    echo "$urls" | head -20 | while read url; do
      [ -n "$url" ] && xdg-open "$url" &>/dev/null &
      sleep 0.3
    done
    echo "Opened $(echo "$urls" | head -20 | wc -l) tabs"
  else
    echo "No history found for $date_str"
  fi
}

# Get current browser tabs
agent_browser_tabs() {
  # Try to get tabs via xdotool
  local focused=$(xdotool getactivewindow getwindowname 2>/dev/null)
  echo "Current window: $focused"
  
  # List all browser windows
  wmctrl -l 2>/dev/null | grep -iE "firefox|chrome|chromium|brave" || echo "No browser windows found"
}

# Search the web — INSIDE TinkerAI (no external browser, no focus steal)
agent_search_up() {
  local query="$1"
  if [ -z "$query" ]; then
    echo "Usage: search-up <query>"
    return 1
  fi

  local encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))" 2>/dev/null)
  
  # Try multiple search sources
  local result=""
  
  # Source 1: DuckDuckGo instant answer
  result=$(curl -s -L "https://api.duckduckgo.com/?q=$encoded&format=json&no_html=1" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    abstract = data.get('AbstractText', '')
    if abstract:
        print(abstract)
        sys.exit(0)
    # Try related topics
    topics = data.get('RelatedTopics', [])
    for t in topics[:3]:
        if isinstance(t, dict) and 'Text' in t:
            print(t['Text'][:200])
            sys.exit(0)
except:
    pass
print('')
" 2>/dev/null)
  
  # Source 2: If no result, try Wikipedia
  if [ -z "$result" ]; then
    # Convert query to Wikipedia title format
    local wiki_title=$(echo "$query" | sed 's/ /_/g')
    result=$(curl -s "https://en.wikipedia.org/api/rest_v1/page/summary/$wiki_title" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    extract = data.get('extract', '')
    if extract:
        print(extract[:500])
except:
    print('')
" 2>/dev/null)
  fi
  
  # Source 3: If still no result, try DuckDuckGo HTML
  if [ -z "$result" ]; then
    result=$(curl -s "https://html.duckduckgo.com/html/?q=$encoded" 2>/dev/null | python3 -c "
import sys, re
html = sys.stdin.read()
# Extract snippets
snippets = re.findall(r'class=\"result__snippet\"[^>]*>(.*?)</a>', html, re.S)
for s in snippets[:3]:
    clean = re.sub(r'<[^>]+>', '', s).strip()
    if clean:
        print(clean[:200])
        break
" 2>/dev/null)
  fi
  
  # Source 4: If still no result, give a helpful response
  if [ -z "$result" ]; then
    result="I searched but couldn't find a direct answer for that. I can help with specific topics like science, technology, history, or math. Try asking about something more specific."
  fi
  
  echo "$result"
}

# Open URL — INSIDE TinkerAI's own panel (no external browser)
agent_open_url() {
  local url="$1"
  if [ -z "$url" ]; then
    echo "Usage: open-url <url>"
    return 1
  fi
  
  if [[ ! "$url" =~ ^https?:// ]]; then
    url="https://$url"
  fi
  
  # Fetch and summarize content
  local content=$(curl -s -L --max-time 10 "$url" 2>/dev/null | python3 -c "
import sys, re
html = sys.stdin.read()
# Get title
title = re.search(r'<title>(.*?)</title>', html, re.I|re.S)
if title:
    print('TITLE: ' + title.group(1).strip())
# Get main text
text = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.S|re.I)
text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.S|re.I)
text = re.sub(r'<[^>]+>', ' ', text)
text = re.sub(r'\s+', ' ', text).strip()
if len(text) > 500:
    text = text[:500] + '...'
print(text)
" 2>/dev/null)
  
  echo "$content"
}

# Play music — INSIDE TinkerAI (no Spotify app needed)
agent_play_music() {
  local query="${1:-}"
  
  if [ -z "$query" ]; then
    echo "What do you want me to play?"
    return 1
  fi
  
  # Use mpv to play from YouTube (no browser needed)
  if command -v mpv &>/dev/null; then
    echo "Playing: $query"
    mpv --no-video "ytsearch1:$query" &>/dev/null &
    echo "Started in background"
  else
    echo "mpv not installed. Install with: sudo apt install mpv"
  fi
}

# Stop music
agent_stop_music() {
  pkill -f mpv 2>/dev/null
  echo "Music stopped"
}

# Type text into a specific window by title (no focus steal)
agent_type_in() {
  local window_title="$1"
  local text="$2"
  if [ -z "$window_title" ] || [ -z "$text" ]; then
    echo "Usage: type-in <window-title> <text>"
    return 1
  fi

  local wid=$(xdotool search --name "$window_title" 2>/dev/null | head -1)
  if [ -n "$wid" ]; then
    xdotool type --window "$wid" --clearmodifiers "$text"
    echo "Typed into '$window_title': $text"
  else
    echo "Window not found: $window_title"
    return 1
  fi
}

# Press key in a specific window (no focus steal)
agent_key_in() {
  local window_title="$1"
  local key="$2"
  if [ -z "$window_title" ] || [ -z "$key" ]; then
    echo "Usage: key-in <window-title> <key>"
    return 1
  fi

  local wid=$(xdotool search --name "$window_title" 2>/dev/null | head -1)
  if [ -n "$wid" ]; then
    xdotool key --window "$wid" "$key"
    echo "Pressed $key in '$window_title'"
  else
    echo "Window not found: $window_title"
    return 1
  fi
}

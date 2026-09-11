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

# Search the web — opens Chrome, types query, hits Enter
agent_search_up() {
  local query="$1"
  if [ -z "$query" ]; then
    echo "Usage: search-up <query>"
    return 1
  fi

  # Find Chrome window
  local wid=$(xdotool search --name "Google Chrome" 2>/dev/null | head -1)
  
  # If no Chrome window, open one
  if [ -z "$wid" ]; then
    google-chrome --new-window "https://www.google.com" &>/dev/null &
    sleep 3
    wid=$(xdotool search --name "Google Chrome" 2>/dev/null | head -1)
  fi

  if [ -n "$wid" ]; then
    # Focus Chrome
    xdotool windowactivate "$wid" 2>/dev/null
    sleep 0.5

    # Ctrl+L to focus address bar
    xdotool key ctrl+l
    sleep 0.3

    # Type the search query
    xdotool type --clearmodifiers "$query"
    sleep 0.3

    # Press Enter
    xdotool key Return
    echo "Searched: $query"
  else
    echo "Could not find Chrome window"
    return 1
  fi
}

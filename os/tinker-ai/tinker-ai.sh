#!/bin/bash
# ===========================================================================
#  tinker-ai.sh — TinkerOS AI ASSISTANT CLI backend
# ---------------------------------------------------------------------------
#  Backend for the Tinker AI glassmorphism GUI. Searches local context
#  (Searchie index, filesystem, command history) and returns structured
#  HTML card responses for rendering in the GUI.
#
#  Usage:
#    tinker-ai ask "<query>"          # HTML card response
#    tinker-ai connect <app>          # connect to an app
#    tinker-ai disconnect <app>       # disconnect from an app
#    tinker-ai connections            # list active connections
#    tinker-ai subsystem <name>       # scope to a subsystem
#    tinker-ai status                 # show AI status
# ===========================================================================
set -euo pipefail
IFS=$'\n\t'

# ---- paths ----------------------------------------------------------------
AI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_CONFIG="${HOME}/.config/tinker-ai"
AI_CONNECTIONS="${AI_CONFIG}/connections"
AI_SUBSYSTEM="${AI_CONFIG}/subsystem"
AI_LOG="${AI_CONFIG}/ai.log"

# vibe-address engine (for index search)
VIBE_ENGINE="${VIBE_ENGINE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../territories/vibe-address" 2>/dev/null && pwd || echo "")}"
VIBE_HOME="${VIBE_HOME:-$HOME/.local/share/tinkeros/vibe}"

# ---- defaults -------------------------------------------------------------
DEFAULT_CONNECTIONS="browser terminal editor file-manager email calendar notes"

mkdir -p "${AI_CONNECTIONS}"
mkdir -p "$(dirname "${AI_LOG}")"

# ---------------------------------------------------------------------------
#  HTML card builder helpers
# ---------------------------------------------------------------------------
html_header() {
  cat <<'HTMLHEAD'
<!DOCTYPE html>
<html><head><style>
body { font-family: Ubuntu Sans, Inter, sans-serif; margin: 0; padding: 0; }
.card {
  background: rgba(26,30,42,170);
  border: 1px solid rgba(150,180,240,80);
  border-radius: 14px;
  padding: 18px 22px;
  margin-bottom: 12px;
}
.card-title {
  font-size: 16pt; font-weight: 700;
  color: rgb(200,215,255);
  margin-bottom: 8px;
}
.card-body {
  font-size: 14pt; font-weight: 400;
  color: rgb(240,244,255);
  line-height: 1.5;
}
.card-body-secondary {
  font-size: 13pt;
  color: rgb(150,165,200);
  line-height: 1.4;
  margin-top: 6px;
}
.card-source {
  font-size: 11pt;
  color: rgb(120,140,180);
  margin-top: 8px;
  border-top: 1px solid rgba(100,120,160,60);
  padding-top: 8px;
}
.code-block {
  background: rgba(16,20,32,200);
  border: 1px solid rgba(100,120,160,80);
  border-radius: 8px;
  padding: 12px 16px;
  font-family: JetBrains Mono, Fira Code, monospace;
  font-size: 12pt;
  color: rgb(180,200,255);
  margin: 10px 0;
  white-space: pre-wrap;
  overflow-x: auto;
}
.code-block .kw { color: rgb(140,200,255); }
.code-block .fn { color: rgb(120,220,170); }
.code-block .str { color: rgb(255,200,140); }
.code-block .cmt { color: rgb(100,115,150); }
a {
  color: rgb(140,200,255);
  text-decoration: none;
}
a:hover { text-decoration: underline; }
.confidence {
  display: inline-block;
  background: rgba(120,220,170,90);
  color: rgb(230,255,239);
  font-size: 11pt;
  font-weight: 600;
  padding: 3px 10px;
  border-radius: 20px;
}
.btn {
  display: inline-block;
  background: rgba(52,62,92,120);
  color: rgb(200,215,255);
  border: 1px solid rgba(150,180,240,80);
  border-radius: 10px;
  padding: 6px 14px;
  font-size: 12pt;
  font-weight: 600;
  margin: 4px 4px 4px 0;
  cursor: pointer;
}
.btn:hover {
  background: rgba(70,90,140,120);
  border-color: rgba(200,215,255,120);
}
.btn-primary {
  background: rgba(140,200,255,90);
  color: rgb(230,248,255);
  border-color: rgba(140,200,255,120);
}
.btn-primary:hover {
  background: rgba(140,200,255,150);
}
.empty-state {
  text-align: center;
  padding: 40px 20px;
  color: rgb(150,165,200);
  font-size: 14pt;
}
.empty-state .icon { font-size: 28pt; margin-bottom: 12px; }
.section-label {
  font-size: 11pt;
  font-weight: 600;
  color: rgb(150,165,200);
  text-transform: uppercase;
  letter-spacing: 1.5px;
  margin-bottom: 6px;
}
</style></head><body>
HTMLHEAD
}

html_footer() {
  echo "</body></html>"
}

card_open() {
  echo '<div class="card">'
}

card_close() {
  echo '</div>'
}

card_title() {
  echo "<div class=\"card-title\">$1</div>"
}

card_body() {
  echo "<div class=\"card-body\">$1</div>"
}

card_secondary() {
  echo "<div class=\"card-body-secondary\">$1</div>"
}

card_source() {
  echo "<div class=\"card-source\">$1</div>"
}

card_code() {
  local lang="${1:-}"
  shift 2>/dev/null || true
  local code="$*"
  if [ -n "$lang" ]; then
    echo "<div class=\"card-source\">$lang</div>"
  fi
  echo "<div class=\"code-block\">$code</div>"
}

card_confidence() {
  local pct="${1:-0}"
  echo "<span class=\"confidence\">${pct}% match</span>"
}

card_buttons() {
  echo '<div style="margin-top:10px;">'
  echo "$@"
  echo '</div>'
}

btn() {
  local label="$1" action="$2"
  echo "<span class=\"btn\" data-action=\"${action}\">${label}</span>"
}

btn_primary() {
  local label="$1" action="$2"
  echo "<span class=\"btn btn-primary\" data-action=\"${action}\">${label}</span>"
}

# ---------------------------------------------------------------------------
#  search helpers
# ---------------------------------------------------------------------------
search_vibe_index() {
  local query="$1"
  if [ -n "$VIBE_ENGINE" ] && [ -r "$VIBE_ENGINE/vibe-address.sh" ]; then
    local out
    out=$(SEARCHIE_TERSE=1 VIBE_HOME="$VIBE_HOME" \
      bash "$VIBE_ENGINE/vibe-address.sh" ask "$query" 2>/dev/null) || true
    echo "$out"
  fi
}

search_local_files() {
  local query="$1"
  find ~/Documents ~/Desktop ~/Downloads ~/Pictures ~/Videos \
       ~/projects ~/workspace ~/code \
    -iname "*${query}*" -type f 2>/dev/null | head -5
}

search_command_history() {
  local query="$1"
  history 2>/dev/null | grep -i "$query" | tail -5 || true
}

get_subsystem() {
  if [ -f "$AI_SUBSYSTEM" ]; then
    cat "$AI_SUBSYSTEM"
  else
    echo "all"
  fi
}

get_connections_list() {
  local conns=""
  if [ -d "$AI_CONNECTIONS" ]; then
    for d in "$AI_CONNECTIONS"/*/; do
      [ -d "$d" ] || continue
      local name
      name=$(basename "$d")
      conns="${conns}${name},"
    done
  fi
  echo "${conns%,}"
}

# ---------------------------------------------------------------------------
#  ask — main query handler
# ---------------------------------------------------------------------------
cmd_ask() {
  local query="${1:-}"
  if [ -z "$query" ]; then
    html_header
    card_open
    card_title "Tinker AI"
    card_body "Ask me anything — I'll search your local files, command history, and index for context."
    card_secondary "Type a question and press Enter."
    card_close
    html_footer
    return 0
  fi

  local subsystem
  subsystem=$(get_subsystem)
  local connections
  connections=$(get_connections_list)

  html_header
  echo "<div class=\"section-label\">query</div>"
  card_open
  card_title "🔍 $query"
  card_close

  # --- 1. Search the vibe-address index ---
  local vibe_results
  vibe_results=$(search_vibe_index "$query")

  if [ -n "$vibe_results" ]; then
    local hit_count=0
    local vibe_html=""
    while IFS= read -r line; do
      if [[ "$line" == RESULT\|* ]]; then
        IFS='|' read -ra parts <<< "$line"
        if [ ${#parts[@]} -ge 5 ]; then
          local score="${parts[1]// /}"
          local fpath="${parts[2]// /}"
          local cat="${parts[3]// /}"
          local ago="${parts[4]// /}"
          local fname
          fname=$(basename "$fpath")
          vibe_html+="<div class=\"card-body\" style=\"margin:4px 0;\">"
          vibe_html+="<a href=\"file://${fpath}\">${fname}</a>"
          vibe_html+=" <span style=\"color:rgb(150,165,200);font-size:12pt;\">${cat} · ${ago} · ${score}% match</span>"
          vibe_html+="</div>"
          hit_count=$((hit_count + 1))
        fi
      fi
    done <<< "$vibe_results"

    if [ "$hit_count" -gt 0 ]; then
      card_open
      card_title "📚 Found in your index"
      echo "$vibe_html"
      card_buttons \
        "$(btn_primary "Open top result" "open-first-result")" \
        "$(btn "Search more" "search-more:${query}")" \
        "$(btn "Copy results" "copy-results")"
      card_close
    fi
  fi

  # --- 2. Search local filesystem ---
  local file_results
  file_results=$(search_local_files "$query")

  if [ -n "$file_results" ]; then
    card_open
    card_title "📁 Local files"
    while IFS= read -r fpath; do
      [ -z "$fpath" ] && continue
      local fname
      fname=$(basename "$fpath")
      local dir
      dir=$(dirname "$fpath")
      card_body "<a href=\"file://${fpath}\">${fname}</a> <span style=\"color:rgb(150,165,200);font-size:12pt;\">in ${dir}</span>"
    done <<< "$file_results"
    card_buttons \
      "$(btn_primary "Open file" "open-file")" \
      "$(btn "Copy path" "copy-path")"
    card_close
  fi

  # --- 3. Search command history ---
  local hist_results
  hist_results=$(search_command_history "$query")

  if [ -n "$hist_results" ]; then
    card_open
    card_title "⏱ Command history"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local trimmed
      trimmed=$(echo "$line" | sed 's/^[ ]*[0-9]*[ ]*//' | cut -c1-100)
      card_code "" "${trimmed}"
    done <<< "$hist_results"
    card_buttons "$(btn "Re-run command" "run-command")"
    card_close
  fi

  # --- 4. If nothing found, provide helpful default ---
  local total_results=$(( $(echo "$vibe_results" | grep -c "^RESULT|" 2>/dev/null || echo 0) + \
                           $(echo "$file_results" | grep -c . 2>/dev/null || echo 0) + \
                           $(echo "$hist_results" | grep -c . 2>/dev/null || echo 0) ))

  if [ "$total_results" -eq 0 ]; then
    card_open
    card_title "I can help with that"
    card_body "I didn't find anything locally matching \"${query}\". Here are some things I can help with:"
    echo '<div style="margin-top:10px;">'
    card_secondary "• Search your documents and files"
    card_secondary "• Look up command history"
    card_secondary "• Manage connected apps"
    card_secondary "• Navigate your project structure"
    echo '</div>'
    card_buttons \
      "$(btn_primary "Try a broader search" "search-broad:${query}")" \
      "$(btn "Show connections" "show-connections")" \
      "$(btn "Help" "help")"
    card_close
  fi

  # --- 5. Footer with metadata ---
  card_open
  card_source "subsystem: ${subsystem} · connected: ${connections:-none} · $(date '+%H:%M:%S')"
  card_close

  html_footer
}

# ---------------------------------------------------------------------------
#  connect / disconnect / connections
# ---------------------------------------------------------------------------
cmd_connect() {
  local app="${1:-}"
  if [ -z "$app" ]; then
    echo "Usage: tinker-ai connect <app>"
    echo "Available: browser terminal editor file-manager email calendar notes"
    return 1
  fi

  local dir="${AI_CONNECTIONS}/${app}"
  mkdir -p "$dir"
  cat > "${dir}/config" <<EOF
app=${app}
connected_at=$(date +%s)
status=active
EOF
  echo "connected to ${app}"
  echo "$(date -Iseconds) CONNECTED ${app}" >> "$AI_LOG"
}

cmd_disconnect() {
  local app="${1:-}"
  if [ -z "$app" ]; then
    echo "Usage: tinker-ai disconnect <app>"
    return 1
  fi

  local dir="${AI_CONNECTIONS}/${app}"
  if [ -d "$dir" ]; then
    rm -rf "$dir"
    echo "disconnected from ${app}"
    echo "$(date -Iseconds) DISCONNECTED ${app}" >> "$AI_LOG"
  else
    echo "not connected to ${app}"
    return 1
  fi
}

cmd_connections() {
  local found=0
  for d in "${AI_CONNECTIONS}"/*/; do
    [ -d "$d" ] || continue
    found=1
    local name
    name=$(basename "$d")
    if [ -f "${d}/config" ]; then
      local status
      status=$(grep "^status=" "${d}/config" 2>/dev/null | cut -d= -f2 || echo "unknown")
      local since
      since=$(grep "^connected_at=" "${d}/config" 2>/dev/null | cut -d= -f2 || echo "")
      echo "  ${name}  [${status}]  $(if [ -n "$since" ]; then date -d "@${since}" '+%H:%M' 2>/dev/null || echo ""; fi)"
    else
      echo "  ${name}  [unknown]"
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "  no active connections"
    echo "  use: tinker-ai connect <app>"
  fi
}

cmd_subsystem() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    if [ -f "$AI_SUBSYSTEM" ]; then
      echo "current subsystem: $(cat "$AI_SUBSYSTEM")"
    else
      echo "subsystem: all (default)"
    fi
    return 0
  fi
  mkdir -p "$(dirname "$AI_SUBSYSTEM")"
  echo "$name" > "$AI_SUBSYSTEM"
  echo "subsystem scoped to: ${name}"
  echo "$(date -Iseconds) SUBSYSTEM ${name}" >> "$AI_LOG"
}

cmd_status() {
  local subsystem
  subsystem=$(get_subsystem)
  local connections
  connections=$(get_connections_list)
  local last_query
  last_query=$(tail -1 "$AI_LOG" 2>/dev/null || echo "none")

  cat <<EOF
Tinker AI Status
  subsystem:    ${subsystem}
  connections:  ${connections:-none}
  last activity: ${last_query}
  config dir:   ${AI_CONFIG}
  log:          ${AI_LOG}
EOF
}

# ---------------------------------------------------------------------------
#  dispatch
# ---------------------------------------------------------------------------
case "${1:-help}" in
  ask)       shift; cmd_ask "$@" ;;
  connect)   shift; cmd_connect "$@" ;;
  disconnect) shift; cmd_disconnect "$@" ;;
  connections) cmd_connections ;;
  subsystem) shift; cmd_subsystem "$@" ;;
  status)    cmd_status ;;
  help|*)
    cat <<EOF
Tinker AI — productivity assistant CLI

Usage:
  tinker-ai ask "<query>"          Ask a question, get HTML card response
  tinker-ai connect <app>          Connect to an app (browser, terminal, ...)
  tinker-ai disconnect <app>       Disconnect from an app
  tinker-ai connections            List active connections
  tinker-ai subsystem <name>       Scope to a subsystem (or "all")
  tinker-ai status                 Show AI status

The 'ask' command searches:
  1. Searchie vibe-address index
  2. Local files (~/Documents, ~/Desktop, etc.)
  3. Command history

Output is valid HTML with glassmorphism CSS for GUI rendering.
EOF
    ;;
esac

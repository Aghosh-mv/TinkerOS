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

# ---- source all modules ---------------------------------------------------
MODULE_DIR="${AI_DIR}/modules"
[ -d "$MODULE_DIR" ] && for m in "$MODULE_DIR"/*.sh; do [ -f "$m" ] && source "$m"; done

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
    card_body "Ask me anything — I answer questions, write code, translate, summarize, and much more."
    card_secondary "Type any question and press Enter."
    card_close
    html_footer
    return 0
  fi

  local subsystem
  subsystem=$(get_subsystem)
  local connections
  connections=$(get_connections_list)

  # --- NLU intent detection ---
  local intent
  intent=$(ai_nlu_intent "$query" 2>/dev/null || echo "unknown")

  html_header

  # === PRIMARY: Use AI Engine (Ollama LLM) for real answers ===
  if ai_ollama_available 2>/dev/null; then
    local answer
    answer=$(ai_smart_answer "$query" 2>/dev/null)
    if [ -n "$answer" ]; then
      # Render as rich markdown card
      local html_answer
      html_answer=$(echo "$answer" | python3 -c "
import sys, re, html as h
text = sys.stdin.read()
text = h.escape(text)
# Bold
text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
# Italic
text = re.sub(r'\*(.+?)\*', r'<i>\1</i>', text)
# Code blocks
text = re.sub(r'\`\`\`(\w*)\n(.*?)\`\`\`', lambda m: f'<pre style=\"background:#0d1117;padding:12px;border-radius:8px;color:#c9d1d9;font-size:12px;overflow-x:auto;white-space:pre-wrap;\">{m.group(2)}</pre>', text, flags=re.S)
# Inline code
text = re.sub(r'\`([^\`]+)\`', r'<code style=\"background:#21262d;padding:2px 6px;border-radius:4px;color:#c9d1d9;font-size:12px;\">\1</code>', text)
# Headers
text = re.sub(r'^### (.+)$', r'<h3 style=\"color:#c8d7ff;margin:12px 0 6px;\">\1</h3>', text, flags=re.M)
text = re.sub(r'^## (.+)$', r'<h2 style=\"color:#c8d7ff;margin:16px 0 8px;\">\1</h2>', text, flags=re.M)
text = re.sub(r'^# (.+)$', r'<h1 style=\"color:#c8d7ff;margin:20px 0 10px;\">\1</h1>', text, flags=re.M)
# Lists
text = re.sub(r'^- (.+)$', r'<li>\1</li>', text, flags=re.M)
text = re.sub(r'^(\d+)\. (.+)$', r'<li>\2</li>', text, flags=re.M)
# Line breaks
text = text.replace('\n', '<br>')
print(text)
" 2>/dev/null || echo "$answer" | sed 's/</\&lt;/g; s/\n/<br>/g')
      
      card_open
      card_title "🤖 TinkerAI"
      card_body "<div style='line-height:1.7;'>${html_answer}</div>"
      card_secondary "Model: ${OLLAMA_MODEL:-llama3.1:8b} · Intent: ${intent}"
      card_close
      html_footer
      return 0
    fi
  fi

  # === FALLBACK: Specialized modules when Ollama is unavailable ===
  case "$intent" in
    greeting)
      card_open
      card_title "Hey there!"
      card_body "I'm TinkerAI, your AI assistant. I can answer questions, write code, help with productivity, and much more. What would you like to know?"
      card_secondary "Try: 'What is quantum computing?' or 'Write me a Python script'"
      card_close
      ;;

    question)
      local target
      target=$(ai_nlu_target "$query" "question" 2>/dev/null || echo "$query")
      card_open
      card_title "🔍 $query"
      local web_results
      web_results=$(ai_web_search "$target" 3 2>/dev/null || echo "")
      if [ -n "$web_results" ]; then
        card_body "<pre style='white-space:pre-wrap;font-size:12pt;'>${web_results}</pre>"
      else
        card_body "I can provide a better answer if you start Ollama: <code>ollama serve</code>"
      fi
      card_close
      ;;

    create)
      local target
      target=$(ai_nlu_target "$query" "create" 2>/dev/null || echo "$query")
      card_open
      card_title "✍️ Creating: $target"
      local result
      result=$(ai_text_generate "$target" 2>&1 || echo "Could not generate content.")
      card_code "" "$result"
      card_close
      ;;

    search)
      local target
      target=$(ai_nlu_target "$query" "search" 2>/dev/null || echo "$query")
      card_open
      card_title "🌐 Search: $target"
      local result
      result=$(ai_web_search "$target" 5 2>&1 || echo "Search unavailable")
      card_body "<pre style='white-space:pre-wrap;font-size:12pt;'>${result}</pre>"
      card_close
      ;;

    code)
      local target
      target=$(ai_nlu_target "$query" "code" 2>/dev/null || echo "$query")
      card_open
      card_title "💻 Code: $target"
      local result
      result=$(ai_code_debug "$target" 2>&1 || echo "Could not analyze code.")
      card_code "" "$result"
      card_close
      ;;

    media)
      card_open
      card_title "🎵 Media"
      card_body "For media processing, use the direct commands:"
      card_secondary "• tinker-ai image &lt;path&gt; — recognize image"
      card_secondary "• tinker-ai ocr &lt;path&gt; — extract text from image"
      card_secondary "• tinker-ai audio &lt;path&gt; — recognize audio"
      card_secondary "• tinker-ai tts &lt;text&gt; — text to speech"
      card_close
      ;;

    summarize)
      local target
      target=$(ai_nlu_target "$query" "summarize" 2>/dev/null || echo "$query")
      card_open
      card_title "📝 Summary"
      local result
      result=$(ai_text_summarize "$target" 5 2>&1 || echo "Could not summarize.")
      card_body "$result"
      card_close
      ;;

    translate)
      card_open
      card_title "🌍 Translate"
      card_body "For translation, use: tinker-ai translate &lt;text&gt; &lt;lang&gt;"
      card_secondary "Supported: es, fr, de, ja, zh"
      card_close
      ;;

    math)
      local target
      target=$(ai_nlu_target "$query" "math" 2>/dev/null || echo "$query")
      card_open
      card_title "🧮 Calculate"
      local result
      result=$(ai_math_calc "$target" 2>&1 || echo "Could not compute.")
      card_code "" "$result"
      card_close
      ;;

    schedule)
      card_open
      card_title "📅 Schedule"
      card_body "For scheduling, use the direct commands:"
      card_secondary "• tinker-ai todo &lt;text&gt; [priority]"
      card_secondary "• tinker-ai cal &lt;title&gt; &lt;date&gt; [time]"
      card_secondary "• tinker-ai today — today's schedule"
      card_close
      ;;

    settings)
      local target
      target=$(ai_nlu_target "$query" "settings" 2>/dev/null || echo "$query")
      card_open
      card_title "⚙️ Settings"
      local result
      result=$(ai_device_settings "$target" 2>&1 || echo "Could not change settings.")
      card_body "$result"
      card_close
      ;;

    commerce)
      card_open
      card_title "🛒 Commerce"
      card_body "For shopping and bookings, use:"
      card_secondary "• tinker-ai order &lt;item&gt; &lt;price&gt;"
      card_secondary "• tinker-ai book &lt;type&gt; &lt;name&gt; &lt;date&gt;"
      card_secondary "• tinker-ai wallet — check balance"
      card_close
      ;;

    help)
      cmd_help
      ;;

    thanks)
      card_open
      card_title "You're welcome!"
      card_body "Happy to help. Let me know if you need anything else."
      card_close
      ;;

    *)
      # Fallback: search local context
      local vibe_results
      vibe_results=$(search_vibe_index "$query")
      local file_results
      file_results=$(search_local_files "$query")

      card_open
      card_title "🔍 $query"

      if [ -n "$vibe_results" ]; then
        while IFS= read -r line; do
          if [[ "$line" == RESULT\|* ]]; then
            IFS='|' read -ra parts <<< "$line"
            if [ ${#parts[@]} -ge 5 ]; then
              local fpath="${parts[2]// /}"
              local score="${parts[1]// /}"
              local fname
              fname=$(basename "$fpath")
              card_secondary "<a href=\"file://${fpath}\">${fname}</a> — ${score}% match"
            fi
          fi
        done <<< "$vibe_results"
      fi

      if [ -n "$file_results" ]; then
        while IFS= read -r fpath; do
          [ -z "$fpath" ] && continue
          local fname
          fname=$(basename "$fpath")
          card_secondary "<a href=\"file://${fpath}\">${fname}</a>"
        done <<< "$file_results"
      fi

      if [ -z "$vibe_results" ] && [ -z "$file_results" ]; then
        card_body "I can help with questions, code, writing, math, translations, device control, and more."
        card_secondary "Try: tinker-ai help to see all commands."
      fi

      card_close
      ;;
  esac

  # Footer
  card_open
  card_source "intent: ${intent} · subsystem: ${subsystem} · connected: ${connections:-none} · $(date '+%H:%M:%S')"
  card_close

  html_footer
}

cmd_help() {
  cat <<'EOF'
Tinker AI — your productivity assistant

USAGE
  tinker-ai <command> [args...]

CORE
  ask "<query>"              Ask anything (NLU-intent routed)
  status                     Show AI status
  help                       Show this help

CONVERSATION & NLU
  ask "<text>"               NLU classifies intent → smart routing
  (intents: greeting, question, command, create, search, code, media,
   summarize, translate, math, schedule, settings, commerce, help, thanks)

TEXT & CONTENT
  generate <topic> [type]    Generate text (email/essay/report/poem/story)
  grammar <text>             Fix grammar and capitalization
  paraphrase <text>          Rewrite with synonyms
  brainstorm <topic>         Generate ideas
  stats <text>               Word/char/sentence counts
  summarize <path>           Summarize file content
  draft <topic>              Draft a short message
  email <to> <purpose> [tone]  Draft email (professional/casual/formal/persuasive/empathetic)
  blog <topic> [style] [words]  Blog outline (informative/howto/opinion)
  social <topic> [platform]   Social captions (twitter/instagram/linkedin/tiktok)
  copywrite <product> [type]  Copywriting (tagline/description/ad)
  poem <topic> [style]        Poetry (freeverse/haiku/limerick/sonnet/rap)
  lyrics <topic>              Rap lyrics

CODE
  code <lang> [name]         Generate boilerplate (py/js/bash/c/rs/go/java)
  debug <error-text>         Analyze error messages
  explain <code>             Explain what code does
  boilerplate <lang> [name]  Generate starter code
  duck <problem>             Rubber-duck debugging

MULTIMEDIA
  image <path>               Recognize/describe an image
  ocr <path>                 Extract text from image (tesseract)
  genimage <prompt> [out]    Generate image from text prompt
  audio <path>               Transcribe/analyze audio
  tts <text> [out]           Text-to-speech
  stt <path>                 Speech-to-text

MATH
  calc <expression>          Evaluate math (e.g. "2**10")
  convert <val> <from> <to>  Unit conversion (km/mi, kg/lb, etc.)
  analyze <csv>              Analyze CSV data
  solve <equation>           Solve linear equations

WEB
  search <query> [n]         Search the web (DuckDuckGo)
  fetch <url>                Fetch and extract URL text
  extract <text>             Extract emails, URLs, phones, dates
  factcheck <claim>          Search for claim verification

LANGUAGE
  detect <text>              Detect language of text
  translate <text> [lang]    Translate (es/fr/de/ja/zh)
  romanize <text>            Romanize CJK text

PRODUCTIVITY
  todo <text> [priority] [due]  Add a todo item
  todos [filter]             List todos (all/pending/done)
  done <id>                  Mark todo as complete
  cal <title> <date> [time] [dur]  Add calendar event
  today                      Today's schedule
  week                       This week's schedule
  remind <msg> <when>        Set reminder (30m, 2h, tomorrow 9am)
  reminders                  List pending reminders

EMAIL & DOCS
  email-reply <to> <subj> <tone>  Draft email reply (formal/casual/professional)
  meeting <audio>            Transcribe meeting audio
  template <type> <topic>    Generate template (email/essay/report/poem/story)
  parse <file>               Parse document (txt/md/csv/json/pdf/docx)
  transcribe <audio>         Transcribe audio file

DEVICE CONTROL
  open <app>                 Launch application (browser/terminal/editor/files)
  media <action>             Media control (play/pause/next/prev/volume/status)
  settings <opt> [val]       Device settings (wifi/bluetooth/brightness/darkmode)
  apps                       List installed applications
  screenshot                 Take screenshot

PERSONA & AUTH
  persona <name>             Switch persona (coder/tutor/writer/casual/pro/chef/...)
  register <user> <email> <pass>  Register account
  login <user> <pass>        Login
  logout                     Logout

COMMERCE
  wallet                     Check wallet balance
  addfunds <amount> [desc]   Add funds to wallet
  spend <amount> [desc]      Spend from wallet
  order <item> <price> [qty] Place order
  track <order-id>           Track order status
  book <type> <name> <date> [time]  Make reservation
  bookings                   List reservations
  wishlist                   View wishlist

CREATIVE
  prompt <topic>             Generate creative prompt
  names <topic> [n]          Generate name ideas
  tagline <product>          Generate tagline
  analogy <concept>          Generate analogy
  perspective <topic>        Alternative perspectives
  moodboard <theme>          Describe a moodboard

TRAVEL
  itinerary <dest> [days] [interests]  Generate trip itinerary
  packing <dest> [days] [activity]     Packing checklist
  recommend <location> [type]          Local recommendations (restaurant/cafe/attraction/hotel)
  tweather <location>                  Weather forecast

ENTERTAINMENT
  joke [category]            Tell a joke (general/tech/science/dad)
  trivia [category]          Trivia question (general/science/history)
  game <type> [topic]        Games (20q/riddle/wordgame)
  ent-recommend [type] [mood]  Recommend (movie/book/music)
  persona-voice [persona]    Talk as persona (pirate/shakespeare/robot/detective/chef/surfer/ninja/professor)

CONTACTS
  contact-add <name> [phone] [email] [notes]  Add contact
  contact-search <query>                      Search contacts
  contacts                                   List all contacts
  contact-del <name>                         Delete contact

FINANCE
  stock <symbol>             Get stock price
  currency <amount> [from] [to]  Currency conversion
  budget [summary]           Budget summary
  budget-add <category> <amount>  Add expense
  budget-income <amount>     Set monthly income

CONNECTIONS
  connect <app>              Connect to an app
  disconnect <app>           Disconnect from an app
  connections                List active connections

SUBSYSTEM
  subsystem [name]           Scope to subsystem (or "all")
EOF
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
  ask)           shift; cmd_ask "$@" ;;
  connect)       shift; cmd_connect "$@" ;;
  disconnect)    shift; cmd_disconnect "$@" ;;
  connections)   cmd_connections ;;
  subsystem)     shift; cmd_subsystem "$@" ;;
  status)        cmd_status ;;

  # --- text & content ---
  generate)      shift; ai_text_generate "$@" ;;
  grammar)       shift; ai_text_grammar "$@" ;;
  paraphrase)    shift; ai_text_paraphrase "$@" ;;
  brainstorm)    shift; ai_text_brainstorm "$@" ;;
  stats)         shift; ai_text_stats "$@" ;;
  summarize)     shift; ai_text_summarize "$@" ;;
  draft)         shift; cmd_draft "$@" ;;
  email)         shift; ai_text_email "$@" ;;
  blog)          shift; ai_text_blog "$@" ;;
  social)        shift; ai_text_social "$@" ;;
  copywrite)     shift; ai_text_copywriting "$@" ;;
  poem)          shift; ai_text_poetry "$@" ;;
  lyrics)        shift; ai_text_poetry "$@" "rap" ;;

  # --- code ---
  code)          shift; ai_code_generate "$@" ;;
  debug)         shift; ai_code_debug "$@" ;;
  explain)       shift; ai_code_document "$@" ;;
  boilerplate)   shift; ai_code_generate "$@" ;;
  duck)          shift; ai_code_debug "$@" ;;

  # --- multimodal ---
  image)         shift; ai_image_recognize "$@" ;;
  ocr)           shift; ai_image_ocr "$@" ;;
  genimage)      shift; ai_image_generate "$@" ;;
  audio)         shift; ai_audio_recognize "$@" ;;
  tts)           shift; ai_audio_tts "$@" ;;
  stt)           shift; ai_audio_recognize "$@" ;;

  # --- math ---
  calc)          shift; ai_math_calc "$@" ;;
  convert)       shift; ai_math_convert "$@" ;;
  analyze)       shift; ai_math_analyze "$@" ;;
  solve)         shift; ai_math_solve "$@" ;;

  # --- web ---
  search)        shift; ai_web_search "$@" ;;
  fetch)         shift; ai_web_fetch "$@" ;;
  extract)       shift; ai_web_extract "$@" ;;
  factcheck)     shift; ai_web_factcheck "$@" ;;

  # --- language ---
  detect)        shift; ai_lang_detect "$@" ;;
  translate)     shift; ai_lang_translate "$@" ;;
  romanize)      shift; ai_lang_romanize "$@" ;;

  # --- productivity ---
  todo)          shift; ai_todo_add "$@" ;;
  todos)         shift; ai_todo_list "$@" ;;
  done)          shift; ai_todo_done "$@" ;;
  cal)           shift; ai_cal_add "$@" ;;
  today)         ai_cal_today ;;
  week)          ai_cal_week ;;
  remind)        shift; cmd_remind "$@" ;;
  reminders)     cmd_reminders ;;

  # --- email & docs ---
  email-reply)   shift; ai_email_draft "$@" ;;
  meeting)       shift; ai_transcribe "$@" ;;
  template)      shift; ai_text_generate "$@" ;;
  parse)         shift; ai_doc_parse "$@" ;;
  transcribe)    shift; ai_transcribe "$@" ;;

  # --- device ---
  open)          shift; ai_device_open "$@" ;;
  media)         shift; ai_device_media "$@" ;;
  settings)      shift; ai_device_settings "$@" ;;
  apps)          ai_device_apps ;;
  screenshot)    ai_device_screenshot ;;

  # --- persona & auth ---
  persona)       shift; ai_persona_get "$@" ;;
  personas)      ai_persona_list ;;
  register)      shift; ai_auth_register "$@" ;;
  login)         shift; ai_auth_login "$@" ;;
  logout)        ai_auth_logout ;;
  auth-status)   ai_auth_status ;;

  # --- commerce ---
  wallet)        shift; ai_wallet_balance "$@" ;;
  balance)       ai_wallet_balance ;;
  addfunds)      shift; ai_wallet_add "$@" ;;
  spend)         shift; ai_wallet_spend "$@" ;;
  order)         shift; ai_order_place "$@" ;;
  track)         shift; ai_order_track "$@" ;;
  book)          shift; ai_book_reserve "$@" ;;
  bookings)      ai_book_list ;;
  wishlist)      ai_recomm_list ;;

  # --- creative ---
  prompt)        shift; ai_text_generate "$@" ;;
  names)         shift; ai_text_brainstorm "$@" ;;
  tagline)       shift; ai_text_generate "$@" ;;
  analogy)       shift; ai_text_generate "$@" ;;
  perspective)   shift; ai_text_generate "$@" ;;
  moodboard)     shift; ai_text_generate "$@" ;;

  # --- travel ---
  itinerary)     shift; ai_travel_itinerary "$@" ;;
  packing)       shift; ai_travel_packing "$@" ;;
  recommend)     shift; ai_travel_recommend "$@" ;;
  tweather)      shift; ai_travel_weather "$@" ;;

  # --- entertainment ---
  joke)          shift; ai_entertainment_joke "$@" ;;
  trivia)        shift; ai_entertainment_trivia "$@" ;;
  game)          shift; ai_entertainment_game "$@" ;;
  ent-recommend) shift; ai_entertainment_recommend "$@" ;;
  persona-voice) shift; ai_entertainment_persona "$@" ;;

  # --- contacts ---
  contact-add)   shift; ai_contact_add "$@" ;;
  contact-search) shift; ai_contact_search "$@" ;;
  contacts)      ai_contact_list ;;
  contact-del)   shift; ai_contact_delete "$@" ;;

  # --- finance ---
  stock)         shift; ai_finance_stock "$@" ;;
  currency)      shift; ai_finance_currency "$@" ;;
  budget)        shift; ai_finance_budget "$@" ;;
  budget-add)    shift; ai_finance_budget_add "$@" ;;
  budget-income) shift; ai_finance_budget_set_income "$@" ;;

  # --- AI engine ---
  chat)          shift; ai_chat "$@" ;;
  chat-stream)   shift; ai_chat_stream "$@" ;;
  clear-history) ai_clear_history ;;
  history)       ai_show_history ;;
  models)        ai_ollama_models ;;
  model-set)     OLLAMA_MODEL="${2:-llama3.1:8b}"; echo "Model set to: $OLLAMA_MODEL" ;;

  # --- agent: system control ---
  exec)          shift; agent_exec "$@" ;;
  open)          shift; agent_open_app "$@" ;;
  screenshot)    shift; agent_screenshot "$@" ;;
  read-screen)   shift; agent_read_screen "$@" ;;
  window)        agent_get_window ;;
  windows)       agent_list_windows ;;
  focus)         shift; agent_focus_window "$@" ;;
  type)          shift; agent_type "$@" ;;
  key)           shift; agent_key "$@" ;;
  click)         shift; agent_click "$@" ;;
  move)          shift; agent_move "$@" ;;
  scroll)        shift; agent_scroll "$@" ;;

  # --- agent: browser ---
  browser-history) shift; agent_browser_history "$@" ;;
  browser-open)  shift; agent_browser_open "$@" ;;
  browser-replay) shift; agent_browser_replay "$@" ;;
  browser-tabs)  agent_browser_tabs ;;

  # --- agent: vision ---
  vision-read)   shift; agent_vision_read "$@" ;;
  vision-find)   shift; agent_vision_find "$@" ;;
  vision-click)  shift; agent_vision_click "$@" ;;
  vision-describe) shift; agent_vision_describe "$@" ;;

  # --- agent: automation ---
  schedule)      shift; agent_schedule "$@" ;;
  schedules)     agent_schedule_list ;;
  cancel)        shift; agent_schedule_cancel "$@" ;;
  chain)         shift; agent_chain "$@" ;;
  purchase)      shift; agent_purchase "$@" ;;

  # --- knowledge ---
  know)          shift; tk_knowledge "$@" ;;
  random-fact)   tk_random_fact ;;
  os-version)    tk_version ;;

  # --- cards ---
  card-image)    shift; ai_card_image "$@" ;;
  card-link)     shift; ai_card_link "$@" ;;
  card-code)     shift; ai_card_code "$@" ;;
  card-snapshot) shift; ai_card_snapshot "$@" ;;
  card-flowchart) shift; ai_card_flowchart "$@" ;;
  card-statemachine) shift; ai_card_statemachine "$@" ;;
  card-mockup)   shift; ai_card_mockup "$@" ;;
  card-pipeline) shift; ai_card_pipeline "$@" ;;
  card-sandbox)  shift; ai_card_sandbox "$@" ;;
  card-codecell) shift; ai_card_codecell "$@" ;;
  card-dataviz)  shift; ai_card_dataviz "$@" ;;
  card-countdown) shift; ai_card_countdown "$@" ;;
  card-pomodoro) ai_card_pomodoro ;;
  card-kanban)   ai_card_kanban ;;
  card-clock)    shift; ai_card_clock "$@" ;;
  card-fileexplorer) shift; ai_card_fileexplorer "$@" ;;
  card-diff)     shift; ai_card_diff "$@" ;;
  card-doceditor) shift; ai_card_doceditor "$@" ;;
  card-mediaplayer) shift; ai_card_mediaplayer "$@" ;;
  card-scenario) shift; ai_card_scenario "$@" ;;
  card-abtest)   shift; ai_card_abtest "$@" ;;
  card-logic)    shift; ai_card_logic "$@" ;;
  card-3d)       shift; ai_card_3d "$@" ;;
  card-map)      shift; ai_card_map "$@" ;;
  card-audioviz) shift; ai_card_audioviz "$@" ;;

  # --- help ---
  help|*)        cmd_help ;;
esac

# ---------------------------------------------------------------------------
#  internal helpers (called by dispatch above)
# ---------------------------------------------------------------------------
cmd_remind() {
  local msg="$1"
  local when="$2"
  local id
  id="r_$(date +%s)_$$"
  local dir="$TINKER_AI_HOME/reminders"
  mkdir -p "$dir"
  cat > "$dir/$id.json" <<EOJSON
{"id":"$id","message":"$msg","when":"$when","created":"$(date -Iseconds)","status":"pending"}
EOJSON
  echo "Reminder set: $msg — $when"
}

cmd_reminders() {
  local dir="${TINKER_AI_HOME:-$HOME/.config/tinker-ai}/reminders"
  mkdir -p "$dir"
  echo "=== Pending Reminders ==="
  local found=0
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    local msg when status
    msg=$(python3 -c "import json; print(json.load(open('$f'))['message'])" 2>/dev/null)
    when=$(python3 -c "import json; print(json.load(open('$f'))['when'])" 2>/dev/null)
    status=$(python3 -c "import json; print(json.load(open('$f'))['status'])" 2>/dev/null)
    [ "$status" = "pending" ] || continue
    echo "  • $msg — $when"
    found=1
  done
  [ "$found" -eq 0 ] && echo "  (none)"
}

cmd_draft() {
  local topic="$1"
  ai_text_generate "$topic" email
}


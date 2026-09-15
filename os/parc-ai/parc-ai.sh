#!/bin/bash
# ===========================================================================
#  parc-ai.sh — KorrinOS Tinkeria ASSISTANT CLI backend
# ---------------------------------------------------------------------------
#  Backend for the Tinker AI glassmorphism GUI. Searches local context
#  (Searchie index, filesystem, command history) and returns structured
#  HTML card responses for rendering in the GUI.
#
#  Usage:
#    parc-ai ask "<query>"          # HTML card response
#    parc-ai connect <app>          # connect to an app
#    parc-ai disconnect <app>       # disconnect from an app
#    parc-ai connections            # list active connections
#    parc-ai subsystem <name>       # scope to a subsystem
#    parc-ai status                 # show AI status
# ===========================================================================
set -euo pipefail
IFS=$'\n\t'

# ---- paths ----------------------------------------------------------------
AI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_CONFIG="${HOME}/.config/tinkeria"
AI_CONNECTIONS="${AI_CONFIG}/connections"
AI_SUBSYSTEM="${AI_CONFIG}/subsystem"
AI_LOG="${AI_CONFIG}/ai.log"

# vibe-address engine (for index search)
VIBE_ENGINE="${VIBE_ENGINE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../territories/vibe-address" 2>/dev/null && pwd || echo "")}"
VIBE_HOME="${VIBE_HOME:-$HOME/.local/share/korrinos/vibe}"

# ---- defaults -------------------------------------------------------------
DEFAULT_CONNECTIONS="browser terminal editor file-manager email calendar notes"

mkdir -p "${AI_CONNECTIONS}"
mkdir -p "$(dirname "${AI_LOG}")"

# ---- source all modules ---------------------------------------------------
MODULE_DIR="${AI_DIR}/modules"
OVERLAY_DIR="${AI_DIR}/overlay"
[ -d "$MODULE_DIR" ] && for m in "$MODULE_DIR"/*.sh; do [ -f "$m" ] && source "$m"; done
[ -f "$OVERLAY_DIR/agent-narrator.sh" ] && source "$OVERLAY_DIR/agent-narrator.sh"
[ -f "$MODULE_DIR/ai-master-brain.sh" ] && source "$MODULE_DIR/ai-master-brain.sh"
[ -f "$MODULE_DIR/ai-self-learn.sh" ] && source "$MODULE_DIR/ai-self-learn.sh"
[ -f "$MODULE_DIR/ai-voice.sh" ] && source "$MODULE_DIR/ai-voice.sh"
[ -f "$MODULE_DIR/ai-image-gen.sh" ] && source "$MODULE_DIR/ai-image-gen.sh"
[ -f "$MODULE_DIR/ai-personality.sh" ] && source "$MODULE_DIR/ai-personality.sh"
[ -f "$MODULE_DIR/nlp-670-patterns.sh" ] && source "$MODULE_DIR/nlp-670-patterns.sh"
[ -f "$MODULE_DIR/ai-nlu-crf.sh" ] && source "$MODULE_DIR/ai-nlu-crf.sh"
[ -f "$MODULE_DIR/ai-narrative.sh" ] && source "$MODULE_DIR/ai-narrative.sh"
[ -f "$MODULE_DIR/ai-knowledge-broad.sh" ] && source "$MODULE_DIR/ai-knowledge-broad.sh"
[ -f "$MODULE_DIR/ai-knowledge-mega.sh" ] && source "$MODULE_DIR/ai-knowledge-mega.sh"
[ -f "$MODULE_DIR/korrinos-features.sh" ] && source "$MODULE_DIR/korrinos-features.sh"

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
    card_title "TinkerIA"
    card_body "Hey! I'm Tinkeria — your built-in AI for KorrinOS. I live right here on your system, no cloud needed. I can answer questions, write code, brainstorm ideas, control your computer, and a lot more. What's on your mind?"
    card_secondary "I know 500+ topics: science, history, math, coding, philosophy, health, economics, and more. Try: 'What is quantum entanglement?' or 'Write me a Python script'"
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

  # --- Knowledge base lookup (instant, no LLM needed) ---
  local kb_answer=""
  if declare -f ai_knowledge_mega_search >/dev/null 2>&1; then
    kb_answer=$(ai_knowledge_mega_search "$query" 2>/dev/null || echo "")
  fi
  if [ -z "$kb_answer" ] && declare -f ai_knowledge_broad_search >/dev/null 2>&1; then
    kb_answer=$(ai_knowledge_broad_search "$query" 2>/dev/null || echo "")
  fi

  # --- Self-learning memory lookup ---
  local learned_answer=""
  if declare -f ai_learn_search >/dev/null 2>&1; then
    learned_answer=$(ai_learn_search "$query" 2>/dev/null || echo "")
  fi

  html_header

  # === TIER 1: Knowledge base (instant, always available) ===
  if [ -n "$kb_answer" ]; then
    card_open
    card_title "🧠 ${query}"
    card_body "<div style='line-height:1.7;'>${kb_answer}</div>"
    card_secondary "Source: TinkerIA Knowledge Base · Intent: ${intent}"
    card_close
    # Still try Ollama for a richer answer below, but show KB instantly
  fi

  # === TIER 2: Self-learned memory ===
  if [ -z "$kb_answer" ] && [ -n "$learned_answer" ]; then
    card_open
    card_title "💡 ${query}"
    card_body "<div style='line-height:1.7;'>${learned_answer}</div>"
    card_secondary "Source: TinkerIA Memory · Intent: ${intent}"
    card_close
  fi

  # === TIER 3: Use AI Engine (Ollama LLM) for real answers ===
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
" 2>/dev/null) || html_answer=$(echo "$answer" | sed 's/</\&lt;/g; s/\n/<br>/g')
      
      card_open
      card_title "🤖 Tinkeria"
      card_body "<div style='line-height:1.7;'>${html_answer}</div>"
      card_secondary "Model: ${OLLAMA_MODEL:-llama3.1:8b} · Intent: ${intent}"
      card_close

      # Auto-learn: store Q&A in self-learning memory for next time
      if declare -f ai_learn_teach >/dev/null 2>&1; then
        ai_learn_teach "$query" "$answer" 2>/dev/null || true
      fi

      # Narrate via glassmorphism overlay (non-blocking)
      if declare -f ai_narrate_creative >/dev/null 2>&1; then
        ai_narrate_creative "$query" "$answer" 2>/dev/null || true
      fi

      html_footer
      return 0
    fi
  fi

  # === TIER 4: Self-learning fallback (search web, store for next time) ===
  if [ -z "$kb_answer" ] && [ -z "$learned_answer" ]; then
    local web_answer=""
    if declare -f ai_web_search >/dev/null 2>&1; then
      web_answer=$(ai_web_search "$query" 1 2>/dev/null || echo "")
    fi
    if [ -n "$web_answer" ]; then
      card_open
      card_title "🌐 ${query}"
      card_body "<div style='line-height:1.7;'>${web_answer}</div>"
      card_secondary "Source: Web Search · Intent: ${intent}"
      card_close
      # Store in self-learning for next time
      if declare -f ai_learn_teach >/dev/null 2>&1; then
        ai_learn_teach "$query" "$web_answer" 2>/dev/null || true
      fi
      html_footer
      return 0
    fi
  fi

  # === FALLBACK: Specialized modules with CONVERSATIONAL responses ===
  case "$intent" in
    greeting)
      card_open
      card_title "Hey there! 👋"
      local greetings=(
        "Hey! I'm Tinkeria — your built-in AI. I live right here on your system and I don't need the cloud to help you out. Ask me anything, I'm ready."
        "What's up! I'm Tinkeria. I can answer questions, write code, brainstorm ideas, control your computer, and a whole lot more. What's on your mind?"
        "Hi there! Tinkeria here. I've got a knowledge base, web search, and a brain full of useful stuff. Just ask — I'm here to help."
      )
      local greet_idx=$((RANDOM % ${#greetings[@]}))
      card_body "${greetings[$greet_idx]}"
      card_secondary "I know about science, history, math, coding, philosophy, health, and 500+ topics. Try me!"
      card_close
      ;;

    question)
      local target
      target=$(ai_nlu_target "$query" "question" 2>/dev/null || echo "$query")
      card_open
      card_title "🔍 $query"

      # Try knowledge base first
      local kb_result=""
      if declare -f ai_knowledge_mega_search >/dev/null 2>&1; then
        kb_result=$(ai_knowledge_mega_search "$target" 2>/dev/null || echo "")
      fi
      if [ -z "$kb_result" ] && declare -f ai_knowledge_broad_search >/dev/null 2>&1; then
        kb_result=$(ai_knowledge_broad_search "$target" 2>/dev/null || echo "")
      fi

      if [ -n "$kb_result" ]; then
        card_body "<div style='line-height:1.7;'>${kb_result}</div>"
        card_secondary "Source: TinkerIA Knowledge Base"
      else
        local web_results
        web_results=$(ai_web_search "$target" 3 2>/dev/null || echo "")
        if [ -n "$web_results" ]; then
          card_body "I found some information about that. Here's what I got:<br><br><pre style='white-space:pre-wrap;font-size:12pt;'>${web_results}</pre>"
        else
          card_body "Hmm, I'm not able to look that up right now. If you start Ollama with <code>ollama serve</code>, I can give you much better answers. In the meantime, try asking me something else — I'm good with code, writing, math, and KorrinOS questions!"
        fi
      fi
      card_close
      ;;

    create)
      local target
      target=$(ai_nlu_target "$query" "create" 2>/dev/null || echo "$query")
      card_open
      card_title "✍️ Writing: $target"
      local result
      result=$(ai_text_generate "$target" 2>&1 || echo "I couldn't generate that, but I can try something else.")
      card_body "$result"
      card_close
      ;;

    search)
      local target
      target=$(ai_nlu_target "$query" "search" 2>/dev/null || echo "$query")
      card_open
      card_title "🌐 Searching: $target"
      local result
      result=$(ai_web_search "$target" 5 2>&1 || echo "Search isn't available right now.")
      card_body "Here's what I found:<br><br><pre style='white-space:pre-wrap;font-size:12pt;'>${result}</pre>"
      card_close
      ;;

    code)
      local target
      target=$(ai_nlu_target "$query" "code" 2>/dev/null || echo "$query")
      card_open
      card_title "💻 Code help"
      # Try knowledge base for code patterns first
      local code_answer=""
      if declare -f ai_knowledge_mega_search >/dev/null 2>&1; then
        code_answer=$(ai_knowledge_mega_search "code $target" 2>/dev/null || echo "")
      fi
      if [ -n "$code_answer" ]; then
        card_body "<div style='line-height:1.7;'>${code_answer}</div>"
        card_secondary "Source: TinkerIA Code Knowledge"
      else
        local result
        result=$(ai_code_debug "$target" 2>&1 || echo "I couldn't analyze that code. Can you paste it again?")
        card_body "$result"
      fi
      card_close
      ;;

    media)
      card_open
      card_title "🎵 Media"
      card_body "I can help with images, audio, and video! Just tell me what you need — like 'recognize this image' or 'read this text from a photo' or 'transcribe this audio clip'."
      card_secondary "Or use: parc-ai image &lt;path&gt; · parc-ai ocr &lt;path&gt; · parc-ai tts &lt;text&gt;"
      card_close
      ;;

    summarize)
      local target
      target=$(ai_nlu_target "$query" "summarize" 2>/dev/null || echo "$query")
      card_open
      card_title "📝 Summary"
      local result
      result=$(ai_text_summarize "$target" 5 2>&1 || echo "I couldn't summarize that. Try pasting the text or giving me a file path.")
      card_body "$result"
      card_close
      ;;

    translate)
      card_open
      card_title "🌍 Translation"
      card_body "Sure, I can translate that! Just tell me what language you want it in — I support Spanish, French, German, Japanese, Chinese, and more."
      card_secondary "Example: 'Translate hello world to Spanish'"
      card_close
      ;;

    math)
      local target
      target=$(ai_nlu_target "$query" "math" 2>/dev/null || echo "$query")
      card_open
      card_title "🧮 Math"
      local result
      result=$(ai_math_calc "$target" 2>&1 || echo "I couldn't calculate that. Can you double-check the numbers?")
      card_body "$result"
      card_close
      ;;

    schedule)
      card_open
      card_title "📅 Scheduling"
      card_body "I can help you manage your time! I can set reminders, create to-do lists, or help you plan your day. Just tell me what you need — like 'remind me to call mom at 3pm' or 'add buy groceries to my todo list'."
      card_secondary "Or use: parc-ai remind &lt;msg&gt; &lt;time&gt; · parc-ai todo add &lt;text&gt;"
      card_close
      ;;

    settings)
      local target
      target=$(ai_nlu_target "$query" "settings" 2>/dev/null || echo "$query")
      card_open
      card_title "⚙️ Settings"
      local result
      result=$(ai_device_settings "$target" 2>&1 || echo "I couldn't change that setting. Can you be more specific?")
      card_body "$result"
      card_close
      ;;

    commerce)
      card_open
      card_title "🛒 Shopping"
      card_body "I can help you track orders, make bookings, or check your wallet balance. Just tell me what you need — like 'track my order' or 'book a table for two' or 'what's my balance?'"
      card_secondary "Or use: parc-ai order &lt;item&gt; · parc-ai book &lt;type&gt; &lt;name&gt; · parc-ai wallet"
      card_close
      ;;

    help)
      cmd_help
      ;;

    thanks)
      card_open
      card_title "You're welcome! 😊"
      card_body "Happy to help! I'm always here if you need anything else — just ask."
      card_close
      ;;

    *)
      # Fallback: try knowledge base → self-learning → vibe search → web → conversational
      local fallback_answer=""

      # Try mega knowledge base
      if [ -z "$fallback_answer" ] && declare -f ai_knowledge_mega_search >/dev/null 2>&1; then
        fallback_answer=$(ai_knowledge_mega_search "$query" 2>/dev/null || echo "")
      fi

      # Try broad knowledge base
      if [ -z "$fallback_answer" ] && declare -f ai_knowledge_broad_search >/dev/null 2>&1; then
        fallback_answer=$(ai_knowledge_broad_search "$query" 2>/dev/null || echo "")
      fi

      # Try self-learned memory
      if [ -z "$fallback_answer" ] && declare -f ai_learn_search >/dev/null 2>&1; then
        fallback_answer=$(ai_learn_search "$query" 2>/dev/null || echo "")
      fi

      # Try vibe index
      local vibe_results
      vibe_results=$(search_vibe_index "$query" 2>/dev/null)
      local file_results
      file_results=$(search_local_files "$query" 2>/dev/null)

      card_open
      card_title "🤔 $query"

      if [ -n "$fallback_answer" ]; then
        card_body "<div style='line-height:1.7;'>${fallback_answer}</div>"
        card_secondary "Source: TinkerIA Knowledge · Intent: ${intent}"
      elif [ -n "$vibe_results" ] || [ -n "$file_results" ]; then
        card_body "I found some things that might be related to what you're asking about:"
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
      else
        card_body "I'm not sure I understand what you're looking for. I'm pretty good with questions about KorrinOS, writing, code, math, translations, and controlling your computer. Could you try rephrasing that, or let me know what kind of help you need?"
        card_secondary "Type 'help' to see everything I can do."
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
  parc-ai <command> [args...]

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
    echo "Usage: parc-ai connect <app>"
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
    echo "Usage: parc-ai disconnect <app>"
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
    echo "  use: parc-ai connect <app>"
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
  type-in)       shift; agent_type_in "$@" ;;
  key-in)        shift; agent_key_in "$@" ;;
  click)         shift; agent_click "$@" ;;
  move)          shift; agent_move "$@" ;;
  scroll)        shift; agent_scroll "$@" ;;

  # --- agent: browser ---
  search-up)      shift; agent_search_up "$@" ;;
  open-url)       shift; agent_open_url "$@" ;;
  play)           shift; agent_play_music "$@" ;;
  stop-music)     agent_stop_music ;;
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

  # --- self-learning ---
  learn)         shift; ai_learn_search "$@" ;;
  teach)         shift; ai_learn_teach "$@" ;;
  learned)       ai_learn_list ;;
  forget)        shift; ai_learn_forget "$@" ;;

  # --- voice ---
  say)           shift; ai_tts "$@" ;;
  listen)        ai_stt "$@" ;;

  # --- image gen ---
  gen-card)      shift; ai_gen_gradient_card "$@" ;;
  gen-code)      shift; ai_gen_code_card "$@" ;;
  gen-flow)      shift; ai_gen_flowchart "$@" ;;
  gen-chart)     shift; ai_gen_chart "$@" ;;
  gen-alert)     shift; ai_gen_alert "$@" ;;
  gen-progress)  shift; ai_gen_progress "$@" ;;

  # --- personality ---
  personality)   shift; ai_personality_set "$@" ;;
  sentiment)     shift; ai_sentiment_detect "$@" ;;
  narrate)       shift; ai_narrate_creative "$@" ;;

  # --- broad knowledge ---
  know-broad)    shift; ai_knowledge_broad_search "$@" ;;
  know-count)    ai_knowledge_broad_count ;;
  know-mega)     shift; ai_knowledge_mega_search "$@" ;;
  know-mega-count) ai_knowledge_mega_count ;;

  # --- OS features ---
  health)        tk_health_dashboard ;;
  quick-action)  shift; tk_quick_action "$@" ;;
  project)       shift; tk_project_template "$@" ;;
  monitor)       shift; tk_system_monitor "$@" ;;
  backup)        shift; tk_backup "$@" ;;
  notes)         shift; case "${1:-list}" in
                       add) shift; tk_notes_add "$@" ;;
                       list) tk_notes_list ;;
                       clear) tk_notes_clear ;;
                       *) echo "Usage: notes (add|list|clear)" ;;
                     esac ;;
  theme)         shift; tk_color_theme "$@" ;;
  clip)          shift; case "${1:-list}" in
                       save) shift; tk_clip_save "$@" ;;
                       list) tk_clip_list ;;
                       clear) tk_clip_clear ;;
                       *) echo "Usage: clip (save|list|clear)" ;;
                     esac ;;

  # --- system tools ---
  sys-health)    "$AI_DIR/korrinos-tools.sh" health ;;
  sys-disk)      shift; "$AI_DIR/korrinos-tools.sh" disk "$@" ;;
  sys-network)   "$AI_DIR/korrinos-tools.sh" network ;;
  sys-usb)       "$AI_DIR/korrinos-tools.sh" usb ;;
  sys-screenshot) shift; "$AI_DIR/korrinos-tools.sh" screenshot "$@" ;;
  sys-cleanup)   "$AI_DIR/korrinos-tools.sh" cleanup ;;

  # --- backup ---
  backup-dotfiles) "$AI_DIR/korrinos-backup.sh" dotfiles ;;
  backup-configs)  "$AI_DIR/korrinos-backup.sh" configs ;;
  backup-kernel)   "$AI_DIR/korrinos-backup.sh" kernel ;;
  backup-list)     "$AI_DIR/korrinos-backup.sh" list ;;
  backup-full)     shift; "$AI_DIR/korrinos-backup.sh" full "$@" ;;

  # --- clipboard ---
  clip-copy)     shift; "$AI_DIR/korrinos-clipboard.sh" copy "$@" ;;
  clip-paste)    "$AI_DIR/korrinos-clipboard.sh" paste ;;
  clip-history)  "$AI_DIR/korrinos-clipboard.sh" history ;;
  clip-select)   shift; "$AI_DIR/korrinos-clipboard.sh" select "$@" ;;

  # --- process monitor ---
  proc-top)      "$AI_DIR/korrinos-procmon.sh" top ;;
  proc-watch)    shift; "$AI_DIR/korrinos-procmon.sh" watch "$@" ;;
  proc-kill)     shift; "$AI_DIR/korrinos-procmon.sh" kill "$@" ;;
  proc-tree)     shift; "$AI_DIR/korrinos-procmon.sh" tree "$@" ;;
  proc-files)    shift; "$AI_DIR/korrinos-procmon.sh" files "$@" ;;
  proc-summary)  "$AI_DIR/korrinos-procmon.sh" summary ;;

  # --- settings daemon ---
  settings)      shift; "$AI_DIR/korrinos-settings.sh" "$@" ;;

  # --- package manager ---
  pm)            shift; "$AI_DIR/korrinos-pm.sh" "$@" ;;
  install)       shift; "$AI_DIR/korrinos-pm.sh" install "$@" ;;
  remove)        shift; "$AI_DIR/korrinos-pm.sh" remove "$@" ;;
  search-app)    shift; "$AI_DIR/korrinos-pm.sh" search "$@" ;;

  # --- searchie 2.0 ---
  searchie)      shift; "$AI_DIR/korrinos-searchie.sh" "$@" ;;
  find)          shift; "$AI_DIR/korrinos-searchie.sh" quick "$@" ;;
  search-text)   shift; "$AI_DIR/korrinos-searchie.sh" search "$@" ;;

  # --- virtual desktops ---
  desktop)       shift; "$AI_DIR/korrinos-desktop.sh" "$@" ;;
  ws)            shift; "$AI_DIR/korrinos-desktop.sh" switch "$@" ;;
  tile-left)     "$AI_DIR/korrinos-desktop.sh" tile-left ;;
  tile-right)    "$AI_DIR/korrinos-desktop.sh" tile-right ;;
  tile-top)      "$AI_DIR/korrinos-desktop.sh" tile-top ;;
  tile-bottom)   "$AI_DIR/korrinos-desktop.sh" tile-bottom ;;

  # --- terminal ---
  terminal)      shift; "$AI_DIR/korrinos-terminal.sh" "$@" ;;
  ai-suggest)    shift; "$AI_DIR/korrinos-terminal.sh" suggest "$@" ;;
  ai-explain)    shift; "$AI_DIR/korrinos-terminal.sh" explain "$@" ;;
  ai-fix)        shift; "$AI_DIR/korrinos-terminal.sh" fix "$@" ;;

  # --- security center ---
  security)      shift; "$AI_DIR/korrinos-security.sh" "$@" ;;
  firewall)      shift; "$AI_DIR/korrinos-security.sh" firewall "$@" ;;
  audit)         shift; "$AI_DIR/korrinos-security.sh" audit "$@" ;;
  gen-password)  shift; "$AI_DIR/korrinos-security.sh" password "$@" ;;

  # --- developer toolkit ---
  dev)           shift; "$AI_DIR/korrinos-devtool.sh" "$@" ;;
  git)           shift; "$AI_DIR/korrinos-devtool.sh" git "$@" ;;
  docker)        shift; "$AI_DIR/korrinos-devtool.sh" docker "$@" ;;
  runtime)       shift; "$AI_DIR/korrinos-devtool.sh" runtime "$@" ;;

  # --- media hub ---
  media)         shift; "$AI_DIR/korrinos-media.sh" "$@" ;;
  music)         shift; "$AI_DIR/korrinos-media.sh" music "$@" ;;
  video)         shift; "$AI_DIR/korrinos-media.sh" video "$@" ;;
  photos)        shift; "$AI_DIR/korrinos-media.sh" photo "$@" ;;

  # --- usb builder ---
  usb)           shift; "$AI_DIR/korrinos-usb.sh" "$@" ;;

  # --- system recovery ---
  recovery)      shift; "$AI_DIR/korrinos-recovery.sh" "$@" ;;
  snapshot)      "$AI_DIR/korrinos-recovery.sh" snapshot ;;
  rollback)      shift; "$AI_DIR/korrinos-recovery.sh" restore "$@" ;;

  # --- sound system ---
  sounds)        shift; "$AI_DIR/korrinos-sounds.sh" "$@" ;;
  sound-theme)   shift; "$AI_DIR/korrinos-sounds.sh" themes ;;
  sound-toggle)  shift; "$AI_DIR/korrinos-sounds.sh" toggle "$@" ;;
  sound-volume)  shift; "$AI_DIR/korrinos-sounds.sh" volume "$@" ;;
  boot-sound)    "$AI_DIR/korrinos-sounds.sh" boot ;;

  # --- voice notifications ---
  voice)         shift; "$AI_DIR/korrinos-voice.sh" "$@" ;;
  voice-toggle)  "$AI_DIR/korrinos-voice.sh" toggle ;;
  voice-say)     shift; "$AI_DIR/korrinos-voice.sh" say "$@" ;;
  voice-cmd)     shift; "$AI_DIR/korrinos-voice.sh" cmd "$@" ;;

  # --- AI shell companion ---
  shell-ai)      shift; "$AI_DIR/korrinos-shell-ai.sh" "$@" ;;
  ai-shell)      shift; "$AI_DIR/korrinos-shell-ai.sh" ask "$@" ;;

  # --- natural language control ---
  nlctl)         shift; "$AI_DIR/korrinos-nlctl.sh" "$@" ;;
  do)            shift; "$AI_DIR/korrinos-nlctl.sh" do "$@" ;;
  undo)          "$AI_DIR/korrinos-nlctl.sh" undo ;;
  redo)          "$AI_DIR/korrinos-nlctl.sh" redo ;;

  # --- context clipboard ---
  clipctx)       shift; "$AI_DIR/korrinos-clipctx.sh" "$@" ;;
  ctx-copy)      shift; "$AI_DIR/korrinos-clipctx.sh" copy "$@" ;;
  ctx-paste)     "$AI_DIR/korrinos-clipctx.sh" paste ;;
  ctx-history)   "$AI_DIR/korrinos-clipctx.sh" history ;;

  # --- hotkeys ---
  hotkeys)       shift; "$AI_DIR/korrinos-hotkeys.sh" "$@" ;;
  hotkey-list)   "$AI_DIR/korrinos-hotkeys.sh" list ;;
  hotkey-add)    shift; "$AI_DIR/korrinos-hotkeys.sh" add "$@" ;;

  # --- focus mode ---
  focus)         shift; "$AI_DIR/korrinos-focus.sh" "$@" ;;
  focus-on)      "$AI_DIR/korrinos-focus.sh" on ;;
  focus-off)     "$AI_DIR/korrinos-focus.sh" off ;;
  focus-status)  "$AI_DIR/korrinos-focus.sh" status ;;

  # --- split screen ---
  split)         shift; "$AI_DIR/korrinos-splitscreen.sh" "$@" ;;
  split-left)    "$AI_DIR/korrinos-splitscreen.sh" left ;;
  split-right)   "$AI_DIR/korrinos-splitscreen.sh" right ;;
  split-grid)    "$AI_DIR/korrinos-splitscreen.sh" grid ;;

  # --- system toggles ---
  toggles)       shift; "$AI_DIR/korrinos-toggles.sh" "$@" ;;
  toggle-auto)   shift; "$AI_DIR/korrinos-toggles.sh" auto-update "$@" ;;
  toggle-health) shift; "$AI_DIR/korrinos-toggles.sh" health "$@" ;;
  toggle-net)    shift; "$AI_DIR/korrinos-toggles.sh" network "$@" ;;

  # --- screenshot annotate ---
  annotate)      shift; "$AI_DIR/korrinos-annotate.sh" "$@" ;;
  ann-screenshot) "$AI_DIR/korrinos-annotate.sh" screenshot ;;
  ann-draw)      shift; "$AI_DIR/korrinos-annotate.sh" draw "$@" ;;

  # --- ASCII art ---
  ascii)         shift; "$AI_DIR/korrinos-ascii.sh" "$@" ;;
  ascii-art)     shift; "$AI_DIR/korrinos-ascii.sh" generate "$@" ;;
  ascii-logo)    "$AI_DIR/korrinos-ascii.sh" logo ;;

  # --- desktop widgets ---
  widgets)       shift; "$AI_DIR/korrinos-widgets.sh" "$@" ;;
  widget-add)    shift; "$AI_DIR/korrinos-widgets.sh" add "$@" ;;
  widget-list)   "$AI_DIR/korrinos-widgets.sh" list ;;
  widget-rm)     shift; "$AI_DIR/korrinos-widgets.sh" remove "$@" ;;

  # --- security apps ---
  sec-apps)      shift; "$AI_DIR/korrinos-security-apps.sh" "$@" ;;
  perm)          shift; "$AI_DIR/korrinos-security-apps.sh" permissions "$@" ;;
  enc-notes)     shift; "$AI_DIR/korrinos-security-apps.sh" notes "$@" ;;
  wifi-sec)      "$AI_DIR/korrinos-security-apps.sh" wifi ;;

  # --- system dashboard ---
  dashboard)     shift; "$AI_DIR/korrinos-dashboard.sh" "$@" ;;
  sys-health)    "$AI_DIR/korrinos-dashboard.sh" health ;;
  sys-monitor)   shift; "$AI_DIR/korrinos-dashboard.sh" monitor "$@" ;;
  sys-top)       "$AI_DIR/korrinos-dashboard.sh" top ;;
  sys-disk)      "$AI_DIR/korrinos-dashboard.sh" disk ;;
  sys-network)   "$AI_DIR/korrinos-dashboard.sh" network ;;
  sys-battery)   "$AI_DIR/korrinos-dashboard.sh" battery ;;
  sys-alerts)    "$AI_DIR/korrinos-dashboard.sh" alerts ;;

  # --- power management ---
  power)         shift; "$AI_DIR/korrinos-power.sh" "$@" ;;
  power-profile) shift; "$AI_DIR/korrinos-power.sh" profile "$@" ;;
  power-status)  "$AI_DIR/korrinos-power.sh" status ;;
  power-battery) "$AI_DIR/korrinos-power.sh" battery ;;
  power-thermal) "$AI_DIR/korrinos-power.sh" thermal ;;

  # --- network manager ---
  net)           shift; "$AI_DIR/korrinos-network.sh" "$@" ;;
  net-status)    "$AI_DIR/korrinos-network.sh" status ;;
  net-wifi)      shift; "$AI_DIR/korrinos-network.sh" wifi "$@" ;;
  net-dns)       shift; "$AI_DIR/korrinos-network.sh" dns "$@" ;;
  net-speed)     "$AI_DIR/korrinos-network.sh" speedtest ;;
  net-vpn)       "$AI_DIR/korrinos-network.sh" vpn ;;

  # --- developer suite ---
  devsuite)      shift; "$AI_DIR/korrinos-devsuite.sh" "$@" ;;
  dev-git)       shift; "$AI_DIR/korrinos-devsuite.sh" git "$@" ;;
  dev-template)  shift; "$AI_DIR/korrinos-devsuite.sh" template "$@" ;;
  dev-analyze)   shift; "$AI_DIR/korrinos-devsuite.sh" analyze "$@" ;;
  dev-docker)    "$AI_DIR/korrinos-devsuite.sh" docker ;;
  dev-runtime)   "$AI_DIR/korrinos-devsuite.sh" runtime ;;

  # --- tinkeria AI ---
  ai)            shift; "$AI_DIR/korrinos-tinkeria.sh" "$@" ;;
  ai-chat)       shift; "$AI_DIR/korrinos-tinkeria.sh" chat "$@" ;;
  ai-persona)    shift; "$AI_DIR/korrinos-tinkeria.sh" personality "$@" ;;
  ai-quick)      shift; "$AI_DIR/korrinos-tinkeria.sh" quick "$@" ;;
  ai-session)    shift; "$AI_DIR/korrinos-tinkeria.sh" session "$@" ;;
  ai-history)    shift; "$AI_DIR/korrinos-tinkeria.sh" history "$@" ;;

  # --- system monitor ---
  monitor)       shift; "$AI_DIR/korrinos-monitor.sh" "$@" ;;
  mon-live)      "$AI_DIR/korrinos-monitor.sh" live ;;
  mon-status)    "$AI_DIR/korrinos-monitor.sh" status ;;
  mon-tree)      "$AI_DIR/korrinos-monitor.sh" tree ;;
  mon-kill)      shift; "$AI_DIR/korrinos-monitor.sh" kill "$@" ;;
  mon-watch)     shift; "$AI_DIR/korrinos-monitor.sh" watch "$@" ;;

  # --- keyboard shortcuts ---
  shortcuts)     shift; "$AI_DIR/korrinos-shortcuts.sh" "$@" ;;
  shortcut-list) "$AI_DIR/korrinos-shortcuts.sh" list ;;
  shortcut-set)  shift; "$AI_DIR/korrinos-shortcuts.sh" set "$@" ;;
  shortcut-preset) shift; "$AI_DIR/korrinos-shortcuts.sh" preset "$@" ;;

  # --- clipboard enhanced ---
  clipctx)       shift; "$AI_DIR/korrinos-clipctx.sh" "$@" ;;
  clip-copy)     shift; "$AI_DIR/korrinos-clipctx.sh" copy "$@" ;;
  clip-paste)    "$AI_DIR/korrinos-clipctx.sh" paste ;;
  clip-history)  shift; "$AI_DIR/korrinos-clipctx.sh" history "$@" ;;
  clip-search)   shift; "$AI_DIR/korrinos-clipctx.sh" search "$@" ;;
  clip-smart)    "$AI_DIR/korrinos-clipctx.sh" smart ;;

  # --- task scheduler ---
  schedule)      shift; "$AI_DIR/korrinos-schedule.sh" "$@" ;;
  sched-add)     shift; "$AI_DIR/korrinos-schedule.sh" add "$@" ;;
  sched-list)    "$AI_DIR/korrinos-schedule.sh" list ;;
  sched-run)     shift; "$AI_DIR/korrinos-schedule.sh" run "$@" ;;
  remind)        shift; "$AI_DIR/korrinos-schedule.sh" remind "$@" ;;

  # --- backup system ---
  backup)        shift; "$AI_DIR/korrinos-backup.sh" "$@" ;;
  backup-run)    shift; "$AI_DIR/korrinos-backup.sh" backup "$@" ;;
  backup-list)   "$AI_DIR/korrinos-backup.sh" list ;;
  backup-restore) shift; "$AI_DIR/korrinos-backup.sh" restore "$@" ;;
  backup-status) "$AI_DIR/korrinos-backup.sh" status ;;

  # --- system cleanup ---
  cleanup)       shift; "$AI_DIR/korrinos-cleanup.sh" "$@" ;;
  clean-full)    "$AI_DIR/korrinos-cleanup.sh" full ;;
  clean-cache)   "$AI_DIR/korrinos-cleanup.sh" cache ;;
  clean-disk)    "$AI_DIR/korrinos-cleanup.sh" disk ;;
  clean-optimize) "$AI_DIR/korrinos-cleanup.sh" optimize ;;

  # --- smooth UI (Mac-like) ---
  smoothui)      shift; "$AI_DIR/korrinos-smoothui.sh" "$@" ;;
  smooth-install) "$AI_DIR/korrinos-smoothui.sh" install ;;
  smooth-start)  "$AI_DIR/korrinos-smoothui.sh" start ;;
  smooth-stop)   "$AI_DIR/korrinos-smoothui.sh" stop ;;
  smooth-status) "$AI_DIR/korrinos-smoothui.sh" status ;;
  smooth-gestures) "$AI_DIR/korrinos-smoothui.sh" gestures ;;
  smooth-windows) "$AI_DIR/korrinos-smoothui.sh" window-management ;;
  smooth-anim)   shift; "$AI_DIR/korrinos-smoothui.sh" animation "$@" ;;

  # --- liquid glass glassmorphism ---
  liquid-glass)  shift; "$AI_DIR/korrinos-liquid-glass.sh" "$@" ;;
  glass-start)   "$AI_DIR/korrinos-liquid-glass.sh" start ;;
  glass-stop)    "$AI_DIR/korrinos-liquid-glass.sh" stop ;;
  glass-status)  "$AI_DIR/korrinos-liquid-glass.sh" status ;;
  glass-preset)  shift; "$AI_DIR/korrinos-liquid-glass.sh" preset "$@" ;;
  glass-set)     shift; "$AI_DIR/korrinos-liquid-glass.sh" set "$@" ;;

  # --- widgets panel (conky) ---
  widgets-panel) shift; "$AI_DIR/korrinos-widgets-panel.sh" "$@" ;;
  wp-start)      "$AI_DIR/korrinos-widgets-panel.sh" start ;;
  wp-stop)       "$AI_DIR/korrinos-widgets-panel.sh" stop ;;
  wp-toggle)     "$AI_DIR/korrinos-widgets-panel.sh" toggle ;;
  wp-status)     "$AI_DIR/korrinos-widgets-panel.sh" status ;;

  # --- notepad reminders ---
  notepad)       shift; "$AI_DIR/korrinos-notepad.sh" "$@" ;;
  note-add)      shift; "$AI_DIR/korrinos-notepad.sh" add "$@" ;;
  note-list)     "$AI_DIR/korrinos-notepad.sh" list ;;
  note-done)     shift; "$AI_DIR/korrinos-notepad.sh" done "$@" ;;
  note-delete)   shift; "$AI_DIR/korrinos-notepad.sh" delete "$@" ;;
  note-gui)      "$AI_DIR/korrinos-notepad.sh" gui ;;

  # --- dock ---
  dock)          shift; "$AI_DIR/korrinos-dock.sh" "$@" ;;
  dock-start)    "$AI_DIR/korrinos-dock.sh" start ;;
  dock-stop)     "$AI_DIR/korrinos-dock.sh" stop ;;
  dock-toggle)   "$AI_DIR/korrinos-dock.sh" toggle ;;
  dock-status)   "$AI_DIR/korrinos-dock.sh" status ;;

  # --- os/apps: app store & software ---
  app-store)     shift; "$AI_DIR/../apps/app-store.sh" "$@" ;;
  install)       shift; "$AI_DIR/../apps/app-store.sh" install "$@" ;;
  uninstall)     shift; "$AI_DIR/../apps/app-store.sh" uninstall "$@" ;;
  software)      shift; "$AI_DIR/../apps/software-center.sh" "$@" ;;
  pkg)           shift; "$AI_DIR/../apps/package-manager.sh" "$@" ;;

  # --- os/apps: battery & power ---
  battery)       shift; "$AI_DIR/../apps/battery-monitor.sh" "$@" ;;

  # --- os/apps: clipboard ---
  clipboard)     shift; "$AI_DIR/../apps/smart-clipboard.sh" "$@" ;;
  clip)          shift; "$AI_DIR/../apps/smart-clipboard.sh" "$@" ;;

  # --- os/apps: ocr ---
  ocr)           shift; "$AI_DIR/../apps/ocr-everywhere.sh" "$@" ;;

  # --- os/apps: notes ---
  note)          shift; "$AI_DIR/../apps/quick-note.sh" "$@" ;;
  quicknote)     shift; "$AI_DIR/../apps/quick-note.sh" "$@" ;;

  # --- os/apps: screen recording ---
  record)        shift; "$AI_DIR/../apps/screen-recorder.sh" "$@" ;;
  screencast)    shift; "$AI_DIR/../apps/screen-recorder.sh" "$@" ;;

  # --- os/apps: voice commands ---
  voicecmd)      shift; "$AI_DIR/../apps/voice-commands.sh" "$@" ;;

  # --- os/apps: file manager ---
  files)         shift; "$AI_DIR/../apps/file-manager.sh" "$@" ;;
  fm)            shift; "$AI_DIR/../apps/file-manager.sh" "$@" ;;

  # --- os/apps: system cleaner ---
  cleaner)       shift; "$AI_DIR/../apps/system-cleaner.sh" "$@" ;;

  # --- os/apps: gaming ---
  game-mode)     shift; "$AI_DIR/../apps/gaming-mode.sh" "$@" ;;
  game-support)  shift; "$AI_DIR/../apps/gaming-support.sh" "$@" ;;
  fps)           shift; "$AI_DIR/../apps/gaming/fps-monitor.sh" "$@" ;;
  game-launcher) shift; "$AI_DIR/../apps/gaming/game-launcher.sh" "$@" ;;
  game-replay)   shift; "$AI_DIR/../apps/gaming/game-replay.sh" "$@" ;;
  game-saves)    shift; "$AI_DIR/../apps/gaming/game-saves-sync.sh" "$@" ;;
  controller)    shift; "$AI_DIR/../apps/gaming/controller-mapper.sh" "$@" ;;
  emulator)      shift; "$AI_DIR/../apps/gaming/emulator-manager.sh" "$@" ;;
  wine)          shift; "$AI_DIR/../apps/gaming/wine-manager.sh" "$@" ;;
  benchmark)     shift; "$AI_DIR/../apps/gaming/hardware-benchmark.sh" "$@" ;;
  game-gif)      shift; "$AI_DIR/../apps/gaming/gif-recorder.sh" "$@" ;;
  game-stream)   shift; "$AI_DIR/../apps/gaming/streaming-manager.sh" "$@" ;;
  game-perf)     shift; "$AI_DIR/../apps/gaming/performance-graph.sh" "$@" ;;
  game-screenshot) shift; "$AI_DIR/../apps/gaming/screenshot-tool.sh" "$@" ;;
  anticheat)     shift; "$AI_DIR/../apps/gaming/anticheat-helper.sh" "$@" ;;
  game-audio)    shift; "$AI_DIR/../apps/gaming/audio-mixer.sh" "$@" ;;
  discord)       shift; "$AI_DIR/../apps/gaming/discord-presence.sh" "$@" ;;

  # --- os/apps: customization ---
  theme)         shift; "$AI_DIR/../apps/customization/gtk-theme.sh" "$@" ;;
  gtk-theme)     shift; "$AI_DIR/../apps/customization/gtk-theme.sh" "$@" ;;
  qt-theme)      shift; "$AI_DIR/../apps/customization/qt-theme.sh" "$@" ;;
  icon-pack)     shift; "$AI_DIR/../apps/customization/icon-packs.sh" "$@" ;;
  cursor)        shift; "$AI_DIR/../apps/customization/cursor-themes.sh" "$@" ;;
  shell-theme)   shift; "$AI_DIR/../apps/customization/shell-theme.sh" "$@" ;;
  font)          shift; "$AI_DIR/../apps/customization/font-manager.sh" "$@" ;;
  wallpaper)     shift; "$AI_DIR/../apps/customization/wallpaper-manager.sh" "$@" ;;
  effects)       shift; "$AI_DIR/../apps/customization/desktop-effects.sh" "$@" ;;
  animations)    shift; "$AI_DIR/../apps/customization/window-animations.sh" "$@" ;;
  login-theme)   shift; "$AI_DIR/../apps/customization/login-theme.sh" "$@" ;;
  grub-theme)    shift; "$AI_DIR/../apps/customization/grub-theme.sh" "$@" ;;
  conky)         shift; "$AI_DIR/../apps/customization/conky-stats.sh" "$@" ;;

  # --- os/apps: hardware ---
  display)       shift; "$AI_DIR/../apps/hardware/display-calibration.sh" "$@" ;;
  hdr)           shift; "$AI_DIR/../apps/hardware/hdr-manager.sh" "$@" ;;
  fingerprint)   shift; "$AI_DIR/../apps/hardware/fingerprint-manager.sh" "$@" ;;
  gpio)          shift; "$AI_DIR/../apps/hardware/gpio-manager.sh" "$@" ;;
  nfc)           shift; "$AI_DIR/../apps/hardware/nfc-manager.sh" "$@" ;;
  serial)        shift; "$AI_DIR/../apps/hardware/serial-uart.sh" "$@" ;;
  usb-dev)       shift; "$AI_DIR/../apps/hardware/usb-manager.sh" "$@" ;;
  webcam)        shift; "$AI_DIR/../apps/hardware/webcam-manager.sh" "$@" ;;
  printer)       shift; "$AI_DIR/../apps/hardware/printer-manager.sh" "$@" ;;
  scanner)       shift; "$AI_DIR/../apps/hardware/scanner-manager.sh" "$@" ;;
  docking)       shift; "$AI_DIR/../apps/hardware/docking-station.sh" "$@" ;;
  kvm)           shift; "$AI_DIR/../apps/hardware/kvm-switch.sh" "$@" ;;
  thunderbolt)   shift; "$AI_DIR/../apps/hardware/thunderbolt-manager.sh" "$@" ;;
  touchscreen)   shift; "$AI_DIR/../apps/hardware/touchscreen-manager.sh" "$@" ;;
  stylus)        shift; "$AI_DIR/../apps/hardware/pen-stylus.sh" "$@" ;;

  # --- os/apps: network ---
  bandwidth)     shift; "$AI_DIR/../apps/network/bandwidth-limiter.sh" "$@" ;;
  dns)           shift; "$AI_DIR/../apps/network/dns-manager.sh" "$@" ;;
  fw-gui)        shift; "$AI_DIR/../apps/network/firewall-gui.sh" "$@" ;;
  hotspot)       shift; "$AI_DIR/../apps/network/hotspot-manager.sh" "$@" ;;
  mesh)          shift; "$AI_DIR/../apps/network/mesh-network.sh" "$@" ;;
  netmon)        shift; "$AI_DIR/../apps/network/network-monitor.sh" "$@" ;;
  proxy)         shift; "$AI_DIR/../apps/network/proxy-manager.sh" "$@" ;;
  speedtest)     shift; "$AI_DIR/../apps/network/speed-test.sh" "$@" ;;
  vpn)           shift; "$AI_DIR/../apps/network/vpn-manager.sh" "$@" ;;
  wifi)          shift; "$AI_DIR/../apps/network/wifi-analyzer.sh" "$@" ;;

  # --- os/apps: security ---
  bio)           shift; "$AI_DIR/../apps/security/biometric.sh" "$@" ;;
  vault)         shift; "$AI_DIR/../apps/security/filevault.sh" "$@" ;;
  findmy)        shift; "$AI_DIR/../apps/security/findmydevice.sh" "$@" ;;
  fw)            shift; "$AI_DIR/../apps/security/firewall.sh" "$@" ;;
  gatekeeper)    shift; "$AI_DIR/../apps/security/gatekeeper.sh" "$@" ;;
  passman)       shift; "$AI_DIR/../apps/security/password-manager.sh" "$@" ;;
  privacy)       shift; "$AI_DIR/../apps/security/privacy.sh" "$@" ;;
  sec-suite)     shift; "$AI_DIR/../apps/security/security-suite.sh" "$@" ;;

  # --- os/apps: system tools ---
  cmd-palette)   shift; "$AI_DIR/../apps/system/command-palette.sh" "$@" ;;
  disk-viz)      shift; "$AI_DIR/../apps/system/disk-visualizer.sh" "$@" ;;
  dupes)         shift; "$AI_DIR/../apps/system/duplicate-finder.sh" "$@" ;;
  focus-app)     shift; "$AI_DIR/../apps/system/focus-mode.sh" "$@" ;;
  search)        shift; "$AI_DIR/../apps/system/global-search.sh" "$@" ;;
  intent)        shift; "$AI_DIR/../apps/system/intent-launcher.sh" "$@" ;;
  json)          shift; "$AI_DIR/../apps/system/json-formatter.sh" "$@" ;;
  markdown)      shift; "$AI_DIR/../apps/system/markdown-editor.sh" "$@" ;;
  parental)      shift; "$AI_DIR/../apps/system/parental-controls.sh" "$@" ;;
  pomodoro)      shift; "$AI_DIR/../apps/system/pomodoro-timer.sh" "$@" ;;
  regex)         shift; "$AI_DIR/../apps/system/regex-tool.sh" "$@" ;;
  screen-time)   shift; "$AI_DIR/../apps/system/screen-time.sh" "$@" ;;
  time-tracker)  shift; "$AI_DIR/../apps/system/time-tracker.sh" "$@" ;;
  terminal-explain) shift; "$AI_DIR/../apps/system/terminal-error-explainer.sh" "$@" ;;
  drag-install)  shift; "$AI_DIR/../apps/system/drag-to-install.sh" "$@" ;;
  file-version)  shift; "$AI_DIR/../apps/system/file-versioning.sh" "$@" ;;
  cognitive)     shift; "$AI_DIR/../apps/system/cognitive-load.sh" "$@" ;;
  context)       shift; "$AI_DIR/../apps/system/context-aware.sh" "$@" ;;
  digital-twin)  shift; "$AI_DIR/../apps/system/digital-twin.sh" "$@" ;;
  self-heal)     shift; "$AI_DIR/../apps/system/self-healing.sh" "$@" ;;
  predictive)    shift; "$AI_DIR/../apps/system/predictive-intelligence.sh" "$@" ;;
  precache)      shift; "$AI_DIR/../apps/system/predictive-caching.sh" "$@" ;;
  temporal)      shift; "$AI_DIR/../apps/system/temporal-mapping.sh" "$@" ;;
  rollback)      shift; "$AI_DIR/../apps/system/rollback-recovery.sh" "$@" ;;
  auto-update)   shift; "$AI_DIR/../apps/system/auto-updates.sh" "$@" ;;
  quick-actions) shift; "$AI_DIR/../apps/system/quick-actions.sh" "$@" ;;
  adaptive-power) shift; "$AI_DIR/../apps/system/adaptive-power-grid.sh" "$@" ;;

  # --- os/apps: aether workspace ---
  aether)        shift; "$AI_DIR/../apps/apps/aether-workspace.sh" "$@" ;;

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
  local dir="${TINKER_AI_HOME:-$HOME/.config/tinkeria}/reminders"
  mkdir -p "$dir"
  cat > "$dir/$id.json" <<EOJSON
{"id":"$id","message":"$msg","when":"$when","created":"$(date -Iseconds)","status":"pending"}
EOJSON
  echo "Reminder set: $msg — $when"
}

cmd_reminders() {
  local dir="${TINKER_AI_HOME:-$HOME/.config/tinkeria}/reminders"
  mkdir -p "$dir"
  echo "=== Pending Reminders ==="
  local found=0
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    local msg when status
    msg=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['message'])" "$f" 2>/dev/null)
    when=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['when'])" "$f" 2>/dev/null)
    status=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['status'])" "$f" 2>/dev/null)
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


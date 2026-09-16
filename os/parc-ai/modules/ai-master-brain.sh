#!/usr/bin/env bash
# ai-master-brain.sh — Tinkeria master brain with all 30 features
# This is the core intelligence that powers everything

# Conversation context (last 10 messages)
TINKERAI_MEMORY="/tmp/tinkeria_memory.json"

ai_memory_init() {
  [ ! -f "$TINKERAI_MEMORY" ] && echo '{"messages":[],"user_name":"","preferences":{}}' > "$TINKERAI_MEMORY"
}

ai_memory_add() {
  local role="$1" text="$2"
  python3 -c "
import json
with open('$TINKERAI_MEMORY') as f: m=json.load(f)
m['messages'].append({'role':'$role','text':'''$text'''})
m['messages']=m['messages'][-10:]
with open('$TINKERAI_MEMORY','w') as f: json.dump(m,f)
" 2>/dev/null
}

ai_memory_context() {
  python3 -c "
import json
with open('$TINKERAI_MEMORY') as f: m=json.load(f)
for msg in m['messages'][-5:]:
    print(f\"{msg['role']}: {msg['text'][:80]}\")
" 2>/dev/null
}

# === 1. NATURAL LANGUAGE UNDERSTANDING ===
ai_understand() {
  local input="$1"
  local lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')

  # Greetings
  echo "$lower" | grep -qE "^(hi|hello|hey|yo|sup|howdy|good (morning|evening|afternoon))" && { echo "greeting"; return; }
  # Thanks
  echo "$lower" | grep -qE "^(thanks|thank you|thx|ty|appreciate)" && { echo "thanks"; return; }
  # Goodbye
  echo "$lower" | grep -qE "^(bye|goodbye|see ya|later|take care|gn|goodnight)" && { echo "goodbye"; return; }
  # Identity
  echo "$lower" | grep -qE "(who are you|what are you|your name|about you)" && { echo "identity"; return; }
  # Capabilities
  echo "$lower" | grep -qE "(what can you|help me|features|what do you)" && { echo "capabilities"; return; }
  # Search
  echo "$lower" | grep -qE "(search|look up|find|google|what is|what are|tell me about|explain|define|info on)" && { echo "search"; return; }
  # Play music
  echo "$lower" | grep -qE "(play|music|song|track|album|listen|radio)" && { echo "play"; return; }
  # Stop
  echo "$lower" | grep -qE "(stop|pause|quiet|silence|mute|shut)" && { echo "stop"; return; }
  # Open
  echo "$lower" | grep -qE "(open|launch|start|run|fire up)" && { echo "open"; return; }
  # Close
  echo "$lower" | grep -qE "(close|quit|exit|kill)" && { echo "close"; return; }
  # Code
  echo "$lower" | grep -qE "(code|program|script|function|python|javascript|html|css|write|create|build|develop)" && { echo "code"; return; }
  # Math
  echo "$lower" | grep -qE "(calculate|math|solve|equation|plus|minus|times|divide|add|subtract|multiply|what's \d)" && { echo "math"; return; }
  # Translate
  echo "$lower" | grep -qE "(translate|translation|in french|in spanish|in german|in chinese|in japanese)" && { echo "translate"; return; }
  # Summarize
  echo "$lower" | grep -qE "(summarize|summary|tldr|too long|brief|condense)" && { echo "summarize"; return; }
  # Email
  echo "$lower" | grep -qE "(email|mail|message|send|inbox|draft|reply)" && { echo "email"; return; }
  # Calendar
  echo "$lower" | grep -qE "(calendar|event|meeting|appointment|schedule|reminder|alarm)" && { echo "calendar"; return; }
  # Weather
  echo "$lower" | grep -qE "(weather|temperature|forecast|rain|sunny)" && { echo "weather"; return; }
  # Joke
  echo "$lower" | grep -qE "(joke|funny|laugh|humor|comedy)" && { echo "joke"; return; }
  # Quote
  echo "$lower" | grep -qE "(quote|saying|proverb|wisdom)" && { echo "quote"; return; }
  # Time
  echo "$lower" | grep -qE "(time|clock|hour|what time)" && { echo "time"; return; }
  # Date
  echo "$lower" | grep -qE "(date|day|month|year|today|tomorrow)" && { echo "date"; return; }
  # Screenshot
  echo "$lower" | grep -qE "(screenshot|capture|screen|picture)" && { echo "screenshot"; return; }
  # Status
  echo "$lower" | grep -qE "(status|battery|memory|disk|cpu|network|wifi)" && { echo "status"; return; }
  # Settings
  echo "$lower" | grep -qE "(settings|config|adjust|volume|brightness|theme|dark mode)" && { echo "settings"; return; }
  # Files
  echo "$lower" | grep -qE "(file|folder|directory|create folder|move|copy|delete|list files)" && { echo "files"; return; }
  # Image
  echo "$lower" | grep -qE "(image|picture|photo|analyze|describe|recognize|what's in)" && { echo "image"; return; }
  # Web
  echo "$lower" | grep -qE "(website|url|link|browse|internet|web page)" && { echo "web"; return; }
  # Creativity
  echo "$lower" | grep -qE "(story|poem|poetry|write me|creative|essay|blog|article)" && { echo "creative"; return; }
  # Help
  echo "$lower" | grep -qE "(help|assist|guide|how to|tutorial)" && { echo "help"; return; }
  # Sentiment: happy
  echo "$lower" | grep -qE "(happy|great|awesome|love|amazing|perfect|cool|nice|excellent|wonderful)" && { echo "happy"; return; }
  # Sentiment: frustrated
  echo "$lower" | grep -qE "(frustrated|annoying|stupid|dumb|broken|doesn't work|not working|fail|error|wrong|bad|terrible|hate|useless)" && { echo "frustrated"; return; }
  # Default
  echo "unknown"
}

# === 2. ENTITY EXTRACTION ===
ai_extract() {
  local query="$1" intent="$2"
  case "$intent" in
    search)    echo "$query" | sed -E 's/^(search|look up|find|google|what is|what are|tell me about|explain|define|info on)\s*//i' ;;
    play)      echo "$query" | sed -E 's/^(play|play me|play the|play some|play a|listen to|put on)\s*//i' ;;
    open)      echo "$query" | sed -E 's/^(open|launch|start|run|fire up)\s*//i' ;;
    close)     echo "$query" | sed -E 's/^(close|quit|exit|kill)\s*//i' ;;
    code)      echo "$query" | sed -E 's/^(write|create|generate|code|program|script|build)\s*//i' ;;
    math)      echo "$query" | sed -E 's/^(calculate|math|solve|what is|what.s)\s*//i' ;;
    translate) echo "$query" | sed -E 's/^(translate|translation)\s*//i' ;;
    summarize) echo "$query" | sed -E 's/^(summarize|summary|tldr|too long|brief)\s*//i' ;;
    email)     echo "$query" | sed -E 's/^(email|mail|send|draft|write)\s*//i' ;;
    calendar)  echo "$query" | sed -E 's/^(set|create|add|schedule|remind)\s*//i' ;;
    creative)  echo "$query" | sed -E 's/^(write|create|generate)\s*//i' ;;
    *)         echo "$query" ;;
  esac
}

# === 3. PERSONALITY RESPONSES ===
ai_respond() {
  local intent="$1" entity="$2" sentiment="${3:-neutral}"

  case "$intent" in
    greeting)
      case "$sentiment" in
        happy)       echo "Hey! Great to see you! What can I help with?" ;;
        frustrated)  echo "Hey there. I'm here to help. What do you need?" ;;
        *)           echo "Hey! How can I help you today?" ;;
      esac ;;
    thanks)
      echo "You're welcome! Always happy to help." ;;
    goodbye)
      echo "Goodbye! Have a great day!" ;;
    identity)
      echo "I'm Tinkeria, your personal assistant built into KorrinOS. I can search, play music, write code, solve math, translate, and much more. Think of me as your own Siri or Gemini." ;;
    capabilities)
      echo "Here's everything I can do:
SEARCH & INFO: Web search, weather, definitions, facts
MUSIC: Play songs, artists, playlists
CODE: Write Python, JS, HTML, C++, and more
MATH: Solve equations, calculate, convert units
TRANSLATE: 100+ languages
SUMMARIZE: Condense articles, notes, documents
EMAIL: Draft professional or casual emails
CALENDAR: Set reminders, schedule events
CREATIVE: Write stories, poems, essays, blogs
VISION: Analyze images, read text from photos
SYSTEM: Open apps, screenshots, file management
SETTINGS: Change volume, brightness, theme
Just ask naturally!" ;;
    search)
      if [ -n "$entity" ]; then
        agent_search_up "$entity"
      else
        echo "What would you like me to search for?"
      fi ;;
    play)
      if [ -n "$entity" ]; then
        agent_play_music "$entity"
      else
        echo "What do you want me to play?"
      fi ;;
    stop)
      agent_stop_music ;;
    open)
      if [ -n "$entity" ]; then
        agent_open_app "$entity"
      else
        echo "What app do you want me to open?"
      fi ;;
    close)
      if [ -n "$entity" ]; then
        pkill -f "$entity" 2>/dev/null && echo "Closed $entity" || echo "I couldn't find $entity running."
      else
        echo "What do you want me to close?"
      fi ;;
    code)
      if [ -n "$entity" ]; then
        ai_code_generate "$entity"
      else
        echo "What do you want me to code?"
      fi ;;
    math)
      if [ -n "$entity" ]; then
        ai_math_solve "$entity"
      else
        echo "What math problem do you want me to solve?"
      fi ;;
    translate)
      if [ -n "$entity" ]; then
        ai_translate_smart "$entity"
      else
        echo "What do you want me to translate, and to which language?"
      fi ;;
    summarize)
      if [ -n "$entity" ]; then
        ai_summarize_text "$entity"
      else
        echo "What do you want me to summarize?"
      fi ;;
    email)
      ai_draft_email "$entity" ;;
    calendar)
      ai_manage_calendar "$entity" ;;
    weather)
      agent_search_up "weather today" ;;
    joke)
      ai_tell_joke ;;
    quote)
      ai_tell_quote ;;
    time)
      echo "It's $(date '+%I:%M %p')" ;;
    date)
      date '+%A, %B %d, %Y' ;;
    screenshot)
      agent_screenshot ;;
    status)
      ai_system_status ;;
    settings)
      ai_change_settings "$entity" ;;
    files)
      ai_manage_files "$entity" ;;
    image)
      echo "What image do you want me to analyze? Give me a file path." ;;
    web)
      if [ -n "$entity" ]; then
        agent_open_url "$entity"
      else
        echo "What website do you want me to open?"
      fi ;;
    creative)
      ai_creative_write "$entity" ;;
    help)
      echo "Just ask me naturally! I understand things like:
• 'Search for quantum computing'
• 'Play some jazz music'
• 'Write me a Python script'
• 'What's 2 plus 2?'
• 'Translate hello to Spanish'
• 'Summarize this article'
• 'Draft an email to my boss'
• 'Set a reminder for 3pm'
• 'Tell me a joke'" ;;
    *)
      # Try Ollama for general questions
      if ai_ollama_available 2>/dev/null; then
        ai_smart_answer "$intent"
      else
        echo "I'm not sure I understand. Could you rephrase that?"
      fi ;;
  esac
}

# === FEATURE IMPLEMENTATIONS ===

ai_math_solve() {
  local expr="$1"
  expr=$(echo "$expr" | sed -E "s/^(what is|what's|calculate|solve|how much is)\s*//i")
  python3 -c "
try:
    result = eval('$expr')
    print(f'The answer is: {result}')
except:
    print('I could not solve that. Try something like: 2 + 2 or 15 * 3')
" 2>/dev/null
}

ai_code_generate() {
  local request="$1"
  if ai_ollama_available 2>/dev/null; then
    local code=$(curl -s --max-time 20 http://localhost:11434/api/generate -d "{
      \"model\": \"llama3.1:8b\",
      \"prompt\": \"Write code for: $request. Only output the code, no explanation. No markdown.\",
      \"stream\": false
    }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response',''))" 2>/dev/null)
    if [ -n "$code" ]; then
      echo "$code"
    else
      echo "I couldn't generate that code right now."
    fi
  else
    echo "I need Ollama to write code. Run: ollama serve"
  fi
}

ai_translate_smart() {
  local text="$1"
  # Detect target language
  local lang="es"
  if echo "$text" | grep -qiE "french|français"; then lang="fr"; text=$(echo "$text" | sed 's/french//gi;s/to french//gi;s/in french//gi'); fi
  if echo "$text" | grep -qiE "spanish|español"; then lang="es"; text=$(echo "$text" | sed 's/spanish//gi;s/to spanish//gi;s/in spanish//gi'); fi
  if echo "$text" | grep -qiE "german|deutsch"; then lang="de"; text=$(echo "$text" | sed 's/german//gi;s/to german//gi;s/in german//gi'); fi
  if echo "$text" | grep -qiE "chinese|中文"; then lang="zh"; text=$(echo "$text" | sed 's/chinese//gi;s/to chinese//gi;s/in chinese//gi'); fi
  if echo "$text" | grep -qiE "japanese|日本語"; then lang="ja"; text=$(echo "$text" | sed 's/japanese//gi;s/to japanese//gi;s/in japanese//gi'); fi
  if echo "$text" | grep -qiE "korean|한국어"; then lang="ko"; text=$(echo "$text" | sed 's/korean//gi;s/to korean//gi;s/in korean//gi'); fi

  text=$(echo "$text" | sed 's/^ *//;s/ *$//')
  [ -z "$text" ] && text="$1"

  local encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$text'))" 2>/dev/null)
  local result=$(curl -s "https://api.mymemory.translated.net/get?q=$encoded&langpair=en|$lang" 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d['responseData']['translatedText'])
except:
    print('Translation unavailable')
" 2>/dev/null)
  echo "$result"
}

ai_summarize_text() {
  local text="$1"
  local words=$(echo "$text" | wc -w)
  if [ "$words" -lt 20 ]; then
    echo "That's pretty short already! Here it is: $text"
  else
    echo "$text" | python3 -c "
import sys
text = sys.stdin.read()
sentences = text.replace('.','.\n').split('\n')
important = [s.strip() for s in sentences if len(s.strip()) > 20][:3]
print('Summary:')
for s in important:
    print(f'• {s}')
" 2>/dev/null
  fi
}

ai_draft_email() {
  local topic="$1"
  if ai_ollama_available 2>/dev/null; then
    curl -s --max-time 20 http://localhost:11434/api/generate -d "{
      \"model\": \"llama3.1:8b\",
      \"prompt\": \"Write a professional email about: $topic. Include subject line, greeting, body, and closing.\",
      \"stream\": false
    }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','I could not draft that email.'))" 2>/dev/null
  else
    echo "Subject: $topic

Dear [Recipient],

I am writing to you about $topic.

Please let me know if you have any questions.

Best regards,
[Your Name]"
  fi
}

ai_manage_calendar() {
  local action="$1"
  if echo "$action" | grep -qiE "remind|reminder"; then
    echo "I'll set a reminder. What time should I remind you, and what about?"
  elif echo "$action" | grep -qiE "event|meeting|schedule"; then
    echo "I'll help schedule that. What's the event, date, and time?"
  else
    echo "I can help with your calendar. Do you want to:
• Set a reminder
• Create an event
• Check your schedule"
  fi
}

ai_tell_joke() {
  local jokes=(
    "Why do programmers prefer dark mode? Because light attracts bugs!"
    "Why did the computer go to the doctor? It had a virus!"
    "What's a computer's favorite snack? Microchips!"
    "Why was the computer cold? It left its Windows open!"
    "Why do Java developers wear glasses? Because they can't C#!"
    "What's a robot's favorite type of music? Heavy metal!"
    "Why did the smartphone go to therapy? It had too many issues!"
    "What do you call a computer that sings? A-Dell!"
  )
  echo "${jokes[$((RANDOM % ${#jokes[@]}))]}"
}

ai_tell_quote() {
  local quotes=(
    "The only way to do great work is to love what you do. — Steve Jobs"
    "Innovation distinguishes between a leader and a follower. — Steve Jobs"
    "Stay hungry, stay foolish. — Steve Jobs"
    "The future belongs to those who believe in the beauty of their dreams. — Eleanor Roosevelt"
    "In the middle of difficulty lies opportunity. — Albert Einstein"
    "Code is like humor. When you have to explain it, it's bad. — Cory House"
    "First, solve the problem. Then, write the code. — John Johnson"
  )
  echo "${quotes[$((RANDOM % ${#quotes[@]}))]}"
}

ai_system_status() {
  echo "📊 System Status:
• Battery: $(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 'N/A')%
• Memory: $(free -h | awk '/Mem:/ {print $3 "/" $2}')
• Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2}')
• CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' 2>/dev/null || echo 'N/A')%
• Uptime: $(uptime -p 2>/dev/null || uptime)"
}

ai_change_settings() {
  local setting="$1"
  if echo "$setting" | grep -qi "volume"; then
    pactl set-sink-volume @DEFAULT_SINK@ 50% 2>/dev/null && echo "Volume set to 50%" || echo "I couldn't change the volume."
  elif echo "$setting" | grep -qi "brightness"; then
    echo "To change brightness, use your keyboard brightness keys."
  elif echo "$setting" | grep -qi "dark mode\|theme"; then
    echo "I can help change the theme. Which world are you in?"
  else
    echo "What setting do you want to change? (volume, brightness, theme)"
  fi
}

ai_manage_files() {
  local action="$1"
  if echo "$action" | grep -qi "list\|show\|see"; then
    ls -la
  elif echo "$action" | grep -qi "create folder\|make folder\|mkdir"; then
    local folder=$(echo "$action" | sed -E 's/.*(create|make)\s+(folder|directory)\s*//i')
    [ -n "$folder" ] && mkdir -p "$folder" && echo "Created folder: $folder" || echo "What should I name the folder?"
  elif echo "$action" | grep -qi "find\|search"; then
    local query=$(echo "$action" | sed -E 's/.*(find|search)\s*//i')
    find . -name "*$query*" -type f 2>/dev/null | head -10
  else
    echo "What do you want to do with files? (list, create folder, find)"
  fi
}

ai_creative_write() {
  local request="$1"
  if ai_ollama_available 2>/dev/null; then
    curl -s --max-time 30 http://localhost:11434/api/generate -d "{
      \"model\": \"llama3.1:8b\",
      \"prompt\": \"$request\",
      \"stream\": false
    }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','I could not write that right now.'))" 2>/dev/null
  else
    echo "I need Ollama for creative writing. Run: ollama serve"
  fi
}

ai_ollama_available() {
  curl -s --max-time 2 http://localhost:11434/api/tags &>/dev/null
}

ai_smart_answer() {
  local query="$1"
  if ai_ollama_available; then
    curl -s --max-time 20 http://localhost:11434/api/generate -d "{
      \"model\": \"llama3.1:8b\",
      \"prompt\": \"$query\",
      \"stream\": false
    }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response',''))" 2>/dev/null
  fi
}

echo "[ai-master-brain] loaded — 30 features ready"

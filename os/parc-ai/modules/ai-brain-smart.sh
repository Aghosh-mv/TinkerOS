#!/usr/bin/env bash
# ai-brain-smart.sh — Smart NLU that handles all 30 features

# Smart intent detection with context
ai_intent_smart() {
  local query="$1"
  local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
  
  # Check context for references
  local context=$(ai_context_get 2>/dev/null)
  local has_context=$(echo "$context" | python3 -c "import sys,json; ctx=json.load(sys.stdin); print(len(ctx)>0)" 2>/dev/null)
  
  # If query references previous context
  if [ "$has_context" = "True" ]; then
    if echo "$query_lower" | grep -qiE "it|that|this|the same|more|again|another"; then
      echo "context_reference"
      return
    fi
  fi
  
  # Greeting
  if echo "$query_lower" | grep -qiE "^(hi|hello|hey|good morning|good evening|what's up|howdy|yo|sup)"; then
    echo "greeting"
    return
  fi
  
  # Thanks
  if echo "$query_lower" | grep -qiE "^(thanks|thank you|appreciate it|thx|ty)"; then
    echo "thanks"
    return
  fi
  
  # Goodbye
  if echo "$query_lower" | grep -qiE "^(bye|goodbye|see you|later|take care|goodnight)"; then
    echo "goodbye"
    return
  fi
  
  # Identity
  if echo "$query_lower" | grep -qiE "who are you|what are you|your name|tell me about yourself|what do you do"; then
    echo "identity"
    return
  fi
  
  # Capabilities
  if echo "$query_lower" | grep -qiE "what can you do|help me|your features|what do you know|how do you work"; then
    echo "capabilities"
    return
  fi
  
  # Search
  if echo "$query_lower" | grep -qiE "search|look up|find|google|what is|what are|tell me about|explain|define"; then
    echo "search"
    return
  fi
  
  # Play music
  if echo "$query_lower" | grep -qiE "play|music|song|track|album|artist|listen|radio"; then
    echo "play"
    return
  fi
  
  # Stop music
  if echo "$query_lower" | grep -qiE "stop|pause|quiet|silence|shut up|mute"; then
    echo "stop"
    return
  fi
  
  # Open app
  if echo "$query_lower" | grep -qiE "open|launch|start|run|fire up"; then
    echo "open"
    return
  fi
  
  # Close app
  if echo "$query_lower" | grep -qiE "close|quit|exit|kill|shut down"; then
    echo "close"
    return
  fi
  
  # Code
  if echo "$query_lower" | grep -qiE "code|program|script|function|python|javascript|html|css|write|create|build"; then
    echo "code"
    return
  fi
  
  # Math
  if echo "$query_lower" | grep -qiE "calculate|math|solve|equation|plus|minus|times|divide|add|subtract|multiply"; then
    echo "math"
    return
  fi
  
  # Translate
  if echo "$query_lower" | grep -qiE "translate|translation|language|french|spanish|german|chinese|japanese|korean"; then
    echo "translate"
    return
  fi
  
  # Summarize
  if echo "$query_lower" | grep -qiE "summarize|summary|tldr|too long|brief|condense"; then
    echo "summarize"
    return
  fi
  
  # Email
  if echo "$query_lower" | grep -qiE "email|mail|message|send|inbox|draft"; then
    echo "email"
    return
  fi
  
  # Calendar
  if echo "$query_lower" | grep -qiE "calendar|event|meeting|appointment|schedule|reminder|alarm"; then
    echo "calendar"
    return
  fi
  
  # Weather
  if echo "$query_lower" | grep -qiE "weather|temperature|forecast|rain|sunny|cold|hot"; then
    echo "weather"
    return
  fi
  
  # Joke
  if echo "$query_lower" | grep -qiE "joke|funny|laugh|humor|comedy|hilarious"; then
    echo "joke"
    return
  fi
  
  # Quote
  if echo "$query_lower" | grep -qiE "quote|saying|proverb|wisdom|motto"; then
    echo "quote"
    return
  fi
  
  # Time
  if echo "$query_lower" | grep -qiE "time|clock|hour|minute|what time|current time"; then
    echo "time"
    return
  fi
  
  # Date
  if echo "$query_lower" | grep -qiE "date|day|month|year|today|tomorrow|yesterday"; then
    echo "date"
    return
  fi
  
  # Screenshot
  if echo "$query_lower" | grep -qiE "screenshot|capture|screen|picture|photo"; then
    echo "screenshot"
    return
  fi
  
  # Status
  if echo "$query_lower" | grep -qiE "status|health|battery|memory|disk|cpu|network|wifi"; then
    echo "status"
    return
  fi
  
  # Settings
  if echo "$query_lower" | grep -qiE "settings|config|change|adjust|volume|brightness|theme"; then
    echo "settings"
    return
  fi
  
  # File management
  if echo "$query_lower" | grep -qiE "file|folder|directory|create folder|move|copy|delete|list"; then
    echo "files"
    return
  fi
  
  # Image
  if echo "$query_lower" | grep -qiE "image|picture|photo|analyze|describe|recognize|what's in"; then
    echo "image"
    return
  fi
  
  # Web
  if echo "$query_lower" | grep -qiE "website|url|link|browse|internet|web"; then
    echo "web"
    return
  fi
  
  # Help
  if echo "$query_lower" | grep -qiE "help|assist|guide|how to|tutorial|explain"; then
    echo "help"
    return
  fi
  
  # Default to search
  echo "search"
}

# Extract entity from query
ai_extract_entity() {
  local query="$1"
  local intent="$2"
  
  case "$intent" in
    search)
      # Remove search prefixes
      echo "$query" | sed -E 's/^(search|look up|find|google|what is|what are|tell me about|explain|define)\s*//i'
      ;;
    play)
      # Remove play prefixes
      echo "$query" | sed -E 's/^(play|play me|play the|play some|play a|listen to|put on)\s*//i'
      ;;
    open)
      # Remove open prefixes
      echo "$query" | sed -E 's/^(open|launch|start|run|fire up)\s*//i'
      ;;
    translate)
      # Extract target language
      local lang=$(echo "$query" | grep -oE '(to|into|in)\s+\w+' | awk '{print $2}')
      local text=$(echo "$query" | sed -E 's/^(translate|translation)\s+//i' | sed -E "s/\s*(to|into|in)\s+\w+//i")
      echo "$lang|$text"
      ;;
    math)
      # Extract math expression
      echo "$query" | sed -E 's/^(calculate|math|solve|what is|what'\''s)\s*//i'
      ;;
    email)
      # Extract email details
      echo "$query"
      ;;
    calendar)
      # Extract event details
      echo "$query"
      ;;
    code)
      # Extract code request
      echo "$query" | sed -E 's/^(write|create|generate|code|program|script)\s*//i'
      ;;
    *)
      echo "$query"
      ;;
  esac
}

# Generate smart response
ai_generate_response() {
  local intent="$1"
  local entity="$2"
  local sentiment="${3:-neutral}"
  
  case "$intent" in
    greeting)
      case "$sentiment" in
        happy) echo "Hey! Great to see you! What can I help with?" ;;
        frustrated) echo "Hey there. I'm here to help. What do you need?" ;;
        *) echo "Hey! How can I help you today?" ;;
      esac
      ;;
    thanks)
      case "$sentiment" in
        happy) echo "You're welcome! Always happy to help!" ;;
        *) echo "You're welcome! Let me know if you need anything else." ;;
      esac
      ;;
    goodbye)
      echo "Goodbye! Have a great day!"
      ;;
    identity)
      echo "I'm TinkerAI, your personal assistant. I can help with search, music, code, math, translation, and much more!"
      ;;
    capabilities)
      echo "I can help with many things:
• Search the web
• Play music
• Write code
• Solve math
• Translate languages
• Summarize text
• Draft emails
• Manage calendar
• Take screenshots
• Open apps
• And much more!

Just ask naturally!"
      ;;
    search)
      if [ -n "$entity" ]; then
        agent_search_up "$entity"
      else
        echo "What would you like me to search for?"
      fi
      ;;
    play)
      if [ -n "$entity" ]; then
        agent_play_music "$entity"
      else
        echo "What do you want me to play?"
      fi
      ;;
    stop)
      agent_stop_music
      ;;
    open)
      if [ -n "$entity" ]; then
        agent_open_app "$entity"
      else
        echo "What app do you want me to open?"
      fi
      ;;
    code)
      if [ -n "$entity" ]; then
        echo "Let me write that code for you..."
        ai_code_generate "$entity"
      else
        echo "What do you want me to code?"
      fi
      ;;
    math)
      if [ -n "$entity" ]; then
        ai_math_solve "$entity"
      else
        echo "What math problem do you want me to solve?"
      fi
      ;;
    translate)
      if [ -n "$entity" ]; then
        local lang=$(echo "$entity" | cut -d'|' -f1)
        local text=$(echo "$entity" | cut -d'|' -f2)
        if [ -n "$lang" ] && [ -n "$text" ]; then
          ai_translate "$text" "$lang"
        else
          echo "What do you want me to translate, and to which language?"
        fi
      else
        echo "What do you want me to translate, and to which language?"
      fi
      ;;
    summarize)
      if [ -n "$entity" ]; then
        ai_summarize "$entity"
      else
        echo "What do you want me to summarize?"
      fi
      ;;
    email)
      echo "I can help draft an email. Who's it to and what's it about?"
      ;;
    calendar)
      echo "I can help with your calendar. Do you want to create an event or check your schedule?"
      ;;
    weather)
      agent_search_up "weather today"
      ;;
    joke)
      ai_tell_joke
      ;;
    quote)
      ai_tell_quote
      ;;
    time)
      echo "It's $(date '+%I:%M %p')"
      ;;
    date)
      date '+%A, %B %d, %Y'
      ;;
    screenshot)
      agent_screenshot
      ;;
    status)
      ai_system_status
      ;;
    settings)
      echo "What setting do you want to change?"
      ;;
    files)
      echo "What do you want to do with files?"
      ;;
    image)
      echo "What image do you want me to analyze?"
      ;;
    web)
      if [ -n "$entity" ]; then
        agent_open_url "$entity"
      else
        echo "What website do you want to open?"
      fi
      ;;
    help)
      echo "I'm here to help! Just tell me what you need naturally."
      ;;
    *)
      echo "I'm not sure I understand. Could you rephrase that?"
      ;;
  esac
}

# Math solver
ai_math_solve() {
  local expr="$1"
  # Remove "what is" prefix
  expr=$(echo "$expr" | sed -E "s/^(what is|what's|calculate|solve)\s*//i")
  
  # Try python evaluation
  local result=$(python3 -c "
import math
try:
    result = eval('$expr')
    print(result)
except:
    print('I could not solve that equation.')
" 2>/dev/null)
  
  echo "$result"
}

# Code generator
ai_code_generate() {
  local request="$1"
  echo "Let me write that code for you..."
  echo "Here's what I came up with:"
  echo ""
  # Use Ollama if available
  if command -v curl &>/dev/null; then
    curl -s http://localhost:11434/api/generate -d "{
      \"model\": \"llama3.1:8b\",
      \"prompt\": \"Write code for: $request. Only output the code, no explanation.\",
      \"stream\": false
    }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','Code generation unavailable'))" 2>/dev/null
  fi
}

# Translator
ai_translate() {
  local text="$1"
  local lang="$2"
  echo "Translating to $lang..."
  if command -v curl &>/dev/null; then
    curl -s "https://api.mymemory.translated.net/get?q=$text&langpair=en|$lang" 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d['responseData']['translatedText'])
except:
    print('Translation unavailable')
" 2>/dev/null
  fi
}

# Summarizer
ai_summarize() {
  local text="$1"
  echo "Here's a summary:"
  echo "$text" | fold -s -w 80 | head -5
}

# Joke teller
ai_tell_joke() {
  local jokes=(
    "Why do programmers prefer dark mode? Because light attracts bugs!"
    "Why did the computer go to the doctor? Because it had a virus!"
    "What's a computer's favorite snack? Microchips!"
    "Why was the computer cold? It left its Windows open!"
  )
  echo "${jokes[$((RANDOM % ${#jokes[@]}))]}"
}

# Quote teller
ai_tell_quote() {
  local quotes=(
    "The only way to do great work is to love what you do. - Steve Jobs"
    "Innovation distinguishes between a leader and a follower. - Steve Jobs"
    "Stay hungry, stay foolish. - Steve Jobs"
    "The future belongs to those who believe in the beauty of their dreams. - Eleanor Roosevelt"
  )
  echo "${quotes[$((RANDOM % ${#quotes[@]}))]}"
}

# System status
ai_system_status() {
  echo "System Status:"
  echo "• Battery: $(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 'N/A')%"
  echo "• Memory: $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
  echo "• Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2}')"
  echo "• CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
}

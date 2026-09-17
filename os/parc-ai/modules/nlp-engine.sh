#!/usr/bin/env bash
# nlp-engine.sh — NLP patterns, natural response generation, conversation flow
# Makes VOKK v4 talk like a real person, not a robot

# Natural response templates for common intents
nlp_respond() {
  local intent="$1" query="$2" context="${3:-}"
  
  case "$intent" in
    greeting)
      local greetings=(
        "Hey! What's up? How can I help?"
        "Hi there! What can I do for you?"
        "Hello! What would you like to know?"
        "Hey! I'm VOKK v4. Ask me anything."
        "Hi! What's on your mind?"
      )
      echo "${greetings[$((RANDOM % ${#greetings[@]}))]}"
      ;;
    farewell)
      local byes=(
        "See you later! Come back anytime."
        "Bye! Let me know if you need anything."
        "Take care! I'll be here when you need me."
        "Later! Feel free to ask me anything anytime."
      )
      echo "${byes[$((RANDOM % ${#byes[@]}))]}"
      ;;
    thanks)
      local thanks=(
        "You're welcome! Anything else?"
        "No problem! Happy to help."
        "Glad I could help! Need anything else?"
        "Anytime! That's what I'm here for."
      )
      echo "${thanks[$((RANDOM % ${#thanks[@]}))]}"
      ;;
    help_general)
      echo "I can help you with lots of stuff! Here are some things I can do:

- Answer any question (science, history, tech, whatever)
- Write code, emails, essays, or creative content
- Control your computer (open apps, take screenshots, manage files)
- Help with KorrinOS features and settings
- Set reminders and manage your contacts
- Search the web for information
- Translate between languages
- Do math and conversions
- And much more!

Just ask me anything — I'm here to help!"
      ;;
    how_are_you)
      local responses=(
        "I'm doing great, thanks for asking! How about you?"
        "Pretty good! Running smooth on this kernel. What can I help with?"
        "All systems go! What do you need?"
        "I'm awesome — ready to help with whatever you need!"
      )
      echo "${responses[$((RANDOM % ${#responses[@]}))]}"
      ;;
    identity)
      echo "I'm VOKK v4 — your built-in assistant for KorrinOS. I can answer questions, help you use your computer, write things, search for info, and lots more. Think of me as your friendly tech helper!"
      ;;
    os_help)
      local os_tips=(
        "KorrinOS has three worlds — Game Station for gaming, Hackerspace for coding, and Normal for everyday use. You can switch between them anytime."
        "You can search all your files instantly with Tab+F7 — that opens Searchie, your personal search engine."
        "Press Ctrl+Alt+Gr to open VOKK v4 anytime. Just ask me anything!"
        "The Control Center has over 224 tools. Open it with korrinos-control-center."
        "Game Mode automatically boosts performance when you start a game. It's enabled by default in the Game Station world."
        "Your files are indexed automatically. Use Tab+F7 to search through everything."
      )
      echo "${os_tips[$((RANDOM % ${#os_tips[@]}))]}"
      ;;
    cant_do)
      echo "I can't do that right now, but I can help you find another way. What are you trying to accomplish?"
      ;;
    confused)
      echo "I'm not quite sure what you mean. Could you rephrase that? I can help with questions about your computer, the KorrinOS features, or pretty much any topic."
      ;;
    *)
      echo ""
      ;;
  esac
}

# Detect if query is about KorrinOS specifically
nlp_is_os_question() {
  local query="${1,,}"
  [[ "$query" =~ (korrinos|tinker\s*os|our\s*os|this\s*os|the\s*os|operating\s*system|desktop|control\s*center|world|game\s*station|hackerspace) ]] && return 0
  return 1
}

# Detect if query is about the AI itself
nlp_is_self_question() {
  local query="${1,,}"
  [[ "$query" =~ (who\s+are\s+you|what\s+are\s+you|your\s+name|about\s+you|what\s+can\s+you|capabilities|what\s+do\s+you\s+know) ]] && return 0
  return 1
}

# Detect if query needs help with the computer
nlp_is_computer_help() {
  local query="${1,,}"
  [[ "$query" =~ (how\s+do\s+i|how\s+to|can\s+you\s+(open|launch|run|start|close|kill)|open\s+\w+|launch\s+\w+|where\s+is|my\s+(wifi|bluetooth|audio|screen|display)) ]] && return 0
  return 1
}

# Generate natural follow-up suggestions
nlp_suggest() {
  local intent="$1"
  case "$intent" in
    question)
      echo "Want me to explain that in more detail?"
      ;;
    os_help)
      echo "Want to know more about a specific feature?"
      ;;
    *)
      echo "Is there anything else I can help with?"
      ;;
  esac
}

# Format a natural response with proper capitalization and punctuation
nlp_format() {
  local text="$1"
  text=$(echo "$text" | sed 's/^\(.\)/\U\1/')
  [[ "$text" != *[.!?]$ ]] && [[ "$text" != *":"$ ]] && [[ "$text" != *"..."$ ]] && text="${text}."
  echo "$text"
}

# Multi-turn conversation: remember what we were talking about
NLP_TOPIC=""
NLP_LAST_QUERY=""
NLP_TURN_COUNT=0

nlp_context_update() {
  local query="$1"
  NLP_LAST_QUERY="$query"
  ((NLP_TURN_COUNT++))
  
  if ! nlp_is_os_question "$query" && ! nlp_is_self_question "$query"; then
    local words=$(echo "$query" | tr ' ' '\n' | head -5)
    NLP_TOPIC=$(echo "$words" | tail -1)
  fi
}

nlp_needs_clarification() {
  local query="$1"
  local len=${#query}
  
  [ "$len" -lt 3 ] && return 0
  
  [[ "$query" =~ ^what$ ]] && return 0
  [[ "$query" =~ ^how$ ]] && return 0
  [[ "$query" =~ ^why$ ]] && return 0
  
  local specials=$(echo "$query" | grep -oP '[^a-zA-Z0-9\s]' | wc -l)
  [ "$specials" -gt $((len / 3)) ] && return 0
  
  return 1
}

#!/usr/bin/env bash
# nlu.sh — intent detection, entity extraction, sentiment analysis
# Source this file; all functions prefixed with ai_nlu_

# Intent detection: classify user input into categories
# Input: raw text. Output: intent name
ai_nlu_intent() {
  local text
  text=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  # Greeting patterns
  if [[ "$text" =~ ^(hi|hello|hey|good\s*(morning|afternoon|evening)|howdy|sup|yo) ]]; then echo "greeting"; return; fi
  # Farewell
  if [[ "$text" =~ ^(bye|goodbye|see\s*ya|later|exit|quit) ]]; then echo "farewell"; return; fi
  # Question patterns
  if [[ "$text" =~ ^(what|who|where|when|why|how|which|can you|could you|would you|is there|are there|do you|does) ]]; then echo "question"; return; fi
  # Command patterns  
  if [[ "$text" =~ ^(open|launch|start|run|execute|play|show|hide|close|kill|stop) ]]; then echo "command"; return; fi
  # Creation patterns
  if [[ "$text" =~ ^(create|make|write|draft|generate|build|compose|design) ]]; then echo "create"; return; fi
  # Search patterns
  if [[ "$text" =~ ^(search|find|look|google|lookup|query|fetch) ]]; then echo "search"; return; fi
  # Reminder/schedule
  if [[ "$text" =~ ^(remind|schedule|set|add|create) ]] && [[ "$text" =~ (remind|reminder|alarm|timer|event|meeting|appointment|tomorrow|today|tonight) ]]; then echo "schedule"; return; fi
  # Code patterns
  if [[ "$text" =~ ^(code|program|function|script|debug|fix|compile|implement) ]]; then echo "code"; return; fi
  # Image/media
  if [[ "$text" =~ ^(image|photo|picture|draw|illustration|audio|voice|speech) ]]; then echo "media"; return; fi
  # Summarize
  if [[ "$text" =~ ^(summarize|summary|tldr|condense|shorten|brief) ]]; then echo "summarize"; return; fi
  # Translate
  if [[ "$text" =~ ^(translate|translation|convert.*language) ]]; then echo "translate"; return; fi
  # Math
  if [[ "$text" =~ ^(calculate|compute|solve|math|what\s+is\s+[0-9]) ]]; then echo "math"; return; fi
  # Settings/device
  if [[ "$text" =~ ^(set|toggle|adjust|change|configure|enable|disable) ]]; then echo "settings"; return; fi
  # Commerce
  if [[ "$text" =~ ^(buy|order|purchase|book|reserve|shop|price|cost) ]]; then echo "commerce"; return; fi
  # Help
  if [[ "$text" =~ ^(help|assist|support|what can you) ]]; then echo "help"; return; fi
  # Thank
  if [[ "$text" =~ ^(thanks|thank you|thx|appreciate) ]]; then echo "thanks"; return; fi
  echo "unknown"
}

# Entity extraction: pull out key pieces (names, dates, numbers, paths, urls)
ai_nlu_entities() {
  local text="$1"
  local entities=""
  # URLs
  local urls=$(echo "$text" | grep -oP 'https?://[^\s]+' | tr '\n' ',')
  [ -n "$urls" ] && entities+="urls:$urls;"
  # File paths
  local paths=$(echo "$text" | grep -oP '/[a-zA-Z0-9_./-]+' | tr '\n' ',')
  [ -n "$paths" ] && entities+="paths:$paths;"
  # Numbers
  local nums=$(echo "$text" | grep -oP '\b[0-9]+\.?[0-9]*\b' | tr '\n' ',')
  [ -n "$nums" ] && entities+="numbers:$nums;"
  # Quoted strings
  local quoted=$(echo "$text" | grep -oP '"[^"]*"' | tr '\n' ',')
  [ -n "$quoted" ] && entities+="quoted:$quoted;"
  # Time expressions
  if [[ "$text" =~ (tomorrow|today|next\s+(week|month|monday|tuesday|wednesday|thursday|friday|saturday|sunday)|in\s+[0-9]+\s+(minutes?|hours?|days?)) ]]; then
    entities+="time:$(echo "$text" | grep -oP '(tomorrow|today|next\s+\w+|in\s+[0-9]+\s+\w+)');"
  fi
  echo "$entities"
}

# Sentiment: positive/negative/neutral
ai_nlu_sentiment() {
  local text
  text=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  local pos=0 neg=0
  local positive_words=(good great awesome amazing love like best wonderful excellent happy pleased fantastic brilliant perfect beautiful nice sweet cool)
  local negative_words=(bad terrible awful hate dislike worst horrible ugly angry sad upset broken fail error wrong slow delete remove destroy)
  for w in "${positive_words[@]}"; do [[ "$text" == *"$w"* ]] && ((pos++)); done
  for w in "${negative_words[@]}"; do [[ "$text" == *"$w"* ]] && ((neg++)); done
  if [ "$pos" -gt "$neg" ]; then echo "positive"
  elif [ "$neg" -gt "$pos" ]; then echo "negative"
  else echo "neutral"; fi
}

# Extract the "action target" — what the user wants to act on
ai_nlu_target() {
  local text="$1"
  local intent="${2:-}"
  case "$intent" in
    command) echo "$text" | sed -E 's/^(open|launch|start|run|execute|play|show|hide|close|kill|stop)\s+//i' ;;
    create) echo "$text" | sed -E 's/^(create|make|write|draft|generate|build|compose|design)\s+(a\s+|an\s+|the\s+)?//i' ;;
    search) echo "$text" | sed -E 's/^(search|find|look|google|lookup|query|fetch)\s+(for\s+)?//i' ;;
    summarize) echo "$text" | sed -E 's/^(summarize|summary|tldr|condense|shorten|brief)\s+(the\s+|this\s+|a\s+)?//i' ;;
    *) echo "$text" ;;
  esac
}

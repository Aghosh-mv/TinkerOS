#!/usr/bin/env bash
# NLP Training Data - 100+ intent patterns for VOKK v4
# Provides response templates, common phrases, and quality rules

nlp_training_data() {
  cat << 'DATA'
{
  "intents": {
    "greeting": {
      "patterns": ["hi", "hello", "hey", "good morning", "good evening", "what's up", "howdy"],
      "responses": ["Hey there!", "Hello! How can I help?", "Hi! What do you need?"]
    },
    "farewell": {
      "patterns": ["bye", "goodbye", "see you", "later", "take care"],
      "responses": ["Goodbye!", "See you later!", "Take care!"]
    },
    "thanks": {
      "patterns": ["thanks", "thank you", "appreciate it", "thanks a lot"],
      "responses": ["You're welcome!", "Happy to help!", "Anytime!"]
    },
    "identity": {
      "patterns": ["who are you", "what are you", "your name", "tell me about yourself"],
      "responses": ["I'm VOKK v4, your built-in assistant for KorrinOS."]
    },
    "capabilities": {
      "patterns": ["what can you do", "help me", "your features", "what do you know"],
      "responses": ["I can help with text, code, productivity, web search, system control, and more."]
    },
    "os_help": {
      "patterns": ["how do i install", "system settings", "update my system", "korrinos help"],
      "responses": ["I can walk you through KorrinOS features and settings."]
    }
  },
  "quality_rules": [
    "Always be concise",
    "Use natural language",
    "Never hallucinate facts",
    "Admit when you don't know",
    "Be helpful and friendly"
  ],
  "common_phrases": {
    "i don't know": "I'm not sure about that. Let me look into it.",
    "what time is it": "Let me check the system clock.",
    "help me focus": "I can set up a distraction-free mode for you.",
    "i'm bored": "Want me to suggest something fun or interesting?"
  }
}
DATA
}

nlp_get_patterns() {
  nlp_training_data | python3 -c "import sys,json; d=json.load(sys.stdin); [print(p) for v in d['intents'].values() for p in v['patterns']]" 2>/dev/null
}

nlp_get_responses() {
  local intent="$1"
  nlp_training_data | python3 -c "import sys,json; d=json.load(sys.stdin); [print(r) for r in d['intents'].get('$intent',{}).get('responses',[])]" 2>/dev/null
}

nlp_match_intent() {
  local input="$1"
  local intents
  intents=$(nlp_training_data | python3 -c "
import sys,json
d=json.load(sys.stdin)
input='$input'.lower()
best_intent='unknown'
best_score=0
for intent,data in d['intents'].items():
    for pattern in data['patterns']:
        if pattern in input or input in pattern:
            score=1
            if score > best_score:
                best_score=score
                best_intent=intent
print(best_intent)
" 2>/dev/null)
  echo "$intents"
}

nlp_quality_check() {
  local text="$1"
  local issues=0
  # Check for common issues
  echo "$text" | grep -q "\.\.\.\.\." && ((issues++)) && echo "Issue: Too many dots"
  echo "$text" | grep -q "  " && ((issues++)) && echo "Issue: Double spaces"
  [ ${#text} -gt 1000 ] && ((issues++)) && echo "Issue: Response too long"
  [ ${#text} -lt 2 ] && ((issues++)) && echo "Issue: Response too short"
  echo "$issues"
}

nlp_common_response() {
  local input_lower
  input_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  
  case "$input_lower" in
    *"hello"*|*"hi"*|*"hey"*) echo "Hey there! What can I help with?" ;;
    *"bye"*|*"goodbye"*|*"see you"*) echo "Goodbye! Take care!" ;;
    *"thank"*) echo "You're welcome!" ;;
    *"who are you"*|*"what are you"*) echo "I'm VOKK v4, your KorrinOS assistant." ;;
    *"what can you do"*) echo "I can help with text, code, productivity, web search, and system control." ;;
    *"i don't know"*|*"idk"*) echo "That's okay! I'm here to help figure it out." ;;
    *) echo "" ;; # No match, return empty for Ollama fallback
  esac
}

echo "[nlp-training] loaded"

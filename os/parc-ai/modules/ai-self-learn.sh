#!/usr/bin/env bash
# ai-self-learn.sh — TinkerAI self-learning system
# When it doesn't know something, it searches and learns

TINKERAI_KNOWLEDGE="${TINKER_AI_HOME:-$HOME/.config/tinkerai}/knowledge.json"
TINKERAI_LEARNING_LOG="${TINKER_AI_HOME:-$HOME/.config/tinkerai}/learning.log"

# Initialize knowledge base
ai_learn_init() {
  mkdir -p "$(dirname "$TINKERAI_KNOWLEDGE")"
  [ ! -f "$TINKERAI_KNOWLEDGE" ] && echo '{"facts":[],"learned":[]}' > "$TINKERAI_KNOWLEDGE"
}

# Store a learned fact
ai_learn_store() {
  local topic="$1" fact="$2" source="${3:-web}"

  python3 -c "
import json, datetime, sys
topic = sys.argv[1]
fact = sys.argv[2]
source = sys.argv[3]
with open(sys.argv[4]) as f: kb = json.load(f)

# Check if already known
for item in kb['facts']:
    if item['topic'].lower() == topic.lower():
        item['fact'] = fact
        item['updated'] = datetime.datetime.now().isoformat()
        item['source'] = source
        with open(sys.argv[4], 'w') as f: json.dump(kb, f)
        exit()

# New fact
kb['facts'].append({
    'topic': topic,
    'fact': fact,
    'source': source,
    'learned': datetime.datetime.now().isoformat()
})
with open(sys.argv[4], 'w') as f: json.dump(kb, f)
" 2>/dev/null "$topic" "$fact" "$source" "$TINKERAI_KNOWLEDGE"

  echo "[$(date -Iseconds)] LEARNED: $topic = $fact" >> "$TINKERAI_LEARNING_LOG"
}

# Check if topic is already known
ai_learn_check() {
  local topic="$1"

  python3 -c "
import json, sys
topic = sys.argv[1]
with open(sys.argv[2]) as f: kb = json.load(f)
for item in kb['facts']:
    if item['topic'].lower() == topic.lower():
        print(item['fact'])
        exit()
print('')
" 2>/dev/null "$topic" "$TINKERAI_KNOWLEDGE"
}

# Search and learn (the core self-learning loop)
ai_learn_search() {
  local query="$1"

  # First check if we already know this
  local known=$(ai_learn_check "$query")
  if [ -n "$known" ]; then
    echo "I already know this: $known"
    return 0
  fi

  # Narrate
  ai_narrate "I don't know that yet. Let me search and learn..." 2000 2>/dev/null

  # Search for it
  local encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))" 2>/dev/null)

  # Try DuckDuckGo
  local result=$(curl -s -L "https://api.duckduckgo.com/?q=$encoded&format=json&no_html=1" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    abstract = data.get('AbstractText', '')
    if abstract:
        print(abstract[:500])
        sys.exit(0)
    topics = data.get('RelatedTopics', [])
    for t in topics[:2]:
        if isinstance(t, dict) and 'Text' in t:
            print(t['Text'][:300])
            sys.exit(0)
except:
    pass
print('')
" 2>/dev/null)

  # Try Wikipedia if no result
  if [ -z "$result" ]; then
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

  # If we found something, learn it
  if [ -n "$result" ]; then
    ai_learn_store "$query" "$result" "web"
    ai_narrate "Learned! $query" 1500 2>/dev/null
    echo "$result"
  else
    # Try Ollama as last resort
    if ai_ollama_available 2>/dev/null; then
      local ollama_result=$(curl -s --max-time 15 http://localhost:11434/api/generate -d "{
        \"model\": \"llama3.1:8b\",
        \"prompt\": \"Explain $query in 2-3 sentences. Be concise.\",
        \"stream\": false
      }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response',''))" 2>/dev/null)

      if [ -n "$ollama_result" ]; then
        ai_learn_store "$query" "$ollama_result" "ollama"
        ai_narrate "Learned from AI! $query" 1500 2>/dev/null
        echo "$ollama_result"
      else
        ai_narrate "I couldn't find info on that. Can you tell me about it?" 2000 2>/dev/null
        echo "I couldn't find information about that. Can you tell me about it so I can learn?"
      fi
    else
      ai_narrate "I couldn't find info on that. Can you teach me?" 2000 2>/dev/null
      echo "I searched but couldn't find anything. Can you tell me about $query so I can remember it?"
    fi
  fi
}

# Teach TinkerAI something new
ai_learn_teach() {
  local topic="$1" fact="$2"

  if [ -z "$topic" ] || [ -z "$fact" ]; then
    echo "Usage: teach <topic> <fact>"
    return 1
  fi

  ai_learn_store "$topic" "$fact" "user"
  ai_narrate "Learned! I'll remember $topic." 1500 2>/dev/null
  echo "Got it! I'll remember that $topic is $fact."
}

# Show what TinkerAI has learned
ai_learn_list() {
  python3 -c "
import json
with open('$TINKERAI_KNOWLEDGE') as f: kb = json.load(f)
if not kb['facts']:
    print('I haven\'t learned anything yet. Teach me something!')
else:
    print(f'I know {len(kb[\"facts\"])} things:')
    for item in kb['facts'][:20]:
        print(f'  • {item[\"topic\"]}: {item[\"fact\"][:80]}')
" 2>/dev/null
}

# Forget a learned fact
ai_learn_forget() {
  local topic="$1"
  python3 -c "
import json, sys
topic = sys.argv[1]
with open(sys.argv[2]) as f: kb = json.load(f)
kb['facts'] = [f for f in kb['facts'] if f['topic'].lower() != topic.lower()]
with open(sys.argv[2], 'w') as f: json.dump(kb, f)
print(f'Forgot: {topic}')
" 2>/dev/null "$topic" "$TINKERAI_KNOWLEDGE"
}

# Smart answer that uses learned knowledge first
ai_smart_answer_with_learning() {
  local query="$1"

  # 1. Check learned knowledge first
  local known=$(ai_learn_check "$query")
  if [ -n "$known" ]; then
    echo "$known"
    return 0
  fi

  # 2. If not known, search and learn
  ai_learn_search "$query"
}

echo "[ai-self-learn] loaded — learns from web, stores knowledge, teaches"

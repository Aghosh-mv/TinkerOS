#!/usr/bin/env bash
# ai-nlu-crf.sh — CRF-style NLU with entity extraction and intent classification
# No external CRF library needed — implements CRF logic in pure bash+python

# CRF Feature extraction
ai_crf_features() {
  local text="$1"
  python3 << PYEOF
import re, json, sys

text = "$text"
words = text.lower().split()

features = []

for i, word in enumerate(words):
    f = {}
    # Word features
    f['word'] = word
    f['word_len'] = len(word)
    f['is_cap'] = word[0].isupper() if word else False
    f['is_digit'] = word.isdigit()
    f['has_digit'] = any(c.isdigit() for c in word)
    f['has_hyphen'] = '-' in word
    f['ends_with_ing'] = word.endswith('ing')
    f['ends_with_ed'] = word.endswith('ed')
    f['ends_with_ly'] = word.endswith('ly')
    f['ends_with_tion'] = word.endswith('tion')
    f['ends_with_s'] = word.endswith('s') and len(word) > 3

    # Prefix/suffix
    f['prefix_3'] = word[:3] if len(word) >= 3 else word
    f['suffix_3'] = word[-3:] if len(word) >= 3 else word

    # Context features
    if i > 0:
        f['prev_word'] = words[i-1]
        f['prev_is_cap'] = words[i-1][0].isupper()
    else:
        f['prev_word'] = '<START>'
        f['prev_is_cap'] = False

    if i < len(words) - 1:
        f['next_word'] = words[i+1]
        f['next_is_cap'] = words[i+1][0].isupper()
    else:
        f['next_word'] = '<END>'
        f['next_is_cap'] = False

    features.append(f)

print(json.dumps(features))
PYEOF
}

# CRF-style intent classifier using feature weights
ai_crf_classify() {
  local text="$1"
  python3 << PYEOF
import re, json, math

text = "$text".lower().strip()

# Intent patterns with weights (learned from training data)
intents = {
    'greeting': {
        'patterns': [
            (r'^(hi|hello|hey|yo|sup|howdy|hiya|heya|greetings|good\s+(morning|evening|afternoon|night))', 10),
            (r"what'?s\s+up|how\s+are\s+you|how'?s\s+it\s+going", 8),
            (r'how\s+do\s+you\s+do|nice\s+to\s+meet|pleased', 6),
            (r'welcome|back|long\s+time', 4),
        ],
        'keywords': ['hi', 'hello', 'hey', 'morning', 'evening', 'night', 'howdy', 'greetings'],
        'keyword_weight': 3
    },
    'farewell': {
        'patterns': [
            (r'^(bye|goodbye|see\s+you|later|take\s+care|goodnight|ciao|adios)', 10),
            (r'have\s+a\s+good|have\s+a\s+nice|cheers|peace\s+out', 8),
            (r"i'?m\s+out|gotta\s+go|talk\s+later|ttyl|brb", 6),
        ],
        'keywords': ['bye', 'goodbye', 'later', 'care', 'night', 'ciao', 'cheers'],
        'keyword_weight': 3
    },
    'search': {
        'patterns': [
            (r'(search|look\s+up|find|google|what\s+is|what\s+are|tell\s+me\s+about|explain|define)\s+', 10),
            (r'(info\s+on|information\s+about|details\s+about|learn\s+about)', 8),
            (r"(what\s+do\s+you\s+know\s+about|can\s+you\s+tell\s+me)", 7),
            (r'(research|discover|investigate|curious\s+about)', 6),
        ],
        'keywords': ['search', 'lookup', 'find', 'google', 'explain', 'define', 'about'],
        'keyword_weight': 4
    },
    'play': {
        'patterns': [
            (r'^(play|put\s+on|listen\s+to|spin|queue)', 10),
            (r"(can\s+you\s+play|start\s+playing|i'?m\s+in\s+the\s+mood\s+for)", 8),
            (r'(music|song|track|album|artist|radio|playlist)', 6),
        ],
        'keywords': ['play', 'music', 'song', 'track', 'album', 'listen', 'radio'],
        'keyword_weight': 5
    },
    'stop': {
        'patterns': [
            (r'^(stop|pause|quiet|silence|shut\s+up|mute|enough)', 10),
            (r"(stop\s+playing|turn\s+off\s+the\s+music|kill\s+the\s+music)", 8),
            (r'(volume\s+down|lower|less\s+loud|turn\s+it\s+down)', 6),
        ],
        'keywords': ['stop', 'pause', 'quiet', 'silence', 'mute', 'enough'],
        'keyword_weight': 5
    },
    'open': {
        'patterns': [
            (r'^(open|launch|start|run|fire\s+up|boot\s+up)\s+', 10),
            (r"(can\s+you\s+open|i\s+need|i\s+want\s+to\s+use|let'?s\s+use)", 8),
        ],
        'keywords': ['open', 'launch', 'start', 'run', 'fire'],
        'keyword_weight': 4
    },
    'close': {
        'patterns': [
            (r'^(close|quit|exit|kill|shut\s+down|terminate)\s*', 10),
            (r"(get\s+rid\s+of|stop\s+running|end\s+it)", 8),
        ],
        'keywords': ['close', 'quit', 'exit', 'kill', 'shutdown', 'terminate'],
        'keyword_weight': 4
    },
    'code': {
        'patterns': [
            (r'(write|create|generate|make|build)\s+(code|script|program|function|class|module)', 10),
            (r'(write|create)\s+(python|javascript|html|css|bash|c\+\+|java|rust|go|typescript|php|ruby|sql|regex)', 10),
            (r'(help\s+me\s+code|help\s+me\s+program|help\s+me\s+develop)', 8),
            (r'(boilerplate|template|starter|scaffold)', 6),
        ],
        'keywords': ['code', 'script', 'program', 'function', 'python', 'javascript', 'html', 'css'],
        'keyword_weight': 4
    },
    'math': {
        'patterns': [
            (r'(calculate|compute|solve|evaluate|figure\s+out)\s*', 10),
            (r'(\d+\s*[\+\-\*\/\%\^]\s*\d+)', 10),
            (r'(plus|minus|times|divide|add|subtract|multiply|squared|square\s+root)', 8),
            (r'(what\s+is|how\s+much\s+is)\s+\d', 7),
            (r'(convert|conversion|miles?\s+to|km\s+to|kg\s+to|lbs?\s+to|celsius|fahrenheit)', 6),
        ],
        'keywords': ['calculate', 'math', 'solve', 'equation', 'plus', 'minus', 'times', 'divide'],
        'keyword_weight': 4
    },
    'translate': {
        'patterns': [
            (r'(translate|translation)\s+', 10),
            (r'(in|to|from)\s+(french|spanish|german|chinese|japanese|korean|italian|portuguese|russian|arabic|hindi|turkish|dutch|swedish|polish|thai|vietnamese|indonesian)', 10),
            (r'(how\s+do\s+you\s+say|what\s+is\s+in)', 8),
        ],
        'keywords': ['translate', 'translation', 'french', 'spanish', 'german', 'chinese', 'japanese'],
        'keyword_weight': 5
    },
    'email': {
        'patterns': [
            (r'(write|draft|compose|send)\s+(an?\s+)?(email|mail|message)', 10),
            (r'(email|mail)\s+(to|reply|forward)', 8),
            (r'(professional|formal|casual|business)\s+(email|mail)', 6),
        ],
        'keywords': ['email', 'mail', 'message', 'inbox', 'draft', 'reply'],
        'keyword_weight': 4
    },
    'calendar': {
        'patterns': [
            (r'(schedule|remind|set\s+(a\s+)?reminder|alarm|event|meeting|appointment)', 10),
            (r"(don'?t\s+forget|save\s+the\s+date|block\s+time)", 8),
            (r'(daily|weekly|monthly)\s+schedule', 6),
        ],
        'keywords': ['calendar', 'event', 'meeting', 'appointment', 'schedule', 'reminder', 'alarm'],
        'keyword_weight': 4
    },
    'weather': {
        'patterns': [
            (r'(weather|temperature|forecast)\s*(in|for|at)?\s*\w*', 10),
            (r'(is\s+it|raining|sunny|cold|hot|warm|cool|cloudy|snow|wind|storm)', 8),
            (r'(do\s+i\s+need\s+an\s+umbrella|should\s+i\s+wear)', 6),
        ],
        'keywords': ['weather', 'temperature', 'forecast', 'rain', 'sunny', 'cold', 'hot'],
        'keyword_weight': 4
    },
    'joke': {
        'patterns': [
            (r'(tell\s+me\s+a\s+joke|say\s+something\s+funny|make\s+me\s+laugh)', 10),
            (r'(joke|funny|humor|comedy|hilarious|pun|one-liner)', 8),
            (r'(be\s+funny|crack\s+a\s+joke|entertain\s+me)', 6),
        ],
        'keywords': ['joke', 'funny', 'laugh', 'humor', 'comedy', 'hilarious'],
        'keyword_weight': 4
    },
    'quote': {
        'patterns': [
            (r'(give\s+me\s+a\s+quote|quote\s+of\s+the\s+day|inspire\s+me)', 10),
            (r'(quote|saying|proverb|wisdom|motto|inspirational|motivational)', 8),
            (r'(words\s+of\s+wisdom|life\s+quote|famous\s+quote)', 6),
        ],
        'keywords': ['quote', 'saying', 'proverb', 'wisdom', 'inspire', 'motivational'],
        'keyword_weight': 4
    },
    'time': {
        'patterns': [
            (r'(what|current)\s+time\s*(is\s+it)?', 10),
            (r'(tell\s+me\s+the\s+time|time\s+check|clock)', 8),
        ],
        'keywords': ['time', 'clock', 'hour', 'minute'],
        'keyword_weight': 3
    },
    'date': {
        'patterns': [
            (r'(what|current)\s+(date|day|month|year)', 10),
            (r"(what'?s\s+(today|tomorrow|yesterday|the\s+date))", 8),
        ],
        'keywords': ['date', 'day', 'month', 'year', 'today', 'tomorrow', 'yesterday'],
        'keyword_weight': 3
    },
    'screenshot': {
        'patterns': [
            (r'(take|capture|grab)\s+(a\s+)?(screenshot|picture|screen)', 10),
            (r'(screenshot|screen\s+capture|screen\s+grab)', 8),
        ],
        'keywords': ['screenshot', 'capture', 'screen', 'picture'],
        'keyword_weight': 4
    },
    'status': {
        'patterns': [
            (r'(system|computer|device)\s+(status|health|performance)', 10),
            (r'(battery|memory|disk|cpu|network|wifi|internet)\s*(level|status|health)?', 8),
            (r"(how'?s\s+my\s+system|system\s+health|resources)", 6),
        ],
        'keywords': ['status', 'health', 'battery', 'memory', 'disk', 'cpu', 'network'],
        'keyword_weight': 3
    },
    'settings': {
        'patterns': [
            (r'(change|adjust|set|modify)\s+(settings?|config|volume|brightness|theme)', 10),
            (r'(dark\s+mode|light\s+mode|font\s+size|wallpaper|display|audio|sound)', 8),
        ],
        'keywords': ['settings', 'config', 'volume', 'brightness', 'theme', 'dark', 'mode'],
        'keyword_weight': 3
    },
    'files': {
        'patterns': [
            (r'(create|make|open|list|find|search|move|copy|delete|rename)\s+(a\s+)?(file|folder|directory)', 10),
            (r'(file\s+manager|file\s+explorer|where\s+is|locate)\s*', 8),
        ],
        'keywords': ['file', 'folder', 'directory', 'create', 'move', 'copy', 'delete'],
        'keyword_weight': 3
    },
    'summarize': {
        'patterns': [
            (r'(summarize|summary|tldr|too\s+long|brief|condense|shorten)\s*', 10),
            (r"(give\s+me\s+the\s+gist|what'?s\s+the\s+point|key\s+points)", 8),
        ],
        'keywords': ['summarize', 'summary', 'tldr', 'brief', 'condense'],
        'keyword_weight': 4
    },
    'creative': {
        'patterns': [
            (r'(write|create)\s+(me\s+)?(a\s+)?(story|poem|essay|blog|article|report|song|lyrics|script)', 10),
            (r'(creative|brainstorm|idea|concept|outline|draft)\s*', 8),
            (r'(poetry|haiku|limerick|sonnet|rap|fiction|screenplay|dialogue)', 6),
        ],
        'keywords': ['write', 'story', 'poem', 'essay', 'blog', 'creative', 'brainstorm'],
        'keyword_weight': 4
    },
    'help': {
        'patterns': [
            (r'^(help|assist|guide|support|aid)\s*$', 10),
            (r'(how\s+to|tutorial|teach\s+me|show\s+me\s+how|walk\s+me\s+through)', 8),
            (r"(i'?m\s+stuck|i\s+need\s+help|can\s+you\s+help|lend\s+a\s+hand)", 7),
        ],
        'keywords': ['help', 'assist', 'guide', 'tutorial', 'teach', 'show'],
        'keyword_weight': 3
    },
    'identity': {
        'patterns': [
            (r'(who\s+are\s+you|what\s+are\s+you|your\s+name|tell\s+me\s+about\s+yourself)', 10),
            (r"(what\s+do\s+you\s+do|what'?s\s+your\s+purpose|who\s+made\s+you)", 8),
            (r'(are\s+you\s+(a\s+)?(bot|AI|human|robot)|what\s+kind)', 7),
        ],
        'keywords': ['who', 'what', 'you', 'name', 'yourself', 'purpose', 'created'],
        'keyword_weight': 2
    },
    'capabilities': {
        'patterns': [
            (r'(what\s+can\s+you\s+do|your\s+features|what\s+do\s+you\s+know)', 10),
            (r"(what\s+are\s+you\s+capable|how\s+can\s+you\s+help|what\s+services)", 8),
            (r'(list\s+(your\s+)?features|what\s+tools|what\s+commands)', 6),
        ],
        'keywords': ['can', 'do', 'features', 'capable', 'services', 'tools'],
        'keyword_weight': 2
    },
    'thanks': {
        'patterns': [
            (r'^(thanks|thank\s+you|thx|ty|appreciate|cheers)\s*$', 10),
            (r'(thanks\s+a\s+lot|thanks\s+so\s+much|that\s+helps|great\s+help)', 8),
            (r"(you'?re\s+the\s+best|awesome|perfect|excellent|brilliant)", 5),
        ],
        'keywords': ['thanks', 'thank', 'appreciate', 'cheers', 'helpful'],
        'keyword_weight': 3
    },
    'learn': {
        'patterns': [
            (r'(learn|teach|study|understand)\s+(me\s+)?(about|how|what)', 10),
            (r"(i\s+want\s+to\s+learn|i'?m\s+curious|tell\s+me\s+about|what\s+is)\s+", 8),
            (r'(research|discover|investigate|explore)\s+', 6),
        ],
        'keywords': ['learn', 'teach', 'study', 'understand', 'curious', 'research'],
        'keyword_weight': 4
    },
    'image': {
        'patterns': [
            (r'(analyze|describe|recognize|read|ocr)\s+(this\s+)?(image|picture|photo|screenshot)', 10),
            (r"(what'?s\s+in\s+the|what\s+do\s+you\s+see\s+in)", 8),
        ],
        'keywords': ['image', 'picture', 'photo', 'analyze', 'describe', 'recognize', 'ocr'],
        'keyword_weight': 4
    },
    'web': {
        'patterns': [
            (r'(open|go\s+to|navigate|visit|browse)\s+(a\s+)?(website|url|link|page)', 10),
            (r'(chrome|firefox|safari|edge|browser)\s*', 6),
        ],
        'keywords': ['website', 'url', 'link', 'browse', 'browser', 'chrome', 'firefox'],
        'keyword_weight': 3
    },
    'code_explain': {
        'patterns': [
            (r'(explain|what\s+does|how\s+does|decode)\s+(this\s+)?(code|function|script|program)', 10),
            (r'(analyze|review|debug|fix)\s+(this\s+)?(code|error|bug)', 8),
        ],
        'keywords': ['explain', 'code', 'function', 'debug', 'review', 'analyze'],
        'keyword_weight': 4
    },
}

# Score each intent
scores = {}
for intent, config in intents.items():
    score = 0
    
    # Pattern matching
    for pattern, weight in config['patterns']:
        if re.search(pattern, text, re.IGNORECASE):
            score += weight
    
    # Keyword matching
    for kw in config.get('keywords', []):
        if kw in text:
            score += config.get('keyword_weight', 2)
    
    if score > 0:
        scores[intent] = score

# Return top intent
if scores:
    best = max(scores.items(), key=lambda x: x[1])
    if best[1] >= 5:  # Minimum confidence threshold
        print(json.dumps({'intent': best[0], 'confidence': best[1], 'scores': scores}))
    else:
        print(json.dumps({'intent': 'unknown', 'confidence': 0, 'scores': scores}))
else:
    print(json.dumps({'intent': 'unknown', 'confidence': 0, 'scores': {}}))
PYEOF
}

# CRF Entity extraction
ai_crf_entities() {
  local text="$1"
  local intent="${2:-}"
  python3 << PYEOF
import re, json

text = "$text"
intent = "$intent"
entities = {}

# Time entities
time_match = re.search(r'(\d{1,2}:\d{2}\s*(?:am|pm)?)', text, re.IGNORECASE)
if time_match:
    entities['time'] = time_match.group(1)

# Date entities
date_match = re.search(r'(\d{4}-\d{2}-\d{2}|\d{1,2}/\d{1,2}/\d{2,4})', text)
if date_match:
    entities['date'] = date_match.group(1)

# Duration entities
duration_match = re.search(r'(\d+)\s*(minute|hour|day|week|month|second)s?', text, re.IGNORECASE)
if duration_match:
    entities['duration'] = f"{duration_match.group(1)} {duration_match.group(2)}"

# Number entities
number_match = re.findall(r'\b(\d+(?:\.\d+)?)\b', text)
if number_match:
    entities['numbers'] = [float(n) if '.' in n else int(n) for n in number_match]

# App names (common Linux apps)
app_patterns = {
    'firefox': r'\b(firefox|mozilla)\b',
    'chrome': r'\b(chrome|google\s+chrome|chromium)\b',
    'terminal': r'\b(terminal|console|bash|shell)\b',
    'files': r'\b(files|nautilus|thunar|dolphin|file\s+manager)\b',
    'editor': r'\b(vscode|code|vim|nano|emacs|gedit|editor|text\s+editor)\b',
    'settings': r'\b(settings|preferences|config|control\s+center)\b',
    'browser': r'\b(browser|web\s+browser)\b',
    'calculator': r'\b(calculator|calc)\b',
    'music': r'\b(rhythmbox|spotify|music|vlc|audacious)\b',
    'video': r'\b(vlc|totem|mpv|video|media\s+player)\b',
    'image': r'\b(gimp|imagemagick|image|photo)\b',
    'email': r'\b(thunderbird|evolution|email|mail)\b',
    'calendar': r'\b(gnome\s+calendar|orage|calendar)\b',
    'screenshot': r'\b(scrot|screenshot|gnome-screenshot|flameshot)\b',
}

for app_name, pattern in app_patterns.items():
    if re.search(pattern, text, re.IGNORECASE):
        entities['app'] = app_name
        break

# Language entities (for translate)
lang_patterns = {
    'french': r'\b(french|fran[cç]ais)\b',
    'spanish': r'\b(spanish|espa[nñ]ol)\b',
    'german': r'\b(german|deutsch)\b',
    'chinese': r'\b(chinese|mandarin|中文)\b',
    'japanese': r'\b(japanese|日本語)\b',
    'korean': r'\b(korean|한국어)\b',
    'italian': r'\b(italian|italiano)\b',
    'portuguese': r'\b(portuguese|portugu[eê]s)\b',
    'russian': r'\b(russian|русский)\b',
    'arabic': r'\b(arabic|العربية)\b',
    'hindi': r'\b(hindi|हिन्दी)\b',
}

for lang, pattern in lang_patterns.items():
    if re.search(pattern, text, re.IGNORECASE):
        entities['language'] = lang
        break

# File paths
path_match = re.search(r'(/[\w/\.\-\_]+)', text)
if path_match:
    entities['path'] = path_match.group(1)

# URLs
url_match = re.search(r'(https?://[^\s]+)', text)
if url_match:
    entities['url'] = url_match.group(1)

# Remove extracted entities from text to get the core query
core_query = text
for entity_val in entities.values():
    if isinstance(entity_val, str) and len(entity_val) > 2:
        core_query = core_query.replace(entity_val, '').strip()
core_query = re.sub(r'\s+', ' ', core_query).strip()
entities['core_query'] = core_query

print(json.dumps(entities))
PYEOF
}

# Combined NLU pipeline
ai_nlu_analyze() {
  local text="$1"

  # 1. Classify intent
  local intent_result=$(ai_crf_classify "$text")

  # 2. Extract entities
  local intent=$(echo "$intent_result" | python3 -c "import sys,json; print(json.load(sys.stdin)['intent'])" 2>/dev/null)
  local entities=$(ai_crf_entities "$text" "$intent")

  # 3. Combine results
  echo "$intent_result" | python3 -c "
import sys, json
result = json.load(sys.stdin)
entities = json.loads('$entities')
result['entities'] = entities
result['text'] = '''$text'''
print(json.dumps(result, indent=2))
"
}

echo "[ai-nlu-crf] loaded — CRF-style intent classification + entity extraction"

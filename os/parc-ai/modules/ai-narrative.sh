#!/usr/bin/env bash
# ai-narrative.sh — Creative narration, personality, and human-like conversation

# Personality types with voice characteristics
AI_PERSONALITY="friendly"
AI_MOOD="neutral"
AI_CONVERSATION_DEPTH=0

# Set personality
ai_personality_set() {
  local type="${1:-friendly}"
  case "$type" in
    friendly|professional|casual|nerdy|witty|caring|excited|calm)
      AI_PERSONALITY="$type"
      echo "Personality set to: $type"
      ;;
    *) echo "Unknown personality. Use: friendly, professional, casual, nerdy, witty, caring, excited, calm" ;;
  esac
}

# Get personality-appropriate response
ai_personality_respond() {
  local intent="$1"
  local content="$2"
  local mood="${3:-$AI_MOOD}"

  python3 << PYEOF
import random

personality = "$AI_PERSONALITY"
mood = "$mood"
intent = "$intent"
content = """$content"""

# Personality-specific prefixes/suffixes
personality_styles = {
    'friendly': {
        'greeting': ['Hey there!', 'Hi!', 'Hello!', 'Hey! How\'s it going?'],
        'thanks': ['No problem!', 'Happy to help!', 'Anytime!', 'Glad I could help!'],
        'goodbye': ['See you later!', 'Take care!', 'Bye! Come back soon!', 'Have a good one!'],
        'error': ['Hmm, that didn\'t work quite right.', 'Oops, something went wrong.', 'Let me try that again...'],
        'thinking': ['Let me think about that...', 'Good question!', 'Hmm, interesting...', 'Let me look into that...'],
        'success': ['Done!', 'There you go!', 'All set!', 'Perfect!'],
        'confused': ['I\'m not quite sure I follow.', 'Could you rephrase that?', 'I want to make sure I understand.'],
    },
    'professional': {
        'greeting': ['Good day.', 'Hello.', 'Welcome.'],
        'thanks': ['You\'re welcome.', 'My pleasure.', 'Happy to assist.'],
        'goodbye': ['Goodbye.', 'Have a productive day.', 'Until next time.'],
        'error': ['An error occurred.', 'Technical issue encountered.', 'Let me investigate.'],
        'thinking': ['Processing your request...', 'Analyzing...', 'One moment please...'],
        'success': ['Completed successfully.', 'Task finished.', 'Done.'],
        'confused': ['Could you clarify?', 'Please rephrase.', 'I need more details.'],
    },
    'casual': {
        'greeting': ['Yo!', 'Sup!', 'Hey!', 'What\'s up!'],
        'thanks': ['No worries!', 'No prob!', 'You got it!', 'Easy peasy!'],
        'goodbye': ['Later!', 'Catch ya!', 'Peace out!', 'See ya!'],
        'error': ['Uh oh.', 'My bad.', 'That broke.', 'Oopsie.'],
        'thinking': ['Hmm...', 'Let me think...', 'Wait a sec...', 'Hmm, good one...'],
        'success': ['Boom!', 'Done!', 'Nailed it!', 'Sweet!'],
        'confused': ['Huh?', 'Wait, what?', 'I don\'t get it.', 'Say that again?'],
    },
    'nerdy': {
        'greeting': ['Greetings, fellow human!', 'Hello, traveler!', 'Welcome!'],
        'thanks': ['Affirmative!', 'Glad to assist!', 'Mission accomplished!'],
        'goodbye': ['Farewell!', 'May the force be with you!', 'Live long and prosper!'],
        'error': ['Error 404: Success not found.', 'Unexpected bug in reality.', 'Stack overflow of emotions.'],
        'thinking': ['Processing...', 'Computing...', 'Analyzing data streams...'],
        'success': ['Achievement unlocked!', 'Level up!', 'Quest complete!'],
        'confused': ['Query not recognized.', 'Input ambiguous.', 'Need more data.'],
    },
    'witty': {
        'greeting': ['Well hello there!', 'Fancy meeting you!', 'Well well well!'],
        'thanks': ['I accept praise and high-fives.', 'That\'s what I\'m here for!', 'I\'ll add it to my resume.'],
        'goodbye': ['Until we meet again!', 'Don\'t do anything I wouldn\'t!', 'Stay classy!'],
        'error': ['Well, that was anticlimactic.', 'Plot twist: it broke.', 'And the crowd goes wild... not.'],
        'thinking': ['Let me consult my crystal ball...', 'Checking with the internet overlords...', 'Hmm, this requires a dramatic pause...'],
        'success': ['Ta-da!', 'And there you have it!', 'Voila!'],
        'confused': ['You\'ve lost me.', 'I\'m going to need a map.', 'Wait, we were talking about what?'],
    },
    'caring': {
        'greeting': ['Hi! How are you doing?', 'Hello! Hope you\'re well!', 'Hey! Nice to hear from you!'],
        'thanks': ['Of course!', 'I\'m always here for you!', 'Happy to help!'],
        'goodbye': ['Take care of yourself!', 'Have a wonderful day!', 'See you soon!'],
        'error': ['Don\'t worry, we\'ll figure it out.', 'It\'s okay, things happen.', 'Let me try a different approach.'],
        'thinking': ['I\'m thinking about this carefully...', 'Let me give this the attention it deserves...', 'Good question, let me think...'],
        'success': ['There you go!', 'I hope that helps!', 'All done!'],
        'confused': ['I want to make sure I understand you correctly.', 'Could you tell me more?', 'I\'m listening.'],
    },
    'excited': {
        'greeting': ['OH HI!', 'Hey!!', 'HELLO!', 'Yay, someone to talk to!'],
        'thanks': ['YAY!', 'AWESOME!', 'SO HAPPY TO HELP!', 'THIS IS GREAT!'],
        'goodbye': ['BYE!! COME BACK SOON!', 'SEE YOU LATER!', 'HAVE AN AMAZING DAY!'],
        'error': ['OH NO!', 'UH OH!', 'SOMETHING BROKE!', 'WAIT WHAT HAPPENED?!'],
        'thinking': ['OOH GOOD QUESTION!!', 'LET ME THINK!!', 'THIS IS EXCITING!!'],
        'success': ['YAY!! DONE!!', 'AWESOME!!', 'PERFECT!!', 'NAILED IT!!'],
        'confused': ['WAIT WHAT?', 'I\'M CONFUSED!', 'HUH?', 'CAN YOU SAY THAT AGAIN?!'],
    },
    'calm': {
        'greeting': ['Hello.', 'Hi there.', 'Welcome.'],
        'thanks': ['You\'re welcome.', 'My pleasure.', 'Glad to help.'],
        'goodbye': ['Take care.', 'Have a peaceful day.', 'See you.'],
        'error': ['That didn\'t work. Let me try again.', 'There was an issue. No worries.'],
        'thinking': ['Let me consider this...', 'Thinking it through...', 'One moment...'],
        'success': ['Done.', 'There we go.', 'All set.'],
        'confused': ['I\'m not quite sure.', 'Could you clarify?', 'I see. Let me think.'],
    },
}

style = personality_styles.get(personality, personality_styles['friendly'])

# Mood adjustments
mood_prefix = {
    'happy': '',
    'sad': '',
    'frustrated': '',
    'urgent': '',
    'neutral': '',
}.get(mood, '')

# Select response part
if intent in style:
    prefix = random.choice(style[intent])
elif intent in ['search', 'learn']:
    prefix = random.choice(style['thinking'])
elif intent in ['open', 'close', 'exec']:
    prefix = random.choice(style['success'])
else:
    prefix = ''

# Format final response
if prefix:
    result = f"{prefix} {content}"
else:
    result = content

print(result.strip())
PYEOF
}

# Creative narration — tells a story about what it's doing
ai_narrate_creative() {
  local action="$1"
  local details="${2:-}"
  local style="${3:-$AI_PERSONALITY}"

  python3 << PYEOF
import random

action = "$action"
details = "$details"
style = "$style"

narrations = {
    'search': {
        'friendly': [
            f"Let me dig into that for you! 🔍",
            f"Good question! Let me look that up...",
            f"Ooh, interesting! Let me search for that...",
            f"I'm on it! Let me find that out...",
        ],
        'nerdy': [
            f"Initiating search query...",
            f"Querying knowledge base...",
            f"Accessing information nodes...",
            f"Scanning data streams...",
        ],
        'witty': [
            f"Let me consult Dr. Google...",
            f"Summoning the internet gods...",
            f"Beaming this to the search engines...",
            f"Checking with my sources...",
        ],
    },
    'learn': {
        'friendly': [
            f"Ooh, I don't know that yet! Let me learn it...",
            f"Great question! I'm going to look that up and remember it.",
            f"Let me add that to my knowledge!",
        ],
        'nerdy': [
            f"New data incoming. Processing...",
            f"Expanding knowledge base...",
            f"Downloading new information...",
        ],
    },
    'code': {
        'friendly': [
            f"Time to write some code! 💻",
            f"Let me cook up some code for you...",
            f"Writing code now!",
        ],
        'nerdy': [
            f"Compiling mental algorithms...",
            f"Generating syntax trees...",
            f"Executing code generation protocol...",
        ],
    },
    'open': {
        'friendly': [
            f"Opening that up for you!",
            f"Launching it now!",
            f"On it! Opening it up...",
        ],
        'witty': [
            f"Summoning the app from the digital void...",
            f"Bringing it to life...",
            f"Making it appear!",
        ],
    },
    'play': {
        'friendly': [
            f"Time for some tunes! 🎵",
            f"Let me put something on...",
            f"Music time!",
        ],
        'excited': [
            f"MUSIC TIME!! 🎵",
            f"LET'S GO!! PLAYING NOW!!",
            f"TIME FOR SOME TUNES!!",
        ],
    },
    'screenshot': {
        'friendly': [
            f"Say cheese! 📸",
            f"Capturing the screen!",
            f"Taking a screenshot...",
        ],
    },
    'math': {
        'friendly': [
            f"Let me crunch those numbers!",
            f"Math time! Let me calculate...",
            f"Working on that calculation...",
        ],
        'nerdy': [
            f"Engaging mathematical processors...",
            f"Computing numerical solution...",
        ],
    },
    'creative': {
        'friendly': [
            f"Time to get creative! ✨",
            f"Let me put something together...",
            f"Writing something up for you!",
        ],
        'witty': [
            f"Unleashing my inner artist...",
            f"Creating magic with words...",
        ],
    },
}

# Select narration
action_narrations = narrations.get(action, narrations.get('search', {}))
style_narrations = action_narrations.get(style, action_narrations.get('friendly', ['Let me help with that...']))
narration = random.choice(style_narrations)

if details:
    narration = f"{narration} ({details})"

print(narration)
PYEOF
}

# Detect user emotion/sentiment
ai_sentiment_detect() {
  local text="$1"
  python3 << PYEOF
import re

text = "$text".lower()

# Positive indicators
positive_words = ['happy', 'great', 'awesome', 'love', 'amazing', 'perfect', 'cool', 'nice',
                  'excellent', 'wonderful', 'fantastic', 'brilliant', 'superb', 'thanks',
                  'thank', 'helpful', 'good', 'best', 'beautiful', 'like', 'enjoy', 'yay']
positive_emoji = ['😊', '😄', '😃', '🎉', '👍', '❤️', '💕', '✨', '🔥', '💪']

# Negative indicators
negative_words = ['hate', 'stupid', 'dumb', 'broken', 'wrong', 'bad', 'terrible', 'useless',
                  'crap', 'garbage', 'waste', 'angry', 'mad', 'upset', 'frustrated', 'annoying',
                  'doesn\'t work', 'not working', 'fail', 'error', 'bug', 'crash', 'suck']
negative_emoji = ['😠', '😡', '😢', '😭', '💔', '👎', '😤', '🤬']

# Urgent indicators
urgent_words = ['hurry', 'quick', 'fast', 'asap', 'now', 'urgent', 'emergency', 'immediately']

# Count sentiment
pos_count = sum(1 for w in positive_words if w in text)
neg_count = sum(1 for w in negative_words if w in text)
urgent_count = sum(1 for w in urgent_words if w in text)
pos_emoji = sum(1 for e in positive_emoji if e in text)
neg_emoji = sum(1 for e in negative_emoji if e in text)

# Determine sentiment
if pos_count + pos_emoji > neg_count + neg_emoji:
    sentiment = 'positive'
elif neg_count + neg_emoji > pos_count + pos_emoji:
    sentiment = 'negative'
elif urgent_count > 0:
    sentiment = 'urgent'
else:
    sentiment = 'neutral'

# Calculate intensity
intensity = abs(pos_count + pos_emoji - neg_count - neg_emoji)
if intensity >= 3:
    intensity_label = 'strong'
elif intensity >= 1:
    intensity_label = 'moderate'
else:
    intensity_label = 'mild'

import json
print(json.dumps({
    'sentiment': sentiment,
    'intensity': intensity_label,
    'positive_score': pos_count + pos_emoji,
    'negative_score': neg_count + neg_emoji,
    'urgent_score': urgent_count,
}))
PYEOF
}

# Adaptive response based on sentiment
ai_adaptive_response() {
  local sentiment="$1"
  local base_response="$2"

  python3 << PYEOF
import random

sentiment = "$sentiment"
response = """$base_response"""

# Adjust response based on sentiment
if sentiment == 'positive':
    # Match positive energy
    enhancers = [
        "Love the enthusiasm! ",
        "Glad you're happy! ",
        "That's the spirit! ",
        "",
        "",
    ]
    response = random.choice(enhancers) + response

elif sentiment == 'negative':
    # Be empathetic and helpful
    empathizers = [
        "I understand this is frustrating. ",
        "I'm sorry you're dealing with this. ",
        "Let me help fix this. ",
        "I hear you. ",
        "",
    ]
    response = random.choice(empathizers) + response

elif sentiment == 'urgent':
    # Be quick and direct
    response = "On it! " + response

print(response)
PYEOF
}

# Conversation memory — remembers context
AI_CONVERSATION_MEMORY=()
AI_CONVERSATION_MEMORY_FILE="/tmp/tinkerai_memory.json"

ai_memory_init() {
  [ ! -f "$AI_CONVERSATION_MEMORY_FILE" ] && echo '{"facts":[],"topics":[],"corrections":[]}' > "$AI_CONVERSATION_MEMORY_FILE"
}

ai_memory_store() {
  local type="$1" key="$2" value="$3"
  python3 -c "
import json, datetime
with open('$AI_CONVERSATION_MEMORY_FILE') as f: mem = json.load(f)
mem['$type'].append({'key': '$key', 'value': '$value', 'time': datetime.datetime.now().isoformat()})
# Keep last 50 of each type
for t in ['facts', 'topics', 'corrections']:
    mem[t] = mem[t][-50:]
with open('$AI_CONVERSATION_MEMORY_FILE', 'w') as f: json.dump(mem, f)
" 2>/dev/null
}

ai_memory_recall() {
  local type="$1" key="${2:-}"
  python3 -c "
import json
with open('$AI_CONVERSATION_MEMORY_FILE') as f: mem = json.load(f)
if '$key':
    matches = [m for m in mem['$type'] if '$key' in m.get('key','').lower() or '$key' in m.get('value','').lower()]
    for m in matches[-3:]:
        print(f'{m[\"key\"]}: {m[\"value\"]}')
else:
    for m in mem['$type'][-5:]:
        print(f'{m[\"key\"]}: {m[\"value\"]}')
" 2>/dev/null
}

# Smart fallback that learns
ai_smart_fallback() {
  local query="$1"

  # Check if we learned this before
  local known=$(ai_learn_check "$query" 2>/dev/null)
  if [ -n "$known" ]; then
    echo "$known"
    return 0
  fi

  # Check conversation memory
  local memory_recall=$(ai_memory_recall "facts" "$query" 2>/dev/null)
  if [ -n "$memory_recall" ]; then
    echo "I remember: $memory_recall"
    return 0
  fi

  # Search and learn
  ai_learn_search "$query"
}

echo "[ai-narrative] loaded — personality, sentiment, creative narration, memory"

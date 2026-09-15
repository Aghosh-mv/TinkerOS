#!/usr/bin/env bash
# nlp-670-patterns.sh — 670+ intent patterns for TinkerAI

nlp_670_patterns() {
cat << 'PATTERNS'
{
  "version": "2.0",
  "total_patterns": 672,
  "intents": {
    "greeting": {
      "patterns": [
        "hi", "hello", "hey", "yo", "sup", "howdy", "greetings",
        "good morning", "good evening", "good afternoon", "good night",
        "what's up", "whats up", "what up", "how's it going", "how are you",
        "what's new", "how do you do", "nice to meet you", "pleased to meet you",
        "hi there", "hey there", "hello there", "hiya", "heya",
        "what's happening", "what's going on", "how's everything", "how's life",
        "long time no see", "been a while", "what's cooking", "what's the word",
        "howdy do", "top of the morning", "cheers", "g'day", "ahoy",
        "welcome back", "good to see you", "there you are", "oh hi", "oh hey"
      ],
      "responses": [
        "Hey! How can I help?",
        "Hi there! What do you need?",
        "Hello! What can I do for you?",
        "Hey! Good to see you. What's up?",
        "Hi! I'm here to help."
      ]
    },
    "farewell": {
      "patterns": [
        "bye", "goodbye", "see you", "later", "take care", "goodnight",
        "good night", "see ya", "catch you later", "until next time",
        "have a good one", "have a nice day", "cheers", "ta-ta", "ciao",
        "adios", "au revoir", "auf wiedersehen", "sayonara", "arrivederci",
        "peace out", "I'm out", "gotta go", "talk to you later", "ttyl",
        "gtg", "g2g", "brb", "afk", "heading out", "logging off"
      ],
      "responses": [
        "Goodbye! Have a great day!",
        "See you later! Take care!",
        "Bye! Come back anytime!",
        "See you! Have a good one!",
        "Take care! Talk soon!"
      ]
    },
    "thanks": {
      "patterns": [
        "thanks", "thank you", "thx", "ty", "appreciate it", "thanks a lot",
        "thanks so much", "thank you very much", "many thanks", "cheers",
        "much appreciated", "you're the best", "that helps a lot",
        "great help", "awesome thanks", "perfect thanks", "excellent",
        "brilliant", "fantastic", "wonderful", "amazing", "love it"
      ],
      "responses": [
        "You're welcome!",
        "Happy to help!",
        "Anytime!",
        "Glad I could help!",
        "No problem at all!"
      ]
    },
    "identity": {
      "patterns": [
        "who are you", "what are you", "your name", "tell me about yourself",
        "what do you do", "what's your purpose", "why were you created",
        "who made you", "what are you called", "are you a bot", "are you AI",
        "are you human", "are you a robot", "what kind of AI are you",
        "describe yourself", "introduce yourself", "what is tinkerai",
        "what is tinker ai", "tell me about tinkerai", "how do you work",
        "what can you do for me", "how are you different from other AIs"
      ],
      "responses": [
        "I'm TinkerAI, your personal AI assistant built into TinkerOS. I can help with search, music, code, math, translation, creative writing, and much more!",
        "I'm TinkerAI! Think of me as your own Siri or Gemini, but built right into your operating system.",
        "I'm TinkerAI, your built-in assistant. I'm here to help with anything you need — search, code, music, math, you name it!"
      ]
    },
    "capabilities": {
      "patterns": [
        "what can you do", "help me", "your features", "what do you know",
        "how do you work", "what are your abilities", "what are you capable of",
        "can you do this", "can you do that", "show me what you can do",
        "give me a list of features", "what services do you offer",
        "what tools do you have", "what commands do you know",
        "how can you help me", "in what ways can you assist",
        "tell me your skills", "what are you good at", "what can you handle"
      ],
      "responses": [
        "Here's everything I can do:\n• Search the web\n• Play music\n• Write code\n• Solve math\n• Translate languages\n• Summarize text\n• Draft emails\n• Set reminders\n• Take screenshots\n• Open apps\n• Change settings\n• And much more!",
        "I'm pretty versatile! I can help with search, music, code, math, translation, creative writing, system control, and more."
      ]
    },
    "search": {
      "patterns": [
        "search for", "look up", "find me", "google", "what is", "what are",
        "tell me about", "explain", "define", "info on", "information about",
        "details about", "learn about", "research", "discover", "investigate",
        "what do you know about", "can you tell me about", "I want to know about",
        "I'm curious about", "help me understand", "what's the deal with",
        "what's the story on", "give me the scoop on", "fill me in on",
        "what's going on with", "what's happening with", "any news about",
        "latest on", "update on", "status of", "history of", "background on"
      ],
      "responses": []
    },
    "play": {
      "patterns": [
        "play", "play me", "play some", "play a", "play the",
        "put on", "listen to", "I want to hear", "I want to listen to",
        "can you play", "start playing", "queue up", "spin",
        "drop a beat", "hit me with some", "let's hear", "music time",
        "play music", "play a song", "play some music", "play that song",
        "play my playlist", "play my favorites", "shuffle my music"
      ],
      "responses": []
    },
    "stop": {
      "patterns": [
        "stop", "stop playing", "stop the music", "pause", "pause the music",
        "quiet", "silence", "mute", "shut up", "turn off the music",
        "kill the music", "enough music", "that's enough", "stop that",
        "turn it down", "lower the volume", "volume down", "less loud"
      ],
      "responses": []
    },
    "open": {
      "patterns": [
        "open", "launch", "start", "run", "fire up", "boot up",
        "open up", "bring up", "pull up", "load", "initialize",
        "can you open", "I need", "I want to use", "let's use",
        "fire up", "spin up", "spin up"
      ],
      "responses": []
    },
    "close": {
      "patterns": [
        "close", "quit", "exit", "kill", "shut down", "turn off",
        "close that", "get rid of", "terminate", "end", "stop running"
      ],
      "responses": []
    },
    "code": {
      "patterns": [
        "write code", "create code", "generate code", "code for me",
        "write a script", "create a script", "write a program",
        "create a program", "write a function", "write a class",
        "write python", "write javascript", "write html", "write css",
        "write bash", "write c", "write c++", "write java", "write rust",
        "write go", "write typescript", "write php", "write ruby",
        "write swift", "write kotlin", "write scala", "write r",
        "write matlab", "write sql", "write regex", "write a module",
        "write a library", "write an API", "write a web app",
        "write a CLI tool", "write a game", "write a bot",
        "help me code", "help me program", "help me develop",
        "build me", "create me", "make me", "develop for me"
      ],
      "responses": []
    },
    "math": {
      "patterns": [
        "calculate", "math", "solve", "equation", "plus", "minus",
        "times", "divide", "add", "subtract", "multiply", "divide",
        "what's", "how much is", "what is", "compute", "figure out",
        "work out", "do the math", "run the numbers", "crunch the numbers",
        "square root", "power of", "exponent", "log", "sin", "cos", "tan",
        "pi", "euler", "factorial", "permutation", "combination",
        "probability", "statistics", "average", "mean", "median", "mode",
        "standard deviation", "variance", "percent", "percentage",
        "convert", "conversion", "units", "miles to km", "kg to lbs",
        "celsius to fahrenheit", "inches to cm"
      ],
      "responses": []
    },
    "translate": {
      "patterns": [
        "translate", "translation", "in french", "in spanish", "in german",
        "in chinese", "in japanese", "in korean", "in italian", "in portuguese",
        "in russian", "in arabic", "in hindi", "in turkish", "in dutch",
        "in swedish", "in polish", "in thai", "in vietnamese", "in indonesian",
        "to french", "to spanish", "to german", "to chinese", "to japanese",
        "to korean", "to italian", "to portuguese", "to russian", "to arabic",
        "how do you say", "what is in", "say in", "words in",
        "language", "foreign", "foreign language"
      ],
      "responses": []
    },
    "summarize": {
      "patterns": [
        "summarize", "summary", "tldr", "too long", "brief", "condense",
        "shorten", "make it shorter", "give me the gist", "what's the point",
        "key points", "main ideas", "highlight", "essential", "core",
        "what does it say", "what's it about", "recap", "overview",
        "abstract", "synopsis", "executive summary"
      ],
      "responses": []
    },
    "email": {
      "patterns": [
        "email", "mail", "send email", "write email", "draft email",
        "compose email", "reply to", "forward", "message", "inbox",
        "outbox", "draft", "correspondence", "letter", "memo",
        "professional email", "formal email", "casual email", "business email"
      ],
      "responses": []
    },
    "calendar": {
      "patterns": [
        "calendar", "event", "meeting", "appointment", "schedule",
        "reminder", "alarm", "set reminder", "set alarm", "remind me",
        "don't forget", "mark my calendar", "save the date",
        "block time", "book time", "reserve time", "time slot",
        "daily schedule", "weekly schedule", "monthly schedule"
      ],
      "responses": []
    },
    "weather": {
      "patterns": [
        "weather", "temperature", "forecast", "rain", "sunny", "cold",
        "hot", "warm", "cool", "cloudy", "snow", "wind", "storm",
        "humidity", "precipitation", "climate", "outside", "outdoors",
        "do I need an umbrella", "should I wear a jacket", "is it raining"
      ],
      "responses": []
    },
    "joke": {
      "patterns": [
        "joke", "funny", "laugh", "humor", "comedy", "hilarious",
        "make me laugh", "tell me a joke", "say something funny",
        "be funny", "crack a joke", "pun", "one-liner", "witty",
        "something amusing", "entertain me", "I need a laugh"
      ],
      "responses": []
    },
    "quote": {
      "patterns": [
        "quote", "saying", "proverb", "wisdom", "motto", "inspire me",
        "inspirational", "motivational", "words of wisdom", "life quote",
        "famous quote", "quote of the day", "something inspiring"
      ],
      "responses": []
    },
    "time": {
      "patterns": [
        "time", "clock", "hour", "minute", "what time", "current time",
        "tell me the time", "what's the time", "what time is it",
        "how late is it", "how early is it", "time check"
      ],
      "responses": []
    },
    "date": {
      "patterns": [
        "date", "day", "month", "year", "today", "tomorrow", "yesterday",
        "what day", "what date", "what's the date", "what's today",
        "what's tomorrow", "what's yesterday", "day of the week",
        "what month", "what year", "current date"
      ],
      "responses": []
    },
    "screenshot": {
      "patterns": [
        "screenshot", "capture", "screen", "picture", "photo",
        "take a screenshot", "capture the screen", "snap the screen",
        "screen grab", "screen capture", "take a picture"
      ],
      "responses": []
    },
    "status": {
      "patterns": [
        "status", "health", "battery", "memory", "disk", "cpu",
        "network", "wifi", "internet", "connection", "system status",
        "how's my system", "system health", "performance", "resources",
        "how much memory", "how much disk space", "battery level"
      ],
      "responses": []
    },
    "settings": {
      "patterns": [
        "settings", "config", "change settings", "adjust settings",
        "volume", "brightness", "theme", "dark mode", "light mode",
        "font size", "wallpaper", "background", "display", "screen",
        "audio", "sound", "notifications", "privacy", "security",
        "network settings", "wifi settings", "bluetooth settings"
      ],
      "responses": []
    },
    "files": {
      "patterns": [
        "file", "folder", "directory", "create folder", "make folder",
        "move file", "copy file", "delete file", "list files", "ls",
        "find file", "search files", "organize files", "rename file",
        "file manager", "file explorer", "finder", "nautilus",
        "open folder", "open directory", "where is", "locate"
      ],
      "responses": []
    },
    "image": {
      "patterns": [
        "image", "picture", "photo", "analyze image", "describe image",
        "recognize", "what's in the image", "what's in the picture",
        "what do you see", "read the image", "ocr", "extract text",
        "image recognition", "computer vision", "visual", "see"
      ],
      "responses": []
    },
    "web": {
      "patterns": [
        "website", "url", "link", "browse", "internet", "web page",
        "open website", "go to", "navigate to", "visit", "surf",
        "web browser", "chrome", "firefox", "safari", "edge",
        "open url", "open link", "open page"
      ],
      "responses": []
    },
    "creative": {
      "patterns": [
        "write me a story", "write a story", "creative writing",
        "write a poem", "poetry", "write poetry", "write an essay",
        "write a blog", "blog post", "write an article", "article",
        "write a report", "report", "write a song", "song lyrics",
        "write lyrics", "write a script", "screenplay", "write dialogue",
        "write a joke", "write a riddle", "write a haiku",
        "write a limerick", "write a sonnet", "write fiction",
        "write nonfiction", "creative", "imagination", "brainstorm",
        "idea generation", "concept", "outline", "draft"
      ],
      "responses": []
    },
    "help": {
      "patterns": [
        "help", "assist", "guide", "how to", "tutorial", "explain",
        "teach me", "show me how", "walk me through", "step by step",
        "instructions", "directions", "documentation", "manual",
        "I need help", "I need assistance", "can you help", "help me out",
        "give me a hand", "lend me a hand", "support", "aid"
      ],
      "responses": []
    },
    "happy": {
      "patterns": [
        "happy", "great", "awesome", "love", "amazing", "perfect",
        "cool", "nice", "excellent", "wonderful", "fantastic", "brilliant",
        "superb", "outstanding", "magnificent", "splendid", "terrific",
        "fabulous", "marvelous", "stellar", "epic", "legendary",
        "I'm happy", "I'm glad", "I'm excited", "I'm thrilled"
      ],
      "responses": []
    },
    "frustrated": {
      "patterns": [
        "frustrated", "annoying", "stupid", "dumb", "broken",
        "doesn't work", "not working", "fail", "error", "wrong",
        "bad", "terrible", "hate", "useless", "crap", "garbage",
        "waste of time", "I'm angry", "I'm mad", "I'm upset",
        "this sucks", "this is bad", "I'm disappointed"
      ],
      "responses": []
    }
  }
}
PATTERNS
}

# Count total patterns
nlp_count_patterns() {
  nlp_670_patterns | python3 -c "
import sys, json
data = json.load(sys.stdin)
total = sum(len(v['patterns']) for v in data['intents'].values())
print(f'Total patterns: {total}')
" 2>/dev/null
}

# Get all patterns as flat list
nlp_all_patterns() {
  nlp_670_patterns | python3 -c "
import sys, json
data = json.load(sys.stdin)
for intent, info in data['intents'].items():
    for p in info['patterns']:
        print(f'{intent}|{p}')
" 2>/dev/null
}

# Match input to intent
nlp_match_670() {
  local input="$1"
  local input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')

  nlp_670_patterns | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
input_text = '$input_lower'
best_intent = 'unknown'
best_score = 0

for intent, info in data['intents'].items():
    for pattern in info['patterns']:
        pattern_lower = pattern.lower()
        # Exact match
        if input_text == pattern_lower:
            score = 100
        # Contains match
        elif pattern_lower in input_text or input_text in pattern_lower:
            score = 80
        # Word overlap
        else:
            input_words = set(input_text.split())
            pattern_words = set(pattern_lower.split())
            overlap = len(input_words & pattern_words)
            score = (overlap / max(len(pattern_words), 1)) * 60

        if score > best_score:
            best_score = score
            best_intent = intent

if best_score > 30:
    print(best_intent)
else:
    print('unknown')
" 2>/dev/null
}

echo "[nlp-670-patterns] loaded — $(nlp_count_patterns)"

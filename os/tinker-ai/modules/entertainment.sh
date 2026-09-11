#!/usr/bin/env bash
# entertainment.sh — games, recommendations, jokes, trivia, memory

ai_entertainment_joke() {
  local category="${1:-general}"
  python3 -c "
import random
category = '$category'

jokes = {
    'general': [
        'Why do programmers prefer dark mode? Because light attracts bugs.',
        'I told my computer I needed a break. Now it keeps sending me vacation ads.',
        'There are only 10 types of people in the world: those who understand binary and those who do not.',
        'A SQL query walks into a bar, sees two tables and asks... Can I join you?',
        'Why was the JavaScript developer sad? Because he did not Node how to Express himself.',
    ],
    'tech': [
        'How many programmers does it take to change a light bulb? None, that is a hardware problem.',
        'Why do Java developers wear glasses? Because they cannot C#.',
        'What is a programmer? Someone who solves a problem you did not know you had in a way you do not understand.',
        'Debugging is like being a detective in a crime movie where you are also the murderer.',
    ],
    'science': [
        'I told a chemistry joke... there was no reaction.',
        'Schr\u00f6dinger\'s cat walks into a bar... and does not.',
        'A photon checks into a hotel. The bellhop asks, Need help with your luggage? The photon replies, No thanks, I am traveling light.',
    ],
    'dad': [
        'I am reading a book about anti-gravity. It is impossible to put down.',
        'Did you hear about the claustrophobic astronaut? He just needed a little space.',
        'I used to hate facial hair, but then it grew on me.',
        'What do you call a fake noodle? An impasta.',
    ],
}

print(random.choice(jokes.get(category, jokes['general'])))
" 2>/dev/null || echo "Why did the scarecrow win an award? He was outstanding in his field."
}

ai_entertainment_trivia() {
  local category="${1:-general}"
  python3 -c "
import random
category = '$category'

trivia = {
    'general': [
        {'q': 'What is the capital of Australia?', 'a': 'Canberra', 'hint': 'Not Sydney or Melbourne'},
        {'q': 'How many bones are in the human body?', 'a': '206', 'hint': 'More than 150, less than 300'},
        {'q': 'What year was the first iPhone released?', 'a': '2007', 'hint': 'Between 2005 and 2010'},
        {'q': 'What is the largest ocean on Earth?', 'a': 'Pacific Ocean', 'hint': 'Covers more area than all land combined'},
        {'q': 'What element has the chemical symbol Au?', 'a': 'Gold', 'hint': 'From the Latin word aurum'},
    ],
    'science': [
        {'q': 'What planet is known as the Red Planet?', 'a': 'Mars', 'hint': 'The fourth planet from the Sun'},
        {'q': 'What is the speed of light in km/s?', 'a': '299,792 km/s', 'hint': 'About 300,000'},
        {'q': 'What gas do plants absorb from the atmosphere?', 'a': 'CO2 (Carbon Dioxide)', 'hint': 'Humans exhale this'},
    ],
    'history': [
        {'q': 'In what year did World War II end?', 'a': '1945', 'hint': 'Mid-1940s'},
        {'q': 'Who painted the Mona Lisa?', 'a': 'Leonardo da Vinci', 'hint': 'Italian Renaissance artist'},
        {'q': 'What ancient wonder was located in Giza?', 'a': 'The Great Pyramid', 'hint': 'The only surviving ancient wonder'},
    ],
}

item = random.choice(trivia.get(category, trivia['general']))
print(f'Trivia ({category}):')
print(f'  Q: {item[\"q\"]}')
print(f'  Hint: {item[\"hint\"]}')
print(f'  A: {item[\"a\"]}')
" 2>/dev/null || echo "Trivia unavailable"
}

ai_entertainment_game() {
  local game="${1:-20q}" topic="${2:-}"
  case "$game" in
    20q|20questions)
      echo "=== 20 Questions ==="
      echo "Think of something and I will try to guess it!"
      echo ""
      echo "1. Is it alive?"
      echo "2. Is it bigger than a bread box?"
      echo "3. Is it man-made?"
      echo "4. Is it something you can hold?"
      echo "5. Is it useful?"
      echo ""
      echo "(Tell me yes/no/maybe to narrow it down!)"
      ;;
    riddle)
      python3 -c "
import random
riddles = [
    {'riddle': 'I have cities, but no houses. I have mountains, but no trees. I have water, but no fish. What am I?', 'answer': 'A map'},
    {'riddle': 'What has keys but no locks?', 'answer': 'A keyboard'},
    {'riddle': 'What gets wetter the more it dries?', 'answer': 'A towel'},
    {'riddle': 'I speak without a mouth and hear without ears. What am I?', 'answer': 'An echo'},
    {'riddle': 'What can travel around the world while staying in a corner?', 'answer': 'A stamp'},
]
r = random.choice(riddles)
print(f'Riddle: {r[\"riddle\"]}')
print(f'Answer: ||{r[\"answer\"]}||')
" 2>/dev/null
      ;;
    wordgame)
      python3 -c "
import random
words = ['python','keyboard','mountain','algorithm','galaxy','whisper','puzzle','quantum','harmony','velocity']
word = random.choice(words)
hint = word[0] + '_' * (len(word)-2) + word[-1]
print(f'Word Game: Guess the word!')
print(f'Hint: {hint} ({len(word)} letters)')
print(f'First letter: {word[0].upper()}, Last letter: {word[-1].upper()}')
" 2>/dev/null
      ;;
  esac
}

ai_entertainment_recommend() {
  local type="${1:-movie}" mood="${2:-}"
  python3 -c "
import random
rtype = '$type'
mood = '$mood'

recs = {
    'movie': [
        {'title': 'Inception', 'year': 2010, 'genre': 'Sci-Fi/Thriller', 'rating': '8.8/10'},
        {'title': 'The Matrix', 'year': 1999, 'genre': 'Sci-Fi/Action', 'rating': '8.7/10'},
        {'title': 'Interstellar', 'year': 2014, 'genre': 'Sci-Fi/Drama', 'rating': '8.6/10'},
        {'title': 'Parasite', 'year': 2019, 'genre': 'Thriller/Drama', 'rating': '8.5/10'},
    ],
    'book': [
        {'title': 'Dune', 'author': 'Frank Herbert', 'genre': 'Sci-Fi', 'rating': '4.3/5'},
        {'title': '1984', 'author': 'George Orwell', 'genre': 'Dystopian', 'rating': '4.2/5'},
        {'title': 'The Hitchhiker Guide', 'author': 'Douglas Adams', 'genre': 'Comedy/Sci-Fi', 'rating': '4.4/5'},
    ],
    'music': [
        {'title': 'Bohemian Rhapsody', 'artist': 'Queen', 'genre': 'Rock'},
        {'title': 'Blinding Lights', 'artist': 'The Weeknd', 'genre': 'Synth-pop'},
        {'title': 'Stairway to Heaven', 'artist': 'Led Zeppelin', 'genre': 'Rock'},
    ],
}

items = recs.get(rtype, recs['movie'])
print(f'Recommended {rtype}s:')
print()
for i, item in enumerate(items, 1):
    print(f'{i}. {item.get(\"title\", \"?\")}')
    for k, v in item.items():
        if k != 'title':
            print(f'   {k}: {v}')
    print()
" 2>/dev/null || echo "Recommendations unavailable"
}

ai_entertainment_persona() {
  local persona="${1:-pirate}"
  python3 -c "
persona = '$persona'
personas = {
    'pirate': 'Yarr! I be yer AI matey! Arrr, ask me anything and I will give ye the treasure of knowledge!',
    'shakespeare': 'Hark! What light through yonder window breaks? \'Tis the east, and I am thine humble AI assistant.',
    'robot': 'PROCESSING... QUERY RECEIVED. INITIATING HELPFUL RESPONSE SEQUENCE. BEEP BOOP.',
    'detective': 'Interesting question. *adjusts magnifying glass* The evidence points to one conclusion...',
    'chef': 'Bon appétit! Let me cook up the perfect answer for you, mon ami!',
    'surfer': 'Dude, that is a gnarly question! Let me catch this wave of knowledge for you!',
    'ninja': '*vanishes and reappears* The answer you seek... I have already prepared it.',
    'professor': 'Ah, an excellent question! Let me elaborate on this fascinating topic.',
}
import random
p = personas.get(persona.lower(), random.choice(list(personas.values())))
print(p)
" 2>/dev/null || echo "I am TinkerAI — ask me anything!"
}

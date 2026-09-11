#!/usr/bin/env bash
# textgen.sh — text generation, writing assistance, summarization, grammar

# Summarize text (extractive: pick top sentences by word frequency)
ai_text_summarize() {
  local text="$1" max_sentences="${2:-5}"
  echo "$text" | python3 -c "
import sys, re, math
text = sys.stdin.read()
sentences = re.split(r'[.!?]+', text)
sentences = [s.strip() for s in sentences if len(s.strip()) > 10]
if not sentences:
    print('No content to summarize.')
    sys.exit()
# Word frequency scoring
words = re.findall(r'\w+', text.lower())
freq = {}
for w in words:
    if len(w) > 3: freq[w] = freq.get(w, 0) + 1
# Score sentences
scored = []
for s in sentences:
    sw = re.findall(r'\w+', s.lower())
    score = sum(freq.get(w, 0) for w in sw) / max(len(sw), 1)
    scored.append((score, s))
scored.sort(key=lambda x: -x[0])
top = sorted(scored[:$max_sentences], key=lambda x: sentences.index(x[1]))
for _, s in top:
    print(s.strip() + '.')
" 2>/dev/null || echo "Unable to summarize."
}

# Grammar correction (basic rules-based)
ai_text_grammar() {
  local text="$1"
  echo "$text" | sed \
    -e 's/\bi\b/I/g' \
    -e "s/\bi'm\b/I'm/g" \
    -e "s/\bi've\b/I've/g" \
    -e "s/\bi'll\b/I'll/g" \
    -e "s/\bi'd\b/I'd/g" \
    -e "s/\bcant\b/can't/g" \
    -e "s/\bwont\b/won't/g" \
    -e "s/\bdont\b/don't/g" \
    -e "s/\bisnt\b/isn't/g" \
    -e "s/\barent\b/aren't/g" \
    -e "s/\bwasnt\b/wasn't/g" \
    -e "s/\bwerent\b/weren't/g" \
    -e "s/\bwouldnt\b/wouldn't/g" \
    -e "s/\bcouldnt\b/couldn't/g" \
    -e "s/\bshouldnt\b/shouldn't/g" \
    -e "s/\btheyre\b/they're/g" \
    -e "s/\byoure\b/you're/g" \
    -e "s/\bweve\b/we've/g" \
    -e "s/\blets\b/let's/g" \
    -e 's/  \+/ /g' \
    -e 's/^[a-z]/\U&/' \
    -e 's/\. \([a-z]\)/. \U\1/g'
}

# Paraphrase (synonym substitution + sentence restructuring)
ai_text_paraphrase() {
  local text="$1"
  echo "$text" | python3 -c "
import sys, random
text = sys.stdin.read()
synonyms = {
    'good': ['excellent', 'fine', 'solid', 'great', 'positive'],
    'bad': ['poor', 'weak', 'terrible', 'negative', 'subpar'],
    'big': ['large', 'huge', 'enormous', 'vast', 'substantial'],
    'small': ['tiny', 'little', 'compact', 'miniature', 'brief'],
    'fast': ['quick', 'rapid', 'swift', 'speedy', 'brisk'],
    'slow': ['leisurely', 'gradual', 'unhurried', 'sluggish'],
    'help': ['assist', 'support', 'aid', 'facilitate', 'enable'],
    'use': ['utilize', 'employ', 'leverage', 'apply', 'harness'],
    'make': ['create', 'build', 'construct', 'produce', 'craft'],
    'show': ['display', 'present', 'demonstrate', 'reveal', 'exhibit'],
    'think': ['consider', 'believe', 'reckon', 'suppose', 'assume'],
    'important': ['crucial', 'vital', 'essential', 'significant', 'critical'],
    'interesting': ['fascinating', 'compelling', 'intriguing', 'notable', 'engaging'],
    'problem': ['issue', 'challenge', 'difficulty', 'obstacle', 'concern'],
    'result': ['outcome', 'consequence', 'effect', 'finding', 'conclusion'],
}
import re
def replace(match):
    word = match.group(0).lower()
    if word in synonyms:
        return random.choice(synonyms[word])
    return word
output = re.sub(r'\b\w+\b', replace, text)
print(output)
" 2>/dev/null || echo "$text"
}

# Generate template-based content
ai_text_generate() {
  local topic="$1" type="${2:-email}"
  case "$type" in
    email)
      cat <<EOF
Subject: $topic

Dear [Recipient],

I am writing to discuss $topic. I believe this is an important matter that deserves our attention.

Please find the details below:

1. Overview of $topic
2. Key points and considerations
3. Proposed next steps

I look forward to hearing your thoughts.

Best regards,
[Your Name]
EOF
      ;;
    essay)
      cat <<EOF
# $topic

## Introduction
$topic is a subject that has gained significant attention in recent years. This essay explores its various dimensions and implications.

## Background
Understanding $topic requires examining its historical context and the factors that have contributed to its current state.

## Analysis
The key aspects of $topic include several important considerations:
- First, we must acknowledge the complexity of the issue
- Second, multiple perspectives exist on this topic
- Third, evidence-based approaches yield the best outcomes

## Conclusion
In summary, $topic remains a vital area of discussion. Further research and dialogue will be essential to advancing our understanding.

## References
[Add your sources here]
EOF
      ;;
    report)
      cat <<EOF
# Report: $topic

**Date:** $(date '+%Y-%m-%d')
**Author:** TinkerAI

## Executive Summary
This report provides an analysis of $topic, covering key findings, methodology, and recommendations.

## Key Findings
- Finding 1: Overview of primary data points
- Finding 2: Secondary observations
- Finding 3: Notable trends or patterns

## Methodology
Data was gathered through [research methods] and analyzed using [approach].

## Recommendations
1. [Primary recommendation]
2. [Secondary recommendation]
3. [Additional consideration]

## Appendix
[Supporting data and charts]
EOF
      ;;
    poem)
      local lines=()
      lines+=("Words flow like rivers through the mind,")
      lines+=("Each verse a world for us to find,")
      lines+=("About $topic, we write and dream,")
      lines+=("In poetry, all things gleam.")
      printf '%s\n' "${lines[@]}"
      ;;
    story)
      cat <<EOF
# The Tale of $topic

Once upon a time, in a land not so different from our own, there existed a profound mystery known as $topic.

It began on an ordinary day, when someone asked a simple question about $topic. What followed was an extraordinary journey of discovery.

Through trials and triumphs, the answer emerged — not as a single revelation, but as a tapestry woven from countless threads of knowledge.

And so, the story of $topic continues, with each new generation adding its own chapter to the ever-growing narrative.

The End.
EOF
      ;;
  esac
}

# Brainstorm ideas
ai_text_brainstorm() {
  local topic="$1" n="${2:-8}"
  echo "Brainstorming ideas for: $topic"
  echo "---"
  echo "1. What if we approached $topic from a completely different angle?"
  echo "2. How could we combine $topic with emerging technology?"
  echo "3. What are the unconventional uses of $topic?"
  echo "4. How might $topic evolve in the next 5 years?"
  echo "5. What are the hidden opportunities in $topic?"
  echo "6. How could we simplify $topic for a broader audience?"
  echo "7. What partnerships could accelerate $topic?"
  echo "8. What would the ideal version of $topic look like?"
}

# Count words, characters, sentences, reading time
ai_text_stats() {
  local text="$1"
  local words=$(echo "$text" | wc -w)
  local chars=$(echo "$text" | wc -c)
  local sentences=$(echo "$text" | grep -oP '[.!?]+' | wc -l)
  local read_time=$((words / 200 + 1))
  echo "words: $words | chars: $chars | sentences: $sentences | ~${read_time}min read"
}

# --- EMAIL DRAFTING ---
ai_text_email() {
  local to="$1" purpose="$2" tone="${3:-professional}"
  python3 -c "
to = '$to'
purpose = '''$purpose'''
tone = '$tone'

templates = {
    'professional': {
        'greeting': f'Dear {to},',
        'body': purpose,
        'closing': 'Best regards,',
    },
    'casual': {
        'greeting': f'Hey {to},',
        'body': purpose,
        'closing': 'Cheers,',
    },
    'formal': {
        'greeting': f'Dear Mr./Ms. {to},',
        'body': purpose,
        'closing': 'Sincerely,',
    },
    'persuasive': {
        'greeting': f'Hi {to},',
        'body': purpose,
        'closing': 'Looking forward to your thoughts,',
    },
    'empathetic': {
        'greeting': f'Dear {to},',
        'body': purpose,
        'closing': 'With care,',
    },
}

t = templates.get(tone, templates['professional'])
print(f'{t[\"greeting\"]}')
print()
print(f'{t[\"body\"]}')
print()
print(f'{t[\"closing\"]}')
" 2>/dev/null || echo "To: $to\n\n$purpose"
}

# --- BLOG POST / ARTICLE ---
ai_text_blog() {
  local topic="$1" style="${2:-informative}" words="${3:-800}"
  python3 -c "
topic = '''$topic'''
style = '$style'
target = int('$words')

sections = {
    'informative': [
        ('Introduction', f'A comprehensive look at {topic} and why it matters today.'),
        ('Background', f'The history and evolution of {topic} provides essential context.'),
        ('Key Concepts', f'Understanding the core principles behind {topic} is crucial.'),
        ('Current State', f'Where {topic} stands today and recent developments.'),
        ('Practical Applications', f'How {topic} is being used in real-world scenarios.'),
        ('Future Outlook', f'What the future holds for {topic} and emerging trends.'),
        ('Conclusion', f'Summary of key takeaways about {topic}.'),
    ],
    'howto': [
        ('What You Will Learn', f'Step-by-step guide to mastering {topic}.'),
        ('Prerequisites', f'What you need before getting started with {topic}.'),
        ('Step 1: Getting Started', f'The foundation of {topic} begins here.'),
        ('Step 2: Core Techniques', f'Master the essential skills of {topic}.'),
        ('Step 3: Advanced Tips', f'Level up your {topic} expertise.'),
        ('Common Mistakes', f'Pitfalls to avoid when working with {topic}.'),
        ('Resources', f'Further reading and tools for {topic}.'),
    ],
    'opinion': [
        ('The Big Question', f'What does {topic} really mean for us?'),
        ('My Take', f'After extensive experience with {topic}, here is my perspective.'),
        ('The Evidence', f'Supporting data and examples for this viewpoint.'),
        ('Counterarguments', f'Fair consideration of opposing views on {topic}.'),
        ('The Verdict', f'Why this perspective on {topic} holds up.'),
        ('Call to Action', f'What you should do about {topic} today.'),
    ],
}

import random
sections_list = sections.get(style, sections['informative'])

print(f'# {topic.title()}')
print()
for title, desc in sections_list:
    print(f'## {title}')
    print()
    print(f'{desc}')
    print()
    print(f'[Expand on {title.lower()} with detailed content, examples, and analysis]')
    print()

print(f'---')
print(f'*Estimated word count: ~{target} words*')
" 2>/dev/null || echo "Blog outline for: $topic"
}

# --- SOCIAL MEDIA CAPTIONS ---
ai_text_social() {
  local topic="$1" platform="${2:-generic}"
  python3 -c "
topic = '''$topic'''
platform = '$platform'

captions = {
    'twitter': [
        f'🚀 {topic} — here is why it matters (thread)',
        f'Hot take: {topic} is about to change everything. Here is what most people miss:',
        f'Just discovered something fascinating about {topic}. The implications are huge.',
        f'Stop scrolling. {topic} deserves your attention right now.',
    ],
    'instagram': [
        f'✨ Exploring the world of {topic} and loving every moment of it ✨ #trending',
        f'{topic} — because life is too short for boring content 🌟',
        f'New day, new vibes, new {topic} adventures 🎯',
    ],
    'linkedin': [
        f'After years of working with {topic}, here are the lessons I wish I knew earlier:',
        f'{topic} is evolving fast. Here is what leaders need to know in 2026:',
        f'The intersection of {topic} and innovation — a thread on what matters most.',
    ],
    'tiktok': [
        f'POV: you just learned about {topic} and now you cannot stop talking about it',
        f'{topic} explained in 30 seconds (you need this)',
        f'Nobody talks about {topic} but here is why you should',
    ],
    'generic': [
        f'Excited to share my thoughts on {topic}',
        f'{topic} — a deep dive into what makes it special',
        f'Exploring {topic} today. What are your thoughts?',
    ],
}

import random
caps = captions.get(platform, captions['generic'])
for i, c in enumerate(random.sample(caps, min(3, len(caps))), 1):
    print(f'{i}. {c}')
" 2>/dev/null || echo "Social captions for: $topic"
}

# --- COPYWRITING ---
ai_text_copywriting() {
  local product="$1" type="${2:-tagline}"
  python3 -c "
product = '''$product'''
type = '$type'

if type == 'tagline':
    import random
    taglines = [
        f'{product} — designed for the bold.',
        f'Meet {product}. Your new obsession.',
        f'{product}. Because average is not enough.',
        f'Introducing {product}. The future is here.',
        f'{product}. Less waiting. More living.',
    ]
    print('Taglines:')
    for i, t in enumerate(random.sample(taglines, 5), 1):
        print(f'  {i}. {t}')

elif type == 'description':
    print(f'Product: {product}')
    print()
    print(f'Discover the power of {product} — crafted for those who demand excellence. Whether you are a professional, a creator, or someone who simply appreciates quality, {product} delivers an unmatched experience.')
    print()
    print(f'Key benefits:')
    print(f'  • Premium quality you can trust')
    print(f'  • Designed with you in mind')
    print(f'  • Effortless and intuitive')
    print(f'  • Built to last')

elif type == 'ad':
    print(f'=== Ad Copy: {product} ===')
    print()
    print(f'HEADLINE: Still struggling without {product}?')
    print()
    print(f'BODY: Every day, thousands of people discover how {product} transforms their workflow. The secret? A perfect blend of simplicity and power.')
    print()
    print(f'CTA: Try {product} free for 30 days. No credit card required.')
    print()
    print(f'SUBHEADLINE: Join the movement. Choose {product}.')
" 2>/dev/null || echo "Copywriting for: $product"
}

# --- POETRY & LYRICS ---
ai_text_poetry() {
  local topic="$1" style="${2:-freeverse}" meter="${3:-}"
  python3 -c "
import random
topic = '''$topic'''
style = '$style'

poems = {
    'freeverse': [
        f'In the quiet of {topic},',
        f'  I find a rhythm,',
        f'  a pulse that echoes',
        f'  through the spaces between.',
        f'',
        f'{topic} is not just a word —',
        f'  it is a feeling,',
        f'  a current that pulls',
        f'  at the edges of what we know.',
        f'',
        f'And in that pull,',
        f'  we discover something true:',
        f'  that {topic}',
        f'  was always part of us.',
    ],
    'haiku': [
        f'{topic[:12]}... ',
        f'  whispers through the morning,',
        f'  silence speaks volumes.',
    ],
    'limerick': [
        f'There once was a concept called {topic[:10]},',
        f'  Which everyone thought was a flop-ic.',
        f'  But with time it grew strong,',
        f'  And proved the crowd wrong,',
        f'  Now {topic[:10]} is topping the topic!',
    ],
    'sonnet': [
        f'Shall I compare {topic} to a summer day?',
        f'Thou art more lovely and more temperate.',
        f'Rough winds do shake the darling buds of May,',
        f'And {topic} hath its own determinate.',
        f'',
        f'Sometime too hot the eye of heaven shines,',
        f'And often is his gold complexion dimm\'d;',
        f'But {topic} never fades, nor ever declines,',
        f'Nor loses the grip by which it is brimm\'d.',
        f'',
        f'So long as men can breathe, or eyes can see,',
        f'So long lives {topic}, and {topic} gives life to thee.',
    ],
    'rap': [
        f'Yo, let me tell you about {topic},',
        f'  It is the real deal, not a myth or a prop.',
        f'  From the ground up, built with intent,',
        f'  Every bar I spit, it is evidence.',
        f'',
        f'{topic} hitting different, no cap,',
        f'  Every single line, a snapped trap.',
        f'  If you know, you know, if you do not, you will,',
        f'  {topic} is the future, and the future is real.',
    ],
}

import random
poem_lines = poems.get(style, poems['freeverse'])
for line in poem_lines:
    print(line)
" 2>/dev/null || echo "Poem about: $topic"
}

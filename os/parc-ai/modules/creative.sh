#!/usr/bin/env bash
# creative.sh — prompt engineering, brainstorming, analogies, perspectives, mood boards

# Refine a rough idea into a specific prompt
ai_creative_prompt() {
  local idea="$1" style="${2:-general}"
  python3 -c "
idea = '''$idea'''
style = '$style'

templates = {
    'general': f'''Refined prompt based on your idea:

\"Create a detailed, comprehensive piece about {idea}. Include:
1. A clear introduction establishing context
2. Key points with supporting evidence or examples
3. Practical applications or actionable takeaways
4. A conclusion that synthesizes the main ideas

Target audience: General readers interested in {idea}.
Tone: Informative and engaging.
Length: 500-800 words.\"''',

    'code': f'''Technical prompt for: {idea}

\"Write production-quality code that implements {idea}. Requirements:
- Include error handling and input validation
- Add inline comments for complex logic
- Follow language-specific best practices
- Include a brief README/explanation
- Provide example usage and test cases

Language: [specify]
Constraints: [performance, memory, compatibility]\"''',

    'writing': f'''Creative writing prompt based on: {idea}

\"Write a compelling piece about {idea}. Consider:
- Opening hook that grabs attention immediately
- Character/subject development with depth
- Conflict or tension that drives the narrative
- Vivid sensory details and imagery
- A satisfying resolution or thought-provoking ending

Style: Literary fiction / narrative non-fiction
Tone: [specify mood]
POV: [first person / third person / omniscient]\"''',

    'marketing': f'''Marketing prompt for: {idea}

\"Create a marketing campaign for {idea}. Include:
- Target audience persona (demographics, pain points, desires)
- 5 headline variations optimized for click-through
- Key value propositions (3-5 bullet points)
- Call-to-action options (3 variations)
- Social media post templates (Twitter, LinkedIn, Instagram)
- Email subject lines (5 A/B test pairs)

Brand voice: [professional / casual / bold]
Campaign goal: [awareness / conversion / retention]\"''',

    'academic': f'''Academic prompt for: {idea}

\"Research and analyze {idea}. Structure:
- Literature review of existing work
- Methodology (if applicable)
- Key findings and analysis
- Implications and future directions
- Proper citations in APA/MLA format

Scope: Peer-reviewed sources preferred
Audience: Academic researchers and practitioners\"''',
}

print(templates.get(style, templates['general']))
" 2>/dev/null || echo "Prompt refinement for: $idea"
}

# Generate 20+ naming options
ai_creative_names() {
  local concept="$1" style="${2:-tech}"
  python3 -c "
import random
concept = '$concept'
style = '$style'

prefixes = ['Neo', 'Pro', 'Ultra', 'Meta', 'Hyper', 'Omni', 'Alpha', 'Beta', 'Core', 'Syn', 'Ax', 'Zy', 'Vox', 'Lum', 'Flux', 'Pulse', 'Apex', 'Nova', 'Zen', 'Sky']
suffixes = ['ify', 'ly', 'io', 'ux', 'hub', 'lab', 'works', 'craft', 'flow', 'sync', 'bit', 'byte', 'wave', 'shift', 'spark', 'forge', 'sync', 'base', 'stack', 'mind']
concepts = concept.split()

print(f'Name suggestions for \"{concept}\":')
print('---')
count = 0
for i in range(25):
    method = random.choice(['prefix', 'suffix', 'compound', 'portmanteau'])
    if method == 'prefix':
        name = random.choice(prefixes) + random.choice(suffixes)
    elif method == 'suffix':
        name = random.choice(concepts[:1] if concepts else ['flow']).capitalize() + random.choice(suffixes)
    elif method == 'compound':
        word1 = random.choice(concepts[:1] if concepts else ['smart']).capitalize()
        word2 = random.choice(['Space', 'Wave', 'Hub', 'Lab', 'Core', 'Sync', 'Shift', 'Link'])
        name = word1 + word2
    else:
        w = random.choice(concepts[:1] if concepts else ['creative'])
        name = w[:3].capitalize() + random.choice(suffixes)
    count += 1
    print(f'{count:2d}. {name}')
" 2>/dev/null || echo "Name suggestions for: $concept"
}

# Generate taglines
ai_creative_tagline() {
  local product="$1"
  python3 -c "
product = '$product'
templates = [
    f'{product}. Because life is too short for ordinary.',
    f'{product}. Built different.',
    f'{product}. The future, delivered.',
    f'{product}. Less effort. More results.',
    f'{product}. Where ideas come alive.',
    f'{product}. Reimagine everything.',
    f'{product}. Simple. Powerful. Yours.',
    f'{product}. Made for what matters.',
    f'{product}. Beyond the ordinary.',
    f'{product}. Think bigger.',
    f'With {product}, everything just works.',
    f'{product}. Your way, every day.',
    f'{product}. Less is more.',
    f'{product}. Crafted for creators.',
    f'{product}. The smarter choice.',
]
import random; random.shuffle(templates)
print(f'Taglines for \"{product}\":')
for i, t in enumerate(templates[:10], 1):
    print(f'{i:2d}. {t}')
" 2>/dev/null || echo "Taglines for: $product"
}

# Analogy generator
ai_creative_analogy() {
  local concept="$1" audience="${2:-general}"
  python3 -c "
concept = '''$concept'''
audience = '$audience'

analogies = {
    'general': [
        f'Think of {concept} like a Swiss Army knife — one tool, many solutions.',
        f'{concept} is to [field] what a compass is to an explorer — it points the way.',
        f'{concept} works like gravity — invisible, constant, and essential.',
        f'{concept} is the scaffolding that lets the building rise.',
    ],
    'tech': [
        f'{concept} is like an API for reality — it defines how different parts communicate.',
        f'{concept} works like a compiler — taking abstract ideas and making them executable.',
        f'{concept} is the middleware between [problem] and [solution].',
    ],
    'business': [
        f'{concept} is like compound interest — small consistent efforts create exponential results.',
        f'{concept} works like a flywheel — each rotation builds momentum.',
        f'{concept} is the leverage point that multiplies every dollar spent.',
    ],
    'kids': [
        f'{concept} is like the engine in a car — you don\'t see it, but it makes everything go!',
        f'{concept} works like your immune system — protecting you from invisible threats.',
        f'{concept} is like a bridge — connecting two sides that were apart.',
    ],
}

import random
print(f'Analogies for \"{concept}\" ({audience} audience):')
print('---')
for a in random.sample(analogies.get(audience, analogies['general']), min(3, len(analogies.get(audience, analogies['general'])))):
    print(f'  {a}')
" 2>/dev/null || echo "Analogy for: $concept"
}

# Alternative perspective simulator
ai_creative_perspective() {
  local idea="$1" perspective="${2:-skeptic}"
  python3 -c "
idea = '''$idea'''
perspective = '$perspective'

perspectives = {
    'skeptic': {
        'title': 'The Skeptic',
        'points': [
            'What evidence supports this? Show me the data.',
            'What are the failure modes? How does this break?',
            'Who has tried this before and failed? Why?',
            'What are we not seeing? What are the blind spots?',
            'Is this solving a real problem or creating one?',
        ]
    },
    'investor': {
        'title': 'The Investor',
        'points': [
            'What is the total addressable market?',
            'What is the competitive moat? How defensible is this?',
            'What are unit economics? Path to profitability?',
            'Who is the team? Can they execute?',
            'What is the 10x improvement over existing solutions?',
        ]
    },
    'minimalist': {
        'title': 'The Minimalist',
        'points': [
            'Can we remove 50% of features and still deliver core value?',
            'What is the absolute simplest version of this?',
            'Are we adding complexity or reducing it?',
            'What can we cut? What is truly essential?',
            'If we had to launch tomorrow with half the scope, what stays?',
        ]
    },
    'user': {
        'title': 'The End User',
        'points': [
            'Does this actually make my life easier?',
            'How long until I see value? Is there instant gratification?',
            'Is this intuitive or do I need a manual?',
            'What happens when things go wrong? Is support helpful?',
            'Would I pay for this? Would I tell friends about it?',
        ]
    },
    'critic': {
        'title': 'The Critic',
        'points': [
            'This has been done before. What makes this different?',
            'The execution matters more than the idea. How will you execute?',
            'There are 10 things wrong with this. Let me list them.',
            'This works in theory but fails in practice. Here is why...',
            'The strongest argument against this is...',
        ]
    },
    'dreamer': {
        'title': 'The Dreamer',
        'points': [
            'What if we went 10x bigger? What would that look like?',
            'This could change everything if we push the boundaries.',
            'Imagine a world where this is the default. What changes?',
            'What is the boldest possible version of this?',
            'Forget constraints. If anything were possible, how would we build this?',
        ]
    },
}

p = perspectives.get(perspective, perspectives['skeptic'])
print(f'Perspective: {p[\"title\"]} — evaluating \"{idea[:60]}\"')
print('---')
for i, pt in enumerate(p['points'], 1):
    print(f'{i}. {pt}')
" 2>/dev/null || echo "Perspective analysis for: $idea"
}

# Visual mood board suggestions
ai_creative_moodboard() {
  local theme="$1"
  python3 -c "
import random
theme = '$theme'

palettes = {
    'warm': {'colors': ['#FF6B35', '#F7C59F', '#EFEFD0', '#004E89', '#1A659E'], 'fonts': 'Playfair Display + Lato', 'mood': 'Inviting, energetic, passionate'},
    'cool': {'colors': ['#0D1321', '#1D2D44', '#3E5C76', '#748CAB', '#F0EBD8'], 'fonts': 'Inter + Space Mono', 'mood': 'Professional, trustworthy, modern'},
    'nature': {'colors': ['#2D6A4F', '#40916C', '#52B788', '#74C69D', '#B7E4C7'], 'fonts': 'Outfit + DM Sans', 'mood': 'Fresh, organic, sustainable'},
    'luxury': {'colors': ['#0B0B0D', '#1A1A2E', '#C9A961', '#E8D5B7', '#F5F0E8'], 'fonts': 'Cormorant Garamond + Montserrat', 'mood': 'Elegant, premium, exclusive'},
    'tech': {'colors': ['#0F0F23', '#1A1A3E', '#6C63FF', '#00D4FF', '#E8E8E8'], 'fonts': 'JetBrains Mono + Space Grotesk', 'mood': 'Futuristic, innovative, precise'},
    'playful': {'colors': ['#FF595E', '#FFCA3A', '#8AC926', '#1982C4', '#6A4C93'], 'fonts': 'Fredoka + Nunito', 'mood': 'Fun, approachable, creative'},
    'minimal': {'colors': ['#FFFFFF', '#F5F5F5', '#E0E0E0', '#333333', '#000000'], 'fonts': 'Helvetica Neue + IBM Plex Sans', 'mood': 'Clean, focused, timeless'},
}

import random
theme_key = random.choice(list(palettes.keys()))
p = palettes[theme_key]

print(f'Mood board for \"{theme}\" ({theme_key} palette):')
print()
print('Color palette:')
for c in p['colors']:
    print(f'  {c}  ████████')
print()
print(f'Fonts: {p[\"fonts\"]}')
print(f'Mood: {p[\"mood\"]}')
print()
print('Style notes:')
print(f'  - Use plenty of whitespace')
print(f'  - Consistent spacing and alignment')
print(f'  - {theme_key} color accents on CTAs')
print(f'  - Photography style: [specify]')
print(f'  - Icon style: [line / filled / duotone]')
" 2>/dev/null || echo "Mood board for: $theme"
}

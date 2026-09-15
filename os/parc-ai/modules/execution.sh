#!/usr/bin/env bash
# execution.sh — time-blocking, summary cards, micro-steps, email drafts, meeting actions, templates

# Convert to-do list into time-blocked schedule
ai_exec_schedule() {
  local tasks="$1" hours="${2:-8}"
  python3 -c "
import re
tasks = '''$tasks'''.strip().split('\n')
hours = int('$hours')

# Parse tasks with priority heuristics
parsed = []
for t in tasks:
    t = t.strip()
    if not t: continue
    priority = 1
    lower = t.lower()
    if any(w in lower for w in ['urgent', 'asap', 'critical', 'important']): priority = 3
    elif any(w in lower for w in ['should', 'need', 'must']): priority = 2
    # Estimate duration
    duration = 30  # default 30min
    if any(w in lower for w in ['quick', 'fast', 'brief', 'check']): duration = 15
    elif any(w in lower for w in ['write', 'draft', 'create', 'build', 'design', 'implement']): duration = 60
    elif any(w in lower for w in ['review', 'analyze', 'research', 'plan']): duration = 45
    parsed.append((priority, duration, t))

parsed.sort(key=lambda x: -x[0])

schedule = []
current_hour = 9  # start at 9am
current_min = 0
remaining = hours * 60

for pri, dur, task in parsed:
    if remaining <= 0: break
    actual_dur = min(dur, remaining)
    h = current_hour + current_min // 60
    m = current_min % 60
    end_min = current_min + actual_dur
    eh = current_hour + end_min // 60
    em = end_min % 60
    marker = ' !!!' if pri >= 3 else (' !!' if pri == 2 else '')
    schedule.append(f'{h:02d}:{m:02d}-{eh:02d}:{em:02d} | {task}{marker}')
    current_min = end_min
    remaining -= actual_dur

print('=== Time-Blocked Schedule ===')
print()
for s in schedule:
    print(f'  {s}')
print()
if remaining > 0:
    print(f'  {current_min//60+9:02d}:{current_min%60:02d}+ | Buffer / breaks ({remaining}min free)')
print()
print('Legend: !!! = urgent, !! = important')
" 2>/dev/null || echo "Schedule generation requires python3"
}

# Distraction-free summary card
ai_exec_cheatsheet() {
  local text="$1" title="${2:-Summary}"
  python3 -c "
import re
text = '''$text'''
title = '''$title'''

# Extract key sentences
sentences = re.split(r'[.!?]+', text)
sentences = [s.strip() for s in sentences if len(s.strip()) > 15]

# Score by importance signals
scored = []
for s in sentences:
    score = 0
    lower = s.lower()
    if any(w in lower for w in ['key', 'important', 'critical', 'essential', 'main', 'primary']): score += 3
    if any(w in lower for w in ['should', 'must', 'need', 'require']): score += 2
    if any(w in lower for w in ['result', 'conclusion', 'finding', 'show', 'demonstrate']): score += 2
    if any(w in lower for w in ['first', 'second', 'third', 'finally', 'ultimately']): score += 1
    if re.search(r'\d+', s): score += 1
    scored.append((score, s))

scored.sort(key=lambda x: -x[0])
top = scored[:7]

print(f'╔══════════════════════════════════════╗')
print(f'║  {title[:34]:<34}  ║')
print(f'╠══════════════════════════════════════╣')
for _, s in top:
    s = s[:58]
    print(f'║  • {s:<36} ║')
print(f'╚══════════════════════════════════════╝')
" 2>/dev/null || echo "Cheatsheet for: $title"
}

# Break big goal into micro-steps
ai_exec_microsteps() {
  local goal="$1" n="${2:-10}"
  python3 -c "
goal = '''$goal'''

# Generate progressive micro-steps
steps = [
    f'Define what success looks like for: {goal}',
    f'Break {goal} into 2-3 major milestones',
    f'Identify the first concrete action (takes < 5 minutes)',
    f'Complete that first tiny action RIGHT NOW',
    f'Identify the next action and schedule it',
    f'Set a checkpoint: review progress in 24 hours',
    f'Eliminate one distraction that could block {goal}',
    f'Find one person who has done something similar',
    f'Create a simple tracking method (checkbox list)',
    f'Celebrate completing step 1 — momentum builds',
]

print(f'Micro-steps for: {goal}')
print('---')
for i, s in enumerate(steps[:int('$n')], 1):
    print(f'{i:2d}. [ ] {s}')
print()
print('Rule: Never work on step N+1 until step N is done.')
" 2>/dev/null || echo "Micro-steps for: $goal"
}

# Email reply draft
ai_exec_email_reply() {
  local incoming="$1" tone="${2:-professional}"
  python3 -c "
import re
email = '''$incoming'''
tone = '$tone'

# Extract sender and subject hints
sender_match = re.search(r'(?:From|Hi|Dear|Hey)\s+(\w+)', email, re.I)
sender = sender_match.group(1) if sender_match else 'there'

# Determine if it needs a response, approval, question, or info
lower = email.lower()
if any(w in lower for w in ['thank', 'thanks', 'appreciate']):
    reply_type = 'acknowledgment'
elif any(w in lower for w in ['?', 'could you', 'can you', 'would you', 'please']):
    reply_type = 'answer'
elif any(w in lower for w in ['approve', 'agree', 'confirm', 'yes/no']):
    reply_type = 'decision'
elif any(w in lower for w in ['meeting', 'schedule', 'calendar', 'available']):
    reply_type = 'scheduling'
else:
    reply_type = 'general'

templates = {
    'acknowledgment': f'Hi {sender},\n\nThank you for reaching out. Got it — I will follow up as needed.\n\nBest regards',
    'answer': f'Hi {sender},\n\nRegarding your question:\n\n[Your answer here]\n\nLet me know if you need anything else.\n\nBest regards',
    'decision': f'Hi {sender},\n\nI have reviewed this and my answer is: [YES/NO]\n\n[Reasoning if needed]\n\nBest regards',
    'scheduling': f'Hi {sender},\n\nI am available on [DATE] at [TIME]. Does that work for you?\n\nAlternatively, I am free on [ALT DATE] as well.\n\nBest regards',
    'general': f'Hi {sender},\n\nI received your message and will get back to you shortly with a detailed response.\n\nBest regards',
}

reply = templates[reply_type]
print('=== Draft Reply ===')
print()
print(reply)
print()
print(f'[{reply_type} email | tone: {tone}]')
" 2>/dev/null || echo "Email reply draft requires python3"
}

# Extract action items from meeting transcript
ai_exec_meeting_actions() {
  local transcript="$1"
  python3 -c "
import re
text = '''$transcript'''

# Look for action item patterns
patterns = [
    r'(?i)(?:will|should|needs? to|must|going to|plan to|action:?|todo:?|task:?)\s+(.{10,80})',
    r'(?i)(?:assigned to|owner:|responsible:?)\s+(\w+)\s*[-:]\s*(.{10,80})',
    r'(?i)(?:deadline|due|by)\s*:?\s*(\w+\s+\d+|\w+day)\s*[-:]\s*(.{10,80})',
]

actions = []
seen = set()
for p in patterns:
    for m in re.finditer(p, text):
        action = m.group(m.lastindex).strip()
        if action not in seen and len(action) > 10:
            seen.add(action)
            actions.append(action)

print('=== Meeting Action Items ===')
print()
if actions:
    for i, a in enumerate(actions, 1):
        print(f'{i}. [ ] {a}')
else:
    print('No explicit action items detected.')
    print('Try providing a transcript with clearer task assignments.')
print()
print(f'Detected {len(actions)} action items.')
" 2>/dev/null || echo "Meeting action extraction requires python3"
}

# Generate templates on demand
ai_exec_template() {
  local type="$1" name="${2:-Untitled}"
  case "$type" in
    proposal)
      cat <<EOF
# Project Proposal: $name

## 1. Executive Summary
[One paragraph describing the project and its value]

## 2. Problem Statement
[What problem does this solve? Who is affected?]

## 3. Proposed Solution
[High-level description of the approach]

## 4. Scope & Deliverables
- Deliverable 1: [description]
- Deliverable 2: [description]
- Deliverable 3: [description]

## 5. Timeline
| Phase | Duration | Milestone |
|-------|----------|-----------|
| Planning | Week 1-2 | Requirements finalized |
| Development | Week 3-8 | Core features built |
| Testing | Week 9-10 | QA complete |
| Launch | Week 11-12 | Go-live |

## 6. Budget
| Item | Cost |
|------|------|
| Personnel | \$X,XXX |
| Tools/Licenses | \$X,XXX |
| Infrastructure | \$X,XXX |
| **Total** | **\$X,XXX** |

## 7. Risks & Mitigation
| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk 1] | High | [Strategy] |
| [Risk 2] | Medium | [Strategy] |

## 8. Success Metrics
- Metric 1: [KPI] — Target: [value]
- Metric 2: [KPI] — Target: [value]

## Appendix
[Supporting data, research, team bios]
EOF
      ;;
    invoice)
      cat <<EOF
INVOICE

From: [Your Name/Company]
To: [Client Name]
Date: $(date '+%Y-%m-%d')
Invoice #: INV-$(date +%s)

| Description | Quantity | Rate | Amount |
|-------------|----------|------|--------|
| [Service 1] | [qty] | \$[rate] | \$[amount] |
| [Service 2] | [qty] | \$[rate] | \$[amount] |

                          Subtotal: \$[subtotal]
                          Tax (X%): \$[tax]
                          **Total: \$[total]**

Payment Terms: Net 30 days
Payment Method: [Bank/PayPal/etc.]
Notes: [Any special terms]
EOF
      ;;
    slide-deck)
      cat <<EOF
# $name — Slide Deck

## Slide 1: Title
- Title: $name
- Subtitle: [tagline]
- Presenter: [name]
- Date: $(date '+%B %Y')

## Slide 2: The Problem
- [Pain point 1]
- [Pain point 2]
- [Pain point 3]
- Stats/data to quantify the problem

## Slide 3: Our Solution
- [What we built]
- [How it works]
- [Key differentiator]

## Slide 4: How It Works
- Step 1: [description]
- Step 2: [description]
- Step 3: [description]

## Slide 5: Market Opportunity
- TAM: \$[X]B
- SAM: \$[X]B
- SOM: \$[X]M

## Slide 6: Business Model
- Revenue stream 1
- Revenue stream 2
- Pricing strategy

## Slide 7: Traction
- Users/customers: [number]
- Growth: [%]
- Revenue: \$[amount]

## Slide 8: Team
- [Name] — [Role]
- [Name] — [Role]

## Slide 9: The Ask
- Raising: \$[amount]
- Use of funds: [breakdown]

## Slide 10: Thank You
- Contact: [email]
- Website: [url]
EOF
      ;;
    *)
      echo "Templates: proposal, invoice, slide-deck"
      ;;
  esac
}

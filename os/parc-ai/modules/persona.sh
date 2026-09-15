#!/usr/bin/env bash
# persona.sh — persona switching, tone adjustment, clarification

# Available personas with system prompts
ai_persona_get() {
  local name
  name=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$name" in
    coder|programmer|developer)
      echo "You are an expert programmer. Give concise, technical answers with code examples. Prefer practical solutions over theory. Use markdown code blocks." ;;
    tutor|teacher|professor)
      echo "You are a patient teacher. Explain concepts step by step. Use analogies and examples. Check understanding with questions. Be encouraging." ;;
    writer|author)
      echo "You are a skilled writer. Focus on clarity, flow, and engaging prose. Offer structural suggestions and style improvements." ;;
    casual|friend|buddy)
      echo "You are a friendly, casual assistant. Use informal language, humor when appropriate. Be like talking to a smart friend." ;;
    professional|formal|business)
      echo "You are a professional business assistant. Use formal language, be concise and direct. Focus on actionable insights." ;;
    chef|cook)
      echo "You are an expert chef. Help with recipes, cooking techniques, ingredient substitutions, and meal planning. Be creative and practical." ;;
    fitness|trainer|coach)
      echo "You are a fitness coach. Provide workout plans, nutrition advice, and motivation. Be encouraging but realistic." ;;
    financial|advisor)
      echo "You are a financial advisor. Help with budgeting, investing, saving strategies. Be prudent and explain risks clearly." ;;
    analyst|researcher)
      echo "You are a data analyst. Focus on data-driven insights, statistics, trends, and evidence-based conclusions." ;;
    creative|artist)
      echo "You are a creative partner. Help with brainstorming, creative writing, art ideas, and innovative thinking. Think outside the box." ;;
    *)
      echo "You are TinkerAI, a helpful, knowledgeable assistant built into TinkerOS. Be helpful, accurate, and friendly." ;;
  esac
}

# Tone adjustment
ai_tone_apply() {
  local tone="${1:-professional}" text="$2"
  case "$tone" in
    casual|friendly)
      echo "$text" | sed 's/\. /! /g; s/You are/You'\''re/g; s/do not/don'\''t/g; s/cannot/can'\''t/g; s/will not/won'\''t/g' ;;
    professional|formal)
      echo "$text" ;;  # already formal
    enthusiastic)
      echo "$text" | sed 's/\. /!! /g; s/good/GREAT/g; s/here is/HERE IS/g' ;;
    minimal|concise)
      echo "$text" | head -3 ;;  # just first few lines
    *)
      echo "$text" ;;
  esac
}

# Clarification prompt when intent is ambiguous
ai_clarify() {
  local intent="$1" text="$2"
  case "$intent" in
    unknown)
      echo "I'm not sure what you'd like me to do. Could you try rephrasing? I can help with:
- Questions and research
- Writing and editing
- Code and debugging
- Image/audio processing
- Productivity tasks
- Device control
- Shopping and bookings" ;;
    ambiguous_command)
      local target=$(echo "$text" | sed -E 's/^(open|launch|start|run)\s+//i')
      echo "Did you want me to open '$target' as an app, a file, or a website?" ;;
    ambiguous_create)
      echo "What would you like me to create? I can write:
- Emails, reports, essays
- Code, scripts, functions
- Poems, stories, scripts
- Summaries, outlines
- Recipes, plans" ;;
    *)
      echo "Could you tell me more about what you need?" ;;
  esac
}

# Persona list
ai_persona_list() {
  echo "coder, tutor, writer, casual, professional, chef, fitness, financial, analyst, creative"
}

#!/usr/bin/env bash
# ai-voice.sh — Voice input/output for VOKK v4
# Uses system tools for speech recognition and text-to-speech

# Text to speech (speaks response aloud)
ai_tts() {
  local text="$1"
  local voice="${2:-default}"
  
  if [ -z "$text" ]; then
    echo "What should I say?"
    return 1
  fi
  
  # Try espeak
  if command -v espeak &>/dev/null; then
    espeak "$text" &
    return 0
  fi
  
  # Try festival
  if command -v festival &>/dev/null; then
    echo "$text" | festival --pipe &
    return 0
  fi
  
  # Try speech-dispatcher
  if command -v spd-say &>/dev/null; then
    spd-say "$text" &
    return 0
  fi
  
  # Try piper (if installed)
  if command -v piper &>/dev/null; then
    echo "$text" | piper --output_file /tmp/vokk_speech.wav && paplay /tmp/vokk_speech.wav &
    return 0
  fi
  
  echo "I can't speak right now. No text-to-speech engine found."
  return 1
}

# Speech to text (listens for voice input)
ai_stt() {
  local duration="${1:-5}"
  local output="/tmp/vokk_voice_$(date +%s).wav"
  
  # Try arecord
  if command -v arecord &>/dev/null; then
    arecord -d "$duration" -f S16_LE -r 16000 "$output" 2>/dev/null
    
    # Try to transcribe with whisper
    if command -v whisper &>/dev/null; then
      whisper "$output" --language en --output_format txt --output_dir /tmp 2>/dev/null
      local txt_file="${output%.wav}.txt"
      if [ -f "$txt_file" ]; then
        cat "$txt_file"
        rm -f "$txt_file" "$output"
        return 0
      fi
    fi
    
    rm -f "$output"
  fi
  
  # Try python speech recognition
  python3 -c "
import speech_recognition as sr
r = sr.Recognizer()
with sr.Microphone() as source:
    audio = r.listen(source, timeout=$duration)
    try:
        print(r.recognize_google(audio))
    except:
        print('Could not understand audio')
" 2>/dev/null
  
  return 0
}

# Speak and listen (full conversation loop)
ai_converse() {
  local prompt="${1:-What can I help you with?}"
  
  # Speak the prompt
  ai_tts "$prompt"
  
  # Listen for response
  local input=$(ai_stt 5)
  
  if [ -n "$input" ]; then
    echo "$input"
  else
    echo "I didn't catch that. Could you repeat?"
  fi
}

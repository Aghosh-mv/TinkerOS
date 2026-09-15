#!/usr/bin/env bash
# korrinos-voice.sh — System Voice Notifications + Voice Commands
# TTS for alerts, voice control via TinkerAI

set -euo pipefail

VOICE_DIR="${HOME}/.config/korrinos/voice"
VOICE_CONFIG="$VOICE_DIR/config.json"

mkdir -p "$VOICE_DIR"

init_voice() {
  if [ ! -f "$VOICE_CONFIG" ]; then
    cat > "$VOICE_CONFIG" << 'DEFAULTS'
{
  "tts_enabled": true,
  "tts_engine": "espeak",
  "tts_speed": 160,
  "tts_pitch": 50,
  "tts_voice": "en",
  "voice_commands_enabled": false,
  "wake_word": "tinker",
  "notifications": {
    "disk_full": true,
    "battery_low": true,
    "update_complete": true,
    "error": true,
    "success": false
  }
}
DEFAULTS
    echo "Voice config initialized"
  fi
}

# Text to speech
speak() {
  local text="$1"
  local enabled engine speed pitch voice
  
  enabled=$(python3 -c "import json; print(json.load(open('$VOICE_CONFIG'))['tts_enabled'])" 2>/dev/null || echo "true")
  [ "$enabled" = "False" ] && return 0
  
  engine=$(python3 -c "import json; print(json.load(open('$VOICE_CONFIG'))['tts_engine'])" 2>/dev/null || echo "espeak")
  speed=$(python3 -c "import json; print(json.load(open('$VOICE_CONFIG'))['tts_speed'])" 2>/dev/null || echo "160")
  pitch=$(python3 -c "import json; print(json.load(open('$VOICE_CONFIG'))['tts_pitch'])" 2>/dev/null || echo "50")
  voice=$(python3 -c "import json; print(json.load(open('$VOICE_CONFIG'))['tts_voice'])" 2>/dev/null || echo "en")
  
  case "$engine" in
    espeak)
      espeak -s "$speed" -p "$pitch" -v "$voice" "$text" 2>/dev/null
      ;;
    espeak-ng)
      espeak-ng -s "$speed" -p "$pitch" -v "$voice" "$text" 2>/dev/null
      ;;
    festival)
      echo "$text" | festival --tts 2>/dev/null
      ;;
    pico)
      pico2wave -w /tmp/tts_out.wav -l "$voice" "$text" 2>/dev/null && \
        paplay /tmp/tts_out.wav 2>/dev/null
      ;;
    say)
      say "$text" 2>/dev/null
      ;;
  esac
}

# Speak notification
notify_speak() {
  local type="$1"
  local msg="${2:-}"
  local enabled
  
  enabled=$(python3 -c "
import json
c = json.load(open('$VOICE_CONFIG'))
print(c.get('notifications', {}).get('$type', False))
" 2>/dev/null || echo "false")
  
  [ "$enabled" = "True" ] || return 0
  
  case "$type" in
    disk_full)    speak "Warning. Disk space is running low." ;;
    battery_low)  speak "Battery low. Please plug in your charger." ;;
    update_complete) speak "System update complete." ;;
    error)        speak "An error occurred. Check your screen." ;;
    success)      speak "Task complete." ;;
    *)            [ -n "$msg" ] && speak "$msg" ;;
  esac
}

# Voice command listener (simple version using sox/arecord)
voice_listen() {
  local duration="${1:-5}"
  local enabled
  
  enabled=$(python3 -c "import json; print(json.load(open('$VOICE_CONFIG'))['voice_commands_enabled'])" 2>/dev/null || echo "false")
  [ "$enabled" = "True" ] || { echo "Voice commands disabled. Enable with: korrinos-voice.sh toggle voice_commands_enabled"; return 1; }
  
  echo "Listening for ${duration}s... (say 'Tinker' to activate)"
  
  # Record audio
  if command -v arecord &>/dev/null; then
    arecord -d "$duration" -f S16_LE -r 16000 /tmp/voice_cmd.wav 2>/dev/null
    
    # Try to transcribe with whisper
    if command -v whisper &>/dev/null; then
      whisper /tmp/voice_cmd.wav --language en --output_format txt --output_dir /tmp 2>/dev/null
      local text=$(cat /tmp/voice_cmd.txt 2>/dev/null)
      echo "Heard: $text"
      
      # Check for wake word
      if echo "$text" | grep -qi "tinker"; then
        local cmd=$(echo "$text" | sed 's/.*tinker[: ]*//i')
        echo "Command: $cmd"
        execute_voice_cmd "$cmd"
      fi
    else
      echo "Install whisper for voice recognition: pip install openai-whisper"
    fi
  else
    echo "Install arecord: sudo apt install alsa-utils"
  fi
}

# Execute voice command
execute_voice_cmd() {
  local cmd="$1"
  
  case "$cmd" in
    *"time"*|*"what time"*)
      speak "It's $(date '+%I:%M %p')"
      ;;
    *"brightness"*)
      local level=$(echo "$cmd" | grep -o '[0-9]*' | head -1)
      [ -n "$level" ] && korrinos-settings.sh set display.brightness "$level" 2>/dev/null
      speak "Brightness set to $level percent"
      ;;
    *"volume"*|*"louder"*|*"quieter"*)
      local level=$(echo "$cmd" | grep -o '[0-9]*' | head -1)
      [ -n "$level" ] && korrinos-settings.sh set audio.volume "$level" 2>/dev/null
      speak "Volume set to $level percent"
      ;;
    *"open"*|*"launch"*)
      local app=$(echo "$cmd" | sed 's/.*open\|.*launch//i' | xargs)
      [ -n "$app" ] && nohup "$app" &>/dev/null &
      speak "Opening $app"
      ;;
    *"screenshot"*)
      korrinos-tools.sh screenshot 2>/dev/null
      speak "Screenshot taken"
      ;;
    *"lock"*)
      xdg-screensaver lock 2>/dev/null || loginctl lock-session 2>/dev/null
      speak "Screen locked"
      ;;
    *)
      # Send to TinkerAI
      if command -v parc-ai &>/dev/null; then
        local answer=$(parc-ai ask "$cmd" 2>/dev/null | head -1)
        speak "$answer"
      fi
      ;;
  esac
}

# Toggle settings
toggle() {
  local key="$1"
  python3 -c "
import json
with open('$VOICE_CONFIG') as f: c = json.load(f)
keys = '$key'.split('.')
d = c
for k in keys[:-1]: d = d[k]
k = keys[-1]
d[k] = not d.get(k, True)
with open('$VOICE_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print(f'$key = {d[k]}')
"
}

case "${1:-help}" in
  init)     init_voice ;;
  speak)    shift; speak "$@" ;;
  notify)   shift; notify_speak "$@" ;;
  listen)   shift; voice_listen "$@" ;;
  toggle)   shift; toggle "$@" ;;
  *)
    echo "KorrinOS Voice System"
    echo "Usage: korrinos-voice.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init                  Initialize voice config"
    echo "  speak <text>          Text to speech"
    echo "  notify <type> [msg]   Speak a notification"
    echo "  listen [duration]     Listen for voice commands"
    echo "  toggle <key>          Toggle setting"
    echo ""
    echo "Notification types: disk_full, battery_low, update_complete, error, success"
    ;;
esac

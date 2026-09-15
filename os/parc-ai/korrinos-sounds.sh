#!/usr/bin/env bash
# korrinos-sounds.sh — Boot Sound & Sound Theme System
# Custom startup chime, UI sounds, notification sounds, togglable

set -euo pipefail

SOUND_DIR="${HOME}/.config/korrinos/sounds"
SOUND_CONFIG="$SOUND_DIR/config.json"
SOUND_THEMES="/usr/share/korrinos/sounds"

mkdir -p "$SOUND_DIR"

# Default config
init_sounds() {
  if [ ! -f "$SOUND_CONFIG" ]; then
    cat > "$SOUND_CONFIG" << 'DEFAULTS'
{
  "enabled": true,
  "boot_sound": true,
  "theme": "korrin-default",
  "volume": 70,
  "sounds": {
    "boot": "boot.wav",
    "notification": "notify.wav",
    "error": "error.wav",
    "success": "success.wav",
    "click": "click.wav",
    "volume_up": "vol-up.wav",
    "volume_down": "vol-down.wav",
    "lock": "lock.wav",
    "logout": "logout.wav"
  }
}
DEFAULTS
    echo "Sound config initialized"
  fi
}

# Per-sound volume overrides (0-100). Boot is loud, error is quiet.
declare -A SOUND_VOLUME_OVERRIDE=(
  [boot.wav]=90
  [error.wav]=30
  [click.wav]=25
  [notify.wav]=50
  [success.wav]=55
)

# Play a sound
play_sound() {
  local sound_name="$1"
  local enabled volume theme
  
  enabled=$(python3 -c "import json; print(json.load(open('$SOUND_CONFIG'))['enabled'])" 2>/dev/null || echo "true")
  [ "$enabled" = "False" ] && return 0
  
  volume=$(python3 -c "import json; print(json.load(open('$SOUND_CONFIG'))['volume'])" 2>/dev/null || echo "70")
  theme=$(python3 -c "import json; print(json.load(open('$SOUND_CONFIG'))['theme'])" 2>/dev/null || echo "korrin-default")
  
  # Apply per-sound volume override if set
  local override="${SOUND_VOLUME_OVERRIDE[$sound_name]:-}"
  [ -n "$override" ] && volume="$override"
  
  local sound_file="$SOUND_THEMES/$theme/$sound_name"
  [ ! -f "$sound_file" ] && sound_file="$SOUND_DIR/$sound_name"
  [ ! -f "$sound_file" ] && return 0
  
  local vol=$((volume * 655 / 100))
  
  if command -v paplay &>/dev/null; then
    paplay --volume="$vol" "$sound_file" 2>/dev/null &
  elif command -v aplay &>/dev/null; then
    paplay "$sound_file" 2>/dev/null &
  elif command -v ffplay &>/dev/null; then
    ffplay -nodisp -autoexit -volume "$volume" "$sound_file" 2>/dev/null &
  fi
}

# Play boot sound
play_boot() {
  local boot_enabled
  boot_enabled=$(python3 -c "import json; print(json.load(open('$SOUND_CONFIG'))['boot_sound'])" 2>/dev/null || echo "true")
  [ "$boot_enabled" = "False" ] && return 0
  play_sound "boot.wav"
}

# Generate default sounds using sox or ffmpeg
generate_sounds() {
  local theme="${1:-korrin-default}"
  local dir="$SOUND_THEMES/$theme"
  mkdir -p "$dir"
  
  if command -v sox &>/dev/null; then
    # Boot chime — warm ascending tones
    sox -n "$dir/boot-chime.wav" synth 2.0 sine 440 sine 554 sine 659 \
      fade 0.1 2.0 0.5 vol 0.5
    
    # Notification — gentle ping
    sox -n "$dir/notify.wav" synth 0.5 sine 880 fade 0.05 0.5 0.2 vol 0.4
    
    # Error — low buzz
    sox -n "$dir/error.wav" synth 0.3 sine 200 fade 0.05 0.3 0.1 vol 0.5
    
    # Success — happy two-tone
    sox -n "$dir/success.wav" synth 0.4 sine 523 sine 659 fade 0.05 0.4 0.15 vol 0.4
    
    # Click — short tick
    sox -n "$dir/click.wav" synth 0.05 sine 1000 fade 0.01 0.05 0.01 vol 0.3
    
    # Volume up
    sox -n "$dir/vol-up.wav" synth 0.2 sine 600 sine 800 fade 0.02 0.2 0.05 vol 0.3
    
    # Volume down
    sox -n "$dir/vol-down.wav" synth 0.2 sine 800 sine 600 fade 0.02 0.2 0.05 vol 0.3
    
    # Lock
    sox -n "$dir/lock.wav" synth 0.3 sine 400 fade 0.05 0.3 0.1 vol 0.4
    
    # Logout
    sox -n "$dir/logout.wav" synth 0.5 sine 600 sine 400 fade 0.1 0.5 0.2 vol 0.4
    
    echo "Generated sound theme: $theme"
  elif command -v ffmpeg &>/dev/null; then
    # Boot chime via ffmpeg
    ffmpeg -f lavfi -i "sine=frequency=440:duration=2" -af "afade=t=in:ss=0:d=0.1,afade=t=out:st=1.5:d=0.5" "$dir/boot-chime.wav" -y 2>/dev/null
    
    ffmpeg -f lavfi -i "sine=frequency=880:duration=0.5" -af "afade=t=in:ss=0:d=0.05,afade=t=out:st=0.3:d=0.2" "$dir/notify.wav" -y 2>/dev/null
    
    ffmpeg -f lavfi -i "sine=frequency=200:duration=0.3" -af "afade=t=in:ss=0:d=0.05,afade=t=out:st=0.2:d=0.1" "$dir/error.wav" -y 2>/dev/null
    
    echo "Generated sound theme: $theme (ffmpeg)"
  else
    echo "Install sox or ffmpeg for sound generation"
  fi
}

# List available sound themes
list_themes() {
  echo "=== Sound Themes ==="
  if [ -d "$SOUND_THEMES" ]; then
    ls -1 "$SOUND_THEMES" 2>/dev/null
  fi
  echo ""
  echo "=== Current Theme ==="
  python3 -c "import json; print(json.load(open('$SOUND_CONFIG'))['theme'])" 2>/dev/null
}

# Toggle sounds
toggle() {
  local key="$1" val="${2:-}"
  if [ -n "$val" ]; then
    python3 -c "
import json
with open('$SOUND_CONFIG') as f: c = json.load(f)
c['$key'] = $val
with open('$SOUND_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print(f'$key = $val')
"
  else
    python3 -c "
import json
with open('$SOUND_CONFIG') as f: c = json.load(f)
c['$key'] = not c.get('$key', True)
with open('$SOUND_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print(f'$key = {c[\"$key\"]}')
"
  fi
}

# Set volume
set_volume() {
  local vol="$1"
  python3 -c "
import json
with open('$SOUND_CONFIG') as f: c = json.load(f)
c['volume'] = int('$vol')
with open('$SOUND_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print(f'Volume: {$vol}%')
"
}

# Install boot sound hook
install_hook() {
  local hook_dir="${HOME}/.config/autostart"
  mkdir -p "$hook_dir"
  cat > "$hook_dir/korrinos-boot-sound.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=KorrinOS Boot Sound
Exec=bash -c 'sleep 2 && korrinos-sounds.sh play boot'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
  echo "Boot sound hook installed"
}

case "${1:-help}" in
  init)         init_sounds ;;
  play)         shift; play_sound "$@" ;;
  boot)         play_boot ;;
  generate)     shift; generate_sounds "$@" ;;
  themes)       list_themes ;;
  toggle)       shift; toggle "$@" ;;
  volume)       shift; set_volume "$@" ;;
  hook)         install_hook ;;
  *)
    echo "KorrinOS Sound System"
    echo "Usage: korrinos-sounds.sh <command>"
    echo ""
    echo "Commands:"
    echo "  init              Initialize sound config"
    echo "  play <sound>      Play a sound"
    echo "  boot              Play boot chime"
    echo "  generate [theme]  Generate default sounds"
    echo "  themes            List sound themes"
    echo "  toggle <key>      Toggle setting (enabled/boot_sound)"
    echo "  volume <0-100>    Set volume"
    echo "  hook              Install boot sound autostart"
    ;;
esac

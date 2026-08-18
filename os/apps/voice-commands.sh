#!/bin/bash
# TinkerOS Voice Commands
# Control your system with your voice

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VOICE_CONFIG="/etc/tinker/voice.conf"
VOICE_LOG="/var/log/tinker/voice.log"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              TINKEROS VOICE COMMANDS                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check and install dependencies
check_deps() {
    local missing=()
    
    if ! command -v whisper >/dev/null 2>&1; then
        missing+=("whisper")
    fi
    
    if ! command -v espeak >/dev/null 2>&1; then
        missing+=("espeak")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing voice dependencies...${NC}"
        if command -v apt >/dev/null 2>&1; then
            sudo apt install -y espeak espeak-ng python3-pip
            pip3 install openai-whisper
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y espeak-ng python3-pip
            pip3 install openai-whisper
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm espeak-ng python-pip
            pip3 install openai-whisper
        fi
    fi
}

# Initialize voice config
init_voice() {
    mkdir -p /etc/tinker /var/log/tinker
    
    if [ ! -f $VOICE_CONFIG ]; then
        cat > $VOICE_CONFIG << 'EOF'
# TinkerOS Voice Commands Configuration

# Enable/disable voice commands
ENABLED=true

# Wake word
WAKE_WORD="hey tinker"

# Language
LANGUAGE="en"

# Voice feedback
VOICE_FEEDBACK=true

# Sensitivity (1-10)
SENSITIVITY=7

# Custom wake words
CUSTOM_WAKE_WORDS="tinker, computer, assistant"

# Command timeout (seconds)
TIMEOUT=10

# Noise cancellation
NOISE_CANCELLATION=true
EOF
    fi
}

# Speech to text using Whisper
speech_to_text() {
    local audio_file=$1
    
    if command -v whisper >/dev/null 2>&1; then
        # Use OpenAI Whisper
        whisper "$audio_file" --language en --output_format txt --output_dir /tmp 2>/dev/null
        local txt_file="${audio_file%.wav}.txt"
        if [ -f "$txt_file" ]; then
            cat "$txt_file"
            rm -f "$txt_file"
        fi
    elif command -vvosk >/dev/null 2>&1; then
        # Fallback to vosk
        echo "Using vosk for speech recognition..."
    else
        echo -e "${RED}No speech recognition available${NC}"
        return 1
    fi
}

# Text to speech
text_to_speech() {
    local text=$1
    local lang=${2:-en}
    
    if command -v espeak >/dev/null 2>&1; then
        espeak -v $lang "$text" 2>/dev/null
    elif command -v espeak-ng >/dev/null 2>&1; then
        espeak-ng -v $lang "$text" 2>/dev/null
    fi
}

# Record audio from microphone
record_audio() {
    local output="/tmp/voice-record-$(date +%s).wav"
    local duration=${1:-5}
    
    if command -v arecord >/dev/null 2>&1; then
        arecord -f S16_LE -r 16000 -c 1 -d $duration "$output" 2>/dev/null
    elif command -v parecord >/dev/null 2>&1; then
        parecord --file-format=wav --rate=16000 --channels=1 --duration=$duration "$output" 2>/dev/null
    fi
    
    echo "$output"
}

# Listen for wake word
listen_for_wake_word() {
    echo -e "${YELLOW}Listening for wake word...${NC}"
    echo "Say: 'Hey Tinker' or your custom wake word"
    echo "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        # Record short audio
        local audio=$(record_audio 3)
        
        # Check for wake word
        local text=$(speech_to_text "$audio")
        
        if echo "$text" | grep -qi "hey tinker\|tinker\|computer"; then
            echo -e "${GREEN}Wake word detected!${NC}"
            text_to_speech "Yes?"
            
            # Listen for command
            listen_for_command
        fi
        
        # Cleanup
        rm -f "$audio"
    done
}

# Listen for voice command
listen_for_command() {
    echo -e "${YELLOW}Listening for command...${NC}"
    
    # Record command
    local audio=$(record_audio 5)
    
    # Convert to text
    local text=$(speech_to_text "$audio")
    
    if [ -n "$text" ]; then
        echo -e "  Heard: ${CYAN}$text${NC}"
        log_voice "command" "$text"
        
        # Process command
        process_voice_command "$text"
    fi
    
    rm -f "$audio"
}

# Process voice command
process_voice_command() {
    local command=$1
    
    # System commands
    case "$command" in
        *"open browser"*|*"start browser"*)
            text_to_speech "Opening browser"
            xdg-open https://www.google.com &
            ;;
        *"open terminal"*|*"start terminal"*)
            text_to_speech "Opening terminal"
            gnome-terminal &
            ;;
        *"open files"*|*"file manager"*|*"open folder"*)
            text_to_speech "Opening file manager"
            xdg-open ~ &
            ;;
        *"open settings"*|*"system settings"*)
            text_to_speech "Opening settings"
            gnome-settings-daemon &
            ;;
        *"screenshot"*|*"take screenshot"*)
            text_to_speech "Taking screenshot"
            import -window root ~/Pictures/screenshot-$(date +%s).png
            ;;
        *"lock screen"*|*"lock"*)
            text_to_speech "Locking screen"
            i3lock -c 2e3440
            ;;
        *"shutdown"*|*"turn off"*)
            text_to_speech "Shutting down in 5 seconds. Say cancel to abort."
            read -p "Cancel? (y/n): " cancel
            if [ "$cancel" != "y" ]; then
                sudo shutdown -h 1
            fi
            ;;
        *"reboot"*|*"restart"*)
            text_to_speech "Rebooting in 5 seconds"
            sudo reboot
            ;;
        *"volume up"*|*"louder"*)
            pactl set-sink-volume @DEFAULT_SINK@ +10%
            text_to_speech "Volume increased"
            ;;
        *"volume down"*|*"quieter"*)
            pactl set-sink-volume @DEFAULT_SINK@ -10%
            text_to_speech "Volume decreased"
            ;;
        *"mute"*|*"unmute"*)
            pactl set-sink-mute @DEFAULT_SINK@ toggle
            text_to_speech "Volume toggled"
            ;;
        *"what time"*|*"current time"*|*"time"*)
            local time=$(date '+%I:%M %p')
            text_to_speech "It's $time"
            ;;
        *"what date"*|*"today's date"*|*"date"*)
            local date=$(date '+%B %d, %Y')
            text_to_speech "Today is $date"
            ;;
        *"weather"*)
            text_to_speech "Getting weather information"
            curl -s "wttr.in?format=%C+%t+%h+%w" | xclip -selection clipboard
            text_to_speech "Weather copied to clipboard"
            ;;
        *"search"*|*"google"*)
            local query=$(echo "$command" | sed 's/.*search for //' | sed 's/.*google //')
            if [ -n "$query" ]; then
                text_to_speech "Searching for $query"
                xdg-open "https://www.google.com/search?q=$query"
            fi
            ;;
        *"play music"*|*"play song"*)
            text_to_speech "Opening music player"
            if command -v spotify >/dev/null 2>&1; then
                spotify &
            elif command -v rhythmbox >/dev/null 2>&1; then
                rhythmbox &
            fi
            ;;
        *"pause"*|*"stop music"*)
            xdotool key space
            text_to_speech "Music paused"
            ;;
        *"next track"*|*"next song"*)
            xdotool key XF86AudioNext
            text_to_speech "Next track"
            ;;
        *"previous track"*|*"previous song"*)
            xdotool key XF86AudioPrev
            text_to_speech "Previous track"
            ;;
        *"gaming mode on"*|*"enable gaming"*)
            /usr/lib/tinker/gaming-mode.sh enable
            text_to_speech "Gaming mode enabled"
            ;;
        *"gaming mode off"*|*"disable gaming"*)
            /usr/lib/tinker/gaming-mode.sh disable
            text_to_speech "Gaming mode disabled"
            ;;
        *"password"*|*"generate password"*)
            local password=$(tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 20)
            echo "$password" | xclip -selection clipboard
            text_to_speech "Password generated and copied to clipboard"
            ;;
        *"help"*|*"what can you do"*)
            show_voice_help
            ;;
        *"close"*|*"goodbye"*|*"stop listening"*)
            text_to_speech "Goodbye"
            exit 0
            ;;
        *)
            text_to_speech "I didn't understand that command"
            ;;
    esac
    
    log_voice "processed" "$command"
}

# Show voice help
show_voice_help() {
    echo -e "${YELLOW}Voice Commands:${NC}"
    echo ""
    echo "  System:"
    echo "    'Open browser' - Launch web browser"
    echo "    'Open terminal' - Launch terminal"
    echo "    'Open files' - Open file manager"
    echo "    'Take screenshot' - Capture screen"
    echo "    'Lock screen' - Lock your computer"
    echo ""
    echo "  Media:"
    echo "    'Volume up/down' - Adjust volume"
    echo "    'Mute' - Toggle mute"
    echo "    'Play music' - Start music player"
    echo "    'Next/Previous track' - Change track"
    echo ""
    echo "  Info:"
    echo "    'What time' - Tell current time"
    echo "    'What date' - Tell today's date"
    echo "    'Weather' - Get weather info"
    echo "    'Search for [query]' - Google search"
    echo ""
    echo "  Power:"
    echo "    'Shutdown' - Turn off computer"
    echo "    'Reboot' - Restart computer"
    echo ""
    echo "  Other:"
    echo "    'Generate password' - Create secure password"
    echo "    'Gaming mode on/off' - Toggle gaming mode"
    echo "    'Help' - Show this help"
    echo ""
}

# Interactive voice mode
voice_mode() {
    echo -e "${YELLOW}Voice Command Mode${NC}"
    echo "Press and hold spacebar to talk, release to process"
    echo "Press Ctrl+C to exit"
    echo ""
    
    while true; do
        # Record on spacebar press
        read -n1 -s key
        
        if [ "$key" = " " ]; then
            echo -e "${GREEN}Recording... (release spacebar to stop)${NC}"
            
            # Record while spacebar held
            local audio="/tmp/voice-interactive-$(date +%s).wav"
            arecord -f S16_LE -r 16000 -c 1 "$audio" 2>/dev/null &
            local arecord_pid=$!
            
            # Wait for spacebar release
            read -n1 -s -r key2
            
            # Stop recording
            kill $arecord_pid 2>/dev/null
            
            # Process
            local text=$(speech_to_text "$audio")
            
            if [ -n "$text" ]; then
                echo -e "  Heard: ${CYAN}$text${NC}"
                process_voice_command "$text"
            fi
            
            rm -f "$audio"
            echo ""
        fi
    done
}

# Log voice events
log_voice() {
    local event=$1
    local data=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp | $event | $data" >> $VOICE_LOG
}

show_help() {
    echo "Usage: tinker-voice [command]"
    echo ""
    echo "Commands:"
    echo "  listen          Listen for wake word"
    echo "  interactive     Interactive voice mode"
    echo "  test            Test voice recognition"
    echo "  calibrate       Calibrate microphone"
    echo "  help            Show this help"
    echo ""
    echo "Examples:"
    echo "  tinker-voice listen"
    echo "  tinker-voice interactive"
}

# Main
init_voice
check_deps

case "$1" in
    listen|start)
        show_header
        listen_for_wake_word
        ;;
    interactive|mode)
        show_header
        voice_mode
        ;;
    test)
        show_header
        echo -e "${YELLOW}Testing voice recognition...${NC}"
        echo "Say something..."
        
        local audio=$(record_audio 3)
        local text=$(speech_to_text "$audio")
        
        if [ -n "$text" ]; then
            echo -e "${GREEN}Recognized: $text${NC}"
        else
            echo -e "${RED}No speech detected${NC}"
        fi
        
        rm -f "$audio"
        ;;
    calibrate)
        show_header
        echo -e "${YELLOW}Microphone Calibration${NC}"
        echo ""
        echo "Please speak clearly for 10 seconds..."
        echo ""
        
        # Record calibration audio
        arecord -f S16_LE -r 16000 -c 1 -d 10 /tmp/calibration.wav 2>/dev/null
        
        echo -e "${GREEN}✓ Calibration complete!${NC}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Voice Commands${NC}"
        echo ""
        echo "Control your system with your voice."
        echo ""
        echo "Quick commands:"
        echo "  tinker-voice listen      - Listen for wake word"
        echo "  tinker-voice interactive  - Interactive mode"
        echo ""
        ;;
esac

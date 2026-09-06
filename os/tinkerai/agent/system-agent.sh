#!/bin/bash
# TinkerOS System Agent - OpenCode as native AI backbone
# Ctrl+Space opens sidebar, type/speak intent, OS assembles everything
AGENT_DIR="$HOME/.tinker/agent"; AGENT_CONFIG="$AGENT_DIR/config.json"
AGENT_LOG="$AGENT_DIR/agent.log"; AGENT_HISTORY="$AGENT_DIR/history.json"
AGENT_CANVAS="$AGENT_DIR/canvas"; mkdir -p "$AGENT_DIR" "$AGENT_CANVAS"

init(){
  cat > "$AGENT_CONFIG" << 'EOF'
{
  "version": 1,
  "trigger": {"hotkey": "ctrl+space", "voice_keyword": "hey tinker", "double_tap_shift": true},
  "sidebar": {"position": "right", "width_pct": 30, "theme": "dark", "opacity": 95},
  "voice": {"enabled": true, "engine": "whisper-local", "language": "en", "continuous": false},
  "intent_engine": {
    "enabled": true,
    "auto_detect": true,
    "context_window": 10,
    "remember_patterns": true
  },
  "canvas": {
    "auto_save": true,
    "max_tabs": 20,
    "persistence": "session",
    "share_across_sessions": true
  },
  "integrations": {
    "unified_memory": true,
    "contextual_search": true,
    "cross_app_automation": true,
    "subscription_audit": true,
    "hardware_control": true
  },
  "privacy": {"voice_processing": "local", "no_cloud": true}
}
EOF
  echo "=== System Agent initialized ==="
  echo "  Hotkey: Ctrl+Space"
  echo "  Voice: 'Hey Tinker'"
  echo "  Engine: OpenCode (local AI)"
  echo "  Sidebar: right panel, 30% width"
}

# The keyboard shortcut daemon - listens for Ctrl+Space
hotkey_daemon(){
  echo "=== Starting Hotkey Daemon ==="
  echo "  Listening for: Ctrl+Space"
  echo "  Action: Toggle sidebar"
  
  cat > /tmp/tinker_hotkey.py << 'PYKEY'
#!/usr/bin/env python3
"""TinkerOS Hotkey Daemon - Ctrl+Space toggles AI sidebar"""
import subprocess, sys, os, json, time

try:
    import pynput
    from pynput import keyboard
except ImportError:
    print("Installing pynput...")
    subprocess.run([sys.executable, "-m", "pip", "install", "pynput", "--quiet"])
    import pynput
    from pynput import keyboard

SIDEBAR_RUNNING = False

def toggle_sidebar():
    global SIDEBAR_RUNNING
    if SIDEBAR_RUNNING:
        # Kill existing sidebar
        subprocess.run(["pkill", "-f", "tinker_sidebar"], capture_output=True)
        SIDEBAR_RUNNING = False
        print("[Agent] Sidebar closed")
    else:
        # Launch sidebar
        subprocess.Popen(["python3", os.path.expanduser("~/.tinker/agent/sidebar.py")],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        SIDEBAR_RUNNING = True
        print("[Agent] Sidebar opened")

def on_activate():
    toggle_sidebar()

# Global hotkey: Ctrl+Space
with keyboard.GlobalHotKeys({
    '<ctrl>+<space>': on_activate
}) as h:
    print("[Agent] Hotkey daemon running. Press Ctrl+Space to toggle sidebar.")
    print("[Agent] Press Ctrl+C to stop.")
    h.join()
PYKEY
  echo "  Daemon script: /tmp/tinker_hotkey.py"
  echo "  Run: python3 /tmp/tinker_hotkey.py"
}

# The sidebar UI - Siri-like text/voice interface
sidebar_ui(){
  cat > "$AGENT_DIR/sidebar.py" << 'PYSIDEBAR'
#!/usr/bin/env python3
"""TinkerOS AI Sidebar - Ctrl+Space triggered intent interface"""
import sys, os, json, subprocess, time
from datetime import datetime

AGENT_DIR = os.path.expanduser("~/.tinker/agent")
CANVAS_DIR = os.path.join(AGENT_DIR, "canvas")
CONFIG = json.load(open(os.path.join(AGENT_DIR, "config.json")))

# ── Intent Detection Engine ────────────────────────────────────────────
class IntentEngine:
    def __init__(self):
        self.patterns = {
            # File operations
            "find_file": ["find", "search", "look for", "where is", "locate"],
            "open_file": ["open", "show", "display", "read"],
            "create_file": ["create", "make", "new", "write", "draft"],
            "send_email": ["email", "send", "mail", "forward"],
            "schedule": ["schedule", "calendar", "meeting", "appointment", "remind"],
            
            # System operations
            "gpu_toggle": ["gpu", "graphics card", "turn on gpu", "turn off gpu"],
            "fan_control": ["fan", "cooling", "temperature", "thermal"],
            "brightness": ["brightness", "screen dim", "screen bright"],
            "volume": ["volume", "sound", "audio", "mute"],
            
            # Financial
            "subscription": ["subscription", "recurring", "billing", "payment"],
            "budget": ["budget", "spending", "cost", "expense"],
            
            # Privacy
            "privacy_shred": ["shred", "wipe", "privacy", "clean", "scrub"],
            "data_audit": ["audit", "track", "what am i paying"],
            
            # Automation
            "automate": ["automate", "macro", "workflow", "every time", "whenever"],
            
            # Hardware
            "hardware_info": ["system info", "what hardware", "specs", "diagnose"],
            "optimize": ["optimize", "speed up", "make faster", "performance"],
            
            # Search
            "search_memory": ["remember", "recall", "what did i", "find that"],
            "search_web": ["search", "google", "look up", "what is"],
        }
    
    def detect(self, text):
        text_lower = text.lower()
        detected = []
        for intent, keywords in self.patterns.items():
            if any(kw in text_lower for kw in keywords):
                detected.append(intent)
        return detected if detected else ["general_query"]

# ── Task Executor ──────────────────────────────────────────────────────
class TaskExecutor:
    def __init__(self):
        self.scripts = {
            "gpu_toggle": "os/hardware-tech/remote-hardware-api/gpu-phone-toggle.sh",
            "privacy_shred": "os/hardware-tech/data-shredder/data-shredder.sh",
            "subscription": "os/hardware-tech/finance-audit/subscription-audit.sh",
            "hardware_info": "os/hardware-tech/hardware-dna/hardware-dna.sh",
            "optimize": "os/hardware-tech/hardware-tuning/cpu-tuning.sh",
        }
    
    def execute(self, intent, user_input):
        if intent in self.scripts:
            script = os.path.expanduser(f"~/linux-kernel/{self.scripts[intent]}")
            if os.path.exists(script):
                result = subprocess.run(["bash", script, "status"], 
                                       capture_output=True, text=True, timeout=10)
                return result.stdout or result.stderr
        return self._ai_respond(user_input)
    
    def _ai_respond(self, query):
        """Use OpenCode/TinkerAI for general queries"""
        tinker_ai = os.path.expanduser("~/linux-kernel/os/tinkerai/tinker_ai.py")
        if os.path.exists(tinker_ai):
            try:
                result = subprocess.run(
                    ["python3", tinker_ai, "--query", query],
                    capture_output=True, text=True, timeout=30
                )
                return result.stdout or "I can help with that. Try asking about specific tasks."
            except:
                pass
        return f"I understand you want: {query}. Let me help with that."

# ── Voice Input ────────────────────────────────────────────────────────
class VoiceInput:
    def __init__(self):
        self.engine = "whisper"
    
    def listen(self):
        try:
            import speech_recognition as sr
            r = sr.Recognizer()
            with sr.Microphone() as source:
                print("🎤 Listening...")
                audio = r.listen(source, timeout=5)
                text = r.recognize_whisper(audio, model="base")
                return text
        except ImportError:
            return input("Voice unavailable. Type your command: ")
        except Exception as e:
            return input("Voice error. Type your command: ")

# ── Unified Canvas ─────────────────────────────────────────────────────
class UnifiedCanvas:
    def __init__(self):
        self.tabs = []
        self.current = None
    
    def create_tab(self, title, content, sources=None):
        tab = {
            "id": len(self.tabs) + 1,
            "title": title,
            "content": content,
            "sources": sources or [],
            "created": datetime.now().isoformat()
        }
        self.tabs.append(tab)
        self.current = tab
        # Save to canvas dir
        path = os.path.join(CANVAS_DIR, f"tab_{tab['id']}.json")
        with open(path, 'w') as f:
            json.dump(tab, f, indent=2)
        return tab
    
    def show(self):
        if not self.tabs:
            return "No open tabs"
        lines = ["=== Unified Canvas ==="]
        for t in self.tabs:
            marker = "→" if t == self.current else " "
            lines.append(f"  {marker} [{t['id']}] {t['title']}")
        return "\n".join(lines)

# ── Main Sidebar ───────────────────────────────────────────────────────
def main():
    engine = IntentEngine()
    executor = TaskExecutor()
    voice = VoiceInput()
    canvas = UnifiedCanvas()
    
    print("╔══════════════════════════════════════════════════════════╗")
    print("║         TinkerOS AI SIDEBAR (Ctrl+Space)              ║")
    print("╠══════════════════════════════════════════════════════════╣")
    print("║  Type or speak what you want to do.                   ║")
    print("║  Examples:                                            ║")
    print("║    'Turn on my GPU'                                   ║")
    print("║    'Write a contract for Client X'                    ║")
    print("║    'What subscriptions am I paying for?'              ║")
    print("║    'Find that email from last week'                   ║")
    print("║    'Optimize my system for gaming'                    ║")
    print("║  Commands: /voice, /canvas, /history, /quit           ║")
    print("╚══════════════════════════════════════════════════════════╝")
    
    history = []
    
    while True:
        try:
            user_input = input("\n🤖 > ").strip()
            
            if not user_input:
                continue
            
            if user_input == "/quit":
                print("Sidebar closed.")
                break
            
            if user_input == "/voice":
                user_input = voice.listen()
                print(f"  Heard: {user_input}")
            
            if user_input == "/canvas":
                print(canvas.show())
                continue
            
            if user_input == "/history":
                for h in history[-10:]:
                    print(f"  {h['time'][:16]} | {h['intent']:20s} | {h['query'][:50]}")
                continue
            
            # Detect intent
            intents = engine.detect(user_input)
            primary_intent = intents[0]
            
            # Execute
            print(f"  Intent: {', '.join(intents)}")
            result = executor.execute(primary_intent, user_input)
            
            # Show result in canvas
            tab = canvas.create_tab(
                title=user_input[:50],
                content=result,
                sources=intents
            )
            
            print(f"\n  📋 Result (Tab {tab['id']}):")
            for line in result.split('\n')[:20]:
                print(f"  {line}")
            
            # Log
            history.append({
                "time": datetime.now().isoformat(),
                "query": user_input,
                "intent": primary_intent,
                "tab_id": tab['id']
            })
            
        except KeyboardInterrupt:
            print("\nSidebar closed.")
            break
        except Exception as e:
            print(f"  Error: {e}")

if __name__ == "__main__":
    main()
PYSIDEBAR
  chmod +x "$AGENT_DIR/sidebar.py"
  echo "  Sidebar UI created: $AGENT_DIR/sidebar.py"
}

# Intent-Driven Task Router
intent_router(){
  cat > "$AGENT_DIR/intent-router.sh" << 'ROUTER'
#!/bin/bash
# TinkerOS Intent Router - maps natural language to system actions
AGENT_DIR="$HOME/.tinker/agent"

route(){
  local intent="$1"
  local query="$2"
  
  case "$intent" in
    # File operations
    find_file|open_file)
      find ~/Documents ~/Downloads ~/Desktop -iname "*$query*" 2>/dev/null | head -10
      ;;
    create_file)
      echo "Creating: $query"
      touch ~/Documents/"$query"
      ;;
    
    # Email
    send_email)
      echo "Drafting email: $query"
      # Integration with email client
      ;;
    
    # Hardware
    gpu_toggle)
      bash ~/linux-kernel/os/hardware-tech/remote-hardware-api/gpu-phone-toggle.sh toggle
      ;;
    fan_control)
      bash ~/linux-kernel/os/hardware-tech/hardware-tuning/thermal-tuning.sh status
      ;;
    brightness)
      bash ~/linux-kernel/os/hardware-tech/hardware-tuning/display-tuning.sh brightness ${3:-80}
      ;;
    volume)
      amixer set Master ${3:-50}% 2>/dev/null
      ;;
    
    # Privacy
    privacy_shred)
      bash ~/linux-kernel/os/hardware-tech/data-shredder/data-shredder.sh shred
      ;;
    subscription)
      bash ~/linux-kernel/os/hardware-tech/finance-audit/subscription-audit.sh dashboard
      ;;
    
    # System
    hardware_info)
      bash ~/linux-kernel/os/hardware-tech/hardware-dna/hardware-dna.sh init
      ;;
    optimize)
      bash ~/linux-kernel/os/hardware-tech/hardware-tuning/cpu-tuning.sh governor performance
      ;;
    
    # Search
    search_memory)
      bash ~/linux-kernel/os/hardware-tech/unified-memory/unified-contextual-memory.sh search "$query"
      ;;
    
    # General
    *)
      python3 ~/linux-kernel/os/tinkerai/tinker_ai.py --query "$query" 2>/dev/null || echo "I can help with that."
      ;;
  esac
}

case "${1:-help}" in
  route) route "$2" "$3" ;;
  *) echo "Usage: $0 route <intent> <query>";;
esac
ROUTER
  chmod +x "$AGENT_DIR/intent-router.sh"
  echo "  Intent router created"
}

# Voice command handler
voice_handler(){
  cat > "$AGENT_DIR/voice-handler.sh" << 'VOICE'
#!/bin/bash
# TinkerOS Voice Handler - speech-to-text -> intent -> action
AGENT_DIR="$HOME/.tinker/agent"

listen(){
  echo "🎤 Listening for voice command..."
  # Using whisper locally (no cloud)
  python3 - << 'PYVOICE'
import speech_recognition as sr
r = sr.Recognizer()
with sr.Microphone() as source:
    print("Speak now...")
    audio = r.listen(source, timeout=5)
    try:
        text = r.recognize_whisper(audio, model="base")
        print(f" Heard: {text}")
        # Route to intent engine
        import subprocess
        subprocess.run(["bash", "$AGENT_DIR/intent-router.sh", "route", "general", text])
    except Exception as e:
        print(f" Could not understand: {e}")
PYVOICE
}

case "${1:-help}" in
  listen) listen ;;
  *) echo "Usage: $0 listen";;
esac
VOICE
  chmod +x "$AGENT_DIR/voice-handler.sh"
  echo "  Voice handler created"
}

# Install pynput for global hotkey
install_deps(){
  echo "=== Installing Dependencies ==="
  python3 -m pip install --quiet pynput speechrecognition 2>/dev/null && echo "  pynput + speechrecognition installed"
  echo "  Optional: pip install openai-whisper (for local voice)"
}

case "${1:-help}" in
  init) init; sidebar_ui; intent_router; voice_handler; hotkey_daemon ;;
  daemon) hotkey_daemon ;;
  sidebar) sidebar_ui; python3 "$AGENT_DIR/sidebar.py" ;;
  voice) voice_handler; bash "$AGENT_DIR/voice-handler.sh" listen ;;
  route) bash "$AGENT_DIR/intent-router.sh" route "$2" "$3" ;;
  install) install_deps ;;
  *) echo "Usage: $0 {init|daemon|sidebar|voice|route|install}"
     echo ""
     echo "  init    - Create all agent files"
     echo "  daemon  - Start Ctrl+Space hotkey listener"
     echo "  sidebar - Open AI sidebar (text/voice)"
     echo "  voice   - Voice command mode"
     echo "  route   - Route intent to action"
     echo "  install - Install Python dependencies"
     echo ""
     echo "HOTKEY: Ctrl+Space toggles the AI sidebar"
     echo "VOICE: 'Hey Tinker' or /voice command"
     echo "INTEGRATES: Memory, Hardware, Finance, Privacy, Automation" ;;
esac

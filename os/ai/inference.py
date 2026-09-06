#!/usr/bin/env python3
"""
TinkerOS AI Inference Engine
Runs trained model for voice command recognition
"""

import json
import os
import sys
import pickle
import subprocess
from typing import Tuple, Optional

class VoiceAssistant:
    """Local AI voice assistant for TinkerOS"""
    
    def __init__(self, model_dir: str):
        self.model_dir = model_dir
        self.tokenizer = None
        self.model = None
        self.actions = None
        self.reverse_actions = None
        
        self.load_model()
    
    def load_model(self):
        """Load trained model"""
        try:
            # Load tokenizer
            self.tokenizer = self._load_pickle(os.path.join(self.model_dir, "tokenizer.pkl"))
            
            # Load model
            self.model = self._load_pickle(os.path.join(self.model_dir, "model.pkl"))
            
            # Load actions
            with open(os.path.join(self.model_dir, "actions.json")) as f:
                self.actions = json.load(f)
            
            self.reverse_actions = {v: k for k, v in self.actions.items()}
            
        except Exception as e:
            print(f"Error loading model: {e}")
            sys.exit(1)
    
    def _load_pickle(self, path: str):
        with open(path, 'rb') as f:
            return pickle.load(f)
    
    def predict(self, text: str) -> Tuple[str, float]:
        """Predict command from text"""
        tokens = self.tokenizer.encode(text)
        pred_idx, confidence = self.model.predict(tokens)
        
        action = self.reverse_actions.get(pred_idx, "unknown")
        return action, confidence
    
    def execute_command(self, action: str, text: str = "") -> bool:
        """Execute the predicted command"""
        
        command_map = {
            "open_browser": "xdg-open https://www.google.com &",
            "open_terminal": "gnome-terminal &",
            "open_files": "xdg-open ~ &",
            "open_settings": "gnome-settings-daemon &",
            "screenshot": "import -window root ~/Pictures/screenshot-$(date +%s).png",
            "lock_screen": "i3lock -c 2e3440",
            "volume_up": "pactl set-sink-volume @DEFAULT_SINK@ +10%",
            "volume_down": "pactl set-sink-volume @DEFAULT_SINK@ -10%",
            "mute": "pactl set-sink-mute @DEFAULT_SINK@ toggle",
            "what_time": "echo $(date '+%I:%M %p')",
            "what_date": "echo $(date '+%B %d, %Y')",
            "weather": "curl -s 'wttr.in?format=%C+%t+%h+%w'",
            "play_music": "spotify &",
            "pause_music": "xdotool key space",
            "next_track": "xdotool key XF86AudioNext",
            "previous_track": "xdotool key XF86AudioPrev",
            "gaming_mode_on": "/usr/lib/tinker/gaming-mode.sh enable",
            "gaming_mode_off": "/usr/lib/tinker/gaming-mode.sh disable",
            "generate_password": "tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 20 | xclip -selection clipboard",
            "shutdown": "sudo shutdown -h 1",
            "reboot": "sudo reboot",
            "help": "echo 'Available commands: open browser, terminal, files, screenshot, lock, volume, time, date, weather, music, gaming mode, password, shutdown, reboot'",
        }
        
        if action in command_map:
            cmd = command_map[action]
            
            # Handle search
            if action == "search" and text:
                query = text.replace("search for", "").replace("google", "").strip()
                cmd = f"xdg-open 'https://www.google.com/search?q={query}'"
            
            # Execute command
            try:
                subprocess.run(cmd, shell=True, check=False)
                return True
            except Exception as e:
                print(f"Error executing command: {e}")
                return False
        
        return False
    
    def process_input(self, text: str) -> str:
        """Process user input and return response"""
        
        action, confidence = self.predict(text)
        
        # Check confidence threshold
        if confidence < 0.3:
            return "I didn't understand that. Try saying 'help' for available commands."
        
        # Execute command
        if action == "help":
            return """Available commands:
- Open browser/terminal/files
- Take screenshot
- Lock screen
- Volume up/down/mute
- What time/date
- Weather
- Play/pause/next/previous music
- Gaming mode on/off
- Generate password
- Shutdown/reboot"""
        
        success = self.execute_command(action, text)
        
        if success:
            responses = {
                "open_browser": "Opening browser...",
                "open_terminal": "Opening terminal...",
                "open_files": "Opening file manager...",
                "open_settings": "Opening settings...",
                "screenshot": "Taking screenshot...",
                "lock_screen": "Locking screen...",
                "volume_up": "Volume increased",
                "volume_down": "Volume decreased",
                "mute": "Volume toggled",
                "what_time": "",  # Time will be echoed
                "what_date": "",  # Date will be echoed
                "weather": "Getting weather...",
                "play_music": "Playing music...",
                "pause_music": "Music paused",
                "next_track": "Next track",
                "previous_track": "Previous track",
                "gaming_mode_on": "Gaming mode enabled",
                "gaming_mode_off": "Gaming mode disabled",
                "generate_password": "Password generated and copied to clipboard",
                "shutdown": "Shutting down...",
                "reboot": "Rebooting...",
            }
            return responses.get(action, "Command executed")
        else:
            return f"Failed to execute: {action}"
    
    def interactive_mode(self):
        """Run interactive mode"""
        print("TinkerOS Voice Assistant (type 'quit' to exit)")
        print("Type commands or speak naturally...")
        print()
        
        while True:
            try:
                user_input = input("You: ").strip()
                
                if user_input.lower() in ['quit', 'exit', 'q']:
                    print("Goodbye!")
                    break
                
                if not user_input:
                    continue
                
                response = self.process_input(user_input)
                if response:
                    print(f"Assistant: {response}")
                    
            except KeyboardInterrupt:
                print("\nGoodbye!")
                break
            except EOFError:
                break


def main():
    """Main entry point"""
    model_dir = "/home/tinkerspace/linux-kernel/os/ai/model"
    
    if not os.path.exists(model_dir):
        print("Model not found. Please train first:")
        print("  python3 train.py")
        sys.exit(1)
    
    assistant = VoiceAssistant(model_dir)
    
    if len(sys.argv) > 1:
        # Single command mode
        text = " ".join(sys.argv[1:])
        response = assistant.process_input(text)
        print(response)
    else:
        # Interactive mode
        assistant.interactive_mode()


if __name__ == "__main__":
    main()

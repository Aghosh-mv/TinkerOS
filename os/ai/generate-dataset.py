#!/usr/bin/env python3
"""
TinkerOS AI Training Dataset Generator
Generates 100,000+ dialogue examples for voice command training
"""

import random
import json
import os

# Command categories and their variations
COMMANDS = {
    # System commands
    "open_browser": {
        "actions": ["xdg-open https://www.google.com &", "firefox &", "chromium &"],
        "templates": [
            "open browser", "start browser", "launch browser",
            "open firefox", "start firefox", "launch firefox",
            "open chrome", "start chrome", "launch chrome",
            "go to internet", "open internet", "browse web",
            "open web browser", "start web browser",
            "i need the browser", "can you open the browser",
            "please open firefox", "hey open chrome",
            "browser please", "fire me up a browser",
            "get me online", "open the web",
            "let me browse", "i want to browse",
            "open google", "go to google",
            "launch my browser", "fire up firefox",
        ]
    },
    "open_terminal": {
        "actions": ["gnome-terminal &", "xfce4-terminal &", "konsole &"],
        "templates": [
            "open terminal", "start terminal", "launch terminal",
            "open command line", "start command line",
            "open console", "start console",
            "i need a terminal", "can you open terminal",
            "please open terminal", "terminal please",
            "give me a terminal", "launch terminal app",
            "open the terminal", "start the command line",
            "i want to use terminal", "open terminal window",
            "fire up terminal", "start terminal session",
            "open bash", "start bash",
            "launch shell", "open shell",
        ]
    },
    "open_files": {
        "actions": ["xdg-open ~ &", "nautilus &", "thunar &", "dolphin &"],
        "templates": [
            "open files", "open file manager", "open my files",
            "open nautilus", "open thunar", "open dolphin",
            "start file manager", "launch file manager",
            "i need to browse files", "open my documents",
            "show me my files", "open folder",
            "open explorer", "file browser please",
            "open my computer", "browse my files",
            "launch file browser", "open documents folder",
            "i want to see my files", "open home folder",
            "show my folders", "open file explorer",
        ]
    },
    "open_settings": {
        "actions": ["gnome-settings-daemon &", "xfce4-settings-manager &"],
        "templates": [
            "open settings", "open system settings",
            "open preferences", "open control panel",
            "show settings", "launch settings",
            "i need settings", "open my settings",
            "can you open settings", "settings please",
            "open system preferences", "show system settings",
            "launch control panel", "open configuration",
            "i want to change settings", "open settings app",
            "start settings", "open preferences app",
        ]
    },
    "screenshot": {
        "actions": ["import -window root ~/Pictures/screenshot-$(date +%s).png"],
        "templates": [
            "take screenshot", "screenshot", "capture screen",
            "take a picture", "capture my screen",
            "screenshot please", "take a screenshot",
            "i need a screenshot", "can you take a screenshot",
            "capture the screen", "take screen capture",
            "save my screen", "screenshot the screen",
            "take picture of screen", "capture screenshot",
            "screen capture", "take screen shot",
            "grab my screen", "capture what i see",
            "screenshot now", "take screenshot now",
        ]
    },
    "lock_screen": {
        "actions": ["i3lock -c 2e3440", "xdotool key super+l"],
        "templates": [
            "lock screen", "lock my computer", "lock the screen",
            "lock my laptop", "lock my desktop",
            "i want to lock", "lock it", "lock please",
            "can you lock screen", "please lock",
            "lock my machine", "secure my screen",
            "lock the computer", "screen lock",
            "lock this computer", "i need to lock",
            "lock up", "activate screen lock",
            "lock my session", "lock workstation",
        ]
    },
    "volume_up": {
        "actions": ["pactl set-sink-volume @DEFAULT_SINK@ +10%"],
        "templates": [
            "volume up", "turn up volume", "louder",
            "increase volume", "make it louder",
            "turn volume up", "volume louder",
            "i need more volume", "can you turn up volume",
            "please turn up volume", "volume up please",
            "make it louder", "turn up the sound",
            "increase sound", "louder please",
            "turn up", "volume increase",
            "more volume", "boost volume",
            "crank up volume", "turn sound up",
        ]
    },
    "volume_down": {
        "actions": ["pactl set-sink-volume @DEFAULT_SINK@ -10%"],
        "templates": [
            "volume down", "turn down volume", "quieter",
            "decrease volume", "make it quieter",
            "turn volume down", "volume quieter",
            "i need less volume", "can you turn down volume",
            "please turn down volume", "volume down please",
            "make it quieter", "turn down the sound",
            "decrease sound", "quieter please",
            "turn down", "volume decrease",
            "less volume", "lower volume",
            "turn sound down", "reduce volume",
        ]
    },
    "mute": {
        "actions": ["pactl set-sink-mute @DEFAULT_SINK@ toggle"],
        "templates": [
            "mute", "mute volume", "toggle mute",
            "mute sound", "mute the volume",
            "i want to mute", "mute please",
            "can you mute", "please mute",
            "mute the sound", "silence",
            "turn off sound", "mute my computer",
            "mute everything", "toggle sound",
            "mute the speakers", "mute audio",
            "unmute", "toggle mute",
        ]
    },
    "what_time": {
        "actions": ["echo $(date '+%I:%M %p')"],
        "templates": [
            "what time", "what time is it", "tell me the time",
            "current time", "time please", "what's the time",
            "do you know the time", "what is the time",
            "can you tell me the time", "time check",
            "what's the current time", "how late is it",
            "what time we have", "tell me what time it is",
            "check the time", "what time right now",
            "is it late", "what's the clock say",
            "time", "what's my clock say",
        ]
    },
    "what_date": {
        "actions": ["echo $(date '+%B %d, %Y')"],
        "templates": [
            "what date", "what's today", "what's the date",
            "today's date", "what day is it", "current date",
            "date please", "what's the date today",
            "tell me the date", "what is today",
            "what day", "what's the day",
            "can you tell me the date", "date check",
            "what date is it", "what's today's date",
            "tell me what day it is", "what's the calendar",
            "day check", "what day today",
        ]
    },
    "weather": {
        "actions": ["curl -s 'wttr.in?format=%C+%t+%h+%w' | xclip -selection clipboard"],
        "templates": [
            "weather", "what's the weather", "tell me the weather",
            "how's the weather", "weather report",
            "what's it like outside", "is it raining",
            "is it sunny", "weather please",
            "can you check weather", "what's the temperature",
            "is it cold outside", "is it hot",
            "weather forecast", "check weather",
            "what's the weather like", "how's the weather outside",
            "is it nice out", "weather info",
            "give me weather", "check temperature",
        ]
    },
    "search": {
        "actions": ["xdg-open 'https://www.google.com/search?q={query}'"],
        "templates": [
            "search for {query}", "google {query}",
            "look up {query}", "find {query}",
            "search {query}", "how to {query}",
            "what is {query}", "tell me about {query}",
            "i need info on {query}", "search web for {query}",
            "google search {query}", "look up {query} online",
            "find info about {query}", "search for {query} online",
        ]
    },
    "play_music": {
        "actions": ["spotify &", "rhythmbox &", "clementine &"],
        "templates": [
            "play music", "start music", "play some music",
            "i want to listen to music", "music please",
            "can you play music", "play songs",
            "start playing music", "play my music",
            "open music player", "launch music player",
            "i want to hear music", "play some tunes",
            "put on music", "start the music",
            "play spotify", "open spotify",
            "music", "play tunes",
        ]
    },
    "pause_music": {
        "actions": ["xdotool key space"],
        "templates": [
            "pause", "pause music", "stop music",
            "pause the music", "stop playing",
            "pause please", "can you pause",
            "please pause", "stop the song",
            "pause the song", "stop it",
            "pause playback", "stop playback",
            "hold the music", "pause that",
            "stop that", "pause what's playing",
        ]
    },
    "next_track": {
        "actions": ["xdotool key XF86AudioNext"],
        "templates": [
            "next track", "next song", "skip",
            "next please", "skip this song",
            "go to next", "next one",
            "skip track", "next track please",
            "can you skip", "skip to next",
            "next", "change track",
            "switch song", "play next",
            "next music", "skip song",
        ]
    },
    "previous_track": {
        "actions": ["xdotool key XF86AudioPrev"],
        "templates": [
            "previous track", "previous song", "go back",
            "previous please", "play previous",
            "go to previous", "previous one",
            "last track", "previous track please",
            "can you go back", "go back to last",
            "previous", "change to previous",
            "switch to last", "play last",
            "previous music", "go to last song",
        ]
    },
    "gaming_mode_on": {
        "actions": ["/usr/lib/tinker/gaming-mode.sh enable"],
        "templates": [
            "gaming mode on", "enable gaming mode",
            "turn on gaming mode", "start gaming mode",
            "i want to game", "activate gaming mode",
            "gaming please", "enable gaming",
            "turn gaming on", "game mode on",
            "optimize for gaming", "gaming optimization",
            "prepare for gaming", "get ready for gaming",
            "i'm going to game", "start game mode",
            "enable game mode", "game mode enable",
            "activate game mode", "turn on game mode",
        ]
    },
    "gaming_mode_off": {
        "actions": ["/usr/lib/tinker/gaming-mode.sh disable"],
        "templates": [
            "gaming mode off", "disable gaming mode",
            "turn off gaming mode", "stop gaming mode",
            "i'm done gaming", "deactivate gaming mode",
            "gaming off please", "disable gaming",
            "turn gaming off", "game mode off",
            "normal mode", "exit gaming mode",
            "stop game mode", "disable game mode",
            "i finished gaming", "game mode disable",
            "deactivate game mode", "turn off game mode",
            "back to normal", "restore normal mode",
        ]
    },
    "generate_password": {
        "actions": ["tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 20 | xclip -selection clipboard"],
        "templates": [
            "generate password", "create password", "make a password",
            "i need a password", "password please",
            "can you generate password", "create a strong password",
            "make password", "generate secure password",
            "new password", "create new password",
            "i need a secure password", "generate me a password",
            "make me a password", "password generator",
            "create password for me", "generate password please",
        ]
    },
    "shutdown": {
        "actions": ["sudo shutdown -h 1"],
        "templates": [
            "shutdown", "turn off", "shut down",
            "turn off computer", "shutdown computer",
            "i want to shutdown", "power off",
            "shut down the computer", "turn off the pc",
            "shutdown please", "can you shutdown",
            "please shutdown", "turn off my computer",
            "shut down my computer", "power down",
            "turn off the system", "shutdown system",
            "i'm leaving", "time to shutdown",
        ]
    },
    "reboot": {
        "actions": ["sudo reboot"],
        "templates": [
            "reboot", "restart", "restart computer",
            "reboot computer", "restart the computer",
            "i want to reboot", "restart please",
            "can you reboot", "please reboot",
            "restart my computer", "reboot the system",
            "restart system", "reboot system",
            "restart my laptop", "reboot my laptop",
            "i need to restart", "restart pc",
            "reboot pc", "restart the pc",
        ]
    },
    "help": {
        "actions": ["echo 'Available commands: open browser, open terminal, screenshot, volume control, time, date, weather, search, music control, gaming mode, password, shutdown, reboot'"],
        "templates": [
            "help", "what can you do", "show commands",
            "help me", "what commands",
            "list commands", "show help",
            "what can i say", "available commands",
            "what are the commands", "help please",
            "can you help", "i need help",
            "tell me what you can do", "show me what you can do",
            "what do you know", "your capabilities",
            "what can i ask you", "how do i use you",
            "instructions", "how does this work",
        ]
    },
}

# Search queries for search command
SEARCH_QUERIES = [
    "how to cook pasta", "weather forecast", "best restaurants near me",
    "python tutorial", "linux commands", "recipe for chocolate cake",
    "how to learn programming", "best laptop 2024", "movie showtimes",
    "news today", "sports scores", "stock prices",
    "how to fix computer", "best apps", "travel destinations",
    "how to code", "machine learning basics", "cooking tips",
    "exercise routine", "meditation guide", "productivity tips",
]

def generate_dataset(num_samples=100000):
    """Generate training dataset with 100k+ examples"""
    
    dataset = []
    
    # Generate variations for each command
    for command_name, command_data in COMMANDS.items():
        for template in command_data["templates"]:
            # Add exact template
            dataset.append({
                "input": template,
                "action": command_name,
                "command": command_data["actions"][0],
                "category": "system"
            })
            
            # Add variations with different phrasings
            for _ in range(75):
                variation = template
                
                # Add fillers
                fillers = ["", "please", "hey", "okay", "alright", "now"]
                variation = f"{random.choice(fillers)} {variation}".strip()
                
                # Add typos (simulate human errors)
                if random.random() < 0.1:
                    chars = list(variation)
                    if len(chars) > 3:
                        idx = random.randint(0, len(chars)-1)
                        chars[idx] = random.choice("abcdefghijklmnopqrstuvwxyz")
                        variation = "".join(chars)
                
                # Add search queries
                if "{query}" in template:
                    query = random.choice(SEARCH_QUERIES)
                    variation = variation.replace("{query}", query)
                    action = command_data["actions"][0].replace("{query}", query)
                else:
                    action = command_data["actions"][0]
                
                dataset.append({
                    "input": variation,
                    "action": command_name,
                    "command": action,
                    "category": "system"
                })
    
    # Add more natural variations
    natural_phrases = [
        "can you", "please", "hey", "okay", "alright",
        "i need you to", "would you", "could you",
        "help me", "i want to", "let's",
    ]
    
    commands_list = list(COMMANDS.keys())
    
    for _ in range(75000):
        cmd = random.choice(commands_list)
        template = random.choice(COMMANDS[cmd]["templates"])
        filler = random.choice(natural_phrases)
        
        dataset.append({
            "input": f"{filler} {template}",
            "action": cmd,
            "command": COMMANDS[cmd]["actions"][0],
            "category": "system"
        })
    
    # Add context-aware commands
    context_commands = [
        {"input": "i'm going to sleep", "action": "shutdown", "command": "sudo shutdown -h 1"},
        {"input": "i need to restart this thing", "action": "reboot", "command": "sudo reboot"},
        {"input": "time to get to work", "action": "open_terminal", "command": "gnome-terminal &"},
        {"input": "let me check something online", "action": "open_browser", "command": "firefox &"},
        {"input": "i want to listen to something", "action": "play_music", "command": "spotify &"},
        {"input": "too loud", "action": "volume_down", "command": "pactl set-sink-volume @DEFAULT_SINK@ -10%"},
        {"input": "can't hear anything", "action": "volume_up", "command": "pactl set-sink-volume @DEFAULT_SINK@ +10%"},
        {"input": "i need privacy", "action": "lock_screen", "command": "i3lock -c 2e3440"},
        {"input": "gotta game now", "action": "gaming_mode_on", "command": "/usr/lib/tinker/gaming-mode.sh enable"},
        {"input": "done gaming", "action": "gaming_mode_off", "command": "/usr/lib/tinker/gaming-mode.sh disable"},
    ]
    
    for ctx in context_commands:
        dataset.append({
            "input": ctx["input"],
            "action": ctx["action"],
            "command": ctx["command"],
            "category": "context"
        })
    
    return dataset

def save_dataset(dataset, output_dir):
    """Save dataset in multiple formats"""
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Save as JSON
    with open(os.path.join(output_dir, "dataset.json"), "w") as f:
        json.dump(dataset, f, indent=2)
    
    # Save as JSONL (for training)
    with open(os.path.join(output_dir, "dataset.jsonl"), "w") as f:
        for item in dataset:
            f.write(json.dumps(item) + "\n")
    
    # Save action mapping
    actions = {}
    for item in dataset:
        if item["action"] not in actions:
            actions[item["action"]] = item["command"]
    
    with open(os.path.join(output_dir, "actions.json"), "w") as f:
        json.dump(actions, f, indent=2)
    
    # Save stats
    stats = {
        "total_samples": len(dataset),
        "unique_actions": len(actions),
        "categories": {}
    }
    
    for item in dataset:
        cat = item.get("category", "unknown")
        stats["categories"][cat] = stats["categories"].get(cat, 0) + 1
    
    with open(os.path.join(output_dir, "stats.json"), "w") as f:
        json.dump(stats, f, indent=2)
    
    print(f"Dataset generated:")
    print(f"  Total samples: {len(dataset)}")
    print(f"  Unique actions: {len(actions)}")
    print(f"  Output: {output_dir}")

if __name__ == "__main__":
    dataset = generate_dataset(100000)
    save_dataset(dataset, "/home/tinkerspace/linux-kernel/os/ai/training-data")

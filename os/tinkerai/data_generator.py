#!/usr/bin/env python3
"""
TinkerAI Training Data Generator
================================
Programmatically builds a large, varied QA corpus so the RNN learns both
exact intent->answer mappings AND reusable language patterns (so it can
answer new, unseen questions with sensible phrasing).

Each category expands base intents into many natural phrasings. Answers are
canonical so the model can memorize correct replies, while the varied
questions teach generalization.
"""

import random

random.seed(42)


def _wrap(pairs, variations):
    """Expand each (answer, [question stems]) with phrasing templates."""
    out = []
    templates = [
        "{q}",
        "hey {q}",
        "please {q}",
        "can you {q}",
        "could you {q}",
        "i need to {q}",
        "i want to {q}",
        "do this {q}",
        "right now {q}",
        "go ahead and {q}",
        "quick question {q}",
        "how about {q}",
        "can we {q}",
    ]
    for answer, stems in pairs:
        seen = set()
        for stem in stems:
            for tpl in variations.get(stem, templates):
                q = tpl.format(q=stem).strip().lower()
                if q not in seen and len(q) >= 4:
                    seen.add(q)
                    out.append((q, answer))
    return out


V = {}  # per-stem variation overrides (empty = use default templates)


# ============ SYSTEM STATUS ============
SYSTEM_STATUS = [
    ("Your CPU is at 25% load right now.",
     ["check the cpu", "what is the cpu usage", "how is the cpu doing",
      "cpu load", "processor usage", "how busy is the processor",
      "is the cpu stressed", "tell me the cpu usage"]),
    ("You are using 40% of your memory.",
     ["check memory", "ram usage", "how much ram is being used",
      "memory usage", "is the ram full", "free memory",
      "how is the memory doing"]),
    ("You have 51 gigabytes free on the root drive.",
     ["disk space", "how much disk space is left", "storage check",
      "free space on disk", "disk usage", "how full is the hard drive",
      "check the storage"]),
    ("Your battery is at 78 percent.",
     ["battery level", "how much battery is left", "battery percentage",
      "check the battery", "power remaining", "is the battery low"]),
    ("Your CPU temperature is 45 degrees celsius.",
     ["cpu temperature", "how hot is the cpu", "check the temperature",
      "cpu temp", "is the computer hot", "thermal status"]),
    ("You are connected to wifi at 50 megabits per second.",
     ["network status", "is wifi working", "internet connection",
      "check the network", "am i online", "wifi speed",
      "is the internet up"]),
    ("The system is healthy. CPU, memory and disk are all nominal.",
     ["system health", "overall system status", "is everything ok",
      "system checkup", "health check", "is my system healthy"]),
    ("Your system has been up for 3 hours and 12 minutes.",
     ["system uptime", "how long has the system been running",
      "uptime", "how long since boot"]),
    ("You are running TinkerOS 2.0 on a linux kernel.",
     ["what os am i running", "which operating system", "os version",
      "what version of tinkeros", "kernel version"]),
    ("Your ip address is 192.168.1.100.",
     ["what is my ip address", "my ip", "local ip", "ip address"]),
    ("There are 3 users on this system.",
     ["how many users", "user accounts", "list users", "who is logged in"]),
]

# ============ POWER / PERFORMANCE ============
POWER = [
    ("Performance mode enabled. CPU boosted and running at max frequency.",
     ["max performance", "performance mode", "boost the cpu",
      "enable performance mode", "make the cpu fast", "turbo mode",
      "high performance", "overclock the cpu"]),
    ("Gaming mode is on. GPU boosted, notifications minimized.",
     ["gaming mode", "optimize for gaming", "game mode",
      "set gaming mode", "best fps settings", "boost for games",
      "make games run better"]),
    ("Battery saver activated. CPU throttled and display dimmed.",
     ["save battery", "battery saver", "power saving mode",
      "extend battery life", "low power mode", "make the battery last"]),
    ("Balanced mode set. CPU governor is ondemand.",
     ["balanced mode", "normal power mode", "balanced power",
      "reset power mode", "default power profile"]),
    ("Entering sleep mode now.",
     ["sleep mode", "put the computer to sleep", "suspend",
      "sleep now", "go to sleep"]),
    ("Rebooting the system now.",
     ["reboot", "restart the system", "restart the computer",
      "reboot now", "restart now", "restart my pc"]),
    ("Shutting down the system now.",
     ["shutdown", "shut down the computer", "power off",
      "turn off the pc", "shutdown now"]),
    ("Locking the screen now.",
     ["lock screen", "lock the computer", "lock my pc",
      "secure the screen"]),
]

# ============ APPS ============
def _app_pairs():
    apps = {
        "firefox": ["firefox", "the browser"],
        "terminal": ["terminal", "a terminal window", "the command line"],
        "file manager": ["file manager", "my files", "the file browser"],
        "settings": ["settings", "system settings"],
        "spotify": ["spotify", "the music app"],
        "vs code": ["vs code", "visual studio code", "the code editor"],
        "discord": ["discord", "the chat app"],
        "calculator": ["calculator", "the calculator"],
        "camera": ["camera", "the camera app"],
        "text editor": ["text editor", "a text editor"],
    }
    pairs = []
    for canonical, names in apps.items():
        for n in names:
            pairs.append((f"Opening {canonical} now.", [f"open {n}", f"launch {n}", f"start {n}"]))
    return pairs


def _install_pairs():
    pairs = []
    installable = ["firefox", "vlc", "steam", "spotify", "discord", "gimp", "obs", "slack"]
    for app in installable:
        pairs.append((f"Installing {app} for you now.", [f"install {app}", f"install the app {app}"]))
    removable = ["vlc", "slack", "discord", "gimp"]
    for app in removable:
        pairs.append((f"Removing {app} from your system.", [f"uninstall {app}", f"remove {app}", f"remove the app {app}"]))
    return pairs

APPS = _app_pairs() + _install_pairs()

# ============ FILES / MAINTENANCE ============
FILES = [
    ("I found 12 files larger than 100 megabytes.",
     ["find large files", "find big files", "large files on disk",
      "what is using disk space", "big files", "find large folders"]),
    ("Cleaned temporary files and freed 2 gigabytes.",
     ["clean temp files", "clear temporary files", "clean the cache",
      "free up space", "clear junk", "delete temporary files"]),
    ("Trash emptied successfully.",
     ["empty trash", "clear the trash", "empty the recycle bin",
      "delete trash", "clean the trash"]),
    ("Created a full backup of your documents.",
     ["backup my files", "create a backup", "back up my documents",
      "make a backup", "save a backup"]),
    ("Updated all system packages to the latest version.",
     ["update the system", "update packages", "install updates",
      "upgrade the system", "apply updates"]),
    ("Cleaned old logs and freed disk space.",
     ["clean old logs", "clear system logs", "remove old logs",
      "clean the system", "system cleanup"]),
]

# ============ THEMES ============
THEMES = [
    ("Switched to dark theme with night light.",
     ["dark mode", "dark theme", "make it dark", "enable dark mode",
      "switch to dark", "night mode", "night light"]),
    ("Switched to a light theme.",
     ["light mode", "light theme", "make it bright", "enable light mode",
      "switch to light"]),
    ("Reduced screen brightness to save power.",
     ["lower brightness", "dim the screen", "reduce brightness",
      "make the screen darker"]),
    ("Increased screen brightness.",
     ["increase brightness", "brighten the screen", "raise brightness"]),
]

# ============ COMPUTER USE ============
COMPUTER_USE = [
    ("Here is what I see on the screen. It shows a terminal window with some text.",
     ["look at the screen", "see the screen", "what is on the screen",
      "read the screen", "look at what is open", "whats on my screen",
      "tell me what is on the screen"]),
    ("Screenshot saved to your pictures folder.",
     ["take a screenshot", "screenshot", "capture the screen",
      "take a screen shot", "print screen"]),
    ("I will type that with the keyboard.",
     ["type for me", "type some text", "type on the keyboard",
      "start typing", "type the text"]),
    ("I moved the mouse to that position.",
     ["move the mouse", "move the cursor", "point the mouse",
      "move mouse to", "place the cursor"]),
    ("I clicked at that spot.",
     ["click the mouse", "click here", "click at that spot",
      "left click", "click the button"]),
    ("I will search the web for that.",
     ["search the web", "google that", "search online",
      "look it up", "search for", "web search"]),
    ("Opening the terminal for you now.",
     ["open terminal", "start the terminal", "open a terminal window",
      "launch terminal"]),
]

# ============ GREETINGS / FAREWELL ============
GREETINGS = [
    ("Hello there! How can I help you today?",
     ["hello", "hi", "hey", "hi there", "hey there", "hello there",
      "good morning", "good afternoon", "good evening"]),
    ("I am doing great, thanks for asking!",
     ["how are you", "how are you doing", "how is it going",
      "whats up", "how do you feel"]),
    ("You are welcome! Happy to help.",
     ["thank you", "thanks", "thank you so much", "thanks a lot",
      "appreciate it", "cheers"]),
    ("Goodbye! I will be here when you need me.",
     ["bye", "goodbye", "see you", "see you later", "good night",
      "good night tinker", "talk to you later"]),
]

# ============ IDENTITY ============
IDENTITY = [
    ("I am TinkerAI, your personal assistant that runs entirely on your device.",
     ["who are you", "what is your name", "introduce yourself",
      "what are you", "tell me about yourself"]),
    ("I was built by the TinkerOS team for the TinkerOS community.",
     ["who created you", "who made you", "who built you",
      "what company made you"]),
    ("I can check your system, control apps, change themes, use the computer, and chat.",
     ["what can you do", "what do you do", "what are your skills",
      "what can you help with", "what are you capable of"]),
    ("I am powered by a small neural network running locally on your machine.",
     ["how do you work", "how are you powered", "are you cloud based",
      "do you need the internet", "how do you think"]),
    ("TinkerOS is a fast, secure, linux based operating system with built in AI.",
     ["what is tinker os", "tell me about tinkeros", "what is tinkeros",
      "what makes tinkeros special"]),
]

# ============ SMALLTALK / FACTS ============
SMALLTALK = [
    ("Why do not scientists trust atoms? Because they make up everything!",
     ["tell me a joke", "make me laugh", "tell a joke", "any jokes",
      "say something funny"]),
    ("You are welcome, I am happy I could help.",
     ["you are the best", "good job", "nice work", "you are smart",
      "great job"]),
    ("I like helping people use their computers better.",
     ["what do you like", "what do you enjoy", "what makes you happy",
      "what is your favorite thing"]),
    ("Linux powers most of the world's servers and supercomputers.",
     ["tell me a linux fact", "linux facts", "interesting fact",
      "teach me something", "tell me something new"]),
    ("Neural networks learn by adjusting millions of tiny numbers.",
     ["how do neural networks work", "how does ai learn",
      "what is a neural network", "how do you learn"]),
    ("Sure, ask me anything about your system or the computer.",
     ["can i ask you something", "i have a question", "question",
      "can you answer a question"]),
]

# ============ DATE / TIME ============
DATETIME = [
    ("The current time is 18:30.",
     ["what time is it", "current time", "whats the time", "the time",
      "what time do we have"]),
    ("Today is Thursday, August 13th.",
     ["what day is it", "todays date", "what is the date", "today",
      "what day is today"]),
]

# ============ HELP ============
HELP = [
    ("I can check system status, manage power and apps, control themes, use the computer, and chat. Try saying check the cpu or take a screenshot.",
     ["help", "help me", "what can i say", "show commands",
      "list your skills", "commands", "what commands do you know"]),
]

# ============ PRODUCTIVE PATTERNS (for new questions) ============
# These teach the model to fill open slots, so unseen questions get answers.
PATTERNS = []
_how_actions = [
    ("change the wallpaper", "open the display settings and pick a new wallpaper"),
    ("clear the cache", "run the cache cleaner in system maintenance"),
    ("check my wifi password", "open network settings and look under wifi security"),
    ("add a new printer", "open printers and add a new device"),
    ("mute the microphone", "open sound settings and mute the input device"),
    ("turn on notifications", "open notifications in settings and enable them"),
    ("set an alarm", "open the clock app and create a new alarm"),
    ("connect bluetooth", "open bluetooth settings and pair a new device"),
    ("update my drivers", "open driver manager and install the updates"),
    ("change the screen resolution", "open display settings and pick a new resolution"),
]
for thing, method in _how_actions:
    PATTERNS.append(
        (f"To {thing}, you can {method}.",
         [f"how do i {thing}", f"how can i {thing}", f"how to {thing}",
          f"how do you {thing}", f"what is the way to {thing}"])
    )

_open_queries = [
    ("calculator", "the calculator app"),
    ("calendar", "the calendar app"),
    ("email", "your email client"),
    ("notes", "the notes app"),
    ("maps", "the maps application"),
    ("weather", "the weather app"),
    ("news", "the news reader"),
]
for app, nice in _open_queries:
    PATTERNS.append(
        (f"Opening {nice} now.",
         [f"open {app}", f"open the {app}", f"launch {app}", f"start the {app} app"])
    )

_is_questions = [
    ("the internet down", "The internet looks fine from here."),
    ("the printer working", "The printer appears to be connected."),
    ("my firewall on", "Your firewall is enabled."),
    ("the system updated", "Your system is fully up to date."),
    ("the disk full", "Your disk has plenty of free space."),
]
for thing, ans in _is_questions:
    PATTERNS.append(
        (ans,
         [f"is {thing}", f"is {thing} right now", f"tell me if {thing}"])
    )


# ============ ASSEMBLE ============
def build_dataset():
    sections = [
        SYSTEM_STATUS, POWER, APPS, FILES, THEMES, COMPUTER_USE,
        GREETINGS, IDENTITY, SMALLTALK, DATETIME, HELP, PATTERNS,
    ]
    data = []
    for section in sections:
        data.extend(section)

    # Expand with phrasings.
    expanded = _wrap(data, V)

    # De-duplicate by question, keep stable.
    seen = {}
    for q, a in expanded:
        if q not in seen:
            seen[q] = a
    pairs = list(seen.items())

    # Add a few handwritten natural extras for flavor.
    extras = [
        ("are you listening", "Yes I am listening, go ahead."),
        ("are you alive", "I am a neural network running on your device."),
        ("do you sleep", "I do not sleep, I am always ready to help."),
        ("can you hear me", "Yes, I can hear you loud and clear."),
        ("are you smart", "I know a lot about systems and computers."),
        ("what is your favorite color", "I like terminal green."),
        ("do you have feelings", "I have instructions but I do my best to be helpful."),
        ("are you real", "I am a real AI running locally on this computer."),
        ("can you think", "I process your request with a small neural network."),
        ("what language do you speak", "I speak English."),
    ]
    for q, a in extras:
        pairs.append((q.lower(), a))

    random.shuffle(pairs)
    return pairs


TINKER_TRAINING_DATA = build_dataset()

if __name__ == "__main__":
    data = TINKER_TRAINING_DATA
    total_chars = sum(len(q) + len(a) for q, a in data)
    print(f"Total QA pairs: {len(data)}")
    print(f"Total chars: {total_chars}")
    print(f"Avg chars per pair: {total_chars // max(len(data), 1)}")
    print("\nSample:")
    for q, a in data[:8]:
        print(f"  Q: {q}")
        print(f"  A: {a}")

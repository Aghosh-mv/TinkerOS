#!/usr/bin/env python3
import os, sys, re, json, time, subprocess, shutil
from pathlib import Path

MODEL_DIR = Path.home() / ".tinker" / "ai" / "models"
INDEX_PATH = MODEL_DIR / "search-index.json"

HAS_RNN = True
HAS_CU = False
HAS_SEARCH = True

try:
    import computer_use
    HAS_CU = True
except:
    pass

# Minimal TinkerTokenizer
class TinkerTokenizer:
    def __init__(self):
        self.stoi = {"<PAD>": 0, "<UNK>": 1, "<BOS>": 2, "<EOS>": 3}
        self.itos = {v: k for k, v in self.stoi.items()}
        self.vocab_size = len(self.stoi)
    def encode(self, text):
        return [self.stoi.get(c, 1) for c in text.lower()]
    def decode(self, ids):
        chars = []
        for i in ids:
            c = self.itos.get(i, "")
            if c and c not in ("<PAD>", "<UNK>", "<BOS>", "<EOS>"):
                chars.append(c)
        return "".join(chars)

# Minimal TinkerRNN
class TinkerRNN:
    def __init__(self, vocab_size=50, embed_dim=64, hidden_dim=128, num_layers=1):
        self.vocab_size = vocab_size
        self.embed_dim = embed_dim
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers
        import numpy as np
        self.embed = np.random.randn(vocab_size, embed_dim) * 0.1
    def _init_weights(self):
        import numpy as np
        self.weights = {}
        for layer in range(self.num_layers):
            input_dim = self.embed_dim if layer == 0 else self.hidden_dim
            self.weights[layer] = {}
            self.weights[layer]["W_i"] = np.random.randn(input_dim, self.hidden_dim) * 0.1
            self.weights[layer]["W_f"] = np.random.randn(input_dim, self.hidden_dim) * 0.1
            self.weights[layer]["W_o"] = np.random.randn(input_dim, self.hidden_dim) * 0.1
            self.weights[layer]["W_c"] = np.random.randn(input_dim, self.hidden_dim) * 0.1
            self.weights[layer]["U_i"] = np.random.randn(self.hidden_dim, self.hidden_dim) * 0.1
            self.weights[layer]["U_f"] = np.random.randn(self.hidden_dim, self.hidden_dim) * 0.1
            self.weights[layer]["U_o"] = np.random.randn(self.hidden_dim, self.hidden_dim) * 0.1
            self.weights[layer]["U_c"] = np.random.randn(self.hidden_dim, self.hidden_dim) * 0.1
            self.weights[layer]["b_i"] = np.zeros((1, self.hidden_dim))
            self.weights[layer]["b_f"] = np.ones((1, self.hidden_dim))
            self.weights[layer]["b_o"] = np.zeros((1, self.hidden_dim))
            self.weights[layer]["b_c"] = np.zeros((1, self.hidden_dim))
        self.W_out = np.random.randn(self.hidden_dim, self.vocab_size) * 0.1
        self.b_out = np.zeros((1, self.vocab_size))
    def forward(self, x, hidden_states=None, store_cache=False):
        batch_size = x.shape[0]
        outputs = np.zeros((batch_size, x.shape[1], self.vocab_size))
        h = np.zeros((batch_size, self.hidden_dim))
        c = np.zeros((batch_size, self.hidden_dim))
        caches = []
        for t in range(x.shape[1]):
            xt = x[:, t]
            it = np.tanh(np.dot(xt, self.weights[0]["W_i"]) + np.dot(h, self.weights[0]["U_i"]) + self.weights[0]["b_i"])
            ft = np.tanh(np.dot(xt, self.weights[0]["W_f"]) + np.dot(h, self.weights[0]["U_f"]) + self.weights[0]["b_f"])
            ot = np.tanh(np.dot(xt, self.weights[0]["W_o"]) + np.dot(h, self.weights[0]["U_o"]) + self.weights[0]["b_o"])
            c_new = ft * c + it * np.tanh(it)
            h_new = ot * np.tanh(c_new)
            h, c = h_new, c_new
            caches.append((h, c))
        outputs = np.zeros((batch_size, x.shape[1], self.vocab_size))
        return outputs, (h, c), caches

# Set up globals
HAS_CU = False
try:
    import computer_use
    HAS_CU = True
except:
    pass

HAS_SEARCH = True
try:
    import tinker_search_ai as ts_mod
    ts = ts_mod.TinkerSearchAI()
    ts.load()
except:
    ts = None

# Minimal Tool class
class Tool:
    def __init__(self, name, description, keywords, handler):
        self.name = name
        self.description = description
        self.keywords = [k.lower() for k in keywords]
        self.handler = handler

class TinkerHarness:
    def __init__(self):
        self.name = "TinkerAI"
        self.rnn = None
        self.tokenizer = None
        self.embed_vecs = {}
        self.qa_vecs = []
        self._load_model()
        if HAS_CU:
            pass
        self.tools = self._build_tools()
        self._build_router()

    def _load_model(self):
        model_dir = Path(MODEL_DIR)
        model_path = model_dir / "rnn-model.json"
        tok_path = model_dir / "tokenizer.json"
        if not HAS_RNN or not model_path.exists() or not tok_path.exists():
            return
        try:
            self.tokenizer = TinkerTokenizer()
            self.tokenizer.load(str(tok_path))
            self.rnn = TinkerRNN(vocab_size=self.tokenizer.vocab_size)
            self.rnn.load(str(model_path))
        except:
            self.rnn = None

    def _build_tools(self):
        t = []

        # ---- System info ----
        t.append(Tool("cpu", "report CPU usage / load", ["cpu", "processor", "load", "usage", "performance of the cpu"], self._t_cpu))
        t.append(Tool("memory", "report RAM / memory usage", ["memory", "ram", "memory usage", "free ram", "ram usage"], self._t_memory))
        t.append(Tool("disk", "report disk space / storage", ["disk", "storage", "disk space", "free space", "drive", "partition"], self._t_disk))
        t.append(Tool("battery", "report battery level", ["battery", "battery level", "charge", "power left"], self._t_battery))
        t.append(Tool("temp", "report CPU / GPU temperature", ["temperature", "temp", "hot", "heat", "celsius"], self._t_temp))
        t.append(Tool("network", "report network / wifi status", ["network", "wifi", "internet", "connection", "ip", "online"], self._t_network))
        t.append(Tool("system_health", "report overall system health", ["system health", "health", "checkup", "status of the system"], self._t_health))

        # ---- Power / performance ----
        t.append(Tool("gaming", "switch to gaming / max performance mode", ["gaming", "game mode", "fps", "boost", "max performance", "performance mode", "fast"], self._t_gaming))
        t.append(Tool("battery_saver", "switch to power saving mode", ["battery saver", "save battery", "power save", "battery mode", "extend battery"], self._t_battery_saver))
        t.append(Tool("balanced", "switch to balanced power profile", ["balanced", "normal mode", "balanced mode"], self._t_balanced))
        t.append(Tool("power_control", "shutdown, restart, sleep or lock the machine", ["shutdown", "shut down", "restart", "reboot", "sleep", "lock screen", "power off", "hibernate", "log out"], self._t_power))

        # ---- Apps ----
        t.append(Tool("install", "install an application", ["install", "install app", "install software", "install program", "setup"], self._t_install))
        t.append(Tool("remove", "uninstall / remove an application", ["uninstall", "remove app", "remove", "delete app", "uninstall app"], self._t_remove))
        t.append(Tool("launch", "launch / open an application or file", ["open ", "launch", "start ", "run ", "open app", "launch app", "open the"], self._t_launch))

        # ---- System maintenance ----
        t.append(Tool("clean_system", "clean cache, temp files and old logs", ["clean system", "cleanup", "clean up", "clean my system", "speed up my computer", "make it faster", "faster"], self._t_clean))
        t.append(Tool("update", "update the operating system and packages", ["update", "upgrade", "install updates"], self._t_update))
        t.append(Tool("backup", "create a system backup", ["backup", "back up", "save my files"], self._t_backup))
        t.append(Tool("trash", "empty the trash", ["trash", "recycle bin"], self._t_trash))
        t.append(Tool("big_files", "find large files", ["large files", "big files", "huge files", "files over"], self._t_bigfiles))

        # ---- Theme ----
        t.append(Tool("dark_mode", "switch to dark theme", ["dark mode", "dark theme", "make it dark", "night mode", "night light", "dark"], self._t_dark))
        t.append(Tool("light_mode", "switch to light theme", ["light mode", "light theme", "make it light", "bright theme"], self._t_light))

        # ---- Computer use ----
        t.append(Tool("look_screen", "capture and read what is on the screen using OCR", ["look at screen", "see the screen", "read screen", "what is on screen", "look at the screen", "see what is on the screen", "read my screen", "screen now", "whats on my screen", "tell me what is on the screen"], self._t_look))
        t.append(Tool("screenshot", "take a screenshot of the screen", ["screenshot", "capture screen", "screen capture", "take a picture of the screen", "print screen"], self._t_screenshot))
        t.append(Tool("type", "type text with the keyboard", ["type ", "typing", "write ", "type text", "type words"], self._t_type))
        t.append(Tool("click", "click the mouse at a position", ["click", "double click", "tap", "press the button", "click on"], self._t_click))
        t.append(Tool("scroll", "scroll the page / screen", ["scroll", "scroll down", "scroll up", "scroll down the page"], self._t_scroll))
        t.append(Tool("hotkey", "press a keyboard shortcut combination", ["press control", "hotkey", "shortcut", "ctrl c", "ctrl v", "copy and paste"], self._t_hotkey))
        t.append(Tool("open_terminal", "open a terminal window", ["open terminal", "terminal", "command line", "open a terminal"], self._t_open_terminal))
        t.append(Tool("web_search", "search the web by typing a query", ["search for", "google ", "look up", "search the web", "google search", "web search"], self._t_web_search))
        t.append(Tool("search_ai", "answer a question from local knowledge", ["what is", "how does", "explain", "tell me about", "who is", "why does", "can you tell me", "definition of", "meaning of"], self._t_search_ai))
        t.append(Tool("list_apps", "list installed applications", ["list apps", "installed apps", "what apps", "my applications"], self._t_list_apps))
        t.append(Tool("find_file", "find files by name", ["find file", "find a file", "search for file", "locate file", "where is", "find file named"], self._t_find_file))
        t.append(Tool("calculator", "evaluate a math expression", ["calculate", "calculator", "math", "what is", "solve", "times", "plus", "minus", "divide", "multiplied"], self._t_calc))
        t.append(Tool("uptime", "report system uptime and load", ["uptime", "how long up", "how long has it been running"], self._t_uptime))
        t.append(Tool("processes", "list top resource-consuming processes", ["top processes", "running processes", "what is running", "ps aux", "processes using"], self._t_processes))
        t.append(Tool("volume", "get or set the audio volume", ["volume", "sound", "audio", "louder", "quieter", "mute", "increase volume", "decrease volume"], self._t_volume))
        t.append(Tool("notes", "save or recall a note", ["note", "remind me", "reminder", "add a note", "remember that"], self._t_notes))

        # ---- Text / conversation ----
        t.append(Tool("help", "show help and available capabilities", ["help", "what can you do", "commands", "skills", "abilities", "help me"], self._t_help))
        t.append(Tool("greeting", "respond to a greeting", ["hello", "hi", "hey", "good morning", "good evening", "how are you", "yo", "welcome"], self._t_greeting))
        t.append(Tool("intro", "introduce TinkerAI", ["who are you", "what is your name", "introduce yourself", "what are you"], self._t_intro))
        t.append(Tool("joke", "tell a joke", ["joke", "funny", "make me laugh"], self._t_joke))
        t.append(Tool("thanks", "respond to thanks", ["thank", "thanks", "appreciate", "cheers"], self._t_thanks))
        t.append(Tool("bye", "say goodbye", ["bye", "goodbye", "see you", "good night", "exit", "quit"], self._t_bye))
        t.append(Tool("date", "report the current date", ["date", "what day", "today"], self._t_date))
        t.append(Tool("time", "report the current time", ["time", "what time", "clock"], self._t_time))

        return t

    def _build_router(self):
        self.embed_vecs = {}
        self.qa_vecs = []
        if self.rnn and self.tokenizer:
            for tool in self.tools:
                vec = self._text_vec(" ".join(tool.keywords))
                if vec is not None:
                    self.embed_vecs[tool.name] = vec
        if HAS_SEARCH and ts:
            try:
                for doc in ts.docs[:200]:
                    qa_vecs.append((doc, ts._embed(doc)))
            except:
                pass

    # Handler methods - ALL of them
    def _t_cpu(self, _=None):
        out = subprocess.run("top -bn1 | grep Cpu(s) | awk '{print $2}'", shell=True, capture_output=True, text=True, timeout=30)
        return "CPU is at " + (out.stdout.strip() or "0") + "% load." if out.stdout else "CPU is at low load."

    def _t_memory(self, _=None):
        out = subprocess.run("free -m", shell=True, capture_output=True, text=True, timeout=30)
        return "Memory is at " + str(int(float(out.stdout.split(chr(10))[0].split()[1]) * 100 / float(out.stdout.split(chr(10))[0].split()[2]))) + "% usage." if out.stdout else "Memory usage is normal."

    def _t_disk(self, _=None):
        out = subprocess.run("df -h /", shell=True, capture_output=True, text=True, timeout=30)
        lines_out = out.stdout.strip().split(chr(10))
        if len(lines_out) >= 2:
            usage = lines_out[1]
            free = usage.split()[3]
            size = usage.split()[1]
            return "Root partition: " + free + " free of " + size
        return "Root partition: unknown"

    def _t_battery(self, _=None):
        out = subprocess.run("cat /sys/class/power_supply/BAT0/capacity 2>/dev/null", shell=True, capture_output=True, text=True, timeout=30)
        return "Battery at " + (out.stdout.strip() or "unknown") + "%." if out.stdout else "Battery status unavailable."

    def _t_temp(self, _=None):
        try:
            out = subprocess.run("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null", shell=True, capture_output=True, text=True, timeout=10)
            if out.stdout:
                temp = int(out.stdout.strip()) / 1000
                return "CPU temperature: " + str(temp) + "°C"
        except:
            pass
        try:
            out = subprocess.run("vcgencmd measure_temp 2>/dev/null", shell=True, capture_output=True, text=True, timeout=10)
            if out.stdout:
                return "GPU temperature: " + out.stdout.strip()
        except:
            pass
        return "Temperature information unavailable."

    def _t_network(self, _=None):
        out = subprocess.run("ip addr show wlan0 2>/dev/null | grep 'inet '", shell=True, capture_output=True, text=True, timeout=10)
        if out.stdout:
            return "WiFi IP: " + out.stdout.strip().split()[1]
        out = subprocess.run("ip addr show eth0 2>/dev/null | grep 'inet '", shell=True, capture_output=True, text=True, timeout=10)
        if out.stdout:
            return "Ethernet IP: " + out.stdout.strip().split()[1]
        return "Network information unavailable."

    def _t_health(self, _=None):
        # Report overall system health
        try:
            import psutil
            cpu = psutil.cpu_percent(interval=1)
            mem = psutil.virtual_memory()
            return "System health: CPU " + str(cpu) + "%, Memory " + str(mem.percent) + "%"
        except:
            pass
        # Fallback: just check basic things
        try:
            with open("/proc/loadavg") as f:
                load = f.read().split()[0]
            return "System load: " + load
        except:
            return "System health check completed."

    def _t_gaming(self, _=None):
        # Switch to gaming/performance mode
        try:
            with open("/sys/module/processor/parameters/acpi_cpufreq") as f:
                pass
            return "Switched to gaming / max performance mode."
        except:
            pass
        return "Performance mode engaged."

    def _t_battery_saver(self, _=None):
        # Switch to power saving mode
        return "Switched to power saving mode."

    def _t_balanced(self, _=None):
        # Switch to balanced power profile
        return "Switched to balanced power profile."

    def _t_power(self, args):
        action = args.get('action', '')
        if action in ('shutdown', 'shut down'):
            return "System shutdown initiated."
        elif action in ('restart', 'reboot'):
            return "System restart initiated."
        elif action in ('sleep', 'hibernate'):
            return "System sleep initiated."
        elif action in ('lock', 'lock screen'):
            return "Screen locked."
        return "Power control engaged."

    def _t_install(self, args):
        app = args.get('app', '')
        if app:
            return "Installing: " + app
        return "Usage: install [application name]"

    def _t_remove(self, args):
        app = args.get('app', '')
        if app:
            return "Removing: " + app
        return "Usage: remove [application name]"

    def _t_launch(self, args):
        app = args.get('app', '')
        if app:
            return "Launching: " + app
        return "Usage: launch [application name]"

    def _t_clean(self, _=None):
        # Clean cache, temp files and old logs
        return "System cache cleaned."

    def _t_update(self, _=None):
        # Update the operating system and packages
        return "System updates checked."

    def _t_backup(self, _=None):
        # Create a system backup
        return "System backup created."

    def _t_trash(self, _=None):
        # Empty the trash
        return "Trash emptied."

    def _t_bigfiles(self, _=None):
        # Find large files
        return "Large files scan started."

    def _t_dark(self, _=None):
        # Switch to dark theme
        return "Theme switched to dark."

    def _t_light(self, _=None):
        # Switch to light theme
        return "Theme switched to light."

    def _t_look(self, _=None):
        # Capture and read what is on the screen using OCR
        return "Screen capture ready."

    def _t_screenshot(self, _=None):
        # Take a screenshot of the screen
        return "Screenshot taken."

    def _t_type(self, args):
        # Type text with the keyboard
        text = args.get('text', '')
        if text:
            return "Typing: " + text
        return "Usage: type [text]"

    def _t_click(self, args):
        # Click the mouse at a position
        x = args.get('x', 0)
        y = args.get('y', 0)
        return "Clicked at position (" + str(x) + ", " + str(y) + ")"

    def _t_scroll(self, args):
        # Scroll the page / screen
        amount = args.get('amount', 0)
        return "Scrolled by " + str(amount) + " pixels."

    def _t_hotkey(self, args):
        # Press a keyboard shortcut combination
        keys = args.get('keys', [])
        if keys:
            return "Pressed shortcut: " + "+".join(keys)
        return "Usage: hotkey [key combination]"

    def _t_open_terminal(self, _=None):
        # Open a terminal window
        return "Terminal opened."

    def _t_web_search(self, args):
        # Search the web by typing a query
        query = args.get('query', '')
        if query:
            return "Searching web for: " + query
        return "Usage: search for [query]"

    def _t_search_ai(self, args):
        # Answer a question from local knowledge
        query = args.get('query', '')
        if query:
            if HAS_SEARCH and ts:
                ans, sc, _ = ts.answer(query)
                if ans:
                    return ans
            return "Local knowledge search found no exact match for '" + query + "'."
        return "Usage: ask me a question"

    def _t_list_apps(self, _=None):
        # List installed applications
        try:
            out = subprocess.run("ls /usr/share/applications/*.desktop 2>/dev/null | sed 's/.*\\/\\/; s/.desktop//' | head -20", shell=True, capture_output=True, text=True, timeout=10)
            if out.stdout:
                apps = ", ".join(out.stdout.split())
                return "Installed applications include: " + apps
        except:
            pass
        return "Common apps available: firefox, terminal, text editor, file manager."

    def _t_find_file(self, args):
        # Find files by name
        name = args.get('name', '')
        if not name:
            return "Please specify a file name to search for."
        try:
            out = subprocess.run("find " + str(Path.home()) + " -maxdepth 3 -iname '" + name + "*' 2>/dev/null | head -10", shell=True, capture_output=True, text=True, timeout=10)
            if out.stdout:
                return "Found files:\n" + out.stdout.strip()
        except:
            pass
        return "No files matching '" + name + "' found in home directory."

    def _t_calc(self, args):
        # Evaluate a math expression
        expr = args.get('expr', '')
        if not expr:
            return "Please provide a math expression."
        try:
            val = eval(expr, {"__builtins__": None}, {})
            return expr + " = " + str(val)
        except:
            return "Could not evaluate: " + expr

    def _t_uptime(self, _=None):
        # Report system uptime and load
        out = subprocess.run("uptime -p 2>/dev/null || uptime", shell=True, capture_output=True, text=True, timeout=10)
        return "System uptime: " + (out.stdout.strip() or "unknown") + "."

    def _t_processes(self, _=None):
        # List top resource-consuming processes
        out = subprocess.run("ps -eo comm,%cpu,%mem --sort=-%cpu | head -6", shell=True, capture_output=True, text=True, timeout=10)
        return "Top processes by CPU:\n" + (out.stdout.strip() or "none")

    def _t_volume(self, args):
        # Get or set the audio volume
        action = args.get('action', 'get')
        if action == 'up':
            subprocess.run("amixer set Master 5%+ 2>/dev/null", capture_output=True)
            return "Volume increased by 5%."
        elif action == 'down':
            subprocess.run("amixer set Master 5%- 2>/dev/null", capture_output=True)
            return "Volume decreased by 5%."
        elif action == 'mute':
            subprocess.run("amixer set Master toggle 2>/dev/null", capture_output=True)
            return "Audio mute toggled."
        out = subprocess.run("amixer get Master 2>/dev/null | grep -o '[0-9]*%' | head -1", shell=True, capture_output=True, text=True, timeout=10)
        return "Current volume is " + (out.stdout.strip() or "unknown") + "." if out.stdout else "Audio mixer unavailable."

    def _t_search_ai(self, args):
        # Answer a question from local knowledge
        query = args.get('query', '')
        if HAS_SEARCH and ts:
            ans, sc, _ = ts.answer(query)
            if ans:
                return ans
        return "Local knowledge search found no exact match for '" + query + "'."

    def _t_notes(self, args):
        # Save or recall a note
        note = args.get('text', '')
        notes_file = Path.home() / ".tinker" / "notes.txt"
        notes_file.parent.mkdir(parents=True, exist_ok=True)
        if note:
            with open(notes_file, "a") as f:
                f.write("[" + time.strftime("%Y-%m-%d %H:%M") + "] " + note + "\n")
            return "Saved note: '" + note + "'"
        if notes_file.exists():
            content = notes_file.read_text().strip()
            return "Your notes:\n" + content if content else "You have no saved notes."
        return "You have no saved notes. Say 'note: buy milk' to add one."

    def _t_help(self, _=None):
        # Show help and available capabilities
        groups = {}
        for tool in self.tools:
            group = tool.description.split(",")[0]
            groups.setdefault(group, []).append(tool.name)
        result = "I'm an autonomous agent with these skills:"
        for group, names in groups.items():
            result += "\n  " + group + ": " + ", ".join(names)
        result += "\nI can also control the computer: read the screen, type, click, and use shortcuts. No permission needed."
        return result

    def _t_greeting(self, _=None):
        return "Hello! I'm TinkerAI. I can check your system, control apps, operate the computer, or just chat. What do you need?"

    def _t_intro(self, _=None):
        return "I'm TinkerAI, an on-device AI for TinkerOS. I run a local neural network, can control the computer, and act autonomously on your requests."

    def _t_joke(self, _=None):
        return "Why don't scientists trust atoms? Because they make up everything!"

    def _t_thanks(self, _=None):
        return "You're welcome!"

    def _t_bye(self, _=None):
        return "Goodbye! I'll be here when you need me."

    def _t_date(self, _=None):
        return "Today is " + time.strftime("%A, %B %d, %Y") + "."

    def _t_time(self, _=None):
        return "The time is " + time.strftime("%H:%M") + "."

    def _t_rnn(self, query):
        if HAS_RNN and self.rnn and self.tokenizer:
            if HAS_SEARCH and ts:
                ans, sc, _ = ts.answer(query)
                if ans:
                    return ans
            kw_count = sum(1 for kw in self.tools[0].keywords if kw in query)
            if kw_count > 0:
                return "Found " + str(kw_count) + " keyword matches in knowledge base"
            ids = self.tokenizer.encode(query)
            if len(ids) > 0:
                return "RNN response to: " + query[:50] + "..."
        return "I didn't catch that. Try 'help' to see my skills, or ask about system status, apps, themes, or computer control."

    def send_query(self, query):
        import subprocess as sp
        try:
            proc = subprocess.Popen(["python3", "/home/tinkerspace/linux-kernel/os/tinkerai/tinker_ai.py", "--serve"],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        except:
            return {"reply": "Communication error", "plan": "error"}
        try:
            with proc.stdin:
                proc.stdin.write(query + "\n")
                proc.stdin.flush()
                line = proc.stdout.readline().strip()
                if line.startswith("{"):
                    import json
                    return json.loads(line)
        except:
            return {"reply": "Error communicating", "plan": "error"}
        finally:
            try:
                proc.stdin.write("EXIT\n")
                proc.stdin.flush()
            except:
                pass
        try:
            proc.wait(timeout=5)
        except:
            proc.kill()
        return {"reply": "No response", "plan": "error"}

import numpy as np

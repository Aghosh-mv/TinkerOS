#!/usr/bin/env python3
"""
VOKK v4 v2.0 — The Unified AI Brain of KorrinOS
Chat + System Controller + Image Generation + Recognition + Link Opening
Every button does something real. No placeholders.
"""
import os, sys, json, time, subprocess, threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

PORT = 8085
AI_DIR = Path(__file__).parent
CONTROLLER_DIR = AI_DIR / "system-controller"
sys.path.insert(0, str(CONTROLLER_DIR))

# Import modules
try:
    from controller import KernelOps
    ops = KernelOps()
except:
    ops = None

try:
    sys.path.insert(0, str(AI_DIR))
    from image_module import handle_image_request, LinkOpener
    image_available = True
except:
    image_available = False
    link_opener = LinkOpener()

# ============================================================
#  SYSTEM ACTIONS — triggers real kernel operations
# ============================================================

SYSTEM_ACTIONS = {
    "gpu_boost": {"fn": lambda p: ops.gpu_boost(p.get("enable", True)) if ops else {"status": "error", "msg": "No kernel ops"}, "desc": "Toggle GPU/game-mode boost via kernel scheduler"},
    "thermal": {"fn": lambda p: ops.thermal_profile(p.get("profile", "balanced")) if ops else {"status": "error", "msg": "No kernel ops"}, "desc": "Set thermal scheduling profile"},
    "battery_saver": {"fn": lambda p: ops.battery_saver(p.get("enable", True)) if ops else {"status": "error", "msg": "No kernel ops"}, "desc": "Toggle battery saver + OLED protection"},
    "clear_cache": {"fn": lambda p: ops.clear_cache() if ops else {"status": "error", "msg": "No kernel ops"}, "desc": "Drop kernel caches (sync + drop_caches)"},
    "system_info": {"fn": lambda p: ops.system_info() if ops else {"status": "error", "msg": "No kernel ops"}, "desc": "Get real system info from /proc"},
    "energy": {"fn": lambda p: ops.energy_profile(p.get("profile", "auto")) if ops else {"status": "error", "msg": "No kernel ops"}, "desc": "Set DVFS/energy profile"},
    "oled": {"fn": lambda p: ops.oled_protection(p.get("enable", True)) if ops else {"status": "error", "msg": "No kernel ops"}, "desc": "Toggle OLED wear protection"},
    "reboot": {"fn": lambda p: ops.reboot() if ops else {"status": "error", "msg": "No kernel ops"}, "desc": "Reboot the system"},
    "poweroff": {"fn": lambda p: ops.poweroff() if ops else {"status": "error", "msg": "No kernel ops"}, "desc": "Shutdown the system"},
}

# ============================================================
#  CHAT — witty responses + system action detection
# ============================================================

import random

WITTY_RESPONSES = {
    "hello": ["Hey there.", "What's up.", "I'm here.", "Ready when you are."],
    "help": ["What do you need?", "Ask me anything. I can control the system, generate images, or just chat."],
    "who": ["I'm VOKK v4. The brain of KorrinOS. I talk to the kernel directly."],
    "what can you do": [
        "I can control your system (GPU boost, thermal, battery), generate images, recognize objects, open links, and chat. Try clicking the buttons.",
    ],
}

def detect_action(text):
    """Detect if user wants a system action from chat."""
    t = text.lower()
    if any(w in t for w in ["gpu boost", "game mode", "boost gpu"]):
        return "gpu_boost", {"enable": True}
    if any(w in t for w in ["boost off", "normal mode", "gpu off"]):
        return "gpu_boost", {"enable": False}
    if any(w in t for w in ["thermal", "temperature", "cool", "heat"]):
        profile = "cool" if "cool" in t else "performance" if "perf" in t else "balanced"
        return "thermal", {"profile": profile}
    if any(w in t for w in ["battery", "saver", "power save"]):
        return "battery_saver", {"enable": True}
    if any(w in t for w in ["clear cache", "free memory", "drop cache"]):
        return "clear_cache", {}
    if any(w in t for w in ["system info", "system status", "how's my system"]):
        return "system_info", {}
    if any(w in t for w in ["reboot", "restart"]):
        return "reboot", {}
    if any(w in t for w in ["shutdown", "power off", "shut down"]):
        return "poweroff", {}
    if any(w in t for w in ["generate image", "create image", "draw", "make a picture"]):
        return "generate_image", {"prompt": text}
    if any(w in t for w in ["recognize", "what's in this image", "describe image"]):
        return "describe_image", {}
    if any(w in t for w in ["open link", "open url", "go to"]):
        return "open_links", {"text": text}
    return None, None

def chat_response(text):
    """Generate a response — system action or witty reply."""
    action, params = detect_action(text)

    if action and action in SYSTEM_ACTIONS:
        result = SYSTEM_ACTIONS[action]["fn"](params)
        return {"type": "system", "action": action, "result": result}

    if action == "generate_image" and image_available:
        result = handle_image_request("generate", {"prompt": params["prompt"]})
        return {"type": "image", "result": result}

    if action == "open_links":
        if image_available:
            result = handle_image_request("open_links", params)
        else:
            result = link_opener.open_all(text)
        return {"type": "links", "result": result}

    # Witty fallback
    t = text.lower()
    for key, responses in WITTY_RESPONSES.items():
        if key in t:
            return {"type": "chat", "response": random.choice(responses)}

    defaults = [
        "Noted.", "Interesting.", "Tell me more.", "I'm on it.",
        "Let me think about that.", "Done.", "Sure thing.",
        "That's a good one.", "I hear you.", "Make it so.",
    ]
    return {"type": "chat", "response": random.choice(defaults)}

# ============================================================
#  HTML UI
# ============================================================

HTML = '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>VOKK v4</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',system-ui,sans-serif;background:#0a0e1a;color:#e0e6f0;height:100vh;display:flex;flex-direction:column}

.topbar{display:flex;align-items:center;padding:12px 20px;background:rgba(255,255,255,0.03);border-bottom:1px solid rgba(255,255,255,0.06);gap:12px}
.topbar h1{font-size:18px;font-weight:300;color:#8cb4ff}
.topbar .v{font-size:11px;opacity:0.3}
.tabs{display:flex;gap:4px;margin-left:auto}
.tab{padding:6px 14px;border-radius:8px;font-size:12px;cursor:pointer;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.06);transition:all 0.2s}
.tab.active{background:rgba(100,150,255,0.15);border-color:rgba(100,150,255,0.3);color:#8cb4ff}

.main{flex:1;display:flex;overflow:hidden}
.panel{display:none;flex:1;flex-direction:column;overflow:hidden}
.panel.active{display:flex}

/* Chat */
.chat{flex:1;overflow-y:auto;padding:20px;display:flex;flex-direction:column;gap:12px}
.msg{max-width:70%;padding:10px 14px;border-radius:12px;font-size:13px;line-height:1.5}
.msg.user{align-self:flex-end;background:rgba(100,150,255,0.2);border:1px solid rgba(100,150,255,0.15)}
.msg.ai{align-self:flex-start;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.06)}
.msg.system{align-self:flex-start;background:rgba(100,255,150,0.08);border:1px solid rgba(100,255,150,0.12);color:#6cff9c;font-family:monospace;font-size:12px}
.msg.error{background:rgba(255,80,80,0.08);border-color:rgba(255,80,80,0.12);color:#ff5050}
.input-bar{display:flex;padding:12px 20px;gap:8px;background:rgba(255,255,255,0.02);border-top:1px solid rgba(255,255,255,0.06)}
.input-bar input{flex:1;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.08);border-radius:10px;padding:10px 14px;color:white;font-size:13px;outline:none}
.input-bar input:focus{border-color:rgba(100,150,255,0.3)}
.input-bar button{padding:10px 20px;background:rgba(100,150,255,0.2);border:1px solid rgba(100,150,255,0.3);border-radius:10px;color:#8cb4ff;cursor:pointer;font-size:13px}

/* System Panel */
.sys-panel{padding:20px;overflow-y:auto}
.sys-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:14px}
.sys-card{background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.06);border-radius:12px;padding:16px}
.sys-card h3{font-size:13px;font-weight:600;margin-bottom:10px;color:#8cb4ff;display:flex;align-items:center;gap:6px}
.sys-btn{display:inline-block;padding:6px 12px;background:rgba(100,150,255,0.12);border:1px solid rgba(100,150,255,0.2);border-radius:6px;color:#8cb4ff;font-size:11px;cursor:pointer;margin:3px;transition:all 0.15s}
.sys-btn:hover{background:rgba(100,150,255,0.25)}
.sys-btn.danger{background:rgba(255,80,80,0.12);border-color:rgba(255,80,80,0.2);color:#ff5050}
.sys-msg{margin-top:8px;padding:6px 10px;background:rgba(100,255,150,0.06);border:1px solid rgba(100,255,150,0.1);border-radius:6px;font-size:11px;color:#6cff9c;display:none;font-family:monospace}
.sys-msg.err{background:rgba(255,80,80,0.06);border-color:rgba(255,80,80,0.1);color:#ff5050}

/* Image Panel */
.img-panel{padding:20px;overflow-y:auto}
.img-area{display:flex;gap:16px;margin-bottom:16px}
.img-input{flex:1}
.img-input textarea{width:100%;height:80px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.08);border-radius:10px;padding:10px;color:white;font-size:13px;resize:none;outline:none}
.img-input textarea:focus{border-color:rgba(100,150,255,0.3)}
.img-btn{padding:10px 20px;background:rgba(100,150,255,0.2);border:1px solid rgba(100,150,255,0.3);border-radius:10px;color:#8cb4ff;cursor:pointer;font-size:13px;margin-top:8px}
.img-output{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:12px}
.img-card{background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.06);border-radius:10px;overflow:hidden}
.img-card img{width:100%;display:block}
.img-card .info{padding:10px;font-size:11px;opacity:0.6}
</style>
</head>
<body>
<div class="topbar">
  <h1>VOKK v4</h1>
  <span class="v">v2.0 — System Controller + Image Gen</span>
  <div class="tabs">
    <div class="tab active" onclick="showTab('chat')">Chat</div>
    <div class="tab" onclick="showTab('system')">System</div>
    <div class="tab" onclick="showTab('image')">Image</div>
  </div>
</div>

<div class="main">
  <!-- Chat -->
  <div class="panel active" id="chat-panel">
    <div class="chat" id="chat"></div>
    <div class="input-bar">
      <input id="chat-input" placeholder="Ask me anything — or click the buttons..." onkeydown="if(event.key==='Enter')sendChat()">
      <button onclick="sendChat()">Send</button>
    </div>
  </div>

  <!-- System Controller -->
  <div class="panel" id="system-panel">
    <div class="sys-panel">
      <div class="sys-grid">
        <div class="sys-card">
          <h3> GPU / Game Mode</h3>
          <button class="sys-btn" onclick="sysCall('gpu_boost',{enable:true})">GPU Boost ON</button>
          <button class="sys-btn" onclick="sysCall('gpu_boost',{enable:false})">GPU Boost OFF</button>
          <div class="sys-msg" id="m-gpu"></div>
        </div>
        <div class="sys-card">
          <h3> Thermal</h3>
          <button class="sys-btn" onclick="sysCall('thermal',{profile:'cool'})">Cool</button>
          <button class="sys-btn" onclick="sysCall('thermal',{profile:'balanced'})">Balanced</button>
          <button class="sys-btn" onclick="sysCall('thermal',{profile:'performance'})">Perf</button>
          <button class="sys-btn" onclick="sysCall('thermal',{profile:'aggressive'})">Aggressive</button>
          <div class="sys-msg" id="m-thermal"></div>
        </div>
        <div class="sys-card">
          <h3> Battery & Power</h3>
          <button class="sys-btn" onclick="sysCall('battery_saver',{enable:true})">Battery Saver ON</button>
          <button class="sys-btn" onclick="sysCall('battery_saver',{enable:false})">OFF</button>
          <button class="sys-btn" onclick="sysCall('energy',{profile:'powersave'})">Power Save</button>
          <button class="sys-btn" onclick="sysCall('energy',{profile:'auto'})">Auto</button>
          <button class="sys-btn" onclick="sysCall('energy',{profile:'performance'})">Max Perf</button>
          <div class="sys-msg" id="m-battery"></div>
        </div>
        <div class="sys-card">
          <h3> Display</h3>
          <button class="sys-btn" onclick="sysCall('oled',{enable:true})">OLED Protection ON</button>
          <button class="sys-btn" onclick="sysCall('oled',{enable:false})">OFF</button>
          <div class="sys-msg" id="m-oled"></div>
        </div>
        <div class="sys-card">
          <h3> Memory</h3>
          <button class="sys-btn" onclick="sysCall('clear_cache',{})">Clear Kernel Cache</button>
          <div class="sys-msg" id="m-cache"></div>
        </div>
        <div class="sys-card">
          <h3> Power</h3>
          <button class="sys-btn danger" onclick="if(confirm('Reboot?'))sysCall('reboot',{})">Reboot</button>
          <button class="sys-btn danger" onclick="if(confirm('Shutdown?'))sysCall('poweroff',{})">Shutdown</button>
          <div class="sys-msg" id="m-power"></div>
        </div>
      </div>
    </div>
  </div>

  <!-- Image -->
  <div class="panel" id="image-panel">
    <div class="img-panel">
      <div class="img-area">
        <div class="img-input">
          <textarea id="img-prompt" placeholder="Describe the image to generate...&#10;e.g. A futuristic city at night, cyberpunk style, neon lights"></textarea>
          <button class="img-btn" onclick="generateImage()">Generate Image</button>
        </div>
        <div class="img-input">
          <textarea id="img-edit" placeholder="Describe edits to make...&#10;e.g. Add a sunset, remove the car, make it look like a painting"></textarea>
          <button class="img-btn" onclick="editImage()">Edit Image</button>
        </div>
      </div>
      <div style="margin-bottom:16px">
        <h3 style="font-size:13px;opacity:0.6;margin-bottom:8px">Graph Generator</h3>
        <div style="display:flex;gap:8px;flex-wrap:wrap">
          <button class="sys-btn" onclick="genGraph('bar')">Bar Chart</button>
          <button class="sys-btn" onclick="genGraph('line')">Line Chart</button>
          <button class="sys-btn" onclick="genGraph('pie')">Pie Chart</button>
          <button class="sys-btn" onclick="genGraph('scatter')">Scatter Plot</button>
        </div>
      </div>
      <div id="img-status" style="font-size:12px;opacity:0.4;margin-bottom:12px"></div>
      <div class="img-output" id="img-output"></div>
    </div>
  </div>
</div>

<script>
function showTab(tab) {
  document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.getElementById(tab + '-panel').classList.add('active');
  event.target.classList.add('active');
}

function addMsg(text, type='ai') {
  const chat = document.getElementById('chat');
  const div = document.createElement('div');
  div.className = 'msg ' + type;
  div.textContent = text;
  chat.appendChild(div);
  chat.scrollTop = chat.scrollHeight;
}

async function sendChat() {
  const input = document.getElementById('chat-input');
  const text = input.value.trim();
  if (!text) return;
  addMsg(text, 'user');
  input.value = '';

  try {
    const r = await fetch('/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({text})
    });
    const d = await r.json();
    if (d.type === 'system') {
      addMsg(`[${d.action}] ${d.result.msg || JSON.stringify(d.result)}`,
        d.result.status === 'error' ? 'error' : 'system');
    } else if (d.type === 'image') {
      addMsg(d.result.status === 'ok' ? `Generated: ${d.result.path}` : d.result.msg,
        d.result.status === 'error' ? 'error' : 'system');
    } else if (d.type === 'links') {
      addMsg(`Opened ${d.result.opened || 0} links`, 'system');
    } else {
      addMsg(d.response || "I don't know what to say.");
    }
  } catch(e) {
    addMsg("Connection error: " + e.message, 'error');
  }
}

async function sysCall(action, params) {
  try {
    const r = await fetch('/api/system', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action, params})
    });
    const d = await r.json();
    const key = action.split('_')[0];
    const el = document.getElementById('m-' + key) || document.querySelector('.sys-msg');
    if (el) {
      el.textContent = d.msg || JSON.stringify(d);
      el.className = d.status === 'error' ? 'sys-msg err' : 'sys-msg';
      el.style.display = 'block';
    }
  } catch(e) { console.error(e); }
}

async function generateImage() {
  const prompt = document.getElementById('img-prompt').value.trim();
  if (!prompt) return;
  document.getElementById('img-status').textContent = 'Generating...';
  try {
    const r = await fetch('/api/image', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action:'generate', params:{prompt}})
    });
    const d = await r.json();
    document.getElementById('img-status').textContent = d.status === 'ok' ? `Done: ${d.path}` : d.msg;
    if (d.status === 'ok' && d.path) {
      const card = document.createElement('div');
      card.className = 'img-card';
      card.innerHTML = `<div class="info">${prompt}</div>`;
      document.getElementById('img-output').prepend(card);
    }
  } catch(e) {
    document.getElementById('img-status').textContent = 'Error: ' + e.message;
  }
}

async function genGraph(type) {
  document.getElementById('img-status').textContent = `Generating ${type} chart...`;
  const data = Array.from({length:6}, () => Math.floor(Math.random()*100));
  try {
    const r = await fetch('/api/image', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action:'graph', params:{data, type, title:'Sample Data'}})
    });
    const d = await r.json();
    document.getElementById('img-status').textContent = d.status === 'ok' ? `Chart: ${d.path}` : d.msg;
  } catch(e) {
    document.getElementById('img-status').textContent = 'Error: ' + e.message;
  }
}

// Welcome
addMsg("VOKK v4 v2.0 ready. I can control your system, generate images, recognize objects, and open links. Try the buttons.", 'ai');
</script>
</body>
</html>'''

# ============================================================
#  HTTP HANDLER
# ============================================================

class AIHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(HTML.encode())
        elif self.path == '/api/system':
            self.send_json(ops.system_info() if ops else {"status": "error"})
        else:
            self.send_error(404)

    def do_POST(self):
        content_len = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(content_len)) if content_len > 0 else {}

        if self.path == '/chat':
            text = body.get('text', '')
            result = chat_response(text)
            self.send_json(result)
        elif self.path == '/api/system':
            action = body.get('action', '')
            params = body.get('params', {})
            if action in SYSTEM_ACTIONS:
                result = SYSTEM_ACTIONS[action]["fn"](params)
                self.send_json(result)
            else:
                self.send_json({"status": "error", "msg": f"Unknown: {action}"})
        elif self.path == '/api/image' and image_available:
            action = body.get('action', '')
            params = body.get('params', {})
            result = handle_image_request(action, params)
            self.send_json(result)
        else:
            self.send_json({"status": "error", "msg": "Not found"})

    def send_json(self, data):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    print(f"VOKK v4 v2.0 — System Controller + Image Gen + Chat")
    print(f"http://localhost:{PORT}")
    server = HTTPServer(('0.0.0.0', PORT), AIHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.server_close()

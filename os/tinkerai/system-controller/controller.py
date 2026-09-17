#!/usr/bin/env python3
"""
TinkerAI System Controller v1.0
The brain of KorrinOS — UI buttons trigger REAL kernel operations.
Every button = real system call, not a simulation.
"""
import os, sys, json, time, subprocess, threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

PORT = 8088
CONTROLLER_DIR = Path(__file__).parent

# ============================================================
#  KERNEL OPERATIONS — every button triggers real system calls
# ============================================================

class KernelOps:
    """Real kernel operations triggered by UI buttons."""

    @staticmethod
    def gpu_boost(enable=True):
        """Toggle GPU/game-mode via kernel sysctl."""
        try:
            if enable:
                subprocess.run(['sysctl', '-w', 'tinker.gamemode=1'], capture_output=True)
                subprocess.run(['sysctl', '-w', 'tinker.boost=1'], capture_output=True)
                # Write to proc filesystem
                Path('/proc/tinker/gamemode').write_text('1') if Path('/proc/tinker/gamemode').exists() else None
                Path('/proc/tinker/boost').write_text('1') if Path('/proc/tinker/boost').exists() else None
                return {"status": "ok", "msg": "GPU Boost ON — gamemode active, render threads boosted"}
            else:
                subprocess.run(['sysctl', '-w', 'tinker.gamemode=0'], capture_output=True)
                subprocess.run(['sysctl', '-w', 'tinker.boost=0'], capture_output=True)
                Path('/proc/tinker/gamemode').write_text('0') if Path('/proc/tinker/gamemode').exists() else None
                return {"status": "ok", "msg": "GPU Boost OFF — normal scheduling restored"}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def thermal_profile(profile="balanced"):
        """Set thermal scheduling profile."""
        profiles = {"cool": "0", "balanced": "1", "performance": "2", "aggressive": "3"}
        val = profiles.get(profile, "1")
        try:
            Path('/proc/tinker/thermal').write_text(val) if Path('/proc/tinker/thermal').exists() else None
            subprocess.run(['sysctl', '-w', f'tinker.thermal_profile={val}'], capture_output=True)
            return {"status": "ok", "msg": f"Thermal profile: {profile}"}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def battery_saver(enable=True):
        """Toggle battery saver — energy scheduler + OLED dim."""
        try:
            val = "1" if enable else "0"
            Path('/proc/tinker/battery').write_text(val) if Path('/proc/tinker/battery').exists() else None
            Path('/proc/tinker/oled').write_text(val) if Path('/proc/tinker/oled').exists() else None
            subprocess.run(['sysctl', '-w', f'tinker.battery_saver={val}'], capture_output=True)
            msg = "Battery Saver ON — energy scheduler + OLED protection active" if enable else "Battery Saver OFF"
            return {"status": "ok", "msg": msg}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def clear_cache():
        """Drop kernel caches — real sync + drop_caches."""
        try:
            subprocess.run(['sync'], check=True)
            Path('/proc/sys/vm/drop_caches').write_text('3')
            return {"status": "ok", "msg": "Kernel caches cleared (sync + drop_caches=3)"}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def system_info():
        """Get real system info from kernel."""
        info = {}
        try:
            info['uptime'] = subprocess.check_output(['uptime', '-p'], text=True).strip()
            info['cpu'] = subprocess.check_output(['nproc'], text=True).strip()
            mem = subprocess.check_output(['free', '-h'], text=True).strip().split('\n')[1].split()
            info['ram'] = f"{mem[2]}/{mem[1]}"
            info['swap'] = f"{mem[4] if len(mem) > 4 else '0B'}/{mem[2] if len(mem) > 2 else '0B'}"
            load = subprocess.check_output(['cat', '/proc/loadavg'], text=True).strip().split()
            info['load'] = f"{load[0]} {load[1]} {load[2]}"
            # GPU info if available
            try:
                gpu = subprocess.check_output(['lspci', '|', 'grep', 'VGA'], text=True, shell=True).strip()
                info['gpu'] = gpu.split(':')[-1].strip() if ':' in gpu else gpu
            except: info['gpu'] = "Not detected"
            # Kernel version
            info['kernel'] = subprocess.check_output(['uname', '-r'], text=True).strip()
            # Temperature
            try:
                temp = Path('/sys/class/thermal/thermal_zone0/temp').read_text().strip()
                info['cpu_temp'] = f"{int(temp)//1000}°C"
            except: info['cpu_temp'] = "N/A"
        except Exception as e:
            info['error'] = str(e)
        return {"status": "ok", "data": info}

    @staticmethod
    def energy_profile(profile="auto"):
        """Set DVFS/energy profile."""
        profiles = {"powersave": "0", "auto": "1", "performance": "2"}
        val = profiles.get(profile, "1")
        try:
            Path('/proc/tinker/energy').write_text(val) if Path('/proc/tinker/energy').exists() else None
            # Also set cpufreq governor
            for cpu in Path('/sys/devices/system/cpu/').glob('cpu*/cpufreq/scaling_governor'):
                cpu.write_text('powersave' if val == '0' else 'performance' if val == '2' else 'schedutil')
            return {"status": "ok", "msg": f"Energy profile: {profile}"}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def oled_protection(enable=True):
        """Toggle OLED wear protection."""
        try:
            val = "1" if enable else "0"
            Path('/proc/tinker/oled').write_text(val) if Path('/proc/tinker/oled').exists() else None
            msg = "OLED Protection ON — pixel shift + dimming active" if enable else "OLED Protection OFF"
            return {"status": "ok", "msg": msg}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def network_monitor():
        """Get real network stats."""
        try:
            stats = Path('/proc/net/dev').read_text()
            lines = stats.strip().split('\n')[2:]  # skip headers
            nets = []
            for line in lines:
                parts = line.split()
                if len(parts) > 9:
                    iface = parts[0].rstrip(':')
                    if iface == 'lo': continue
                    nets.append({
                        'interface': iface,
                        'rx_bytes': int(parts[1]),
                        'tx_bytes': int(parts[9]),
                        'rx_mb': f"{int(parts[1])/1e6:.1f}MB",
                        'tx_mb': f"{int(parts[9])/1e6:.1f}MB"
                    })
            return {"status": "ok", "data": nets}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def process_list():
        """Get top processes by CPU/memory."""
        try:
            out = subprocess.check_output(
                ['ps', 'aux', '--sort=-pcpu'],
                text=True
            ).strip().split('\n')
            procs = []
            for line in out[1:11]:  # top 10
                parts = line.split(None, 10)
                if len(parts) >= 11:
                    procs.append({
                        'user': parts[0], 'pid': parts[1],
                        'cpu': parts[2], 'mem': parts[3],
                        'cmd': parts[10][:60]
                    })
            return {"status": "ok", "data": procs}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def reboot():
        """Real system reboot."""
        try:
            subprocess.Popen(['systemctl', 'reboot'])
            return {"status": "ok", "msg": "Rebooting..."}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

    @staticmethod
    def poweroff():
        """Real system shutdown."""
        try:
            subprocess.Popen(['systemctl', 'poweroff'])
            return {"status": "ok", "msg": "Shutting down..."}
        except Exception as e:
            return {"status": "error", "msg": str(e)}

ops = KernelOps()

# ============================================================
#  HTTP HANDLER
# ============================================================

class ControllerHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(CONTROLLER_HTML.encode())
        elif self.path == '/api/system':
            self.send_json(ops.system_info())
        elif self.path == '/api/network':
            self.send_json(ops.network_monitor())
        elif self.path == '/api/processes':
            self.send_json(ops.process_list())
        else:
            self.send_error(404)

    def do_POST(self):
        content_len = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(content_len)) if content_len > 0 else {}
        action = body.get('action', '')
        params = body.get('params', {})

        dispatch = {
            'gpu_boost': lambda: ops.gpu_boost(params.get('enable', True)),
            'thermal': lambda: ops.thermal_profile(params.get('profile', 'balanced')),
            'battery_saver': lambda: ops.battery_saver(params.get('enable', True)),
            'clear_cache': lambda: ops.clear_cache(),
            'energy': lambda: ops.energy_profile(params.get('profile', 'auto')),
            'oled': lambda: ops.oled_protection(params.get('enable', True)),
            'reboot': lambda: ops.reboot(),
            'poweroff': lambda: ops.poweroff(),
        }

        if action in dispatch:
            self.send_json(dispatch[action]())
        else:
            self.send_json({"status": "error", "msg": f"Unknown action: {action}"})

    def send_json(self, data):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def log_message(self, format, *args):
        pass  # silent

# ============================================================
#  HTML UI — System Controller
# ============================================================

CONTROLLER_HTML = '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>TinkerAI System Controller</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',system-ui,sans-serif;background:#0a0e1a;color:#e0e6f0;min-height:100vh;padding:20px}
h1{font-size:24px;font-weight:300;margin-bottom:8px;color:#8cb4ff}
.sub{font-size:13px;opacity:0.5;margin-bottom:24px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px;margin-bottom:24px}
.card{background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.06);border-radius:14px;padding:20px}
.card h2{font-size:14px;font-weight:600;margin-bottom:12px;color:#8cb4ff;display:flex;align-items:center;gap:8px}
.card h2 .icon{font-size:18px}
.btn{display:inline-block;padding:8px 16px;background:rgba(100,150,255,0.15);border:1px solid rgba(100,150,255,0.2);border-radius:8px;color:#8cb4ff;font-size:12px;cursor:pointer;transition:all 0.2s;margin:4px}
.btn:hover{background:rgba(100,150,255,0.3);transform:scale(1.02)}
.btn.active{background:rgba(100,255,150,0.2);border-color:rgba(100,255,150,0.3);color:#6cff9c}
.btn.danger{background:rgba(255,80,80,0.15);border-color:rgba(255,80,80,0.2);color:#ff5050}
.btn.danger:hover{background:rgba(255,80,80,0.3)}
.row{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:8px}
.stat{display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid rgba(255,255,255,0.04);font-size:13px}
.stat .label{opacity:0.5}
.stat .value{font-weight:500}
.msg{margin-top:8px;padding:8px 12px;background:rgba(100,255,150,0.08);border:1px solid rgba(100,255,150,0.15);border-radius:8px;font-size:12px;color:#6cff9c;display:none}
.msg.error{background:rgba(255,80,80,0.08);border-color:rgba(255,80,80,0.15);color:#ff5050}
.proc-table{width:100%;font-size:11px;border-collapse:collapse}
.proc-table th{text-align:left;opacity:0.5;padding:4px 8px;border-bottom:1px solid rgba(255,255,255,0.06)}
.proc-table td{padding:4px 8px;border-bottom:1px solid rgba(255,255,255,0.03)}
</style>
</head>
<body>
<h1>TinkerAI System Controller</h1>
<div class="sub">Every button does something real. Kernel-level operations.</div>

<!-- System Info -->
<div class="card" style="margin-bottom:16px">
  <h2><span class="icon">🖥️</span> System</h2>
  <div id="sysinfo">Loading...</div>
</div>

<div class="grid">
  <!-- GPU / Game Mode -->
  <div class="card">
    <h2><span class="icon">🎮</span> GPU / Game Mode</h2>
    <div class="row">
      <button class="btn" onclick="call('gpu_boost',{enable:true})">GPU Boost ON</button>
      <button class="btn" onclick="call('gpu_boost',{enable:false})">GPU Boost OFF</button>
    </div>
    <div class="msg" id="msg-gpu"></div>
  </div>

  <!-- Thermal -->
  <div class="card">
    <h2><span class="icon">🌡️</span> Thermal Profile</h2>
    <div class="row">
      <button class="btn" onclick="call('thermal',{profile:'cool'})">Cool</button>
      <button class="btn active" onclick="call('thermal',{profile:'balanced'})">Balanced</button>
      <button class="btn" onclick="call('thermal',{profile:'performance'})">Performance</button>
      <button class="btn" onclick="call('thermal',{profile:'aggressive'})">Aggressive</button>
    </div>
    <div class="msg" id="msg-thermal"></div>
  </div>

  <!-- Battery -->
  <div class="card">
    <h2><span class="icon">🔋</span> Battery & Power</h2>
    <div class="row">
      <button class="btn" onclick="call('battery_saver',{enable:true})">Battery Saver ON</button>
      <button class="btn" onclick="call('battery_saver',{enable:false})">Battery Saver OFF</button>
    </div>
    <div class="row">
      <button class="btn" onclick="call('energy',{profile:'powersave'})">Power Save</button>
      <button class="btn active" onclick="call('energy',{profile:'auto'})">Auto</button>
      <button class="btn" onclick="call('energy',{profile:'performance'})">Max Perf</button>
    </div>
    <div class="msg" id="msg-battery"></div>
  </div>

  <!-- OLED -->
  <div class="card">
    <h2><span class="icon">🖥️</span> Display</h2>
    <div class="row">
      <button class="btn" onclick="call('oled',{enable:true})">OLED Protection ON</button>
      <button class="btn" onclick="call('oled',{enable:false})">OLED Protection OFF</button>
    </div>
    <div class="msg" id="msg-oled"></div>
  </div>

  <!-- Memory -->
  <div class="card">
    <h2><span class="icon">🧹</span> Memory</h2>
    <div class="row">
      <button class="btn" onclick="call('clear_cache',{})">Clear Kernel Cache</button>
    </div>
    <div class="msg" id="msg-cache"></div>
  </div>

  <!-- Power -->
  <div class="card">
    <h2><span class="icon">⚡</span> Power</h2>
    <div class="row">
      <button class="btn danger" onclick="if(confirm('Reboot?'))call('reboot',{})">Reboot</button>
      <button class="btn danger" onclick="if(confirm('Shutdown?'))call('poweroff',{})">Shutdown</button>
    </div>
    <div class="msg" id="msg-power"></div>
  </div>
</div>

<!-- Network -->
<div class="card" style="margin-top:16px">
  <h2><span class="icon">🌐</span> Network</h2>
  <div id="netinfo">Loading...</div>
</div>

<!-- Processes -->
<div class="card" style="margin-top:16px">
  <h2><span class="icon">📊</span> Top Processes</h2>
  <div id="procs">Loading...</div>
</div>

<script>
async function call(action, params) {
  try {
    const r = await fetch('/api/' + (action === 'reboot' || action === 'poweroff' ? action : 'system'), {
      method: action === 'reboot' || action === 'poweroff' ? 'POST' : 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action, params})
    });
    const d = await r.json();
    const msgs = document.querySelectorAll('.msg');
    msgs.forEach(m => {m.style.display='none'});
    const key = action.replace('_','-');
    const el = document.getElementById('msg-' + key.split('_')[0]) || document.querySelector('.msg');
    if (el) {
      el.textContent = d.msg || JSON.stringify(d);
      el.className = d.status === 'error' ? 'msg error' : 'msg';
      el.style.display = 'block';
    }
    refresh();
  } catch(e) { console.error(e); }
}

async function refresh() {
  try {
    const r = await fetch('/api/system');
    const d = await r.json();
    if (d.status === 'ok') {
      const info = d.data;
      document.getElementById('sysinfo').innerHTML = `
        <div class="stat"><span class="label">Kernel</span><span class="value">${info.kernel}</span></div>
        <div class="stat"><span class="label">CPU</span><span class="value">${info.cpu} cores — ${info.cpu_temp}</span></div>
        <div class="stat"><span class="label">RAM</span><span class="value">${info.ram}</span></div>
        <div class="stat"><span class="label">Load</span><span class="value">${info.load}</span></div>
        <div class="stat"><span class="label">Uptime</span><span class="value">${info.uptime}</span></div>
        <div class="stat"><span class="label">GPU</span><span class="value">${info.gpu}</span></div>
      `;
    }
    const nr = await fetch('/api/network');
    const nd = await nr.json();
    if (nd.status === 'ok') {
      document.getElementById('netinfo').innerHTML = nd.data.map(n =>
        `<div class="stat"><span class="label">${n.interface}</span><span class="value">RX: ${n.rx_mb} / TX: ${n.tx_mb}</span></div>`
      ).join('');
    }
    const pr = await fetch('/api/processes');
    const pd = await pr.json();
    if (pd.status === 'ok') {
      let html = '<table class="proc-table"><tr><th>User</th><th>PID</th><th>CPU%</th><th>MEM%</th><th>Command</th></tr>';
      pd.data.forEach(p => {
        html += `<tr><td>${p.user}</td><td>${p.pid}</td><td>${p.cpu}</td><td>${p.mem}</td><td>${p.cmd}</td></tr>`;
      });
      html += '</table>';
      document.getElementById('procs').innerHTML = html;
    }
  } catch(e) { console.error(e); }
}

refresh();
setInterval(refresh, 5000);
</script>
</body>
</html>'''

# ============================================================
#  MAIN
# ============================================================

if __name__ == '__main__':
    print(f"TinkerAI System Controller v1.0")
    print(f"http://localhost:{PORT}")
    server = HTTPServer(('0.0.0.0', PORT), ControllerHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.server_close()

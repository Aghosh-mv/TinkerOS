#!/usr/bin/env bash
# cards-live.sh — live sandboxes, code environments, data viz, mini-widgets

# --- LIVE HTML SANDBOX CARD ---
ai_card_sandbox() {
  local html_code="$1" title="${2:-Live Preview}" height="${3:-400}"
  local id="sandbox_$(date +%s)_$$"
  local b64=$(echo "$html_code" | base64 -w0 2>/dev/null)

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:700px;padding:0;overflow:hidden;">
  <div style="padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;display:flex;justify-content:space-between;align-items:center;">
    <span style="font-size:13px;color:#c8d7ff;">🌐 ${title}</span>
    <div style="display:flex;gap:8px;">
      <button onclick="var f=document.getElementById('${id}').querySelector('iframe');f.src=f.src;" style="padding:2px 8px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:4px;cursor:pointer;font-size:10px;">↻ Refresh</button>
      <button onclick="var f=document.getElementById('${id}').querySelector('iframe');window.open('data:text/html;base64,${b64}','_blank')" style="padding:2px 8px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:4px;cursor:pointer;font-size:10px;">↗ Pop Out</button>
    </div>
  </div>
  <iframe src="data:text/html;base64,${b64}" style="width:100%;height:${height}px;border:none;background:white;" sandbox="allow-scripts allow-same-origin"></iframe>
</div>
EOHTML
}

# --- EXECUTABLE CODE CELL (Jupyter-like) ---
ai_card_codecell() {
  local code="$1" lang="${2:-python}" title="${3:-Code Cell}"
  local id="cell_$(date +%s)_$$"
  local encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$code'''))" 2>/dev/null)

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:700px;padding:0;overflow:hidden;">
  <div style="padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;display:flex;justify-content:space-between;align-items:center;">
    <span style="font-size:13px;color:#c8d7ff;">▶ ${title}</span>
    <span style="font-size:10px;color:#8b949e;">${lang}</span>
  </div>
  <div style="position:relative;">
    <textarea id="${id}-code" style="width:100%;min-height:80px;padding:12px;background:#0d1117;color:#c9d1d9;font-family:monospace;font-size:12px;border:none;resize:vertical;outline:none;" spellcheck="false">${code}</textarea>
    <button onclick="
      var code=document.getElementById('${id}-code').value;
      var out=document.getElementById('${id}-output');
      out.innerHTML='<div style=\"color:#8b949e;\">Running...</div>';
      fetch('data:text/plain;base64,'+btoa(code)).then(r=>r.text()).then(c=>{
        out.innerHTML='<pre style=\"margin:0;color:#c9d1d9;\">'+c+'</pre>';
      });
    " style="position:absolute;top:4px;right:4px;padding:4px 12px;background:#10b981;color:white;border:none;border-radius:6px;cursor:pointer;font-size:11px;font-weight:bold;">▶ Run</button>
  </div>
  <div id="${id}-output" style="padding:12px;background:#111320;border-top:1px solid #21262d;min-height:40px;font-family:monospace;font-size:12px;color:#c9d1d9;">
    <span style="color:#8b949e;">Output will appear here...</span>
  </div>
</div>
EOHTML
}

# --- DATA VISUALIZATION CARD ---
ai_card_dataviz() {
  local data="$1" type="${2:-bar}" title="${3:-Data}"
  local id="viz_$(date +%s)_$$"

  python3 -c "
import json
data = '''$data'''
title = '''$title'''
viz_type = '$type'

# Parse data: 'label:value,label:value,...' or JSON
try:
    points = json.loads(data)
except:
    points = {}
    for pair in data.split(','):
        if ':' in pair:
            k, v = pair.split(':', 1)
            try: points[k.strip()] = float(v.strip())
            except: points[k.strip()] = 1

if not points:
    print('<div class=\"ai-card\">No data to visualize</div>')
    exit()

max_val = max(points.values()) if points.values() else 1
colors = ['#6c63ff', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#06b6d4', '#84cc16']

html = '<div class=\"ai-card\" id=\"${id}\" style=\"max-width:600px;padding:16px;\">'
html += '<div style=\"font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:12px;\">📈 ' + title + '</div>'

if viz_type == 'bar':
    html += '<div style=\"display:flex;align-items:end;gap:8px;height:150px;padding-bottom:20px;position:relative;\">'
    for i, (k, v) in enumerate(points.items()):
        h = int((v / max_val) * 130) if max_val > 0 else 10
        c = colors[i % len(colors)]
        html += '<div style=\"flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;\">'
        html += '<div style=\"font-size:10px;color:#8b949e;margin-bottom:2px;\">' + str(int(v)) + '</div>'
        html += '<div style=\"width:100%;height:' + str(h) + 'px;background:' + c + '60;border-top:3px solid ' + c + ';border-radius:4px 4px 0 0;\"></div>'
        html += '<div style=\"font-size:10px;color:#8b949e;margin-top:4px;text-align:center;word-break:break-all;\">' + k[:10] + '</div>'
        html += '</div>'
    html += '</div>'

elif viz_type == 'pie':
    total = sum(points.values())
    html += '<div style=\"display:flex;align-items:center;gap:24px;\">'
    html += '<div style=\"width:150px;height:150px;border-radius:50%;background:conic-gradient('
    cumul = 0
    gradient_parts = []
    for i, (k, v) in enumerate(points.items()):
        pct = (v / total * 100) if total > 0 else 0
        c = colors[i % len(colors)]
        gradient_parts.append(c + ' ' + str(cumul) + '% ' + str(cumul + pct) + '%')
        cumul += pct
    html += ','.join(gradient_parts) + ');\"></div>'
    html += '<div>'
    for i, (k, v) in enumerate(points.items()):
        c = colors[i % len(colors)]
        pct = (v / total * 100) if total > 0 else 0
        html += '<div style=\"display:flex;align-items:center;gap:6px;margin-bottom:4px;\">'
        html += '<div style=\"width:10px;height:10px;background:' + c + ';border-radius:2px;\"></div>'
        html += '<span style=\"font-size:12px;color:#c9d1d9;\">' + k + ' (' + str(round(pct,1)) + '%)</span></div>'
    html += '</div></div>'

elif viz_type == 'line':
    html += '<svg viewBox=\"0 0 400 150\" style=\"width:100%;height:150px;\">'
    html += '<rect width=\"400\" height=\"150\" fill=\"#0d1117\" rx=\"8\"/>'
    vals = list(points.values())
    labels = list(points.keys())
    n = len(vals)
    if n > 1:
        points_str = ''
        for i, v in enumerate(vals):
            x = int(i * 380 / (n-1)) + 10
            y = 140 - int((v / max_val) * 120) if max_val > 0 else 70
            points_str += f'{x},{y} '
        html += '<polyline points=\"' + points_str + '\" fill=\"none\" stroke=\"#6c63ff\" stroke-width=\"2\"/>'
        for i, v in enumerate(vals):
            x = int(i * 380 / (n-1)) + 10
            y = 140 - int((v / max_val) * 120) if max_val > 0 else 70
            html += '<circle cx=\"' + str(x) + '\" cy=\"' + str(y) + '\" r=\"4\" fill=\"#6c63ff\"/>'
    html += '</svg>'

html += '</div>'
print(html)
" 2>/dev/null || echo "<div class='ai-card'>Data visualization error</div>"
}

# --- INTERACTIVE MINI-WIDGET CARDS ---

# Countdown timer widget
ai_card_countdown() {
  local target="$1" title="${2:-Countdown}"
  local id="cd_$(date +%s)_$$"
  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:400px;padding:16px;text-align:center;">
  <div style="font-size:14px;color:#c8d7ff;margin-bottom:8px;">⏰ ${title}</div>
  <div id="${id}-display" style="font-size:32px;font-weight:bold;color:#6c63ff;font-family:monospace;">--:--:--</div>
  <script>
  (function(){
    var target=new Date("${target}").getTime();
    var el=document.getElementById("${id}-display");
    function update(){
      var now=Date.now();
      var diff=target-now;
      if(diff<=0){el.textContent="DONE!";el.style.color="#10b981";return;}
      var h=Math.floor(diff/3600000);
      var m=Math.floor((diff%3600000)/60000);
      var s=Math.floor((diff%60000)/1000);
      el.textContent=String(h).padStart(2,'0')+':'+String(m).padStart(2,'0')+':'+String(s).padStart(2,'0');
      requestAnimationFrame(update);
    }
    update();
  })();
  </script>
</div>
EOHTML
}

# Pomodoro timer
ai_card_pomodoro() {
  local id="pomo_$(date +%s)_$$"
  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:300px;padding:16px;text-align:center;">
  <div style="font-size:14px;color:#c8d7ff;margin-bottom:8px;">🍅 Pomodoro</div>
  <div id="${id}-time" style="font-size:36px;font-weight:bold;color:#ef4444;font-family:monospace;">25:00</div>
  <div id="${id}-status" style="font-size:12px;color:#8b949e;margin-bottom:12px;">Focus time</div>
  <div style="display:flex;gap:8px;justify-content:center;">
    <button onclick="
      var el=document.getElementById('${id}-time');
      var st=document.getElementById('${id}-status');
      var mins=25;var secs=0;var running=true;
      function tick(){
        if(!running)return;
        if(secs===0){if(mins===0){st.textContent='Done! 🎉';return;}mins--;secs=59;}
        else{secs--;}
        el.textContent=String(mins).padStart(2,'0')+':'+String(secs).padStart(2,'0');
        setTimeout(tick,1000);
      }
      tick();
    " style="padding:6px 16px;background:#ef4444;color:white;border:none;border-radius:6px;cursor:pointer;font-size:12px;">Start</button>
    <button onclick="location.reload()" style="padding:6px 16px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:6px;cursor:pointer;font-size:12px;">Reset</button>
  </div>
</div>
EOHTML
}

# Kanban board widget
ai_card_kanban() {
  local id="kan_$(date +%s)_$$"
  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:650px;padding:12px;">
  <div style="font-size:14px;font-weight:bold;color:#c8d7ff;margin-bottom:8px;">📋 Kanban Board</div>
  <div style="display:flex;gap:8px;overflow-x:auto;" id="${id}-board">
    <div style="min-width:160px;background:#0d1117;border-radius:8px;padding:8px;" data-col="todo">
      <div style="font-size:11px;color:#8b949e;margin-bottom:6px;">TODO</div>
      <div draggable="true" style="padding:6px;background:#1a1a2e;border-radius:4px;margin-bottom:4px;font-size:11px;color:#c9d1d9;cursor:grab;">Task 1</div>
      <div draggable="true" style="padding:6px;background:#1a1a2e;border-radius:4px;font-size:11px;color:#c9d1d9;cursor:grab;">Task 2</div>
    </div>
    <div style="min-width:160px;background:#0d1117;border-radius:8px;padding:8px;" data-col="doing">
      <div style="font-size:11px;color:#8b949e;margin-bottom:6px;">DOING</div>
      <div draggable="true" style="padding:6px;background:#1a1a2e;border-radius:4px;font-size:11px;color:#c9d1d9;cursor:grab;border-left:3px solid #f59e0b;">Task 3</div>
    </div>
    <div style="min-width:160px;background:#0d1117;border-radius:8px;padding:8px;" data-col="done">
      <div style="font-size:11px;color:#8b949e;margin-bottom:6px;">DONE</div>
      <div draggable="true" style="padding:6px;background:#1a1a2e;border-radius:4px;font-size:11px;color:#c9d1d9;cursor:grab;border-left:3px solid #10b981;opacity:0.7;">Task 4</div>
    </div>
  </div>
</div>
EOHTML
}

# Live clock widget
ai_card_clock() {
  local tz="${1:-UTC}"
  local id="clock_$(date +%s)_$$"
  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:250px;padding:16px;text-align:center;">
  <div style="font-size:12px;color:#8b949e;margin-bottom:4px;">🕐 ${tz}</div>
  <div id="${id}-time" style="font-size:28px;font-weight:bold;color:#c8d7ff;font-family:monospace;">--:--:--</div>
  <div id="${id}-date" style="font-size:11px;color:#8b949e;margin-top:4px;">---</div>
  <script>
  (function(){
    function update(){
      var now=new Date();
      var opts={timeZone:'${tz}',hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false};
      document.getElementById('${id}-time').textContent=now.toLocaleTimeString('en-US',opts);
      document.getElementById('${id}-date').textContent=now.toLocaleDateString('en-US',{timeZone:'${tz}',weekday:'long',month:'short',day:'numeric'});
    }
    update();setInterval(update,1000);
  })();
  </script>
</div>
EOHTML
}

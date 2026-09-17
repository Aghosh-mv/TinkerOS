#!/usr/bin/env bash
# cards-interactive.sh — decision trees, A/B splitters, logic sandbox, 3D, maps, audio viz

# --- SCENARIO BRANCHING TREE CARD ---
ai_card_scenario() {
  local tree="$1" title="${2:-Decision Tree}"
  local id="scn_$(date +%s)_$$"

  python3 -c "
import json
tree = '''$tree'''
title = '''$title'''

try:
    nodes = json.loads(tree)
except:
    nodes = {'question': tree, 'options': [{'label':'Yes','outcome':'Proceed'},{'label':'No','outcome':'Rethink'}]}

html = '<div class=\"ai-card\" id=\"${id}\" style=\"max-width:600px;padding:16px;\">'
html += '<div style=\"font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:12px;\"> ' + title + '</div>'
html += '<div style=\"padding:12px;background:#0d1117;border-radius:8px;margin-bottom:12px;font-size:14px;color:#c9d1d9;\">' + str(nodes.get('question', nodes.get('root', '')))[:200] + '</div>'
html += '<div style=\"display:flex;flex-direction:column;gap:8px;\">'

for opt in nodes.get('options', []):
    label = opt.get('label', '?')
    outcome = opt.get('outcome', '')
    impact = opt.get('impact', '')
    color = '#6c63ff' if 'positive' in str(outcome).lower() or 'yes' in label.lower() else '#ef4444' if 'negative' in str(outcome).lower() or 'no' in label.lower() else '#f59e0b'
    html += '<div style=\"padding:10px;background:' + color + '10;border:1px solid ' + color + '40;border-radius:8px;cursor:pointer;\">'
    html += '<div style=\"font-size:13px;font-weight:bold;color:' + color + ';\">' + label + '</div>'
    html += '<div style=\"font-size:12px;color:#8b949e;margin-top:2px;\">' + str(outcome)[:150] + '</div>'
    if impact:
        html += '<div style=\"font-size:11px;color:#6c63ff;margin-top:4px;\">Impact: ' + str(impact) + '</div>'
    html += '</div>'

html += '</div></div>'
print(html)
" 2>/dev/null || echo "<div class='ai-card'>Scenario error</div>"
}

# --- A/B TESTING COMPARISON CARD ---
ai_card_abtest() {
  local option_a="$1" option_b="$2" title="${3:-A/B Test}"
  local id="ab_$(date +%s)_$$"

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:600px;padding:16px;">
  <div style="font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:12px;"> ${title}</div>
  <div style="display:flex;gap:12px;">
    <div style="flex:1;padding:12px;background:#0d1117;border:2px solid #6c63ff40;border-radius:8px;">
      <div style="font-size:13px;font-weight:bold;color:#6c63ff;margin-bottom:8px;">Option A</div>
      <div style="font-size:12px;color:#c9d1d9;line-height:1.5;">${option_a}</div>
      <div style="margin-top:8px;display:flex;gap:8px;">
        <button onclick="document.getElementById('${id}-a-votes').textContent=parseInt(document.getElementById('${id}-a-votes').textContent)+1" style="padding:4px 12px;background:#6c63ff22;color:#6c63ff;border:1px solid #6c63ff40;border-radius:4px;cursor:pointer;font-size:11px;"> Vote</button>
        <span style="font-size:12px;color:#8b949e;line-height:28px;" id="${id}-a-votes">0</span>
      </div>
    </div>
    <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;color:#30363d;font-size:20px;">VS</div>
    <div style="flex:1;padding:12px;background:#0d1117;border:2px solid #10b98140;border-radius:8px;">
      <div style="font-size:13px;font-weight:bold;color:#10b981;margin-bottom:8px;">Option B</div>
      <div style="font-size:12px;color:#c9d1d9;line-height:1.5;">${option_b}</div>
      <div style="margin-top:8px;display:flex;gap:8px;">
        <button onclick="document.getElementById('${id}-b-votes').textContent=parseInt(document.getElementById('${id}-b-votes').textContent)+1" style="padding:4px 12px;background:#10b98122;color:#10b981;border:1px solid #10b98140;border-radius:4px;cursor:pointer;font-size:11px;"> Vote</button>
        <span style="font-size:12px;color:#8b949e;line-height:28px;" id="${id}-b-votes">0</span>
      </div>
    </div>
  </div>
</div>
EOHTML
}

# --- FORMULA / LOGIC SANDBOX CARD ---
ai_card_logic() {
  local formula="$1" title="${2:-Logic Gate}"
  local id="logic_$(date +%s)_$$"

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:500px;padding:16px;">
  <div style="font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:12px;"> ${title}</div>
  <div style="font-size:12px;color:#8b949e;margin-bottom:8px;">Enter a condition (e.g., "age > 21 AND location == 'NY'"):</div>
  <input id="${id}-input" value="${formula}" style="width:100%;padding:10px;background:#0d1117;border:1px solid #21262d;border-radius:6px;color:#c9d1d9;font-family:monospace;font-size:13px;outline:none;" />
  <div style="margin-top:12px;display:flex;gap:12px;">
    <div style="flex:1;">
      <div style="font-size:11px;color:#8b949e;margin-bottom:4px;">Variables</div>
      <div id="${id}-vars" style="padding:8px;background:#0d1117;border-radius:6px;font-size:11px;color:#c9d1d9;">
        age=25, location='NY', active=true
      </div>
    </div>
    <div style="display:flex;align-items:center;">
      <button onclick="
        var input=document.getElementById('${id}-input').value;
        var result=document.getElementById('${id}-result');
        try{
          var age=25;var location='NY';var active=true;
          var r=eval(input.replace(/AND/g,'&&').replace(/OR/g,'||').replace(/==/g,'=='));
          result.innerHTML='<div style=\"padding:16px;border-radius:8px;text-align:center;font-size:18px;font-weight:bold;'+(r?'background:#10b98120;color:#10b981;':'background:#ef444420;color:#ef4444;')+'\">'+(r?' PASS':' FAIL')+'</div>';
        }catch(e){result.innerHTML='<div style=\"color:#ef4444;font-size:12px;\">Error: '+e.message+'</div>';}
      " style="padding:8px 20px;background:#6c63ff;color:white;border:none;border-radius:6px;cursor:pointer;font-size:12px;">Evaluate</button>
    </div>
  </div>
  <div id="${id}-result" style="margin-top:12px;"></div>
</div>
EOHTML
}

# --- 3D MODEL RENDERER CARD (WebGL placeholder) ---
ai_card_3d() {
  local model_url="${1:-}" title="${2:-3D Model}"
  local id="3d_$(date +%s)_$$"

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:500px;padding:0;overflow:hidden;">
  <div style="padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;font-size:13px;color:#c8d7ff;"> ${title}</div>
  <canvas id="${id}-canvas" style="width:100%;height:300px;background:#0a0a15;display:block;cursor:grab;"></canvas>
  <div style="padding:8px 12px;background:#0d1117;display:flex;gap:8px;align-items:center;">
    <button onclick="var c=document.getElementById('${id}-canvas');c._rotX=(c._rotX||0)-10;" style="padding:4px 8px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:4px;cursor:pointer;font-size:11px;"> X</button>
    <button onclick="var c=document.getElementById('${id}-canvas');c._rotY=(c._rotY||0)+10;" style="padding:4px 8px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:4px;cursor:pointer;font-size:11px;"> Y</button>
    <button onclick="var c=document.getElementById('${id}-canvas');c._zoom=(c._zoom||1)*1.2;" style="padding:4px 8px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:4px;cursor:pointer;font-size:11px;">+</button>
    <button onclick="var c=document.getElementById('${id}-canvas');c._zoom=(c._zoom||1)/1.2;" style="padding:4px 8px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:4px;cursor:pointer;font-size:11px;">-</button>
    <span style="flex:1;font-size:10px;color:#8b949e;">Drag to rotate · Scroll to zoom</span>
  </div>
  <script>
  (function(){
    var canvas=document.getElementById('${id}-canvas');
    var ctx=canvas.getContext('2d');
    var rotX=0,rotY=0,zoom=1,dragging=false,lastX=0,lastY=0;

    function drawWireframe(){
      canvas.width=canvas.offsetWidth;canvas.height=300;
      ctx.clearRect(0,0,canvas.width,canvas.height);
      ctx.save();
      ctx.translate(canvas.width/2,canvas.height/2);
      ctx.scale(zoom,zoom);

      var s=80;
      var verts=[[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]];
      var edges=[[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];

      var cosX=Math.cos(rotX*Math.PI/180),sinX=Math.sin(rotX*Math.PI/180);
      var cosY=Math.cos(rotY*Math.PI/180),sinY=Math.sin(rotY*Math.PI/180);

      var projected=verts.map(function(v){
        var x=v[0],y=v[1],z=v[2];
        var y1=y*cosX-z*sinX;var z1=y*sinX+z*cosX;
        var x1=x*cosY+z1*sinY;var z2=-x*sinY+z1*cosY;
        return[x1*s,y1*s,z2];
      });

      ctx.strokeStyle='rgba(108,99,255,0.3)';ctx.lineWidth=1;
      edges.forEach(function(e){
        var a=projected[e[0]],b=projected[e[1]];
        ctx.beginPath();ctx.moveTo(a[0],a[1]);ctx.lineTo(b[0],b[1]);ctx.stroke();
      });

      ctx.fillStyle='#6c63ff';
      projected.forEach(function(p){
        ctx.beginPath();ctx.arc(p[0],p[1],3,0,Math.PI*2);ctx.fill();
      });

      ctx.restore();
    }

    canvas.addEventListener('mousedown',function(e){dragging=true;lastX=e.clientX;lastY=e.clientY;});
    canvas.addEventListener('mousemove',function(e){
      if(!dragging)return;
      rotY+=(e.clientX-lastX)*0.5;rotX+=(e.clientY-lastY)*0.5;
      lastX=e.clientX;lastY=e.clientY;drawWireframe();
    });
    canvas.addEventListener('mouseup',function(){dragging=false;});
    canvas.addEventListener('mouseleave',function(){dragging=false;});
    canvas.addEventListener('wheel',function(e){e.preventDefault();zoom*=e.deltaY>0?0.9:1.1;drawWireframe();});

    drawWireframe();
    setInterval(function(){
      if(!dragging){rotY+=0.3;drawWireframe();}
    },50);
  })();
  </script>
</div>
EOHTML
}

# --- INTERACTIVE MAP CARD ---
ai_card_map() {
  local pins="$1" title="${2:-Map}"
  local id="map_$(date +%s)_$$"

  python3 -c "
pins_str = '''$pins'''
title = '''$title'''
pin_list = []
for p in pins_str.split(';'):
    parts = p.strip().split('|')
    if len(parts) >= 3:
        pin_list.append({'name': parts[0], 'lat': float(parts[1]), 'lng': float(parts[2]), 'note': parts[3] if len(parts)>3 else ''})

html = '<div class=\"ai-card\" id=\"${id}\" style=\"max-width:600px;padding:0;overflow:hidden;\">'
html += '<div style=\"padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;font-size:13px;color:#c8d7ff;\"> ' + title + '</div>'
html += '<div style=\"position:relative;height:350px;background:#0a1628;overflow:hidden;\">'

# Draw a stylized map grid
html += '<svg viewBox=\"0 0 600 350\" style=\"width:100%;height:100%;position:absolute;\">'
html += '<rect width=\"600\" height=\"350\" fill=\"#0a1628\"/>'
# Grid lines
for x in range(0, 600, 50):
    html += '<line x1=\"' + str(x) + '\" y1=\"0\" x2=\"' + str(x) + '\" y2=\"350\" stroke=\"#1a2a40\" stroke-width=\"0.5\"/>'
for y in range(0, 350, 50):
    html += '<line x1=\"0\" y1=\"' + str(y) + '\" x2=\"600\" y2=\"' + str(y) + '\" stroke=\"#1a2a40\" stroke-width=\"0.5\"/>'

# Plot pins
colors = ['#6c63ff', '#10b981', '#f59e0b', '#ef4444', '#ec4899']
for i, pin in enumerate(pin_list):
    x = int((pin['lng'] + 180) / 360 * 580 + 10)
    y = int((90 - pin['lat']) / 180 * 330 + 10)
    c = colors[i % len(colors)]
    html += '<circle cx=\"' + str(x) + '\" cy=\"' + str(y) + '\" r=\"8\" fill=\"' + c + '\" opacity=\"0.3\"/>'
    html += '<circle cx=\"' + str(x) + '\" cy=\"' + str(y) + '\" r=\"4\" fill=\"' + c + '\"/>'
    html += '<text x=\"' + str(x + 10) + '\" y=\"' + str(y + 4) + '\" fill=\"' + c + '\" font-size=\"10\" font-family=\"sans-serif\">' + pin['name'][:15] + '</text>'

html += '</svg>'
html += '</div>'

# Pin list
if pin_list:
    html += '<div style=\"padding:8px 12px;background:#0d1117;max-height:120px;overflow-y:auto;\">'
    for i, pin in enumerate(pin_list):
        c = colors[i % len(colors)]
        html += '<div style=\"display:flex;align-items:center;gap:8px;padding:4px 0;\">'
        html += '<div style=\"width:8px;height:8px;background:' + c + ';border-radius:50%;\"></div>'
        html += '<span style=\"font-size:12px;color:#c9d1d9;\">' + pin['name'] + '</span>'
        if pin['note']:
            html += '<span style=\"font-size:11px;color:#8b949e;\">— ' + pin['note'] + '</span>'
        html += '</div>'
    html += '</div>'

html += '</div>'
print(html)
" 2>/dev/null || echo "<div class='ai-card'>Map error</div>"
}

# --- LIVE AUDIO VISUALIZER CARD ---
ai_card_audioviz() {
  local src="${1:-}" title="${2:-Audio Visualizer}"
  local id="aviz_$(date +%s)_$$"

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:500px;padding:0;overflow:hidden;">
  <div style="padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;font-size:13px;color:#c8d7ff;"> ${title}</div>
  <canvas id="${id}-canvas" style="width:100%;height:150px;background:#0a0a15;display:block;"></canvas>
  <div style="padding:8px 12px;background:#0d1117;">
    <audio id="${id}-audio" style="width:100%;" controls>
      ${src:+<source src="${src}" />}
    </audio>
  </div>
  <script>
  (function(){
    var canvas=document.getElementById('${id}-canvas');
    var ctx=canvas.getContext('2d');
    var audio=document.getElementById('${id}-audio');
    var running=false;

    function draw(){
      canvas.width=canvas.offsetWidth;canvas.height=150;
      ctx.clearRect(0,0,canvas.width,canvas.height);
      var bars=64;
      var barW=canvas.width/bars;
      for(var i=0;i<bars;i++){
        var h=running?Math.random()*120+10:Math.sin(Date.now()/500+i*0.3)*30+40;
        var gradient=ctx.createLinearGradient(0,150,0,150-h);
        gradient.addColorStop(0,'#6c63ff');
        gradient.addColorStop(1,'#10b981');
        ctx.fillStyle=gradient;
        ctx.fillRect(i*barW+1,150-h,barW-2,h);
      }
      requestAnimationFrame(draw);
    }

    audio.addEventListener('play',function(){running=true;});
    audio.addEventListener('pause',function(){running=false;});
    audio.addEventListener('ended',function(){running=false;});
    draw();
  })();
  </script>
</div>
EOHTML
}

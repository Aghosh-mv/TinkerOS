#!/usr/bin/env bash
# cards-workspace.sh — file explorer, diff viewer, doc editor, media player

# --- MULTI-TAB FILE EXPLORER CARD ---
ai_card_fileexplorer() {
  local root="${1:-.}" title="${2:-Files}"
  local id="fe_$(date +%s)_$$"

  python3 -c "
import os
root = '$root'
title = '''$title'''

html = '<div class=\"ai-card\" id=\"${id}\" style=\"max-width:500px;padding:0;overflow:hidden;\">'
html += '<div style=\"padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;font-size:13px;color:#c8d7ff;\"> ' + title + '</div>'
html += '<div style=\"max-height:350px;overflow-y:auto;padding:4px;\">'

for item in sorted(os.listdir(root))[:30]:
    path = os.path.join(root, item)
    if os.path.isdir(path):
        icon = ''
        size = ''
        items = len(os.listdir(path)) if os.path.isdir(path) else 0
        size = f'{items} items'
    else:
        ext = os.path.splitext(item)[1].lower()
        icons = {'.py':'','.js':'','.md':'','.txt':'','.c':'','.h':'','.sh':'',
                '.json':'','.yml':'','.yaml':'','.html':'','.css':'','.png':'',
                '.jpg':'','.svg':'','.pdf':'','.zip':'','.rs':'','.go':''}
        icon = icons.get(ext, '')
        sz = os.path.getsize(path)
        size = f'{sz//1024}KB' if sz > 1024 else f'{sz}B'

    html += '<div style=\"display:flex;align-items:center;gap:8px;padding:6px 8px;border-radius:4px;cursor:pointer;\" '
    html += 'onmouseover=\"this.style.background=\\\"rgba(108,99,255,0.1)\\\"\" '
    html += 'onmouseout=\"this.style.background=\\\"transparent\\\"\">'
    html += '<span>' + icon + '</span>'
    html += '<span style=\"flex:1;font-size:12px;color:#c9d1d9;\">' + item + '</span>'
    html += '<span style=\"font-size:10px;color:#8b949e;\">' + size + '</span>'
    html += '</div>'

html += '</div></div>'
print(html)
" 2>/dev/null || echo "<div class='ai-card'>File explorer error</div>"
}

# --- DIFF VIEWER CARD ---
ai_card_diff() {
  local old="$1" new="$2" title="${3:-Changes}"
  local id="diff_$(date +%s)_$$"

  python3 -c "
import difflib
old = '''$old'''.splitlines()
new = '''$new'''.splitlines()
title = '''$title'''

diff = list(difflib.unified_diff(old, new, lineterm='', n=1))

html = '<div class=\"ai-card\" id=\"${id}\" style=\"max-width:700px;padding:0;overflow:hidden;\">'
html += '<div style=\"padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;font-size:13px;color:#c8d7ff;\"> ' + title + '</div>'
html += '<div style=\"padding:8px;background:#0d1117;font-family:monospace;font-size:12px;overflow-x:auto;\">'

added = removed = 0
for line in diff:
    if line.startswith('---') or line.startswith('+++') or line.startswith('@@'):
        html += '<div style=\"color:#8b949e;padding:2px 0;\">' + line[:100].replace('<','&lt;') + '</div>'
    elif line.startswith('+'):
        added += 1
        html += '<div style=\"background:#10b98120;color:#10b981;padding:2px 8px;border-left:3px solid #10b981;\">+ ' + line[1:].replace('<','&lt;')[:90] + '</div>'
    elif line.startswith('-'):
        removed += 1
        html += '<div style=\"background:#ef444420;color:#ef4444;padding:2px 8px;border-left:3px solid #ef4444;\">- ' + line[1:].replace('<','&lt;')[:90] + '</div>'
    else:
        html += '<div style=\"color:#6a737d;padding:2px 8px;\">  ' + line[1:].replace('<','&lt;')[:90] if len(line)>1 else '' + '</div>'

html += '<div style=\"padding:8px;border-top:1px solid #21262d;font-size:11px;color:#8b949e;\">'
html += '<span style=\"color:#10b981;\">+' + str(added) + ' added</span> · '
html += '<span style=\"color:#ef4444;\">-' + str(removed) + ' removed</span></div>'
html += '</div></div>'
print(html)
" 2>/dev/null || echo "<div class='ai-card'>Diff viewer error</div>"
}

# --- INLINE DOCUMENT EDITOR CARD ---
ai_card_doceditor() {
  local content="${1:-}" title="${2:-Document}"
  local id="doc_$(date +%s)_$$"
  local encoded=$(echo "$content" | base64 -w0 2>/dev/null)

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:600px;padding:0;overflow:hidden;">
  <div style="padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;display:flex;justify-content:space-between;align-items:center;">
    <span style="font-size:13px;color:#c8d7ff;"> ${title}</span>
    <div style="display:flex;gap:4px;">
      <button onclick="document.execCommand('bold')" style="padding:2px 6px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:3px;cursor:pointer;font-size:11px;font-weight:bold;">B</button>
      <button onclick="document.execCommand('italic')" style="padding:2px 6px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:3px;cursor:pointer;font-size:11px;font-style:italic;">I</button>
      <button onclick="document.execCommand('underline')" style="padding:2px 6px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:3px;cursor:pointer;font-size:11px;text-decoration:underline;">U</button>
      <button onclick="document.execCommand('formatBlock',false,'h2')" style="padding:2px 6px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:3px;cursor:pointer;font-size:11px;">H</button>
      <button onclick="document.execCommand('insertUnorderedList')" style="padding:2px 6px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:3px;cursor:pointer;font-size:11px;">•</button>
    </div>
  </div>
  <div contenteditable="true" id="${id}-editor" style="min-height:250px;padding:16px;background:#1a1a2e;color:#c9d1d9;font-size:14px;line-height:1.6;outline:none;overflow-y:auto;">
    ${content:-<p>Start typing...</p>}
  </div>
  <div style="padding:8px 12px;background:#0d1117;border-top:1px solid #21262d;display:flex;justify-content:space-between;align-items:center;">
    <span style="font-size:10px;color:#8b949e;" id="${id}-words">0 words</span>
    <div style="display:flex;gap:8px;">
      <button onclick="
        var ed=document.getElementById('${id}-editor');
        var text=ed.innerText||ed.textContent;
        navigator.clipboard.writeText(text);
      " style="padding:4px 12px;background:#6c63ff22;color:#6c63ff;border:1px solid #6c63ff40;border-radius:4px;cursor:pointer;font-size:11px;">Copy</button>
      <button onclick="
        var ed=document.getElementById('${id}-editor');
        var text=ed.innerText||ed.textContent;
        var blob=new Blob([text],{type:'text/plain'});
        var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='${title}.txt';a.click();
      " style="padding:4px 12px;background:#10b98122;color:#10b981;border:1px solid #10b98140;border-radius:4px;cursor:pointer;font-size:11px;">Download</button>
    </div>
  </div>
  <script>
  (function(){
    var ed=document.getElementById('${id}-editor');
    var wc=document.getElementById('${id}-words');
    ed.addEventListener('input',function(){
      var t=this.innerText||this.textContent;
      var w=t.trim().split(/\\s+/).filter(function(x){return x.length>0}).length;
      wc.textContent=w+' words';
    });
    wc.dispatchEvent(new Event('input'));
  })();
  </script>
</div>
EOHTML
}

# --- MEDIA PLAYER CARD ---
ai_card_mediaplayer() {
  local src="$1" title="${2:-Media}" type="${3:-auto}"
  local id="media_$(date +%s)_$$"

  # Auto-detect type
  if [ "$type" = "auto" ]; then
    case "${src,,}" in
      *.mp3|*.wav|*.ogg|*.flac|*.m4a|*.aac) type="audio" ;;
      *.mp4|*.webm|*.mkv|*.avi|*.mov) type="video" ;;
      *.png|*.jpg|*.jpeg|*.gif|*.svg|*.webp) type="image" ;;
      *) type="audio" ;;
    esac
  fi

  case "$type" in
    audio)
      cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:500px;padding:0;overflow:hidden;">
  <div style="padding:12px;background:linear-gradient(135deg,#0d1117,#1a1a2e);display:flex;align-items:center;gap:12px;">
    <div style="width:48px;height:48px;background:#6c63ff30;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:20px;"></div>
    <div style="flex:1;">
      <div style="font-size:14px;color:#c8d7ff;">${title}</div>
      <div style="font-size:11px;color:#8b949e;">Audio</div>
    </div>
  </div>
  <div style="padding:0 12px 12px;background:#0d1117;">
    <audio id="${id}-player" style="width:100%;" controls preload="metadata">
      <source src="${src}" />
    </audio>
    <canvas id="${id}-viz" style="width:100%;height:60px;margin-top:8px;background:#111320;border-radius:6px;"></canvas>
    <script>
    (function(){
      var audio=document.getElementById('${id}-player');
      var canvas=document.getElementById('${id}-viz');
      var ctx=canvas.getContext('2d');
      audio.addEventListener('play',function(){
        function draw(){
          if(audio.paused)return;
          canvas.width=canvas.offsetWidth;canvas.height=60;
          ctx.clearRect(0,0,canvas.width,canvas.height);
          var bars=40;
          for(var i=0;i<bars;i++){
            var h=Math.random()*50+5;
            var x=i*(canvas.width/bars);
            ctx.fillStyle='rgba(108,99,255,'+(0.3+Math.random()*0.7)+')';
            ctx.fillRect(x,60-h,canvas.width/bars-2,h);
          }
          requestAnimationFrame(draw);
        }
        draw();
      });
    })();
    </script>
  </div>
</div>
EOHTML
      ;;
    video)
      cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:600px;padding:0;overflow:hidden;">
  <div style="padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;font-size:13px;color:#c8d7ff;"> ${title}</div>
  <video id="${id}-player" style="width:100%;max-height:400px;background:black;" controls preload="metadata">
    <source src="${src}" />
  </video>
  <div style="padding:8px 12px;background:#0d1117;display:flex;gap:8px;align-items:center;">
    <button onclick="var v=document.getElementById('${id}-player');v.playbackRate=Math.max(0.25,v.playbackRate-0.25)" style="padding:2px 8px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:4px;cursor:pointer;font-size:10px;"></button>
    <button onclick="var v=document.getElementById('${id}-player');v.playbackRate=Math.min(4,v.playbackRate+0.25)" style="padding:2px 8px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:4px;cursor:pointer;font-size:10px;"></button>
    <span style="flex:1;"></span>
    <span style="font-size:10px;color:#8b949e;" id="${id}-speed">1x</span>
  </div>
</div>
EOHTML
      ;;
    image)
      cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:600px;padding:0;overflow:hidden;">
  <div style="padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;font-size:13px;color:#c8d7ff;"> ${title}</div>
  <div style="padding:12px;background:#0d1117;text-align:center;">
    <img src="${src}" style="max-width:100%;max-height:400px;border-radius:8px;cursor:zoom-in;" onclick="window.open('${src}','_blank')" />
  </div>
</div>
EOHTML
      ;;
  esac
}

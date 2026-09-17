#!/usr/bin/env bash
# cards-visual.sh — visual asset cards, link previews, code blocks, workspace snapshots

TINKER_AI_HOME="${TINKER_AI_HOME:-$HOME/.config/vokk}"
CARDS_DIR="$TINKER_AI_HOME/cards"
mkdir -p "$CARDS_DIR/snapshots" "$CARDS_DIR/cache"

# --- VISUAL ASSET CARD ---
# Generate HTML card for an image (local file or URL)
ai_card_image() {
  local src="$1" caption="${2:-}" width="${3:-400}"
  local id="img_$(date +%s)_$$"
  local local_path=""

  # If URL, try to download
  if [[ "$src" == http* ]]; then
    local_path="$CARDS_DIR/cache/${id}.png"
    curl -sL "$src" -o "$local_path" 2>/dev/null || local_path=""
  elif [ -f "$src" ]; then
    local_path="$src"
  fi

  local img_tag=""
  if [ -n "$local_path" ] && [ -f "$local_path" ]; then
    # Base64 embed for self-contained card
    local b64=$(base64 -w0 "$local_path" 2>/dev/null)
    local ext="${local_path##*.}"
    [ "$ext" = "jpg" ] && ext="jpeg"
    img_tag="<img src='data:image/${ext};base64,${b64}' style='max-width:${width}px;border-radius:12px;box-shadow:0 4px 20px rgba(0,0,0,0.3);' />"
  else
    img_tag="<div style='width:${width}px;height:200px;background:linear-gradient(135deg,#1a1a2e,#16213e);border-radius:12px;display:flex;align-items:center;justify-content:center;color:#6c63ff;font-size:14px;'>Image: ${src}</div>"
  fi

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:${width}px;margin:8px 0;">
  <div style="position:relative;">
    ${img_tag}
    <div style="position:absolute;bottom:0;left:0;right:0;padding:8px 12px;background:linear-gradient(transparent,rgba(0,0,0,0.7));border-radius:0 0 12px 12px;">
      <span style="color:#e8e8e8;font-size:12px;">${caption:-Image}</span>
    </div>
  </div>
  <div style="padding:4px;display:flex;gap:4px;">
    <button onclick="window.open('${src}','_blank')" style="...">Open</button>
    <button onclick="navigator.clipboard.writeText('${src}')" style="...">Copy Link</button>
  </div>
</div>
EOHTML
}

# --- IMAGE GALLERY CARD ---
ai_card_gallery() {
  local images="$1" title="${2:-Gallery}"
  local id="gal_$(date +%s)_$$"
  local cols=3
  local items=""
  local i=0
  while IFS= read -r img; do
    [ -z "$img" ] && continue
    local caption=$(echo "$img" | cut -d'|' -f2)
    local url=$(echo "$img" | cut -d'|' -f1)
    items+="<div style='flex:1;min-width:150px;margin:4px;'>$(ai_card_image "$url" "$caption" 200)</div>"
    ((i++))
  done <<< "$images"

  echo "<div class='ai-card' id='${id}' style='padding:12px;'>"
  echo "<div style='font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:8px;'>${title}</div>"
  echo "<div style='display:flex;flex-wrap:wrap;gap:8px;'>${items}</div>"
  echo "</div>"
}

# --- SMART LINK PREVIEW CARD ---
ai_card_link() {
  local url="$1"
  local id="link_$(date +%s)_$$"

  # Fetch and parse OG tags
  local meta=$(curl -sL --max-time 5 "$url" 2>/dev/null | head -200)
  local title=$(echo "$meta" | grep -oP 'property="og:title"\s+content="\K[^"]*' | head -1)
  local desc=$(echo "$meta" | grep -oP 'property="og:description"\s+content="\K[^"]*' | head -1)
  local img=$(echo "$meta" | grep -oP 'property="og:image"\s+content="\K[^"]*' | head -1)
  local site=$(echo "$meta" | grep -oP 'property="og:site_name"\s+content="\K[^"]*' | head -1)

  [ -z "$title" ] && title=$(echo "$meta" | grep -oP '<title>\K[^<]*' | head -1)
  [ -z "$title" ] && title="$url"
  [ -z "$desc" ] && desc="Click to visit ${url}"
  [ -z "$site" ] && site=$(echo "$url" | grep -oP '://\K[^/]*')

  local img_html=""
  if [ -n "$img" ]; then
    img_html="<img src='${img}' style='width:120px;height:80px;object-fit:cover;border-radius:8px;flex-shrink:0;' />"
  fi

  cat <<EOHTML
<div class="ai-card" id="${id}" style="cursor:pointer;max-width:500px;" onclick="window.open('${url}','_blank')">
  <div style="display:flex;gap:12px;padding:12px;">
    ${img_html}
    <div style="flex:1;overflow:hidden;">
      <div style="color:#c8d7ff;font-size:14px;font-weight:bold;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${title}</div>
      <div style="color:#8892b0;font-size:11px;margin-top:2px;">${site}</div>
      <div style='color:#a0a8c0;font-size:12px;margin-top:4px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;'>${desc}</div>
    </div>
  </div>
  <div style="padding:0 12px 8px;font-size:10px;color:#6c63ff;">${url}</div>
</div>
EOHTML
}

# --- SYNTAX-HIGHLIGHTED CODE BLOCK ---
ai_card_code() {
  local code="$1" lang="${2:-auto}" title="${3:-}" filename="${4:-}"
  local id="code_$(date +%s)_$$"

  # Auto-detect language if not specified
  if [ "$lang" = "auto" ]; then
    if echo "$code" | grep -qP '^\s*(def|import|class|print)'; then lang="python"
    elif echo "$code" | grep -qP '^\s*(function|const|let|var|=>)'; then lang="javascript"
    elif echo "$code" | grep -qP '^\s*(#include|int main|void|struct)'; then lang="c"
    elif echo "$code" | grep -qP '^\s*(fn |pub |use |impl |struct )'; then lang="rust"
    elif echo "$code" | grep -qP '^\s*(func |package |import )'; then lang="go"
    elif echo "$code" | grep -qP '^\s*(if|then|else|fi|for|do|done)'; then lang="bash"
    elif echo "$code" | grep -qP '^\s*(<|</|<!DOCTYPE)'; then lang="html"
    elif echo "$code" | grep -qP '^\s*(SELECT|INSERT|UPDATE|DELETE|CREATE)'; then lang="sql"
    else lang="text"
    fi
  fi

  # Line numbers
  local numbered=""
  local i=1
  while IFS= read -r line; do
    numbered+="<span style='color:#4a5568;min-width:30px;display:inline-block;text-align:right;padding-right:8px;'>${i}</span>${line}<br>"
    ((i++))
  done <<< "$code"

  local header=""
  [ -n "$title" ] && header="<div style='padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;color:#c9d1d9;font-size:12px;display:flex;justify-content:space-between;'><span>${title}</span><span style='color:#8b949e;'>${lang}</span></div>"
  [ -n "$filename" ] && header="<div style='padding:8px 12px;background:#0d1117;border-bottom:1px solid #21262d;color:#c9d1d9;font-size:12px;display:flex;justify-content:space-between;'><span>📄 ${filename}</span><span style='color:#8b949e;'>${lang}</span></div>"

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:700px;border-radius:12px;overflow:hidden;border:1px solid #21262d;">
  ${header}
  <div style="position:relative;">
    <pre style='margin:0;padding:12px;background:#0d1117;color:#c9d1d9;font-family:"JetBrains Mono",monospace;font-size:12px;line-height:1.5;overflow-x:auto;white-space:pre-wrap;word-break:break-word;'>${numbered}</pre>
    <button onclick="navigator.clipboard.writeText(decodeURIComponent('${(python3 -c "import urllib.parse; print(urllib.parse.quote('''$code'''))" 2>/dev/null || echo "$code" | sed 's/"/\\"/g')}'))" style="position:absolute;top:4px;right:4px;padding:4px 8px;background:#21262d;color:#8b949e;border:1px solid #30363d;border-radius:6px;cursor:pointer;font-size:11px;">📋 Copy</button>
  </div>
</div>
EOHTML
}

# --- WORKSPACE SNAPSHOT CARD ---
ai_card_snapshot() {
  local snapshot_dir="${1:-.}" title="${2:-Workspace}"
  local id="snap_$(date +%s)_$$"
  local files_html=""
  local count=0

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local name=$(basename "$f")
    local size=$(wc -c < "$f" 2>/dev/null)
    local ext="${name##*.}"
    local icon="📄"
    [[ "$ext" =~ ^(py|js|ts|c|cpp|rs|go|sh)$ ]] && icon="💻"
    [[ "$ext" =~ ^(md|txt|doc)$ ]] && icon="📝"
    [[ "$ext" =~ ^(png|jpg|gif|svg)$ ]] && icon="🖼️"
    [[ "$ext" =~ ^(json|yaml|yml|toml)$ ]] && icon="⚙️"
    [[ "$ext" =~ ^(html|css)$ ]] && icon="🌐"

    files_html+="<div style='display:flex;align-items:center;gap:6px;padding:4px 8px;border-radius:6px;cursor:pointer;' onmouseover='this.style.background=\"rgba(108,99,255,0.1)\"' onmouseout='this.style.background=\"transparent\"'>"
    files_html+="<span>${icon}</span>"
    files_html+="<span style='flex:1;font-size:12px;color:#c8d1d9;'>${name}</span>"
    files_html+="<span style='font-size:10px;color:#8b949e;'>$(numfmt --to=iec $size 2>/dev/null || echo "${size}B")</span>"
    files_html+="</div>"
    ((count++))
    [ "$count" -ge 20 ] && break
  done < <(find "$snapshot_dir" -maxdepth 2 -type f 2>/dev/null | sort | head -20)

  # Save snapshot metadata
  local snap_file="$CARDS_DIR/snapshots/${id}.json"
  cat > "$snap_file" <<EOJSON
{"id":"$id","dir":"$snapshot_dir","title":"$title","created":"$(date -Iseconds)","files":$count}
EOJSON

  cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:400px;">
  <div style="padding:12px;border-bottom:1px solid #21262d;">
    <div style="font-size:14px;font-weight:bold;color:#c8d7ff;">📁 ${title}</div>
    <div style="font-size:11px;color:#8b949e;">${snapshot_dir} · ${count} files · saved $(date '+%H:%M')</div>
  </div>
  <div style="max-height:300px;overflow-y:auto;padding:4px;">
    ${files_html}
  </div>
  <div style="padding:8px 12px;border-top:1px solid #21262d;display:flex;gap:8px;">
    <button style="padding:4px 12px;background:rgba(108,99,255,0.2);color:#6c63ff;border:1px solid rgba(108,99,255,0.3);border-radius:6px;cursor:pointer;font-size:11px;">Open in File Manager</button>
    <button style="padding:4px 12px;background:rgba(108,99,255,0.2);color:#6c63ff;border:1px solid rgba(108,99,255,0.3);border-radius:6px;cursor:pointer;font-size:11px;">Save Snapshot</button>
  </div>
</div>
EOHTML
}

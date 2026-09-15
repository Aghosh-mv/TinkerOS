#!/usr/bin/env bash
# cards-structural.sh — flowcharts, state machines, UI mockups, process visualizations

# --- FLOWCHART CARD (node-based process map) ---
ai_card_flowchart() {
  local nodes="$1" title="${2:-Process Flow}"
  # nodes format: "start→Step 1→Step 2→end" or "start→decision{yes→A,no→B}→end"
  local id="flow_$(date +%s)_$$"

  python3 -c "
import re
nodes_str = '''$nodes'''
title = '''$title'''
node_list = [n.strip() for n in nodes_str.split('→') if n.strip()]

html = '<div class=\"ai-card\" id=\"${id}\" style=\"max-width:700px;padding:16px;\">'
html += '<div style=\"font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:12px;\">' + title + '</div>'
html += '<div style=\"display:flex;align-items:center;flex-wrap:wrap;gap:8px;\">'

colors = {'start': '#10b981', 'end': '#ef4444', 'decision': '#f59e0b', 'default': '#6c63ff'}
for i, node in enumerate(node_list):
    # Check for decision branch
    m = re.match(r'(\w+)\{(.+)\}', node)
    if m:
        label = m.group(1)
        branches = [b.strip() for b in m.group(2).split(',')]
        color = colors['decision']
        html += '<div style=\"display:flex;flex-direction:column;align-items:center;\">'
        html += '<div style=\"width:100px;padding:8px;background:' + color + '22;border:2px solid ' + color + ';border-radius:8px;text-align:center;font-size:12px;color:' + color + ';transform:rotate(0deg);\">⚖️ ' + label + '</div>'
        html += '<div style=\"display:flex;gap:8px;margin-top:4px;\">'
        for b in branches:
            bname = b.strip()
            html += '<div style=\"padding:2px 8px;background:#1a1a2e;border:1px solid #30363d;border-radius:4px;font-size:10px;color:#8b949e;\">' + bname + '</div>'
        html += '</div></div>'
    else:
        n = node.strip().lower()
        if n in ('start', 'begin'): color = colors['start']
        elif n in ('end', 'done', 'finish'): color = colors['end']
        else: color = colors['default']
        html += '<div style=\"width:100px;padding:8px;background:' + color + '22;border:2px solid ' + color + ';border-radius:8px;text-align:center;font-size:12px;color:' + color + ';\">' + node.strip() + '</div>'

    if i < len(node_list) - 1:
        html += '<div style=\"color:#30363d;font-size:18px;\">→</div>'

html += '</div></div>'
print(html)
" 2>/dev/null || echo "<div class='ai-card'>Flowchart error</div>"
}

# --- STATE MACHINE CARD ---
ai_card_statemachine() {
  local states="$1" title="${2:-State Machine}"
  # states format: "idle→running→paused→idle, idle→stopped"
  local id="sm_$(date +%s)_$$"

  python3 -c "
import re
states_str = '''$states'''
title = '''$title'''
transitions = [t.strip() for t in states_str.split(',') if t.strip()]

all_states = set()
edges = []
for t in transitions:
    parts = [p.strip() for p in t.split('→')]
    if len(parts) >= 2:
        for i in range(len(parts)-1):
            all_states.add(parts[i])
            all_states.add(parts[i+1])
            edges.append((parts[i], parts[i+1]))

html = '<div class=\"ai-card\" id=\"${id}\" style=\"max-width:600px;padding:16px;\">'
html += '<div style=\"font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:12px;\">🔄 ' + title + '</div>'
html += '<div style=\"display:flex;flex-wrap:wrap;gap:8px;justify-content:center;\">'

state_colors = {}
palette = ['#6c63ff', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#06b6d4']
for i, s in enumerate(sorted(all_states)):
    state_colors[s] = palette[i % len(palette)]
    color = palette[i % len(palette)]
    html += '<div style=\"padding:8px 16px;background:' + color + '22;border:2px solid ' + color + ';border-radius:20px;font-size:13px;color:' + color + ';font-weight:bold;\">' + s + '</div>'

html += '</div>'
html += '<div style=\"margin-top:12px;padding:8px;background:#0d1117;border-radius:8px;\">'
html += '<div style=\"font-size:11px;color:#8b949e;margin-bottom:4px;\">Transitions:</div>'
for src, dst in edges:
    html += '<div style=\"font-size:12px;color:#c9d1d9;\">' + src + ' <span style=\"color:#6c63ff;\">→</span> ' + dst + '</div>'
html += '</div></div>'
print(html)
" 2>/dev/null || echo "<div class='ai-card'>State machine error</div>"
}

# --- UI MOCKUP CARD ---
ai_card_mockup() {
  local type="${1:-dashboard}" title="${2:-UI Mockup}"
  local id="mock_$(date +%s)_$$"

  case "$type" in
    dashboard)
      cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:600px;padding:0;overflow:hidden;">
  <div style="padding:12px 16px;background:#0d1117;border-bottom:1px solid #21262d;font-size:14px;font-weight:bold;color:#c8d7ff;">📊 ${title}</div>
  <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:1px;background:#21262d;">
    <div style="padding:16px;background:#0d1117;text-align:center;">
      <div style="font-size:24px;font-weight:bold;color:#10b981;">1,234</div>
      <div style="font-size:11px;color:#8b949e;">Users</div>
    </div>
    <div style="padding:16px;background:#0d1117;text-align:center;">
      <div style="font-size:24px;font-weight:bold;color:#6c63ff;">567</div>
      <div style="font-size:11px;color:#8b949e;">Active</div>
    </div>
    <div style="padding:16px;background:#0d1117;text-align:center;">
      <div style="font-size:24px;font-weight:bold;color:#f59e0b;">89%</div>
      <div style="font-size:11px;color:#8b949e;">Uptime</div>
    </div>
  </div>
  <div style="padding:16px;background:#0d1117;">
    <div style="font-size:12px;color:#8b949e;margin-bottom:8px;">Activity (7 days)</div>
    <div style="display:flex;align-items:end;gap:4px;height:60px;">
      <div style="flex:1;background:#6c63ff40;border-top:3px solid #6c63ff;height:40%;"></div>
      <div style="flex:1;background:#6c63ff40;border-top:3px solid #6c63ff;height:60%;"></div>
      <div style="flex:1;background:#6c63ff40;border-top:3px solid #6c63ff;height:80%;"></div>
      <div style="flex:1;background:#6c63ff40;border-top:3px solid #6c63ff;height:45%;"></div>
      <div style="flex:1;background:#6c63ff40;border-top:3px solid #6c63ff;height:90%;"></div>
      <div style="flex:1;background:#6c63ff40;border-top:3px solid #6c63ff;height:70%;"></div>
      <div style="flex:1;background:#10b98140;border-top:3px solid #10b981;height:95%;"></div>
    </div>
  </div>
</div>
EOHTML
      ;;
    login)
      cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:350px;padding:0;overflow:hidden;">
  <div style="padding:32px;background:linear-gradient(135deg,#0d1117,#1a1a2e);">
    <div style="text-align:center;margin-bottom:24px;">
      <div style="font-size:32px;">◆</div>
      <div style="font-size:18px;font-weight:bold;color:#c8d7ff;margin-top:8px;">Welcome Back</div>
    </div>
    <div style="margin-bottom:12px;">
      <div style="font-size:11px;color:#8b949e;margin-bottom:4px;">Email</div>
      <div style="padding:10px;background:#0d1117;border:1px solid #21262d;border-radius:8px;color:#c9d1d9;font-size:13px;">user@example.com</div>
    </div>
    <div style="margin-bottom:16px;">
      <div style="font-size:11px;color:#8b949e;margin-bottom:4px;">Password</div>
      <div style="padding:10px;background:#0d1117;border:1px solid #21262d;border-radius:8px;color:#c9d1d9;font-size:13px;">••••••••</div>
    </div>
    <div style="padding:10px;background:#6c63ff;border-radius:8px;text-align:center;color:white;font-size:13px;font-weight:bold;cursor:pointer;">Sign In</div>
    <div style="text-align:center;margin-top:12px;font-size:11px;color:#6c63ff;cursor:pointer;">Forgot password?</div>
  </div>
</div>
EOHTML
      ;;
    form)
      cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:450px;padding:16px;">
  <div style="font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:16px;">📝 ${title}</div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
    <div><div style="font-size:11px;color:#8b949e;margin-bottom:4px;">First Name</div><div style="padding:8px;background:#0d1117;border:1px solid #21262d;border-radius:6px;color:#c9d1d9;font-size:12px;">John</div></div>
    <div><div style="font-size:11px;color:#8b949e;margin-bottom:4px;">Last Name</div><div style="padding:8px;background:#0d1117;border:1px solid #21262d;border-radius:6px;color:#c9d1d9;font-size:12px;">Doe</div></div>
  </div>
  <div style="margin-top:12px;"><div style="font-size:11px;color:#8b949e;margin-bottom:4px;">Email</div><div style="padding:8px;background:#0d1117;border:1px solid #21262d;border-radius:6px;color:#c9d1d9;font-size:12px;">john@example.com</div></div>
  <div style="margin-top:12px;"><div style="font-size:11px;color:#8b949e;margin-bottom:4px;">Message</div><div style="padding:8px;background:#0d1117;border:1px solid #21262d;border-radius:6px;color:#c9d1d9;font-size:12px;height:60px;">Type your message here...</div></div>
  <div style="margin-top:16px;display:flex;gap:8px;">
    <div style="padding:8px 24px;background:#6c63ff;border-radius:6px;color:white;font-size:12px;cursor:pointer;">Submit</div>
    <div style="padding:8px 24px;background:transparent;border:1px solid #21262d;border-radius:6px;color:#8b949e;font-size:12px;cursor:pointer;">Cancel</div>
  </div>
</div>
EOHTML
      ;;
    kanban)
      cat <<EOHTML
<div class="ai-card" id="${id}" style="max-width:700px;padding:16px;">
  <div style="font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:12px;">📋 ${title}</div>
  <div style="display:flex;gap:12px;overflow-x:auto;">
    <div style="min-width:180px;background:#0d1117;border-radius:8px;padding:12px;">
      <div style="font-size:12px;font-weight:bold;color:#8b949e;margin-bottom:8px;">TODO (3)</div>
      <div style="padding:8px;background:#1a1a2e;border-radius:6px;margin-bottom:6px;border-left:3px solid #6c63ff;font-size:12px;color:#c9d1d9;">Design mockups</div>
      <div style="padding:8px;background:#1a1a2e;border-radius:6px;margin-bottom:6px;border-left:3px solid #f59e0b;font-size:12px;color:#c9d1d9;">API endpoints</div>
      <div style="padding:8px;background:#1a1a2e;border-radius:6px;border-left:3px solid #10b981;font-size:12px;color:#c9d1d9;">Write tests</div>
    </div>
    <div style="min-width:180px;background:#0d1117;border-radius:8px;padding:12px;">
      <div style="font-size:12px;font-weight:bold;color:#8b949e;margin-bottom:8px;">IN PROGRESS (2)</div>
      <div style="padding:8px;background:#1a1a2e;border-radius:6px;margin-bottom:6px;border-left:3px solid #ef4444;font-size:12px;color:#c9d1d9;">Auth system</div>
      <div style="padding:8px;background:#1a1a2e;border-radius:6px;border-left:3px solid #6c63ff;font-size:12px;color:#c9d1d9;">Database schema</div>
    </div>
    <div style="min-width:180px;background:#0d1117;border-radius:8px;padding:12px;">
      <div style="font-size:12px;font-weight:bold;color:#8b949e;margin-bottom:8px;">DONE (4)</div>
      <div style="padding:8px;background:#1a1a2e;border-radius:6px;margin-bottom:6px;border-left:3px solid #10b981;font-size:12px;color:#c9d1d9;text-decoration:line-through;opacity:0.7;">Project setup</div>
      <div style="padding:8px;background:#1a1a2e;border-radius:6px;border-left:3px solid #10b981;font-size:12px;color:#c9d1d9;text-decoration:line-through;opacity:0.7;">CI/CD pipeline</div>
    </div>
  </div>
</div>
EOHTML
      ;;
  esac
}

# --- PROCESS PIPELINE CARD ---
ai_card_pipeline() {
  local steps="$1" title="${2:-Pipeline}"
  local id="pipe_$(date +%s)_$$"

  python3 -c "
steps_str = '''$steps'''
title = '''$title'''
step_list = [s.strip() for s in steps_str.split('|') if s.strip()]

html = '<div class=\"ai-card\" id=\"${id}\" style=\"max-width:700px;padding:16px;\">'
html += '<div style=\"font-size:16px;font-weight:bold;color:#c8d7ff;margin-bottom:12px;\">⚡ ' + title + '</div>'
html += '<div style=\"display:flex;align-items:center;flex-wrap:wrap;gap:4px;\">'

for i, step in enumerate(step_list):
    html += '<div style=\"padding:8px 16px;background:#6c63ff22;border:1px solid #6c63ff;border-radius:8px;font-size:12px;color:#c8d7ff;text-align:center;\">'
    html += '<div style=\"font-size:10px;color:#8b949e;\">Step ' + str(i+1) + '</div>'
    html += '<div>' + step + '</div></div>'
    if i < len(step_list) - 1:
        html += '<div style=\"color:#30363d;\">→</div>'

html += '</div></div>'
print(html)
" 2>/dev/null || echo "<div class='ai-card'>Pipeline error</div>"
}

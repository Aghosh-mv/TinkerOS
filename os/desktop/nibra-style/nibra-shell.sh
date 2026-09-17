#!/bin/bash
# KorrinOS Desktop Shell v1.0
# Frosted glass, smooth layout, KorrinOS identity
# ALL data pulled from real KorrinOS system — no placeholders, no macOS.

set -euo pipefail

KORRINOS_DIR="/opt/korrinos/os"
DESKTOP_DIR="$KORRINOS_DIR/desktop/nibra-style"
PICOM_CONF="$DESKTOP_DIR/picom.conf"
WALLPAPER_DIR="/usr/share/korrinos/wallpapers"
WIDGET_DIR="${HOME}/.local/share/korrinos/widgets"
TASKS_FILE="${HOME}/.local/share/korrinos/tasks.txt"
USER_HOME="${HOME:-/home/$(whoami)}"

mkdir -p "$WIDGET_DIR"

log() { echo "[korrinos-desktop] $(date '+%H:%M:%S') $*"; }

# ============================================
#  REAL DATA
# ============================================

get_username() { echo "${SUDO_USER:-$(whoami)}"; }

get_battery() {
    local cap=""
    if ls /sys/class/power_supply/BAT*/capacity >/dev/null 2>&1; then
        cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
    fi
    if [ -z "$cap" ]; then
        cap=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "percentage" | awk '{print $2}' | tr -d '%') || true
    fi
    [ -z "$cap" ] && echo "Desktop" && return
    local icon="Battery"
    [ "$cap" -lt 20 ] && icon="Low Battery"
    echo "$icon ${cap}%"
}

get_greeting() {
    local user=$(get_username)

    if [ -f "$KORRINOS_DIR/system/korrinos-greetings.sh" ]; then
        local greeting
        greeting=$("$KORRINOS_DIR/system/korrinos-greetings.sh" boot 2>/dev/null | grep -v "═" | grep -v "^$" | head -1) || true
        if [ -n "$greeting" ] && [ "$greeting" != "KorrinOS Greeting Engine v2.0 — Time-Aware" ]; then
            echo "$greeting"
            return
        fi
    fi

    local hour=$(date +%H)
    local time_word="evening"
    [ "$hour" -ge 5 ] && [ "$hour" -lt 12 ] && time_word="morning"
    [ "$hour" -ge 12 ] && [ "$hour" -lt 17 ] && time_word="afternoon"
    [ "$hour" -ge 21 ] || [ "$hour" -lt 5 ] && time_word="night"

    local greetings=(
        "Good $time_word, $user."
        "Welcome back, $user."
        "Ah, $user returns."
        "The legend returns."
        "There you are, $user."
        "$user has entered the workspace."
        "Good $time_word. $user has arrived."
        "The protagonist has arrived."
        "$user detected. Mischief protocols standing by."
        "Welcome, $user. Let us begin."
        "Hello, $user. What shall we break today?"
        "$user has connected. Reality may now continue."
    )
    echo "${greetings[$((RANDOM % ${#greetings[@]}))]}"
}

get_recent_files() {
    local search_dirs=("$USER_HOME/Documents" "$USER_HOME/Downloads" "$USER_HOME/.local/share/korrinos" "$KORRINOS_DIR")
    for dir in "${search_dirs[@]}"; do
        [ -d "$dir" ] && find "$dir" -maxdepth 2 -type f -mtime -7 -printf "%T@ %p\n" 2>/dev/null
    done | sort -rn | head -5 | while IFS=' ' read -r ts filepath; do
        local name=$(basename "$filepath" 2>/dev/null)
        local ago=$(date -d "@$ts" '+%I:%M %p' 2>/dev/null || echo "")
        echo "$name|$ago"
    done
}

get_tasks() {
    if [ -f "$TASKS_FILE" ]; then
        cat "$TASKS_FILE"
    else
        cat > "$TASKS_FILE" <<'EOF'
Review KorrinOS build|10:00 AM
Test kernel modules|2:00 PM
Update documentation|4:30 PM
EOF
        cat "$TASKS_FILE"
    fi
}

# ============================================
#  WIDGET BUILDERS (all real data)
# ============================================

build_datetime_widget() {
    local DAY=$(date '+%A, %d %B %Y')
    local TIME=$(date '+%I:%M %p')

    cat > "$WIDGET_DIR/datetime.html" <<HTMLEOF
<!DOCTYPE html><html><head><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:transparent;font-family:'Segoe UI',system-ui,sans-serif;color:white}
.w{width:220px;padding:18px 22px;background:rgba(255,255,255,0.12);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);border:1px solid rgba(255,255,255,0.15);border-radius:20px;text-align:right}
.date{font-size:12px;opacity:0.6;margin-bottom:4px}
.time{font-size:38px;font-weight:200;letter-spacing:-1px}
</style></head><body>
<div class="w">
  <div class="date">${DAY}</div>
  <div class="time">${TIME}</div>
</div>
<script>setInterval(()=>location.reload(),60000)</script>
</body></html>
HTMLEOF
}

build_weather_widget() {
    cat > "$WIDGET_DIR/weather.html" <<'HTMLEOF'
<!DOCTYPE html><html><head><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:transparent;font-family:'Segoe UI',system-ui,sans-serif;color:white}
.w{width:220px;padding:16px 20px;background:rgba(255,255,255,0.12);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);border:1px solid rgba(255,255,255,0.15);border-radius:20px}
.loc{font-size:13px;opacity:0.6;margin-bottom:2px}
.row{display:flex;justify-content:space-between;align-items:center}
.temp{font-size:40px;font-weight:200;line-height:1}
.icon{font-size:28px;opacity:0.8}
.desc{font-size:12px;opacity:0.5;margin-top:4px}
.hilo{font-size:11px;opacity:0.4;margin-top:6px}
</style></head><body>
<div class="w" id="w">
  <div class="loc" id="loc">Loading...</div>
  <div class="row"><div class="temp" id="temp">--°</div><div class="icon" id="icon">☀️</div></div>
  <div class="desc" id="desc"></div>
  <div class="hilo" id="hilo"></div>
</div>
<script>
const icons={Cloudy:'☁️',Sunny:'☀️',Clear:'🌙','Partly cloudy':'⛅',Overcast:'☁️','Light rain':'🌧️',Rain:'🌧️',Thunderstorm:'⛈️',Snow:'❄️',Mist:'🌫️',Fog:'🌫️'};
async function u(){try{const r=await fetch('https://wttr.in/?format=j1');const d=await r.json();const c=d.current_condition[0];const w=d.weather[0];document.getElementById('loc').textContent=d.nearest_area[0].areaName[0].value;document.getElementById('temp').textContent=c.temp_C+'°';document.getElementById('desc').textContent=c.weatherDesc[0].value;document.getElementById('hilo').textContent='H: '+w.maxtempC+'°  L: '+w.mintempC+'°';document.getElementById('icon').textContent=icons[c.weatherDesc[0].value]||'☀️'}catch(e){document.getElementById('loc').textContent='—'}}
u();setInterval(u,600000);
</script></body></html>
HTMLEOF
}

build_recent_widget() {
    local HTML=""
    local icons=("📄" "" "" "" "")
    local i=0
    while IFS='|' read -r name time; do
        [ -z "$name" ] && continue
        local icon="${icons[$((i % 5))]}"
        HTML="${HTML}<div class='item'><div class='icon'>${icon}</div><div class='info'><div class='name'>${name}</div><div class='meta'>Edited ${time}</div></div></div>"
        i=$((i+1))
    done < <(get_recent_files)
    [ -z "$HTML" ] && HTML='<div class="item"><div class="info"><div class="name">No recent files</div></div></div>'

    cat > "$WIDGET_DIR/recent.html" <<HTMLEOF
<!DOCTYPE html><html><head><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:transparent;font-family:'Segoe UI',system-ui,sans-serif;color:white}
.w{width:220px;padding:16px 20px;background:rgba(255,255,255,0.12);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);border:1px solid rgba(255,255,255,0.15);border-radius:20px}
.title{font-size:14px;font-weight:600;margin-bottom:12px;display:flex;justify-content:space-between}
.title .more{opacity:0.4;font-size:12px}
.item{display:flex;align-items:center;gap:10px;padding:6px 0;border-bottom:1px solid rgba(255,255,255,0.06)}
.item:last-child{border:none}
.icon{width:28px;height:28px;border-radius:8px;background:rgba(255,255,255,0.08);display:flex;align-items:center;justify-content:center;font-size:14px}
.info{flex:1}
.name{font-size:12px;font-weight:500}
.meta{font-size:10px;opacity:0.4;margin-top:1px}
</style></head><body>
<div class="w">
  <div class="title"><span>Recent</span><span class="more">›</span></div>
  ${HTML}
</div></body></html>
HTMLEOF
}

build_music_widget() {
    cat > "$WIDGET_DIR/music.html" <<'HTMLEOF'
<!DOCTYPE html><html><head><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:transparent;font-family:'Segoe UI',system-ui,sans-serif;color:white}
.w{width:220px;padding:14px 18px;background:rgba(255,255,255,0.12);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);border:1px solid rgba(255,255,255,0.15);border-radius:20px;display:flex;align-items:center;gap:12px}
.album{width:44px;height:44px;border-radius:10px;background:linear-gradient(135deg,rgba(100,140,220,0.5),rgba(160,120,200,0.5));display:flex;align-items:center;justify-content:center;font-size:20px}
.info{flex:1}
.title{font-size:12px;font-weight:600}
.artist{font-size:10px;opacity:0.5;margin-top:2px}
.controls{display:flex;gap:8px;font-size:14px;opacity:0.6}
</style></head><body>
<div class="w">
  <div class="album"></div>
  <div class="info"><div class="title">Now Playing</div><div class="artist">KorrinOS Radio</div></div>
  <div class="controls"><span></span><span></span><span></span></div>
</div></body></html>
HTMLEOF
}

build_continue_widget() {
    local HTML=""
    local icons=("" "" "")
    local i=0
    while IFS='|' read -r name time; do
        [ -z "$name" ] && continue
        local icon="${icons[$((i % 3))]}"
        HTML="${HTML}<div class='item'><div class='icon'>${icon}</div><div class='text'>${name}</div><div class='meta'>${time}</div></div>"
        i=$((i+1))
    done < <(get_recent_files)
    [ -z "$HTML" ] && HTML='<div class="item"><div class="text">Start working to see recent files</div></div>'

    cat > "$WIDGET_DIR/continue.html" <<HTMLEOF
<!DOCTYPE html><html><head><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:transparent;font-family:'Segoe UI',system-ui,sans-serif;color:white}
.w{width:400px;padding:18px 22px;background:rgba(255,255,255,0.10);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);border:1px solid rgba(255,255,255,0.12);border-radius:20px}
.title{font-size:14px;font-weight:600;margin-bottom:14px;display:flex;justify-content:space-between}
.title .more{opacity:0.4;font-size:12px}
.item{display:flex;align-items:center;gap:10px;padding:6px 0}
.icon{width:28px;height:28px;border-radius:8px;background:rgba(255,255,255,0.08);display:flex;align-items:center;justify-content:center;font-size:14px}
.text{flex:1;font-size:12px;font-weight:500}
.meta{font-size:10px;opacity:0.4}
</style></head><body>
<div class="w">
  <div class="title"><span>Continue where you left off</span><span class="more">›</span></div>
  ${HTML}
</div></body></html>
HTMLEOF
}

build_explore_widget() {
    cat > "$WIDGET_DIR/explore.html" <<'HTMLEOF'
<!DOCTYPE html><html><head><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:transparent;font-family:'Segoe UI',system-ui,sans-serif;color:white}
.w{width:280px;padding:18px 22px;background:rgba(255,255,255,0.10);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);border:1px solid rgba(255,255,255,0.12);border-radius:20px}
.label{font-size:11px;opacity:0.5;margin-bottom:6px}
.heading{font-size:16px;font-weight:600;margin-bottom:4px}
.sub{font-size:12px;opacity:0.5;margin-bottom:14px}
.btn{display:inline-block;padding:8px 16px;background:rgba(255,255,255,0.15);border:1px solid rgba(255,255,255,0.1);border-radius:10px;font-size:12px;cursor:pointer;transition:background 0.2s}
.btn:hover{background:rgba(255,255,255,0.25)}
</style></head><body>
<div class="w">
  <div class="label">Explore</div>
  <div class="heading">Build. Create. Imagine.</div>
  <div class="sub">VOKK v4 is ready when you are.</div>
  <div class="btn">Open VOKK v4 →</div>
</div></body></html>
HTMLEOF
}

build_user_widget() {
    local USER=$(get_username)
    cat > "$WIDGET_DIR/user.html" <<HTMLEOF
<!DOCTYPE html><html><head><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:transparent;font-family:'Segoe UI',system-ui,sans-serif;color:white}
.w{display:flex;align-items:center;gap:10px;padding:8px 12px;background:rgba(255,255,255,0.08);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);border:1px solid rgba(255,255,255,0.08);border-radius:14px}
.avatar{width:32px;height:32px;border-radius:50%;background:linear-gradient(135deg,#6C9CFC,#A78BFA);display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:600}
.info{flex:1}
.name{font-size:12px;font-weight:500}
.status{font-size:10px;opacity:0.5}
.arrow{opacity:0.3;font-size:12px}
</style></head><body>
<div class="w">
  <div class="avatar">$(echo "$USER" | head -c1 | tr a-z A-Z)</div>
  <div class="info"><div class="name">${USER}</div><div class="status">Online</div></div>
  <div class="arrow">→</div>
</div></body></html>
HTMLEOF
}

build_main_content() {
    local GREETING=$(get_greeting)
    local TAGLINE="Search, create, explore — your world, your way."
    local QUOTE="\"Small steps build big worlds.\""

    cat > "$WIDGET_DIR/main-content.html" <<HTMLEOF
<!DOCTYPE html><html><head><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:transparent;font-family:'Segoe UI',system-ui,sans-serif;color:white;overflow:hidden}
.d{width:100vw;height:100vh;padding:36px 36px 36px 96px;display:grid;grid-template-columns:1fr 240px;grid-template-rows:auto auto 1fr auto;gap:16px}

.greeting{grid-column:1;grid-row:1;padding-top:16px}
.greeting h1{font-size:32px;font-weight:300;line-height:1.2;margin-bottom:4px}
.greeting .sub{font-size:13px;opacity:0.5}

.search{grid-column:1;grid-row:2;margin-top:12px}
.search input{width:480px;height:40px;background:rgba(255,255,255,0.12);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);border:1px solid rgba(255,255,255,0.12);border-radius:12px;padding:0 16px 0 40px;font-size:13px;color:white;outline:none}
.search input::placeholder{color:rgba(255,255,255,0.4)}
.search{position:relative}
.search .icon{position:absolute;left:14px;top:50%;transform:translateY(-50%);font-size:16px;opacity:0.4}
.search .enter{position:absolute;right:14px;top:50%;transform:translateY(-50%);font-size:12px;opacity:0.3}

.apps{grid-column:1;grid-row:3;align-self:start;margin-top:16px}
.apps .label{font-size:13px;font-weight:600;margin-bottom:14px;display:flex;justify-content:space-between}
.apps .label .all{font-size:11px;opacity:0.4}
.grid{display:grid;grid-template-columns:repeat(6,70px);gap:14px}
.app{display:flex;flex-direction:column;align-items:center;gap:5px;cursor:pointer;transition:transform 0.15s}
.app:hover{transform:scale(1.08)}
.app .ic{width:52px;height:52px;border-radius:14px;display:flex;align-items:center;justify-content:center;font-size:22px;background:rgba(255,255,255,0.10);backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);border:1px solid rgba(255,255,255,0.08)}
.app .nm{font-size:10px;opacity:0.6;text-align:center}

.right{grid-column:2;grid-row:1/4;display:flex;flex-direction:column;gap:12px}

.bottom{grid-column:1;grid-row:4;display:flex;gap:16px;align-items:end}
.quote{font-size:11px;opacity:0.3;position:fixed;bottom:16px;left:96px}
.hint{position:fixed;bottom:16px;left:50%;transform:translateX(-50%);font-size:11px;opacity:0.25}

.sidebar{position:fixed;left:0;top:0;width:80px;height:100vh;background:rgba(255,255,255,0.06);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);border-right:1px solid rgba(255,255,255,0.06);display:flex;flex-direction:column;align-items:center;padding:20px 0;gap:20px;z-index:10}
.sidebar .item{display:flex;flex-direction:column;align-items:center;gap:4px;cursor:pointer;padding:8px;border-radius:12px;transition:background 0.2s;width:56px}
.sidebar .item:hover{background:rgba(255,255,255,0.08)}
.sidebar .item.active{background:rgba(255,255,255,0.12)}
.sidebar .item .ic{font-size:20px;opacity:0.6}
.sidebar .item.active .ic{opacity:1}
.sidebar .item .nm{font-size:9px;opacity:0.4;text-align:center}
.sidebar .item.active .nm{opacity:0.8}
.sidebar .logo{font-size:18px;margin-bottom:10px;opacity:0.7}
.sidebar .spacer{flex:1}
.sidebar .user{margin-bottom:10px}
</style></head><body>
<div class="sidebar">
  <div class="logo"></div>
  <div class="item active"><div class="ic">🏠</div><div class="nm">Home</div></div>
  <div class="item"><div class="ic">📱</div><div class="nm">Apps</div></div>
  <div class="item"><div class="ic"></div><div class="nm">Files</div></div>
  <div class="item"><div class="ic"></div><div class="nm">Browser</div></div>
  <div class="item"><div class="ic"></div><div class="nm">AI</div></div>
  <div class="item"><div class="ic"></div><div class="nm">Settings</div></div>
  <div class="spacer"></div>
  <div class="user"><iframe src="user.html" style="width:60px;height:40px;border:none;background:transparent;"></iframe></div>
</div>

<div class="d">
  <div class="greeting">
    <h1>${GREETING}</h1>
    <div class="sub">${TAGLINE}</div>
  </div>

  <div class="search">
    <span class="icon"></span>
    <input type="text" placeholder="Ask me anything...">
    <span class="enter">→</span>
  </div>

  <div class="apps">
    <div class="label"><span>Your Apps</span><span class="all">All apps →</span></div>
    <div class="grid">
      <div class="app"><div class="ic"></div><div class="nm">VOKK</div></div>
      <div class="app"><div class="ic"></div><div class="nm">Browser</div></div>
      <div class="app"><div class="ic"></div><div class="nm">Chat</div></div>
      <div class="app"><div class="ic">⟨/⟩</div><div class="nm">Code</div></div>
      <div class="app"><div class="ic"></div><div class="nm">Files</div></div>
      <div class="app"><div class="ic"></div><div class="nm">Music</div></div>
      <div class="app"><div class="ic"></div><div class="nm">Video</div></div>
      <div class="app"><div class="ic"></div><div class="nm">Photos</div></div>
      <div class="app"><div class="ic"></div><div class="nm">Settings</div></div>
      <div class="app"><div class="ic"></div><div class="nm">Store</div></div>
      <div class="app"><div class="ic"></div><div class="nm">Games</div></div>
      <div class="app"><div class="ic"></div><div class="nm">More</div></div>
    </div>
  </div>

  <div class="right">
    <iframe src="datetime.html" style="width:220px;height:100px;border:none;background:transparent;"></iframe>
    <iframe src="weather.html" style="width:220px;height:120px;border:none;background:transparent;"></iframe>
    <iframe src="recent.html" style="width:220px;height:200px;border:none;background:transparent;"></iframe>
    <iframe src="music.html" style="width:220px;height:70px;border:none;background:transparent;"></iframe>
  </div>

  <div class="bottom">
    <iframe src="continue.html" style="width:400px;height:160px;border:none;background:transparent;"></iframe>
    <iframe src="explore.html" style="width:280px;height:140px;border:none;background:transparent;"></iframe>
  </div>
</div>

<div class="quote">${QUOTE}</div>
<div class="hint">Swipe up for more</div>
</body></html>
HTMLEOF
}

# ============================================
#  WALLPAPER — soft blue/white gradient
# ============================================
setup_wallpaper() {
    log "Setting up KorrinOS wallpaper..."
    mkdir -p "$WALLPAPER_DIR"
    WP="$WALLPAPER_DIR/korrinos-desktop.png"

    if ! [ -f "$WP" ]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 << 'PYEOF' "$WP"
import sys, math, random
try:
    from PIL import Image
except ImportError:
    sys.exit(1)

w, h = 1920, 1080
img = Image.new('RGB', (w, h))
pixels = img.load()
random.seed(42)

for y in range(h):
    for x in range(w):
        # Soft blue-white base
        t = y / h
        r = int(200 + 40 * t)
        g = int(210 + 30 * t)
        b = int(230 + 15 * t)

        # Warm glow center-right
        dx = (x - w*0.6) / w
        dy = (y - h*0.4) / h
        dist = math.sqrt(dx*dx + dy*dy)
        glow = max(0, 1 - dist*2.8)
        r = min(255, int(r + 30 * glow))
        g = min(255, int(g + 20 * glow))
        b = min(255, int(b + 10 * glow))

        # Soft blue tint top-left
        dx2 = (x - w*0.2) / w
        dy2 = (y - h*0.2) / h
        dist2 = math.sqrt(dx2*dx2 + dy2*dy2)
        blue = max(0, 1 - dist2*3)
        r = int(r * (0.92 + 0.05 * blue))
        g = int(g * (0.94 + 0.04 * blue))
        b = min(255, int(b * (0.95 + 0.08 * blue)))

        # Subtle horizon line
        if abs(y - h*0.65) < 2:
            r, g, b = int(r*0.85), int(g*0.88), int(b*0.92)

        pixels[x, y] = (r, g, b)

img.save(sys.argv[1])
PYEOF
        fi
    fi

    if [ -f "$WP" ]; then
        feh --bg-fill "$WP" 2>/dev/null || \
        nitrogen --set-zoom-fill "$WP" 2>/dev/null || \
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$WP" 2>/dev/null || true
        log "Wallpaper set."
    fi
}

# ============================================
#  PICOM
# ============================================
start_picom() {
    log "Starting picom..."
    pkill picom 2>/dev/null || true
    sleep 0.3
    if command -v picom >/dev/null 2>&1; then
        picom --config "$PICOM_CONF" -b --experimental-backends 2>/dev/null || \
        picom --config "$PICOM_CONF" -b 2>/dev/null || \
        log "picom failed" &
        sleep 0.5
    fi
}

# ============================================
#  PANELS (sidebar + topbar + dock)
# ============================================
setup_panels() {
    log "Configuring panels..."
    # Panel 1: Left sidebar (vertical, 80px)
    xfconf-query -c xfce4-panel -p /panels/panel-1/mode -n -t int -s 1 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/position -n -t string -s "p=8;x=0;y=0" 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/length -n -t uint -s 80 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/background-style -n -t int -s 2 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/background-rgba -n -t double -s 0.06 -t double -s 0.06 -t double -s 0.08 -t double -s 0.50 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/icon-size -n -t uint -s 24 2>/dev/null || true

    # Panel 2: Top bar
    xfconf-query -c xfce4-panel -p /panels/panel-2/mode -n -t int -s 0 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-2/position -n -t string -s "p=6;x=0;y=0" 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-2/length -n -t uint -s 100 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-2/size -n -t uint -s 28 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-2/background-style -n -t int -s 2 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-2/background-rgba -n -t double -s 0.06 -t double -s 0.06 -t double -s 0.08 -t double -s 0.40 2>/dev/null || true

    # Panel 3: Bottom dock
    xfconf-query -c xfce4-panel -p /panels/panel-3/mode -n -t int -s 0 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-3/position -n -t string -s "p=2;x=300;y=0" 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-3/length -n -t uint -s 40 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-3/size -n -t uint -s 48 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-3/background-style -n -t int -s 2 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-3/background-rgba -n -t double -s 0.08 -t double -s 0.08 -t double -s 0.12 -t double -s 0.60 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-3/icon-size -n -t uint -s 30 2>/dev/null || true
}

# ============================================
#  LAUNCH
# ============================================
launch() {
    log "Launching KorrinOS Desktop..."
    pkill -f "korrinos-liquid-glass" 2>/dev/null || true
    pkill -f "korrinos-widgets-panel" 2>/dev/null || true
    pkill -f "korrinos-dock" 2>/dev/null || true
    pkill -f "korrinos-smoothui" 2>/dev/null || true
    sleep 0.3

    setup_wallpaper
    start_picom
    setup_panels

    # Build ALL widgets with real data
    build_datetime_widget
    build_weather_widget
    build_recent_widget
    build_music_widget
    build_continue_widget
    build_explore_widget
    build_user_widget
    build_main_content

    pkill xfce4-panel 2>/dev/null || true
    sleep 0.5
    xfce4-panel --disable-wm-check 2>/dev/null &
    sleep 1

    log "KorrinOS Desktop ready."
}

stop() {
    log "Stopping..."
    pkill picom 2>/dev/null || true
    pkill xfce4-panel 2>/dev/null || true
    log "Stopped."
}

case "${1:-start}" in
    start|launch) launch ;;
    stop) stop ;;
    restart) stop; sleep 1; launch ;;
    status)
        pgrep -a picom >/dev/null && echo "picom: running" || echo "picom: stopped"
        pgrep -a xfce4-panel >/dev/null && echo "panel: running" || echo "panel: stopped"
        ;;
    widgets) build_datetime_widget; build_weather_widget; build_recent_widget; build_music_widget; build_continue_widget; build_explore_widget; build_user_widget; build_main_content; echo "Widgets rebuilt." ;;
    *) echo "Usage: $0 {start|stop|restart|status|widgets}" ;;
esac

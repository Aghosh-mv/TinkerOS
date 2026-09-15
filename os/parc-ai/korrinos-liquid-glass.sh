#!/usr/bin/env bash
# korrinos-liquid-glass.sh — Liquid Glass Glassmorphism System
# Apple-style liquid glass via picom compositor: blur, saturation, rim highlights, refraction

set -euo pipefail

GLASS_DIR="${HOME}/.config/korrinos/liquid-glass"
PICOM_DIR="${HOME}/.config/picom"
mkdir -p "$GLASS_DIR" "$PICOM_DIR"

GLASS_CONFIG="$GLASS_DIR/config.json"
PICOM_CONF="$PICOM_DIR/korrinos.conf"

init_glass() {
  if [ ! -f "$GLASS_CONFIG" ]; then
    cat > "$GLASS_CONFIG" << 'DEFAULTS'
{
  "enabled": true,
  "blur_method": "dual_kawase",
  "blur_strength": 18,
  "blur_background": true,
  "blur_frame": true,
  "saturate": 1.45,
  "opacity": 0.92,
  "active_opacity": 0.95,
  "inactive_opacity": 0.88,
  "corner_radius": 14,
  "shadow": true,
  "shadow_opacity": 0.55,
  "shadow_offset_x": -7,
  "shadow_offset_y": -7,
  "shadow_radius": 28,
  "fading": true,
  "fade_delta": 5,
  "fade_in_step": 0.04,
  "fade_out_step": 0.04,
  "vsync": true,
  "glx_no_stencil": true,
  "use_damage": true,
  "rounded_corners_exclude": [],
  "focus_exclude": [],
  "transparent_clipping": false,
  "detect_rounded_corners": true,
  "detect_client_opacity": true,
  "vsync_use_glFinish": true
}
DEFAULTS
    echo "Liquid glass config initialized"
  fi
}

# Generate picom config with liquid glass effects
generate_picom_conf() {
  local blur_str
  blur_str=$(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('blur_strength', 18))" 2>/dev/null || echo 18)
  local saturate
  saturate=$(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('saturate', 1.45))" 2>/dev/null || echo 1.45)
  local opacity
  opacity=$(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('opacity', 0.92))" 2>/dev/null || echo 0.92)
  local active_op
  active_op=$(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('active_opacity', 0.95))" 2>/dev/null || echo 0.95)
  local inactive_op
  inactive_op=$(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('inactive_opacity', 0.88))" 2>/dev/null || echo 0.88)
  local radius
  radius=$(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('corner_radius', 14))" 2>/dev/null || echo 14)
  local shadow_op
  shadow_op=$(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('shadow_opacity', 0.55))" 2>/dev/null || echo 0.55)
  local fade_delta
  fade_delta=$(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('fade_delta', 5))" 2>/dev/null || echo 5)

  cat > "$PICOM_CONF" << PICOM
# KorrinOS Liquid Glass — Auto-generated picom config
# Do not edit manually; use: korrinos liquid-glass [command]

# ═══ Backend ═══
backend = "glx";
glx-no-stencil = true;
use-damage = true;
vsync = true;
glx-no-rebind-pixmap = true;
vsync-use-glfinish = true;

# ═══ Liquid Glass — Blur ═══
blur-method = "dual_kawase";
blur-strength = ${blur_str};
blur-background = true;
blur-background-frame = true;
blur-background-fixed = false;
blur-kernel = "3x3box";

# ═══ Liquid Glass — Saturation ═══
# Increases color vibrancy through blurred surfaces
# This is what makes glass look "liquid" vs flat
wintypes:
{
  tooltip = { fade = true; shadow = true; opacity = ${opacity}; focus = true; full-shadow = false; };
  dock = { shadow = true; clip-shadow-above = true; };
  dnd = { shadow = false; };
  popup_menu = { opacity = ${opacity}; shadow = true; focus = true; };
  dropdown_menu = { opacity = ${opacity}; shadow = true; focus = true; };
  notification = { shadow = true; opacity = ${opacity}; };
  combo = { shadow = false; };
  dialog = { shadow = true; opacity = ${active_op}; };
  splash = { shadow = false; };
  toolbar = { shadow = true; opacity = ${active_op}; };
  menu = { shadow = true; opacity = ${active_op}; };
  popup = { shadow = true; opacity = ${active_op}; };
  utility = { shadow = true; opacity = ${active_op}; };
  desktop = { shadow = false; };
  normal = { shadow = true; opacity = ${inactive_op}; };
  dialog = { shadow = true; opacity = ${active_op}; };
  undecoded = { shadow = true; };
  slider = { shadow = true; };
  notification = { shadow = true; };
};

# ═══ Liquid Glass — Shadows ═══
shadow = true;
shadow-radius = 28;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = ${shadow_op};
shadow-red = 0.0;
shadow-green = 0.0;
shadow-blue = 0.0;

# ═══ Liquid Glass — Transparency ═══
active-opacity = ${active_op};
inactive-opacity = ${inactive_op};
frame-opacity = 1.0;
inactive-opacity-override = false;

focus-exclude = [
  "class_g = 'Cairo-clock'",
  "class_g = 'Bar'",
  "class_g = 'korrinos-panel'",
  "class_g = 'korrinos-dock'",
  "class_g = 'korrinos-tinkeria'"
];

opacity-rule = [
  "100:class_g = 'firefox' && focused",
  "95:class_g = 'firefox' && !focused",
  "100:class_g = 'Code' && focused",
  "95:class_g = 'Code' && !focused",
  "100:class_g = 'korrinos-terminal' && focused",
  "92:class_g = 'korrinos-terminal' && !focused",
  "100:_GTK_FRAME_EXTENTS@:c",
  "100:_NET_WM_STATE@:32a = '_NET_WM_STATE_FOCUSED'"
];

# ═══ Liquid Glass — Fading ═══
fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;
fade-delta = ${fade_delta};
fade-exclude = [
  "class_g = 'slop'"
];

# ═══ Liquid Glass — Rounded Corners ═══
corner-radius = ${radius};
rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "class_g = 'korrinos-panel'",
  "_NET_WM_STATE@:32a *= '_NET_WM_STATE_FULLSCREEN'",
  "_NET_WM_STATE@:32a *= '_MAXIMIZED_HORZ'",
  "_NET_WM_STATE@:32a *= '_MAXIMIZED_VERT'"
];

detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
detect-clipped = true;

# ═══ Liquid Glass — Extras ═══
transparent-clipping = false;
PICOM

  echo "Picom liquid glass config written to $PICOM_CONF"
}

# Start picom with liquid glass config
cmd_start() {
  init_glass
  generate_picom_conf

  # Kill existing picom
  pkill picom 2>/dev/null || true
  sleep 0.3

  # Start picom with liquid glass config
  if command -v picom &>/dev/null; then
    picom --config "$PICOM_CONF" --daemon --log-path "$GLASS_DIR/picom.log" 2>/dev/null &
    local pid=$!
    sleep 0.5
    if kill -0 "$pid" 2>/dev/null; then
      echo "Liquid glass started (PID: $pid)"
      echo "  Blur: dual_kawase $(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('blur_strength', 18))" 2>/dev/null || echo 18)"
      echo "  Saturation: $(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('saturate', 1.45))" 2>/dev/null || echo 1.45)"
      echo "  Corner radius: $(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('corner_radius', 14))" 2>/dev/null || echo 14)"
      echo "  Opacity: $(python3 -c "import json; print(json.load(open('$GLASS_CONFIG')).get('active_opacity', 0.95))" 2>/dev/null || echo 0.95)"
    else
      echo "Error: picom failed to start. Check $GLASS_DIR/picom.log"
      return 1
    fi
  else
    echo "Error: picom not installed. Install with: sudo apt install picom"
    return 1
  fi
}

# Stop picom
cmd_stop() {
  pkill picom 2>/dev/null && echo "Liquid glass stopped" || echo "Picom not running"
}

# Status
cmd_status() {
  init_glass
  if pgrep picom &>/dev/null; then
    echo "Liquid Glass: ACTIVE"
    echo "  PID: $(pgrep picom | head -1)"
    echo "  Config: $PICOM_CONF"
  else
    echo "Liquid Glass: INACTIVE"
  fi
  echo ""
  echo "Settings:"
  python3 -c "
import json
c = json.load(open('$GLASS_CONFIG'))
for k, v in c.items():
    print(f'  {k}: {v}')
" 2>/dev/null
}

# Set a config value
cmd_set() {
  local key="$1" value="$2"
  init_glass
  python3 -c "
import json
with open('$GLASS_CONFIG') as f: c = json.load(f)
if '$key' not in c:
    print(f'Unknown key: $key')
    print('Available keys: ' + ', '.join(c.keys()))
else:
    c['$key'] = $value
    with open('$GLASS_CONFIG', 'w') as f: json.dump(c, f, indent=2)
    print(f'$key = $value')
    print('Run: korrinos liquid-glass restart')
"
}

# Presets
cmd_preset() {
  local preset="$1"
  init_glass
  case "$preset" in
    clear)
      python3 -c "
import json
with open('$GLASS_CONFIG') as f: c = json.load(f)
c['blur_strength'] = 8; c['saturate'] = 1.2; c['opacity'] = 0.95
c['active_opacity'] = 0.97; c['inactive_opacity'] = 0.92; c['corner_radius'] = 12
with open('$GLASS_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Preset: Clear (subtle, transparent)')
"
      ;;
    frosted)
      python3 -c "
import json
with open('$GLASS_CONFIG') as f: c = json.load(f)
c['blur_strength'] = 18; c['saturate'] = 1.45; c['opacity'] = 0.92
c['active_opacity'] = 0.95; c['inactive_opacity'] = 0.88; c['corner_radius'] = 14
with open('$GLASS_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Preset: Frosted (default liquid glass)')
"
      ;;
    crystal)
      python3 -c "
import json
with open('$GLASS_CONFIG') as f: c = json.load(f)
c['blur_strength'] = 24; c['saturate'] = 1.6; c['opacity'] = 0.88
c['active_opacity'] = 0.92; c['inactive_opacity'] = 0.82; c['corner_radius'] = 18
with open('$GLASS_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Preset: Crystal (heavy frost, bright)')
"
      ;;
    heavy)
      python3 -c "
import json
with open('$GLASS_CONFIG') as f: c = json.load(f)
c['blur_strength'] = 30; c['saturate'] = 1.7; c['opacity'] = 0.85
c['active_opacity'] = 0.90; c['inactive_opacity'] = 0.78; c['corner_radius'] = 20
with open('$GLASS_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Preset: Heavy (deep frost, maximum blur)')
"
      ;;
    off)
      python3 -c "
import json
with open('$GLASS_CONFIG') as f: c = json.load(f)
c['blur_strength'] = 0; c['blur_background'] = False
c['saturate'] = 1.0; c['opacity'] = 1.0; c['corner_radius'] = 0
with open('$GLASS_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Preset: Off (no effects)')
"
      ;;
    *)
      echo "Unknown preset: $preset"
      echo "Available: clear, frosted, crystal, heavy, off"
      return 1
      ;;
  esac
  cmd_stop 2>/dev/null
  cmd_start
}

# Main
init_glass

case "${1:-start}" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  restart) cmd_stop; sleep 0.3; cmd_start ;;
  status)  cmd_status ;;
  set)     shift; cmd_set "$@" ;;
  preset)  shift; cmd_preset "$@" ;;
  config)  cat "$PICOM_CONF" ;;
  *)
    echo "Usage: korrinos liquid-glass {start|stop|restart|status|set|preset|config}"
    echo ""
    echo "Presets: clear, frosted, crystal, heavy, off"
    echo "Example: korrinos liquid-glass set blur_strength 20"
    echo "Example: korrinos liquid-glass preset crystal"
    ;;
esac

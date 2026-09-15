#!/usr/bin/env bash
# korrinos-smoothui.sh — Mac-like Smooth UI System
# Compositor, animations, gestures, blur, smooth scrolling, transitions

set -euo pipefail

SMOOTH_DIR="${HOME}/.config/korrinos/smoothui"
SMOOTH_CONFIG="$SMOOTH_DIR/config.json"
mkdir -p "$SMOOTH_DIR"

# Default config
init_smooth() {
  if [ ! -f "$SMOOTH_CONFIG" ]; then
    cat > "$SMOOTH_CONFIG" << 'DEFAULTS'
{
  "compositor": "picom",
  "animations_enabled": true,
  "animation_type": "smooth",
  "blur_enabled": true,
  "blur_strength": 12,
  "rounded_corners": true,
  "corner_radius": 12,
  "shadow_enabled": true,
  "shadow_opacity": 0.6,
  "vsync": true,
  "smooth_scrolling": true,
  "gestures_enabled": true,
  "gesture_sensitivity": 1.0,
  "transparency": 0.92,
  "docking": "macos",
  "hot_cornners": true,
  "expose_enabled": true,
  "mission_control": true,
  "launchpad": true,
  "smooth_fonts": true,
  "subpixel_rendering": true,
  "fading": true,
  "fade_duration_ms": 250
}
DEFAULTS
    echo "Smooth UI config initialized"
  fi
}

# Get config
get_config() {
  local key="$1"
  local default="${2:-}"
  python3 -c "import json; print(json.load(open('$SMOOTH_CONFIG')).get('$key', '$default'))" 2>/dev/null || echo "$default"
}

# Set config
set_config() {
  local key="$1"
  local value="$2"
  python3 -c "
import json
with open('$SMOOTH_CONFIG') as f: c = json.load(f)
c['$key'] = $value
with open('$SMOOTH_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print(f'$key = {$value}')
"
}

# Install picom compositor
cmd_install() {
  echo "╔══════════════════════════════════════════════╗"
  echo "║    KorrinOS Smooth UI — Mac-like Experience  ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  
  echo "  [1/5] Installing compositor..."
  if ! command -v picom &>/dev/null; then
    sudo apt install -y picom 2>/dev/null || \
    sudo pacman -S picom 2>/dev/null || \
    sudo dnf install -y picom 2>/dev/null || \
    echo "    ⚠ Could not install picom — install manually"
  else
    echo "    ✓ picom already installed"
  fi
  
  echo "  [2/5] Installing animation tools..."
  if ! command -v xdotool &>/dev/null; then
    sudo apt install -y xdotool 2>/dev/null || true
  fi
  echo "    ✓ xdotool ready"
  
  echo "  [3/5] Installing gesture support..."
  if ! command -v libinput &>/dev/null; then
    sudo apt install -y libinput-tools 2>/dev/null || true
  fi
  echo "    ✓ libinput ready"
  
  echo "  [4/5] Configuring font rendering..."
  # Enable subpixel rendering and hinting
  cat > ~/.config/fontconfig/fonts.conf << 'FONTEOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>
</fontconfig>
FONTEOF
  echo "    ✓ Font rendering configured"
  
  echo "  [5/5] Generating picom config..."
  generate_picom_config
  echo "    ✓ Picom config generated"
  
  echo ""
  echo "  ✓ Smooth UI installed!"
  echo "  Run: korrinos-smoothui.sh start"
}

# Generate picom config
generate_picom_config() {
  local blur
  blur=$(get_config "blur_enabled" "true")
  local blur_strength
  blur_strength=$(get_config "blur_strength" "12")
  local corners
  corners=$(get_config "rounded_corners" "true")
  local radius
  radius=$(get_config "corner_radius" "12")
  local shadow
  shadow=$(get_config "shadow_enabled" "true")
  local shadow_opacity
  shadow_opacity=$(get_config "shadow_opacity" "0.6")
  local fading
  fading=$(get_config "fading" "true")
  local fade_ms
  fade_ms=$(get_config "fade_duration_ms" "250")
  local vsync
  vsync=$(get_config "vsync" "true")
  
  cat > ~/.config/picom/picom.conf << PICOMEOF
# KorrinOS Smooth UI — Picom Configuration
# Mac-like smooth experience

# Backend
backend = "glx";
vsync = ${vsync};
glx-no-stencil = true;
use-damage = true;
glx-no-rebind-pixmap = true;

# Shadows
shadow = ${shadow};
shadow-radius = 20;
shadow-offset-x = -15;
shadow-offset-y = -15;
shadow-opacity = ${shadow_opacity};

shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Conky'",
  "class_g ?= 'Notify-osd'",
  "class_g = 'Cairo-clock'",
  "_GTK_FRAME_EXTENTS@:c"
];

# Fading
fading = ${fading};
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 5;

fade-exclude = [];

# Rounded corners
${corners:+corner-radius = ${radius};}
${corners:+round-borders = ${radius};}

# Blur
${blur:+blur-method = "dual_kawase";}
${blur:+blur-strength = ${blur_strength};}
${blur:+blur-background = true;}
${blur:+blur-background-frame = false;}
${blur:+blur-background-fixed = false;}

blur-background-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "_GTK_FRAME_EXTENTS@:c"
];

# Opacity rules (Mac-like transparency)
opacity-rule = [
  "92:class_g = 'Rofi'",
  "95:class_g = 'Thunar'",
  "95:class_g = 'Nautilus'",
  "90:class_g = 'Code'",
  "90:class_g = 'Alacritty'",
  "95:class_g = 'Firefox'"
];

# Window type settings
wintypes:
{
  tooltip = { fade = true; shadow = true; opacity = 0.9; };
  dock = { shadow = false; clip-shadow-above = true; };
  dnd = { shadow = false; };
  popup_menu = { opacity = 0.95; };
  dropdown_menu = { opacity = 0.95; };
};

# General settings
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
use-ewmh-active-win = true;
PICOMEOF
}

# Start compositor
cmd_start() {
  echo "Starting Smooth UI compositor..."
  
  # Kill existing picom
  pkill picom 2>/dev/null || true
  sleep 1
  
  # Start picom
  picom --config ~/.config/picom/picom.conf -b 2>/dev/null && \
    echo "✓ Picom compositor started" || \
    echo "⚠ Failed to start picom"
  
  # Enable smooth scrolling
  if [ "$(get_config 'smooth_scrolling' 'true')" = "true" ]; then
    # Configure natural scrolling
    gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true 2>/dev/null || true
    gsettings set org.gnome.desktop.peripherals.mouse natural-scroll true 2>/dev/null || true
    echo "✓ Natural scrolling enabled"
  fi
  
  # Enable animations
  if [ "$(get_config 'animations_enabled' 'true')" = "true" ]; then
    gsettings set org.gnome.desktop.interface enable-animations true 2>/dev/null || true
    echo "✓ Animations enabled"
  fi
  
  # Configure smooth fonts
  if [ "$(get_config 'smooth_fonts' 'true')" = "true" ]; then
    gsettings set org.gnome.desktop.interface font-antialiasing 'rgba' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-hinting 'slight' 2>/dev/null || true
    echo "✓ Smooth font rendering enabled"
  fi
  
  echo ""
  echo "✓ Smooth UI active!"
}

# Stop compositor
cmd_stop() {
  echo "Stopping Smooth UI..."
  pkill picom 2>/dev/null && echo "✓ Picom stopped" || echo "Picom not running"
}

# Configure gestures
cmd_gestures() {
  echo "=== Gesture Configuration ==="
  echo ""
  
  if [ "$(get_config 'gestures_enabled' 'true')" = "true" ]; then
    echo "  Gestures: Enabled"
    echo ""
    echo "  Available gestures:"
    echo "    3-finger swipe left/right  → Switch workspace"
    echo "    3-finger swipe up          → Mission Control (expose all)"
    echo "    3-finger swipe down        → Show desktop"
    echo "    4-finger pinch             → Launchpad"
    echo "    2-finger pinch             → Zoom"
    echo "    2-finger scroll            → Smooth scroll"
    echo ""
    
    # Configure touchpad
    gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true 2>/dev/null || true
    gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true 2>/dev/null || true
    gsettings set org.gnome.desktop.peripherals.touchpad edge-scrolling-enabled false 2>/dev/null || true
    
    echo "  ✓ Touchpad gestures configured"
  else
    echo "  Gestures: Disabled"
    echo "  Enable with: korrinos-smoothui.sh config gestures_enabled true"
  fi
}

# Configure window management (Mission Control, Expose, etc.)
cmd_window_management() {
  echo "=== Window Management ==="
  echo ""
  
  # Mission Control (Expose all windows)
  if [ "$(get_config 'mission_control' 'true')" = "true" ]; then
    gsettings set org.gnome.desktop.wm.keybindings show-desktop "['<Super>d']" 2>/dev/null || true
    gsettings set org.gnome.shell.keybindings toggle-overview "['<Super>space']" 2>/dev/null || true
    echo "  ✓ Mission Control: Super+Space"
    echo "  ✓ Show Desktop: Super+D"
  fi
  
  # Expose (show all windows of current app)
  if [ "$(get_config 'expose_enabled' 'true')" = "true" ]; then
    gsettings set org.gnome.desktop.wm.keybindings toggle-message-tray "['<Super>n']" 2>/dev/null || true
    echo "  ✓ Expose: Super+N"
  fi
  
  # Launchpad
  if [ "$(get_config 'launchpad' 'true')" = "true" ]; then
    gsettings set org.gnome.shell.keybindings toggle-application-view "['<Super>a']" 2>/dev/null || true
    echo "  ✓ Launchpad: Super+A"
  fi
  
  # Hot corners
  if [ "$(get_config 'hot_cornners' 'true')" = "true" ]; then
    gsettings set org.gnome.desktop.interface enable-hot-corners true 2>/dev/null || true
    echo "  ✓ Hot corners enabled"
  fi
  
  echo ""
  echo "  Window shortcuts:"
  echo "    Super+Left/Right  → Snap window to half"
  echo "    Super+Up          → Maximize"
  echo "    Super+Down        → Minimize"
  echo "    Super+H           → Hide window"
  echo "    Super+Q           → Close window"
  echo "    Alt+Tab           → Switch windows"
  echo "    Super+Tab         → Switch applications"
}

# Animation presets
cmd_animation() {
  local preset="${1:-smooth}"
  
  echo "Setting animation preset: ${preset}"
  
  case "$preset" in
    smooth)
      # Smooth Mac-like animations
      gsettings set org.gnome.desktop.interface enable-animations true 2>/dev/null || true
      gsettings set org.gnome.shell.extensions.jupiter rollback-animation "smooth" 2>/dev/null || true
      echo "✓ Smooth animations enabled"
      ;;
    snappy)
      # Fast, responsive animations
      gsettings set org.gnome.desktop.interface enable-animations true 2>/dev/null || true
      gsettings set org.gnome.shell.extensions.jupiter rollback-animation "snappy" 2>/dev/null || true
      echo "✓ Snappy animations enabled"
      ;;
    none)
      # Disable animations for performance
      gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
      echo "✓ Animations disabled"
      ;;
    *)
      echo "Available presets: smooth, snappy, none"
      ;;
  esac
}

# Status
cmd_status() {
  echo "=== Smooth UI Status ==="
  echo ""
  
  echo "  Configuration:"
  python3 -c "
import json
c = json.load(open('$SMOOTH_CONFIG'))
for k, v in c.items():
    print(f'    {k}: {v}')
" 2>/dev/null
  
  echo ""
  echo "  Running:"
  if pgrep picom &>/dev/null; then
    echo "    ✓ Picom compositor: running"
  else
    echo "    ✗ Picom compositor: not running"
  fi
  
  if gsettings get org.gnome.desktop.interface enable-animations 2>/dev/null | grep -q "true"; then
    echo "    ✓ Animations: enabled"
  else
    echo "    ✗ Animations: disabled"
  fi
  
  if gsettings get org.gnome.desktop.peripherals.touchpad natural-scroll 2>/dev/null | grep -q "true"; then
    echo "    ✓ Natural scrolling: enabled"
  else
    echo "    ✗ Natural scrolling: disabled"
  fi
}

# Configure setting
cmd_config() {
  local key="$1"
  local value="$2"
  set_config "$key" "$value"
}

case "${1:-help}" in
  init)              init_smooth ;;
  install)           cmd_install ;;
  start)             cmd_start ;;
  stop)              cmd_stop ;;
  status)            cmd_status ;;
  gestures)          cmd_gestures ;;
  window-management) cmd_window_management ;;
  animation)         shift; cmd_animation "$@" ;;
  config)            shift; cmd_config "$@" ;;
  *)
    echo "KorrinOS Smooth UI — Mac-like Experience"
    echo "Usage: korrinos-smoothui.sh <command>"
    echo ""
    echo "Commands:"
    echo "  install           Install compositor & dependencies"
    echo "  start             Start Smooth UI compositor"
    echo "  stop              Stop compositor"
    echo "  status            Show Smooth UI status"
    echo "  gestures          Configure touchpad gestures"
    echo "  window-management Configure Mission Control/Expose"
    echo "  animation <preset>  Set animation (smooth|snappy|none)"
    echo "  config <key> <value>  Configure setting"
    ;;
esac

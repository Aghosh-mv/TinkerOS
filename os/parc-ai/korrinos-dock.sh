#!/usr/bin/env bash
# korrinos-dock.sh — Application Dock with Magnification
# Plank-based or custom dock with liquid glass styling

set -euo pipefail

DOCK_DIR="${HOME}/.config/korrinos/dock"
PLANK_DIR="${HOME}/.local/share/plank"
mkdir -p "$DOCK_DIR" "$PLANK_DIR/dock1/launchers"

DOCK_CONFIG="$DOCK_DIR/config.json"
PLANK_DOCKS="$HOME/.local/share/plank/docks"

init_dock() {
  if [ ! -f "$DOCK_CONFIG" ]; then
    cat > "$DOCK_CONFIG" << 'DEFAULTS'
{
  "enabled": true,
  "position": "bottom",
  "theme": "liquid-glass",
  "icon_size": 48,
  "zoom_enabled": true,
  "zoom_percent": 150,
  "zoom_duration": 200,
  "hide_enabled": true,
  "hide_delay": 500,
  "show_delay": 100,
  "pin_together": false,
  "taskbar_mode": "window_list",
  "lock_items": false,
  "auto_pinning": true,
  "default_dock": "korrinos"
}
DEFAULTS
  fi
}

# Create plank dock theme
create_plank_theme() {
  local theme_dir="$PLANK_DIR/themes/korrinos-liquid-glass"
  mkdir -p "$theme_dir"

  cat > "$theme_dir/dock.theme" << 'THEME'
[KorrinOS Liquid Glass]
Name=KorrinOS Liquid Glass
Description=Liquid glass glassmorphism dock theme for KorrinOS
Author=KorrinOS

DockItemCount=0

# Background — liquid glass
TopPadding=4
BottomPadding=4
LeftPadding=10
RightPadding=10
Anchor=Bottom
Fixed/Internal=0
ThemePath=/usr/share/plank/themes/

# Items
ItemSize=48

# Appearance
UseCustomOpacity=false
CustomOpacity=0.85
UseCustomGlow=false
CustomGlowColor=50;110;255
GlowSize=30
DrawShadow=true
THEME

  echo "Plank theme created: $theme_dir"
}

# Create plank dock config
create_plank_dock() {
  local dock_dir="$PLANK_DOCKS/korrinos"
  mkdir -p "$dock_dir"

  cat > "$dock_dir/dock.xml" << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<dock version="1">
  <settings version="1">
    <name>KorrinOS Dock</name>
    <theme>korrinos-liquid-glass</theme>
    <position>bottom</position>
    <alignment>center</alignment>
    <items-alignment>center</items-alignment>
    <show-dock-for autohide="false" />
    <hide-delay>500</hide-delay>
    <show-delay>100</show-delay>
    <zoom-enabled>true</zoom-enabled>
    <zoom-duration>200</zoom-duration>
    <zoom-percent>150</zoom-percent>
    <pin-together>false</pin-together>
    <lock-items>false</lock-items>
    <dock-fixed>false</dock-fixed>
    <intellihide>false</intellihide>
    <taskbar-mode>window-list</taskbar-mode>
    <animation(enabled="true" bouncingSpeed="0.65" duration="300" type="UDLLPUDLU">3</animation>
  </settings>
</dock>
XML

  echo "Plank dock config created"
}

# Create default launchers
create_launchers() {
  local launcher_dir="$PLANK_DOCKS/korrinos/launchers"
  mkdir -p "$launcher_dir"

  # Common apps
  local apps=(
    "nautilus;Files;system-file-manager"
    "gnome-terminal;Terminal;utilities-terminal"
    "firefox;Browser;firefox"
    "gnome-settings;Settings;preferences-system"
    "rhythmbox;Music;rhythmbox"
    "shotwell;Photos;shotwell"
    "trash:///;Trash;user-trash"
  )

  local i=1
  for app in "${apps[@]}"; do
    IFS=';' read -r exec name icon <<< "$app"
    local launcher="$launcher_dir/${i}-${name,,}.dockitem"
    if [ ! -f "$launcher" ]; then
      cat > "$launcher" << LAUNCHER
<?xml version="1.0" encoding="UTF-8"?>
<dockitem version="1">
  <Factory>
    <Launcher>
      <Path>/usr/share/applications/${exec}.desktop</Path>
    </Launcher>
  </Factory>
  <LastSelected>0</LastSelected>
  <Timestamp>$(date +%s)</Timestamp>
</dockitem>
LAUNCHER
    fi
    i=$((i + 1))
  done

  echo "Default launchers created"
}

# Create custom korrinos dock using yad (fallback if no plank)
create_custom_dock() {
  local dock_dir="$DOCK_DIR/custom"
  mkdir -p "$dock_dir"

  cat > "$dock_dir/dock.sh" << 'DOCK'
#!/usr/bin/env bash
# KorrinOS Custom Dock — yad-based fallback

ICONS=(":Files:nautilus" "💻:Terminal:gnome-terminal" ":Tinkeria:korrinos-vokk" ":Settings:gnome-settings" ":Music:rhythmbox" ":Browser:firefox" "🗑️:Trash:user-trash")

while true; do
  BUTTON=""
  ICON_STR=""
  for entry in "${ICONS[@]}"; do
    IFS=':' read -r emoji name icon <<< "$entry"
    ICON_STR+="$icon:$emoji $name|"
  done
  ICON_STR=${ICON_STR%|}

  CHOICE=$(yad --notification \
    --image="$ICON_STR" \
    --text="KorrinOS Dock" \
    2>/dev/null)

  case "$CHOICE" in
    "Files") nautilus & ;;
    "Terminal") gnome-terminal & ;;
    "Tinkeria") korrinos ai & ;;
    "Settings") gnome-control-center & ;;
    "Music") rhythmbox & ;;
    "Browser") firefox & ;;
    "Trash") nautilus trash:/// & ;;
  esac

  sleep 0.5
done
DOCK
  chmod +x "$dock_dir/dock.sh"
  echo "Custom dock script created at $dock_dir/dock.sh"
}

# Start dock
cmd_start() {
  init_dock

  # Try plank first
  if command -v plank &>/dev/null; then
    create_plank_theme
    create_plank_dock
    create_launchers

    pkill plank 2>/dev/null || true
    sleep 0.3
    plank --preferences 2>/dev/null &
    sleep 0.5
    pkill -f "plank --preferences" 2>/dev/null || true
    plank -d korrinos &
    echo "Plank dock started"
  else
    # Fallback to custom dock
    create_custom_dock
    echo "Plank not installed. Using custom dock."
    echo "Install plank for full experience: sudo apt install plank"
  fi
}

# Stop dock
cmd_stop() {
  pkill plank 2>/dev/null && echo "Plank dock stopped" || true
  pkill -f "korrinos/custom/dock.sh" 2>/dev/null || true
}

# Status
cmd_status() {
  init_dock
  if pgrep plank &>/dev/null; then
    echo "Dock: ACTIVE (Plank)"
    echo "  PID: $(pgrep plank | head -1)"
  elif pgrep -f "korrinos/custom/dock.sh" &>/dev/null; then
    echo "Dock: ACTIVE (Custom)"
  else
    echo "Dock: INACTIVE"
  fi
}

# Toggle
cmd_toggle() {
  if pgrep plank &>/dev/null || pgrep -f "korrinos/custom/dock.sh" &>/dev/null; then
    cmd_stop
  else
    cmd_start
  fi
}

# Main
init_dock

case "${1:-toggle}" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  toggle)  cmd_toggle ;;
  status)  cmd_status ;;
  restart) cmd_stop; sleep 0.3; cmd_start ;;
  *)
    echo "Usage: korrinos dock {start|stop|toggle|status|restart}"
    ;;
esac

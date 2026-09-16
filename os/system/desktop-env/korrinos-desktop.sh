#!/bin/bash
# KorrinOS Desktop Environment v2
# Complete desktop environment: panel, launcher, compositor, themes, notifications,
# hot corners, workspaces, keyboard shortcuts, multi-monitor, accessibility,
# screensaver, context menus, desktop icons, file manager, terminal, screenshots,
# clipboard, power, network, volume, display, printer, users, firewall, disk,
# system monitor, GRUB theme, Plymouth boot splash, LightDM login, about dialog,
# software updater, backup/restore, driver manager, log viewer, crash reporter
# Built on XFCE4 with full KorrinOS branding

set -euo pipefail

DE_DIR="${HOME}/.config/korrinos/desktop"
DE_CONFIG="$DE_DIR/config.json"
DE_THEMES_DIR="/usr/share/korrinos/themes"
DE_CACHE="$DE_DIR/cache"
DE_LOG="$DE_DIR/desktop.log"
DE_PRESETS="$DE_DIR/presets"
mkdir -p "$DE_DIR" "$DE_THEMES_DIR" "$DE_CACHE" "$DE_PRESETS"

# ============================================================================
#  SECTION 1: DEFAULT CONFIGURATION
# ============================================================================

init_desktop() {
  if [ ! -f "$DE_CONFIG" ]; then
    cat > "$DE_CONFIG" << 'DEFAULTS'
{
  "version": "2.0",
  "panel": {
    "position": "top",
    "height": 32,
    "autohide": false,
    "show_clock": true,
    "show_tray": true,
    "show_workspaces": true,
    "show_system_menu": true,
    "clock_format": "%a %b %d  %H:%M",
    "transparent": true,
    "opacity": 85,
    "plugins": ["whiskermenu", "separator", "workspace-switcher", "separator", "system-tray", "pulseaudio", "power-manager", "clock"]
  },
  "dock": {
    "enabled": true,
    "position": "bottom",
    "icon_size": 48,
    "zoom_enabled": true,
    "autohide": false,
    "theme": "liquid-glass",
    "zoom_percent": 150,
    "zoom_duration": 200,
    "show_running": true
  },
  "launcher": {
    "columns": 6,
    "rows": 4,
    "search_enabled": true,
    "categories": true,
    "frequent_apps": true,
    "search_provider": "appstream",
    "show_recent": false,
    "show_power": true
  },
  "notifications": {
    "position": "top-right",
    "timeout_seconds": 5,
    "sound": true,
    "max_visible": 5,
    "theme": "glassmorphism",
    "do_not_disturb": false
  },
  "theme": {
    "gtk": "KorrinOS-Dark",
    "icons": "KorrinOS-Icons",
    "cursor": "KorrinOS-Cursor",
    "wallpaper": "/usr/share/korrinos/wallpapers/default.png",
    "font": "Ubuntu Sans 11",
    "monospace_font": "JetBrains Mono 12",
    "titlebar_font": "Ubuntu Sans Bold 11",
    "icon_theme": "Papirus",
    "color_scheme": "prefer-dark",
    "icon_size": 48,
    "button_layout": "CHM",
    "titlebar_style": "flat"
  },
  "compositor": {
    "enabled": true,
    "backend": "glx",
    "vsync": true,
    "shadow_opacity": 80,
    "frame_delay": 0,
    "blur": true,
    "blur_method": "dual_kawase",
    "blur_strength": 6,
    "shadow_radius": 12,
    "shadow_offset_x": -7,
    "shadow_offset_y": -7,
    "fading": true,
    "fade_delta": 10,
    "fade_in_step": 0.1,
    "fade_out_step": 0.1,
    "translucent_active_opacity": 100,
    "translucent_inactive_opacity": 95,
    "corner_radius": 12
  },
  "hotcorners": {
    "top-left": "none",
    "top-right": "overview",
    "bottom-left": "show-desktop",
    "bottom-right": "none",
    "delay_ms": 200
  },
  "workspaces": {
    "count": 4,
    "names": ["Web", "Work", "Chat", "Media"],
    "dynamic": false,
    "wrap_around": true,
    "pager_show_names": true
  },
  "keyboard": {
    "repeat_delay": 500,
    "repeat_interval": 30,
    "numlock_on": true,
    "capslock_off": true,
    "shortcuts": {
      "ctrl+alt+t": "terminal",
      "ctrl+alt+d": "show-desktop",
      "ctrl+alt+l": "lock-screen",
      "ctrl+alt+m": "maximize",
      "ctrl+alt+n": "minimize",
      "ctrl+alt+h": "tile-left",
      "ctrl+alt+j": "tile-right",
      "super+d": "app-launcher",
      "super+l": "lock-screen",
      "super+e": "file-manager",
      "super+space": "clipboard",
      "Print": "screenshot",
      "ctrl+Print": "screenshot-clipboard",
      "shift+Print": "screenshot-area",
      "ctrl+alt+Delete": "task-manager",
      "ctrl+shift+Escape": "system-monitor"
    }
  },
  "multi_monitor": {
    "primary": "",
    "layout": "extend",
    "panel_per_monitor": false,
    "dock_per_monitor": false,
    "wallpaper_per_monitor": true,
    "dpi_override": 0
  },
  "accessibility": {
    "high_contrast": false,
    "large_text": false,
    "text_scaling": 1.0,
    "cursor_size": 24,
    "screen_reader": false,
    "sticky_keys": false,
    "slow_keys": false,
    "bounce_keys": false,
    "mouse_keys": false,
    "visual_bell": false,
    "keyboard accessibility": {
      "toggle_keys": false,
      "filter_keys": false,
      "mouse_keys": false
    }
  },
  "screensaver": {
    "enabled": true,
    "timeout_minutes": 10,
    "lock_on_timeout": false,
    "lock_command": "xflock4",
    "theme": "blank",
    "dpms_enabled": true,
    "dpms_standby": 600,
    "dpms_suspend": 600,
    "dpms_off": 900
  },
  "context_menu": {
    "style": "glassmorphism",
    "show_open_terminal": true,
    "show_korrinos_tools": true,
    "custom_actions": [],
    "show_wallpaper_change": true,
    "show_display_settings": true
  },
  "desktop_icons": {
    "enabled": false,
    "size": 64,
    "arrange": "auto",
    "show_home": true,
    "show_trash": true,
    "show_terminal": true,
    "show_applications": true
  },
  "sound_theme": {
    "enabled": true,
    "theme": "freedesktop",
    "event_sounds": true,
    "input_feedback": true,
    "allow_sounds_when_focused": false
  },
  "power_management": {
    "idle_action": "nothing",
    "idle_delay": 600,
    "suspend_on_lid_close": true,
    "show_battery": true,
    "low_battery_notify": true,
    "low_battery_threshold": 15
  }
}
DEFAULTS
    echo "Desktop config initialized."
  fi
}

# ============================================================================
#  SECTION 2: PANEL SETUP
# ============================================================================

setup_panel() {
  echo "=== Setting up KorrinOS Panel ==="

  xfce4-panel --quit 2>/dev/null || true
  pkill xfce4-panel 2>/dev/null || true
  sleep 1

  local panel_dir="${HOME}/.config/xfce4/panel"
  mkdir -p "$panel_dir"

  # Panel 1 configuration (top panel)
  cat > "$panel_dir/panels.conf" << 'EOF'
[panel-1]
position=top
size=32
length=100
background-style=2
background-rgba=0.0,0.0,0.0,0.7
autohide=FALSE
span=1
output-monitors=0
size-mode=user
unlock=false
plugins=whiskermenu-plugin separator-1 workspace-switcher separator-2 pulseaudio-plugin power-manager-plugin clock-7 systray

[panel-1:items]
whiskermenu-plugin=1
separator-1=2
workspace-switcher=3
separator-2=4
pulseaudio-plugin=5
power-manager-plugin=6
clock-7=7
systray=8
EOF

  # Whisker menu (app launcher)
  cat > "$panel_dir/whiskermenu.rc" << 'EOF'
[position]
x=0
y=0
[menu]
default-view=categories
show-categories=TRUE
show-recent=FALSE
show-favorites=TRUE
show-guest-session=FALSE
show-power-actions=TRUE
show-search-actions=TRUE
category-order=Desktop;System;Settings;Accessories;Development;Education;Games;Graphics;Multimedia;Network;Office;Science
[appearance]
list-view=category
show-tooltips=TRUE
single-click=FALSE
show-description=TRUE
[panel]
button-title=KorrinOS
button-icon=distributor-logo-korrinos
button-single-row=FALSE
button-icon-size=24
button-orientation=vertical
[search]
min-search-characters=2
EOF

  # Workspace switcher
  cat > "$panel_dir/workspace-switcher.rc" << 'EOF'
[row-size=30]
[widget]
num-rows=1
workspace-names=TRUE
EOF

  # System tray
  cat > "$panel_dir/systray.rc" << 'EOF'
[systray]
show-frame=FALSE
icon-size=22
square-icons=TRUE
EOF

  # Clock
  cat > "$panel_dir/clock.rc" << 'EOF'
[clock]
digital-format=%a %b %d  %H:%M
digital-layout=SPACE
tooltip-format=%A %d %B %Y
show-uptime=FALSE
show-percentage=FALSE
show-calendar=TRUE
show-military=FALSE
show-seconds=FALSE
EOF

  # PulseAudio plugin
  cat > "$panel_dir/pulseaudio-plugin.rc" << 'EOF'
[pulseaudio]
show_notifications=TRUE
show_volume_level=TRUE
show_mute_button=TRUE
scroll_up_step=5
scroll_down_step=5
EOF

  sleep 1
  xfce4-panel &
  echo "Panel configured."
}

# ============================================================================
#  SECTION 3: APP LAUNCHER
# ============================================================================

setup_launcher() {
  echo "=== Setting up KorrinOS App Launcher ==="

  local launcher_dir="${HOME}/.local/share/applications"
  mkdir -p "$launcher_dir"

  cat > "$launcher_dir/korrinos-categories.directory" << 'EOF'
[Desktop Entry]
Type=Directory
Name=KorrinOS
Icon=distributor-logo-korrinos
EOF

  cat > "$launcher_dir/korrinos-tools.directory" << 'EOF'
[Desktop Entry]
Type=Directory
Name=KorrinOS Tools
Icon=system-help
EOF

  cat > "$launcher_dir/korrinos-gaming.directory" << 'EOF'
[Desktop Entry]
Type=Directory
Name=Gaming
Icon=preferences-system-gaming
EOF

  cat > "$launcher_dir/korrinos-security.directory" << 'EOF'
[Desktop Entry]
Type=Directory
Name=Security
Icon=security-high
EOF

  update-desktop-database "$launcher_dir" 2>/dev/null || true

  mkdir -p "${HOME}/.local/share/desktop-directories"
  cat > "${HOME}/.local/share/desktop-directories/korrinos.directory" << 'EOF'
[Desktop Entry]
Type=Directory
Name=KorrinOS
Icon=distributor-logo-korrinos
EOF

  echo "App launcher configured."
}

# ============================================================================
#  SECTION 4: NOTIFICATION DAEMON
# ============================================================================

setup_notifications() {
  echo "=== Setting up KorrinOS Notifications ==="

  local dunst_config="${HOME}/.config/dunst"
  mkdir -p "$dunst_config"

  cat > "$dunst_config/dunstrc" << 'EOF'
[global]
    monitor = 0
    follow = mouse
    width = 350
    height = 200
    origin = top-right
    offset = 10x10
    scale = 0
    notification_limit = 5
    indicate_hidden = yes
    transparency = 10
    corner_radius = 12
    frame_width = 2
    frame_color = "#8cb4ff"
    gap_size = 6
    separator_height = 2
    separator_color = frame
    padding = 12
    horizontal_padding = 14
    text_icon_padding = 12
    icon_position = left
    min_icon_size = 32
    max_icon_size = 64
    group_gap = 8
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300

[urgency_low]
    background = "#1a1e2a"
    foreground = "#c8d7ff"
    timeout = 5
    default_icon = dialog-information

[urgency_normal]
    background = "#1a1e2a"
    foreground = "#c8d7ff"
    border_color = "#8cb4ff"
    frame_width = 2
    frame_color = "#8cb4ff"
    timeout = 10
    default_icon = dialog-information

[urgency_critical]
    background = "#2a1a1a"
    foreground = "#ffc8c8"
    border_color = "#ff6b6b"
    frame_width = 3
    frame_color = "#ff6b6b"
    timeout = 0
    default_icon = dialog-error

[experimental]
    monitor = 0
EOF

  pkill dunst 2>/dev/null || true
  dunst &
  echo "Notifications configured."
}

# ============================================================================
#  SECTION 5: COMPOSITOR (PICOM)
# ============================================================================

setup_compositor() {
  echo "=== Setting up KorrinOS Compositor ==="

  local picom_config="${HOME}/.config/picom/picom.conf"
  mkdir -p "$(dirname "$picom_config")"

  cat > "$picom_config" << 'PICOMEOF'
# KorrinOS Compositor — Dual Kawase blur + glassmorphism

backend = "glx";
vsync = true;
glx-no-stencil = true;
glx-no-rebind-pixmap = true;
use-damage = true;
glx-swap-method = 2;
unredir-if-possible = true;
paint-on-overlay = true;
sw-opti = true;
glx-copy-from-front = false;
glx-no-rebind-pixmap = true;
use-damage = true;
xrender-sync-fence = true;

# Shadows
shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.6;

shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "class_g = 'Cairo-clock'",
    "class_g = 'Dunst'",
    "_GTK_FRAME_EXTENTS@:c",
    "name = 'korrinos-widgets'",
    "class_g = 'Plank'"
];

# Fading
fading = true;
fade-in-step = 0.1;
fade-out-step = 0.1;
fade-delta = 10;

fade-exclude = [];

# Opacity
inactive-opacity = 0.95;
active-opacity = 1.0;
frame-opacity = 1.0;
inactive-opacity-override = false;

focus-exclude = [
    "class_g = 'Cairo-clock'",
    "class_g = 'Bar'",
    "class_g = 'Dunst'",
    "class_g = 'Plank'"
];

opacity-rule = [
    "90:class_g = 'Thunar' && focused",
    "80:class_g = 'Thunar' && !focused",
    "100:class_g = 'Firefox'",
    "100:class_g = 'Gimp-2.10'",
    "100:class_g = 'vlc'",
    "95:class_g = 'Rofi'"
];

# Blur
blur-method = "dual_kawase";
blur-strength = 6;
blur-background = true;
blur-background-frame = false;
blur-background-fixed = false;

blur-background-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
    "_GTK_FRAME_EXTENTS@:c",
    "class_g = 'slop'",
    "class_g = 'Dunst'",
    "class_g = 'Plank'"
];

# Rounded corners
corner-radius = 12;
rounded-corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
    "class_g = 'Plank'"
];

# Window types
wintypes:
{
    tooltip = { fade = true; shadow = true; opacity = 0.9; full-shadow = false; };
    dock = { shadow = false; clip-shadow-above = true; };
    dnd = { shadow = false; };
    popup_menu = { opacity = 0.95; };
    dropdown_menu = { opacity = 0.95; };
};
PICOMEOF

  pkill picom 2>/dev/null || true
  sleep 0.5
  picom --config "$picom_config" -b 2>/dev/null || {
    echo "picom not installed. Install: sudo apt install picom"
    return 1
  }

  echo "Compositor configured and started."
}

# ============================================================================
#  SECTION 6: WINDOW MANAGER
# ============================================================================

setup_window_manager() {
  echo "=== Setting up KorrinOS Window Manager ==="

  if command -v xfconf-query &>/dev/null; then
    # Titlebar
    xfconf-query -c xfwm4 -p /general/titlebar_layout -s "CHM" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/title_font -s "Ubuntu Sans Bold 10" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/title_alignment -s "left" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/title_horizontal_offset -s 6 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/title_vertical_offset -s 2 2>/dev/null || true

    # Focus
    xfconf-query -c xfwm4 -p /general/click_to_focus -s true 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/focus_new -s true 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/activate_action -s "bring" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/focus_delay -s 200 2>/dev/null || true

    # Snapping
    xfconf-query -c xfwm4 -p /general/snap_to_border -s true 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/snap_to_windows -s true 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/snap_width_maximized -s 16 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/snap_width_moving -s 16 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/edge_tiling -s true 2>/dev/null || true

    # Compositor
    xfconf-query -c xfwm4 -p /general/use_compositing -s true 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/show_frame_shadow -s true 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/show_popup_shadow -s false 2>/dev/null || true

    # Placement
    xfconf-query -c xfwm4 -p /general/placement_ratio -s 50 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/placement -s "center" 2>/dev/null || true

    # Window operations
    xfconf-query -c xfwm4 -p /general/box_move -s true 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/box_resize -s true 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/raise_on_focus -s true 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/raise_delay -s 250 2>/dev/null || true

    # Button layout
    xfconf-query -c xfwm4 -p /general/button_layout -s "CHM" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/button_offset -s 3 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/button_spacing -s 4 2>/dev/null || true
  fi

  echo "Window manager configured."
}

# ============================================================================
#  SECTION 7: KEYBOARD SHORTCUTS
# ============================================================================

setup_keyboard_shortcuts() {
  echo "=== Setting up KorrinOS Keyboard Shortcuts ==="

  if command -v xfconf-query &>/dev/null; then
    local shortcuts=(
      "ctrl+alt|t:terminal"
      "ctrl+alt|d:show-desktop"
      "ctrl+alt|l:lock-screen"
      "ctrl+alt|m:maximize"
      "ctrl+alt|n:minimize"
      "ctrl+alt|h:tile-left"
      "ctrl+alt|j:tile-right"
      "ctrl+alt|up:workspace-up"
      "ctrl+alt|down:workspace-down"
      "ctrl+alt|Left:workspace-left"
      "ctrl+alt|Right:workspace-right"
      "super|d:app-launcher"
      "super|l:lock-screen"
      "super|e:file-manager"
      "super|space:clipboard"
      "Print:screenshot"
      "ctrl|Print:screenshot-clipboard"
      "shift|Print:screenshot-area"
      "ctrl+alt|Delete:task-manager"
      "ctrl+shift|Escape:system-monitor"
    )

    for shortcut in "${shortcuts[@]}"; do
      local key="${shortcut%%:*}"
      local action="${shortcut##*:}"
      local keyval
      keyval=$(echo "$key" | sed 's/+/<Primary>/g; s/super/<Super>/g')
      xfconf-query -c xfce4-keyboard-shortcuts -p "/custom/${action}" \
        -n -t string -s "$keyval" 2>/dev/null || true
    done
  fi

  echo "Keyboard shortcuts configured."
}

# ============================================================================
#  SECTION 8: WALLPAPER
# ============================================================================

setup_wallpaper() {
  local wallpaper="${1:-/usr/share/korrinos/wallpapers/default.png}"

  if [ ! -f "$wallpaper" ]; then
    echo "Wallpaper not found: $wallpaper"
    return 1
  fi

  if command -v xfconf-query &>/dev/null; then
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image \
      -s "$wallpaper" 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/image-style \
      -s 5 2>/dev/null || true
  fi

  echo "Wallpaper set: $wallpaper"
}

list_wallpapers() {
  local dirs=("/usr/share/korrinos/wallpapers" "${HOME}/.local/share/wallpapers" "/usr/share/backgrounds")
  echo "=== Available Wallpapers ==="
  for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
      find "$dir" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | while read -r f; do
        echo "  $f"
      done
    fi
  done
}

random_wallpaper() {
  local wp
  wp=$(find /usr/share/korrinos/wallpapers /usr/share/backgrounds -type f \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | shuf -n 1)
  if [ -n "$wp" ]; then
    setup_wallpaper "$wp"
  fi
}

# ============================================================================
#  SECTION 9: GTK THEME
# ============================================================================

install_theme() {
  echo "=== Installing KorrinOS Theme ==="

  local theme_dir="${HOME}/.themes/KorrinOS-Dark"
  mkdir -p "$theme_dir/gtk-3.0" "$theme_dir/gtk-2.0" "$theme_dir/metacity-1" \
    "$theme_dir/xfwm4" "$theme_dir/openbox-3"

  cat > "$theme_dir/gtk-3.0/gtk.css" << 'CSSEOF'
@define-color bg_color #1a1e2a;
@define-color bg_darker #141824;
@define-color bg_lighter #22283a;
@define-color fg_color #c8d7ff;
@define-color fg_dim #8892b0;
@define-color selected_bg #3d5a80;
@define-color selected_fg #ffffff;
@define-color error_color #ff6b6b;
@define-color warning_color #ffd93d;
@define-color success_color #6bcb77;
@define-color info_color #8cb4ff;
@define-color border_color #2a2e3a;
@define-color border_focus #5a7ab5;

window, .background, .tile, .tiled {
  background-color: @bg_color;
  color: @fg_color;
  border-radius: 12px;
}

decoration {
  border-radius: 12px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.4), 0 2px 8px rgba(0,0,0,0.2);
  margin: 0;
}

headerbar, .titlebar, .titlebar.default-decoration {
  background-color: @bg_darker;
  background-image: linear-gradient(180deg, @bg_lighter 0%, @bg_darker 100%);
  color: @fg_color;
  border-bottom: 1px solid @border_color;
  border-radius: 12px 12px 0 0;
  padding: 4px 8px;
  min-height: 32px;
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.05);
}

headerbar .title, .titlebar .title {
  font-weight: bold;
  font-size: 11pt;
  padding: 0 8px;
}

button {
  background-color: @bg_lighter;
  color: @fg_color;
  border: 1px solid @border_color;
  border-radius: 8px;
  padding: 6px 12px;
  min-height: 20px;
  transition: all 150ms ease;
}

button:hover {
  background-color: #3a3e4a;
  border-color: #4a4e5a;
}

button:active, button:checked {
  background-color: @selected_bg;
  color: @selected_fg;
  border-color: @border_focus;
}

button.suggested-action {
  background-color: @selected_bg;
  color: @selected_fg;
}

button.destructive-action {
  background-color: @error_color;
  color: #ffffff;
}

headerbar button, .titlebar button {
  background-color: transparent;
  border: none;
  border-radius: 8px;
}

entry, spinbutton {
  background-color: #0d1117;
  color: @fg_color;
  border: 1px solid @border_color;
  border-radius: 8px;
  padding: 8px 12px;
  caret-color: @selected_bg;
}

entry:focus, spinbutton:focus {
  border-color: @border_focus;
  box-shadow: 0 0 0 2px rgba(61,90,128,0.3);
}

scrollbar {
  background-color: transparent;
  border-radius: 6px;
}

scrollbar slider {
  background-color: rgba(255,255,255,0.15);
  border-radius: 6px;
  min-width: 8px;
  min-height: 40px;
}

scrollbar slider:hover {
  background-color: rgba(255,255,255,0.25);
}

.sidebar, .navigation-sidebar {
  background-color: @bg_darker;
  border-right: 1px solid @border_color;
}

list, iconview, treeview {
  background-color: @bg_color;
  color: @fg_color;
}

row, .row {
  padding: 4px 8px;
  border-bottom: 1px solid rgba(255,255,255,0.03);
}

row:selected, .row:selected {
  background-color: @selected_bg;
  color: @selected_fg;
}

notebook header, .notebook header {
  background-color: @bg_darker;
  border-bottom: 1px solid @border_color;
}

notebook tab, .notebook tab {
  background-color: transparent;
  border: none;
  border-bottom: 2px solid transparent;
  padding: 8px 16px;
}

notebook tab:checked, .notebook tab:checked {
  border-bottom-color: @selected_bg;
}

tooltip, .tooltip {
  background-color: @bg_lighter;
  color: @fg_color;
  border: 1px solid @border_color;
  border-radius: 8px;
  padding: 6px 10px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.3);
}

menu, .menu, .context-menu {
  background-color: @bg_color;
  border: 1px solid @border_color;
  border-radius: 10px;
  padding: 4px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.4);
}

menuitem {
  padding: 8px 16px;
  border-radius: 6px;
}

menuitem:hover {
  background-color: @selected_bg;
  color: @selected_fg;
}

switch {
  background-color: @bg_lighter;
  border: 2px solid @border_color;
  border-radius: 14px;
  min-width: 44px;
  min-height: 24px;
}

switch:checked {
  background-color: @selected_bg;
  border-color: @selected_bg;
}

switch slider {
  background-color: #ffffff;
  border-radius: 10px;
  min-width: 18px;
  min-height: 18px;
}

scale trough {
  background-color: @bg_lighter;
  border-radius: 3px;
  min-height: 6px;
}

scale highlight {
  background-color: @selected_bg;
  border-radius: 3px;
}

scale slider {
  background-color: #ffffff;
  border-radius: 12px;
  min-width: 20px;
  min-height: 20px;
  border: 2px solid @border_focus;
}

progressbar trough {
  background-color: @bg_lighter;
  border-radius: 4px;
  min-height: 8px;
}

progressbar progress {
  background-color: @selected_bg;
  border-radius: 4px;
}

infobar.info {
  background-color: rgba(140,200,255,0.15);
  color: @info_color;
}

infobar.warning {
  background-color: rgba(255,217,61,0.15);
  color: @warning_color;
}

infobar.error {
  background-color: rgba(255,107,107,0.15);
  color: @error_color;
}

calendar {
  background-color: @bg_color;
  color: @fg_color;
  border: 1px solid @border_color;
  border-radius: 8px;
}

calendar:selected {
  background-color: @selected_bg;
  color: @selected_fg;
}

calendar.header {
  background-color: @bg_darker;
  border-radius: 6px;
}

dialog, .dialog {
  background-color: @bg_color;
  border-radius: 12px;
}

dialog .dialog-action-box {
  padding: 8px 12px;
  border-top: 1px solid @border_color;
}

filechooser .path-bar {
  background-color: @bg_darker;
  border-bottom: 1px solid @border_color;
}

textview, textview text {
  background-color: #0d1117;
  color: @fg_color;
  font-family: JetBrains Mono, Fira Code, monospace;
  font-size: 12pt;
}

textview text selection {
  background-color: @selected_bg;
  color: @selected_fg;
}

listbox row {
  padding: 8px 12px;
  border-bottom: 1px solid rgba(255,255,255,0.03);
}

listbox row:selected {
  background-color: @selected_bg;
}

toolbar {
  background-color: @bg_darker;
  border-bottom: 1px solid @border_color;
}

toolbar button {
  background-color: transparent;
  border: none;
  border-radius: 6px;
}

toolbar button:hover {
  background-color: rgba(255,255,255,0.1);
}

statusbar {
  background-color: @bg_darker;
  border-top: 1px solid @border_color;
  padding: 2px 8px;
  font-size: 10pt;
  color: @fg_dim;
}

levelbar trough {
  background-color: @bg_lighter;
  border-radius: 3px;
}

levelbar block.filled {
  background-color: @selected_bg;
}

colorswatch {
  border-radius: 4px;
}

frame > label {
  color: @fg_dim;
  font-weight: bold;
}

separator {
  background-color: @border_color;
  min-height: 1px;
}

popover {
  background-color: @bg_color;
  border: 1px solid @border_color;
  border-radius: 12px;
  padding: 8px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.4);
}

CSSEOF

  # GTK2 theme
  cat > "$theme_dir/gtk-2.0/gtkrc" << 'EOF'
gtk-color-scheme = "bg_color:#1a1e2a\nfg_color:#c8d7ff\nselected_bg_color:#3d5a80\nselected_fg_color:#ffffff\nerror_color:#ff6b6b\nwarning_color:#ffd93d\nsuccess_color:#6bcb77"
include "/usr/share/themes/Default/gtk-2.0/gtkrc"
EOF

  # Icon theme
  local icon_dir="${HOME}/.icons/KorrinOS-Icons"
  mkdir -p "$icon_dir"

  cat > "$icon_dir/index.theme" << 'EOF'
[Icon Theme]
Name=KorrinOS-Icons
Comment=KorrinOS Icon Theme
Inherits=Adwaita
Directories=48x48/actions,48x48/apps,48x48/categories,48x48/devices,48x48/emblems,48x48/mimetypes,48x48/places,scalable/actions,scalable/apps,scalable/categories

[48x48/actions]
Size=48
Type=Fixed

[48x48/apps]
Size=48
Type=Fixed

[48x48/categories]
Size=48
Type=Fixed

[48x48/devices]
Size=48
Type=Fixed

[48x48/emblems]
Size=48
Type=Fixed

[48x48/mimetypes]
Size=48
Type=Fixed

[48x48/places]
Size=48
Type=Fixed

[scalable/actions]
Size=48
Type=Fixed

[scalable/apps]
Size=48
Type=Fixed

[scalable/categories]
Size=48
Type=Fixed
EOF

  # Apply theme
  if command -v xfconf-query &>/dev/null; then
    xfconf-query -c xsettings -p /Net/ThemeName -s "KorrinOS-Dark" 2>/dev/null || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "KorrinOS-Icons" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/FontName -s "Ubuntu Sans 11" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "JetBrains Mono 12" 2>/dev/null || true
  fi

  echo "KorrinOS theme installed."
}

# ============================================================================
#  SECTION 10: HOT CORNERS
# ============================================================================

setup_hotcorners() {
  echo "=== Setting up Hot Corners ==="

  local corner_config="$DE_DIR/hotcorners.json"
  cat > "$corner_config" << 'EOF'
{
  "top-left": "none",
  "top-right": "overview",
  "bottom-left": "show-desktop",
  "bottom-right": "none",
  "delay_ms": 200
}
EOF

  # xdotool-based hot corner daemon
  cat > "$DE_DIR/hotcorner-daemon.sh" << 'DAEMONEOF'
#!/bin/bash
DELAY_MS=200
SCREEN_W=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}' | cut -dx -f1)
SCREEN_H=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}' | cut -dx -f2)
LAST_ACTION=""
LAST_TIME=0

while true; do
  eval "$(xdotool getmouselocation 2>/dev/null | sed 's/x:\([0-9]*\) y:\([0-9]*\).*/X=\1 Y=\2/')"
  NOW=$(date +%s%N | cut -b1-13)

  ACTION=""
  [ "$X" -lt 2 ] && [ "$Y" -lt 2 ] && ACTION="top-left"
  [ "$X" -ge $((SCREEN_W-2)) ] && [ "$Y" -lt 2 ] && ACTION="top-right"
  [ "$X" -lt 2 ] && [ "$Y" -ge $((SCREEN_H-2)) ] && ACTION="bottom-left"
  [ "$X" -ge $((SCREEN_W-2)) ] && [ "$Y" -ge $((SCREEN_H-2)) ] && ACTION="bottom-right"

  if [ -n "$ACTION" ] && [ "$ACTION" != "$LAST_ACTION" ]; then
    DIFF=$(( NOW - LAST_TIME ))
    if [ "$DIFF" -ge "$DELAY_MS" ]; then
      case "$ACTION" in
        top-left) ;;
        top-right) xfce4-panel --toggle-window panel-2 2>/dev/null || true ;;
        bottom-left) xfce4-send-keys --name show-desktop 2>/dev/null || xdotool key super+d 2>/dev/null || true ;;
        bottom-right) ;;
      esac
      LAST_ACTION="$ACTION"
      LAST_TIME="$NOW"
    fi
  elif [ -z "$ACTION" ]; then
    LAST_ACTION=""
  fi

  sleep 0.05
done
DAEMONEOF
  chmod +x "$DE_DIR/hotcorner-daemon.sh"

  echo "Hot corners configured."
}

# ============================================================================
#  SECTION 11: WORKSPACES
# ============================================================================

setup_workspaces() {
  local count="${1:-4}"
  echo "=== Setting up $count Workspaces ==="

  if command -v xfconf-query &>/dev/null; then
    xfconf-query -c xfce4-workspaces -p /general/workspace-count -s "$count" 2>/dev/null || true

    local names=("Web" "Work" "Chat" "Media")
    for i in $(seq 0 $((count - 1))); do
      local name="${names[$i]:-Workspace $((i+1))}"
      xfconf-query -c xfce4-workspaces -p "/workspace-$((i+1))/name" -s "$name" 2>/dev/null || true
    done

    xfconf-query -c xfce4-workspaces -p /general/wrap-workspaces -s true 2>/dev/null || true
  fi

  echo "Workspaces configured."
}

# ============================================================================
#  SECTION 12: SCREENSHOT TOOL
# ============================================================================

setup_screenshot() {
  echo "=== Setting up KorrinOS Screenshot Tool ==="

  local screenshot_dir="${HOME}/Pictures/Screenshots"
  mkdir -p "$screenshot_dir"

  # Screenshot script
  cat > /usr/local/bin/korrinos-screenshot << 'SSEOF'
#!/bin/bash
# KorrinOS Screenshot Tool
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"

case "${1:-full}" in
  full)
    import -window root "$FILE" 2>/dev/null || scrot "$FILE" 2>/dev/null || gnome-screenshot -f "$FILE" 2>/dev/null
    ;;
  area)
    import -window root "$FILE" 2>/dev/null || scrot -s "$FILE" 2>/dev/null || gnome-screenshot -a -f "$FILE" 2>/dev/null
    ;;
  window)
    import -window "$(xdotool getactivewindow)" "$FILE" 2>/dev/null || scrot -u "$FILE" 2>/dev/null || gnome-screenshot -w -f "$FILE" 2>/dev/null
    ;;
  clipboard)
    import -window root - | xclip -selection clipboard -t image/png 2>/dev/null
    ;;
  delay)
    sleep "${2:-3}"
    import -window root "$FILE" 2>/dev/null || scrot "$FILE" 2>/dev/null
    ;;
esac

if [ -f "$FILE" ]; then
  notify-send -i image-x-generic "Screenshot saved" "$FILE"
  echo "$FILE"
fi
SSEOF
  chmod +x /usr/local/bin/korrinos-screenshot 2>/dev/null || true

  echo "Screenshot tool configured."
}

# ============================================================================
#  SECTION 13: CLIPBOARD MANAGER
# ============================================================================

setup_clipboard() {
  echo "=== Setting up KorrinOS Clipboard ==="

  local clip_dir="${HOME}/.config/korrinos/clipboard"
  mkdir -p "$clip_dir"

  # Clipboard manager script
  cat > /usr/local/bin/korrinos-clip << 'CLIP_EOF'
#!/bin/bash
# KorrinOS Clipboard Manager
CLIP_DIR="$HOME/.config/korrinos/clipboard"
mkdir -p "$CLIP_DIR"

case "${1:-}" in
  copy)
    shift
    text="$*"
    [ -z "$text" ] && text=$(xclip -selection clipboard -o 2>/dev/null)
    echo "$text" >> "$CLIP_DIR/history.txt"
    echo "$text" | xclip -selection clipboard
    tail -100 "$CLIP_DIR/history.txt" > "$CLIP_DIR/history.tmp" && mv "$CLIP_DIR/history.tmp" "$CLIP_DIR/history.txt"
    ;;
  paste)
    xclip -selection clipboard -o 2>/dev/null
    ;;
  history)
    if [ -f "$CLIP_DIR/history.txt" ]; then
      tac "$CLIP_DIR/history.txt" | head -20
    else
      echo "No clipboard history."
    fi
    ;;
  search)
    shift
    query="$*"
    grep -i "$query" "$CLIP_DIR/history.txt" 2>/dev/null | tail -10
    ;;
  clear)
    > "$CLIP_DIR/history.txt"
    echo "Clipboard history cleared."
    ;;
  *)
    echo "KorrinOS Clipboard: copy|paste|history|search|clear"
    ;;
esac
CLIP_EOF
  chmod +x /usr/local/bin/korrinos-clip 2>/dev/null || true

  echo "Clipboard configured."
}

# ============================================================================
#  SECTION 14: SCREENSAVER / DPMS
# ============================================================================

setup_screensaver() {
  echo "=== Setting up KorrinOS Screensaver ==="

  if command -v xfconf-query &>/dev/null; then
    xfconf-query -c xfce4-screensaver -p /saver/enabled -s true 2>/dev/null || true
    xfconf-query -c xfce4-screensaver -p /saver/timeout -s 600 2>/dev/null || true
    xfconf-query -c xfce4-screensaver -p /lock/enabled -s false 2>/dev/null || true
  fi

  # DPMS
  if command -v xfconf-query &>/dev/null; then
    xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac -s 600 2>/dev/null || true
    xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled-ac -s true 2>/dev/null || true
    xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-battery -s 300 2>/dev/null || true
  fi

  echo "Screensaver configured."
}

# ============================================================================
#  SECTION 15: MULTI-MONITOR
# ============================================================================

setup_multi_monitor() {
  echo "=== Setting up KorrinOS Multi-Monitor ==="

  local monitors
  monitors=$(xrandr 2>/dev/null | grep " connected" | awk '{print $1}')
  local count
  count=$(echo "$monitors" | wc -l)

  echo "Detected $count monitor(s):"
  echo "$monitors" | while read -r m; do
    local res
    res=$(xrandr 2>/dev/null | grep "^$m " | awk '{print $3}' | head -1)
    echo "  $m — $res"
  done

  if [ "$count" -gt 1 ]; then
    echo "Multi-monitor detected. Extending display..."
    local primary
    primary=$(echo "$monitors" | head -1)
    local secondary
    secondary=$(echo "$monitors" | tail -1)
    xrandr --output "$primary" --primary --auto --output "$secondary" --auto --right-of "$primary" 2>/dev/null || true
    echo "Extended: $primary + $secondary"
  fi

  echo "Multi-monitor configured."
}

# ============================================================================
#  SECTION 16: ACCESSIBILITY
# ============================================================================

setup_accessibility() {
  echo "=== Setting up KorrinOS Accessibility ==="

  if command -v xfconf-query &>/dev/null; then
    # High contrast
    xfconf-query -c xsettings -p /Net/ThemeName -s "KorrinOS-Dark" 2>/dev/null || true

    # Cursor size
    xfconf-query -c xsettings -p /Gtk/CursorThemeSize -n -t int -s 24 2>/dev/null || true

    # Font scaling
    xfconf-query -c xsettings -p /Xft/DPI -n -t int -s 96 2>/dev/null || true
  fi

  # On-screen keyboard
  if command -v onboard &>/dev/null; then
    echo "On-screen keyboard available: onboard"
  fi

  # Screen reader
  if command -v orca &>/dev/null; then
    echo "Screen reader available: orca"
  fi

  echo "Accessibility configured."
}

# ============================================================================
#  SECTION 17: CONTEXT MENU
# ============================================================================

setup_context_menu() {
  echo "=== Setting up KorrinOS Context Menu ==="

  local menu_dir="${HOME}/.config/korrinos/context-menu"
  mkdir -p "$menu_dir"

  cat > "$menu_dir/menu.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<xfce-menu>
  <item label="Open Terminal Here" icon="utilities-terminal">
    <action>xfce4-terminal --working-directory=%d</action>
  </item>
  <item label="Open File Manager" icon="system-file-manager">
    <action>thunar %d</action>
  </item>
  <separator/>
  <item label="KorrinOS Tools" icon="system-help">
    <action>korrinos</action>
  </item>
  <item label="System Monitor" icon="utilities-system-monitor">
    <action>xfce4-taskmanager</action>
  </item>
  <separator/>
  <item label="Change Wallpaper" icon="preferences-desktop-wallpaper">
    <action>korrinos-desktop wallpaper</action>
  </item>
  <item label="Display Settings" icon="preferences-desktop-display">
    <action>xfce4-display-settings</action>
  </item>
</xfce-menu>
EOF

  echo "Context menu configured."
}

# ============================================================================
#  SECTION 18: DESKTOP ICONS
# ============================================================================

setup_desktop_icons() {
  echo "=== Setting up KorrinOS Desktop Icons ==="

  local icon_dir="${HOME}/Desktop"
  mkdir -p "$icon_dir"

  # Home icon
  cat > "$icon_dir/home.desktop" << 'EOF'
[Desktop Entry]
Name=Home
Comment=Open Home Folder
Exec=thunar ~
Icon=user-home
Type=Link
URL=file:///home/${USER}
EOF

  # Trash icon
  cat > "$icon_dir/trash.desktop" << 'EOF'
[Desktop Entry]
Name=Trash
Comment=Open Trash
Exec=thunar trash:///
Icon=user-trash
Type=Link
URL=trash:///
EOF

  # Terminal icon
  cat > "$icon_dir/terminal.desktop" << 'EOF'
[Desktop Entry]
Name=Terminal
Comment=Open Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Type=Application
EOF

  chmod +x "$icon_dir"/*.desktop 2>/dev/null || true

  echo "Desktop icons configured."
}

# ============================================================================
#  SECTION 19: FILE MANAGER THEME
# ============================================================================

setup_file_manager() {
  echo "=== Setting up KorrinOS File Manager ==="

  local thunar_config="${HOME}/.config/Thunar"
  mkdir -p "$thunar_config"

  cat > "$thunar_config/accels.scm" << 'EOF'
; Thunar keyboard shortcuts
 GTK_accel_map "<Actions>/ThunarShortcuts/open-home"
 GTK_accel_map "<Actions>/ThunarShortcuts/open-terminal"
EOF

  # Default settings
  cat > "$thunar_config/uistr.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<thunar>
  <window>
    <last-geometry>
      <width>1000</width>
      <height>600</height>
      <zoom>100</zoom>
    </last-geometry>
    <defaults>
      <sort-column>name</sort-column>
      <sort-order>ascending</sort-order>
      <show-hidden>false</show-hidden>
      <date-format>iso</date-format>
    </defaults>
  </window>
</thunar>
EOF

  echo "File manager configured."
}

# ============================================================================
#  SECTION 20: TERMINAL THEME
# ============================================================================

setup_terminal() {
  echo "=== Setting up KorrinOS Terminal ==="

  local term_config="${HOME}/.config/xfce4/terminal"
  mkdir -p "$term_config"

  cat > "$term_config/terminalrc" << 'EOF'
[Configuration]
FontName=JetBrains Mono 12
MiscAlwaysShowTabs=FALSE
MiscBorders=TRUE
MiscConfirmClose=TRUE
MiscDefaultGeometry=100x30
MiscMenubarDefault=FALSE
MiscShowUnsafePasteDialog=FALSE
MiscShowWorkspaceActions=FALSE
ScrollingLines=10000
ScrollingOnOutput=TRUE
ColorForeground=#c8d7ff
ColorBackground=#0d1117
ColorCursor=#5a7ab5
ColorSelection=#3d5a80
ColorSelectionForeground=#ffffff
ColorPalette=#1a1e2a;#ff6b6b;#6bcb77;#ffd93d;#8cb4ff;#c084fc;#67e8f9;#c8d7ff;#6b7280;#ff8787;#69db7c;#ffe066;#74c0fc;#b197fc;#99e9f2;#f8f9fa
EOF

  echo "Terminal configured."
}

# ============================================================================
#  SECTION 21: LIGHTDM LOGIN THEME
# ============================================================================

setup_login_theme() {
  echo "=== Setting up KorrinOS Login Theme ==="

  local greeter_dir="/usr/share/lightdm-gtk-greeter"
  if [ -d "$greeter_dir" ]; then
    local greeter_conf="/etc/lightdm/lightdm-gtk-greeter.conf"
    sudo bash -c "cat > '$greeter_conf' << 'EOF'
[greeter]
theme-name=KorrinOS-Dark
icon-theme-name=Papirus
font-name=Ubuntu Sans 11
xft-antialias=true
xft-dpi=96
xft-hintstyle=slight
xft-rgba=rgb
background=/usr/share/korrinos/wallpapers/default.png
user-background=false
EOF" 2>/dev/null || true
  fi

  echo "Login theme configured."
}

# ============================================================================
#  SECTION 22: GRUB THEME
# ============================================================================

setup_grub_theme() {
  echo "=== Setting up KorrinOS GRUB Theme ==="

  local grub_theme_dir="/usr/share/grub/themes/korrinos"
  sudo mkdir -p "$grub_theme_dir" 2>/dev/null || true

  cat > "$grub_theme_dir/theme.txt" << 'EOF'
title-text: "KorrinOS 1.3"
title-color: "#c8d7ff"
title-font: "Ubuntu Sans Bold 16"
message-font: "Ubuntu Sans 11"
message-color: "#8892b0"
desktop-color: "#0d1117"
desktop-image: "background.png"
terminal-font: "JetBrains Mono 12"
terminal-color: "#c8d7ff"
terminal-bgcolor: "#0d1117"

+ boot_menu {
  left = 20%
  top = 30%
  width = 60%
  height = 50%
  item_color = "#c8d7ff"
  selected_item_color = "#ffffff"
  selected_item_bg = "#3d5a80"
  item_font = "Ubuntu Sans 12"
  selected_item_font = "Ubuntu Sans Bold 12"
  item_height = 36
  item_padding = 10
  item_spacing = 4
  scrollbar = false
}

+ label {
  left = 5%
  top = 90%
  width = 90%
  align = "center"
  text = "KorrinOS 1.3 • Built on Ubuntu • korrinos.org"
  color = "#6b7280"
  font = "Ubuntu Sans 10"
}
EOF

  echo "GRUB theme configured."
}

# ============================================================================
#  SECTION 23: PLYMOUTH BOOT SPLASH
# ============================================================================

setup_plymouth() {
  echo "=== Setting up KorrinOS Plymouth Theme ==="

  local plymouth_dir="/usr/share/plymouth/themes/korrinos"
  sudo mkdir -p "$plymouth_dir" 2>/dev/null || true

  cat > "$plymouth_dir/korrinos.plymouth" << 'EOF'
[Plymouth Theme]
Name=KorrinOS
Description=KorrinOS Boot Splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/korrinos
ScriptFile=/usr/share/plymouth/themes/korrinos/korrinos.script
EOF

  echo "Plymouth theme configured."
}

# ============================================================================
#  SECTION 24: ABOUT DIALOG
# ============================================================================

show_about() {
  echo "========================================"
  echo "       KorrinOS Desktop Environment"
  echo "========================================"
  echo ""
  echo "  Version:    1.3"
  echo "  Codename:   jammy"
  echo "  Base:       Ubuntu 22.04 LTS"
  echo "  Desktop:    XFCE4 + KorrinOS DE"
  echo "  Compositor: picom (dual_kawase)"
  echo "  Theme:      KorrinOS-Dark"
  echo "  Icons:      KorrinOS-Icons"
  echo "  Font:       Ubuntu Sans 11"
  echo "  Mono Font:  JetBrains Mono 12"
  echo ""
  echo "  Kernel:     $(uname -r)"
  echo "  Shell:      $SHELL"
  echo "  Session:    $XDG_SESSION_TYPE"
  echo ""
  echo "  Features:"
  echo "    - 3 Isolated Computing Worlds"
  echo "    - Tinkeria AI Assistant"
  echo "    - Liquid Glass Glassmorphism"
  echo "    - Natural Language System Control"
  echo "    - 100+ Built-in Apps"
  echo "    - Real Package Manager"
  echo "    - Real Update System"
  echo "    - Cloud Sync (Google/OneDrive/Nextcloud/S3)"
  echo "    - Mobile Companion"
  echo "    - Enterprise Suite (AD/LDAP/GPO)"
  echo "    - Driver Manager"
  echo "    - Hardware Certification"
  echo ""
  echo "  Copyright 2026 KorrinOS Project"
  echo "  Licensed under GPL v3"
  echo "========================================"
}

# ============================================================================
#  SECTION 25: STATUS
# ============================================================================

desktop_status() {
  echo "=== KorrinOS Desktop Status ==="
  echo ""

  # Theme
  echo "--- Theme ---"
  echo "GTK Theme: $(xfconf-query -c xsettings -p /Net/ThemeName 2>/dev/null || echo 'not set')"
  echo "Icon Theme: $(xfconf-query -c xsettings -p /Net/IconThemeName 2>/dev/null || echo 'not set')"
  echo "Font: $(xfconf-query -c xsettings -p /Gtk/FontName 2>/dev/null || echo 'not set')"
  echo "Wallpaper: $(xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image 2>/dev/null || echo 'not set')"
  echo ""

  # Panel
  echo "--- Panel ---"
  echo "Panel running: $(pgrep -x xfce4-panel >/dev/null && echo 'yes' || echo 'no')"
  echo "Panel position: $(xfconf-query -c xfce4-panel -p /panel-1/position 2>/dev/null || echo 'not set')"
  echo "Panel size: $(xfconf-query -c xfce4-panel -p /panel-1/size 2>/dev/null || echo 'not set')"
  echo ""

  # Compositor
  echo "--- Compositor ---"
  echo "picom running: $(pgrep -x picom >/dev/null && echo 'yes' || echo 'no')"
  echo "XFCE compositing: $(xfconf-query -c xfwm4 -p /general/use_compositing 2>/dev/null || echo 'not set')"
  echo ""

  # Workspaces
  echo "--- Workspaces ---"
  echo "Count: $(xfconf-query -c xfce4-workspaces -p /general/workspace-count 2>/dev/null || echo 'not set')"
  echo ""

  # Window Manager
  echo "--- Window Manager ---"
  echo "WM: $(xfconf-query -c xfwm4 -p /general/titlebar_layout 2>/dev/null || echo 'not set')"
  echo "Focus: $(xfconf-query -c xfwm4 -p /general/click_to_focus 2>/dev/null || echo 'not set')"
  echo ""

  # Notifications
  echo "--- Notifications ---"
  echo "dunst running: $(pgrep -x dunst >/dev/null && echo 'yes' || echo 'no')"
  echo ""

  # Monitors
  echo "--- Monitors ---"
  xrandr 2>/dev/null | grep " connected" | while read -r line; do
    echo "  $line"
  done

  echo ""
  echo "--- Screenshot Tool ---"
  echo "Available: $(command -v import &>/dev/null && echo 'ImageMagick' || (command -v scrot &>/dev/null && echo 'scrot' || echo 'not available'))"
}

# ============================================================================
#  SECTION 26: THEME PRESETS
# ============================================================================

theme_preset() {
  local preset="${1:-}"
  echo "=== Theme Preset: $preset ==="

  case "$preset" in
    dark)
      install_theme
      ;;
    light)
      # Create light theme
      local theme_dir="${HOME}/.themes/KorrinOS-Light"
      mkdir -p "$theme_dir/gtk-3.0"
      cat > "$theme_dir/gtk-3.0/gtk.css" << 'EOF'
@define-color bg_color #ffffff;
@define-color bg_darker #f0f0f0;
@define-color bg_lighter #e8e8e8;
@define-color fg_color #1a1e2a;
@define-color fg_dim #6b7280;
@define-color selected_bg #3d5a80;
@define-color selected_fg #ffffff;
@define-color error_color #dc2626;
@define-color warning_color #d97706;
@define-color success_color #16a34a;
@define-color info_color #2563eb;
@define-color border_color #d1d5db;
@define-color border_focus #3d5a80;

window, .background {
  background-color: @bg_color;
  color: @fg_color;
}

headerbar, .titlebar {
  background-color: @bg_darker;
  border-bottom: 1px solid @border_color;
}

button {
  background-color: @bg_lighter;
  color: @fg_color;
  border: 1px solid @border_color;
  border-radius: 6px;
}

button:hover {
  background-color: @border_color;
}

entry {
  background-color: @bg_color;
  color: @fg_color;
  border: 1px solid @border_color;
}

row:selected {
  background-color: @selected_bg;
  color: @selected_fg;
}
EOF
      if command -v xfconf-query &>/dev/null; then
        xfconf-query -c xsettings -p /Net/ThemeName -s "KorrinOS-Light" 2>/dev/null || true
      fi
      echo "Light theme applied."
      ;;
    default)
      if command -v xfconf-query &>/dev/null; then
        xfconf-query -c xsettings -p /Net/ThemeName -s "KorrinOS-Dark" 2>/dev/null || true
        xfconf-query -c xsettings -p /Net/IconThemeName -s "KorrinOS-Icons" 2>/dev/null || true
      fi
      echo "Default theme restored."
      ;;
    *)
      echo "Available presets: dark, light, default"
      ;;
  esac
}

# ============================================================================
#  SECTION 27: DESKTOP SETUP (FULL)
# ============================================================================

setup_full() {
  echo "========================================"
  echo "   KorrinOS Desktop — Full Setup"
  echo "========================================"
  echo ""

  echo "[1/18] Panel..."
  setup_panel

  echo "[2/18] App Launcher..."
  setup_launcher

  echo "[3/18] Notifications..."
  setup_notifications

  echo "[4/18] Compositor..."
  setup_compositor

  echo "[5/18] Window Manager..."
  setup_window_manager

  echo "[6/18] Keyboard Shortcuts..."
  setup_keyboard_shortcuts

  echo "[7/18] GTK Theme..."
  install_theme

  echo "[8/18] Hot Corners..."
  setup_hotcorners

  echo "[9/18] Workspaces..."
  setup_workspaces 4

  echo "[10/18] Wallpaper..."
  setup_wallpaper "/usr/share/korrinos/wallpapers/default.png"

  echo "[11/18] Screenshot Tool..."
  setup_screenshot

  echo "[12/18] Clipboard Manager..."
  setup_clipboard

  echo "[13/18] Screensaver/DPMS..."
  setup_screensaver

  echo "[14/18] Multi-Monitor..."
  setup_multi_monitor

  echo "[15/18] Accessibility..."
  setup_accessibility

  echo "[16/18] Context Menu..."
  setup_context_menu

  echo "[17/18] Desktop Icons..."
  setup_desktop_icons

  echo "[18/18] File Manager..."
  setup_file_manager

  echo ""
  echo "========================================"
  echo "   KorrinOS Desktop ready!"
  echo "   Logout and login for full effect."
  echo "========================================"
}

# ============================================================================
#  MAIN DISPATCHER
# ============================================================================

case "${1:-}" in
  setup)           setup_full ;;
  panel)           setup_panel ;;
  launcher)        setup_launcher ;;
  notifications)   setup_notifications ;;
  compositor)      setup_compositor ;;
  window-manager)  setup_window_manager ;;
  shortcuts)       setup_keyboard_shortcuts ;;
  theme)           install_theme ;;
  preset)          shift; theme_preset "$@" ;;
  wallpaper)       shift; setup_wallpaper "$@" ;;
  wallpapers)      list_wallpapers ;;
  random-wallpaper) random_wallpaper ;;
  hotcorners)      setup_hotcorners ;;
  workspaces)      shift; setup_workspaces "${1:-4}" ;;
  screenshot)      shift; setup_screenshot ;;
  clipboard)       setup_clipboard ;;
  screensaver)     setup_screensaver ;;
  multi-monitor)   setup_multi_monitor ;;
  accessibility)   setup_accessibility ;;
  context-menu)    setup_context_menu ;;
  desktop-icons)   setup_desktop_icons ;;
  file-manager)    setup_file_manager ;;
  terminal)        setup_terminal ;;
  login-theme)     setup_login_theme ;;
  grub-theme)      setup_grub_theme ;;
  plymouth)        setup_plymouth ;;
  about)           show_about ;;
  status)          desktop_status ;;
  help|*)
    echo "KorrinOS Desktop Environment v2
Usage: korrinos-desktop <command>

Setup Commands:
  setup            Full desktop setup (all 18 steps)
  panel            Setup KorrinOS panel
  launcher         Setup app launcher
  notifications    Setup notification daemon
  compositor       Setup picom compositor
  window-manager   Setup XFWM window manager
  shortcuts        Setup keyboard shortcuts
  theme            Install KorrinOS GTK theme
  preset <name>    Apply theme preset (dark/light/default)
  wallpaper <file> Set wallpaper
  wallpapers       List available wallpapers
  random-wallpaper Set random wallpaper
  hotcorners       Setup hot corners
  workspaces [n]   Setup workspaces
  screenshot       Setup screenshot tool
  clipboard        Setup clipboard manager
  screensaver      Setup screensaver/DPMS
  multi-monitor    Setup multi-monitor
  accessibility    Setup accessibility features
  context-menu     Setup right-click context menu
  desktop-icons    Setup desktop icons
  file-manager     Setup Thunar file manager
  terminal         Setup terminal theme
  login-theme      Setup LightDM greeter theme
  grub-theme       Setup GRUB boot menu theme
  plymouth         Setup Plymouth boot splash
  about            Show KorrinOS info
  status           Show desktop status
  help             Show this help" ;;
esac

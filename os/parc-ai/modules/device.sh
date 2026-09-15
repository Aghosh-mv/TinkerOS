#!/usr/bin/env bash
# device.sh — device control, smart home, media playback, app launching

# Open/launch an application
ai_device_open() {
  local app="$1"
  case "${app,,}" in
    browser|firefox|chrome|chromium|brave|vivaldi)
      local browsers=("brave-browser" "vivaldi" "chromium-browser" "google-chrome" "firefox")
      for b in "${browsers[@]}"; do
        if command -v "$b" &>/dev/null || dpkg -l | grep -q "$b" 2>/dev/null; then
          nohup "$b" &>/dev/null & echo "Opened: $b"; return 0
        fi
      done
      echo "No browser found"
      ;;
    terminal|term|konsole|alacritty|kitty|wezterm)
      local terms=("alacritty" "kitty" "wezterm" "konsole" "gnome-terminal")
      for t in "${terms[@]}"; do
        if command -v "$t" &>/dev/null; then
          nohup "$t" &>/dev/null & echo "Opened: $t"; return 0
        fi
      done
      echo "No terminal found"
      ;;
    editor|code|vscode|vim|nano|emacs)
      local editors=("code" "codium" "vim" "nano" "emacs")
      for e in "${editors[@]}"; do
        if command -v "$e" &>/dev/null; then
          nohup "$e" &>/dev/null & echo "Opened: $e"; return 0
        fi
      done
      echo "No editor found"
      ;;
    files|nautilus|dolphin|thunar|pcmanfm)
      local fms=("nautilus" "dolphin" "thunar" "pcmanfm" "nemo")
      for f in "${fms[@]}"; do
        if command -v "$f" &>/dev/null; then
          nohup "$f" &>/dev/null & echo "Opened: $f"; return 0
        fi
      done
      echo "No file manager found"
      ;;
    calculator|calc)
      nohup gnome-calculator &>/dev/null || nohup qalculate-gtk &>/dev/null || echo "No calculator found"
      ;;
    settings|preferences)
      nohup gnome-control-center &>/dev/null || nohup xfce4-settings-manager &>/dev/null || echo "No settings found"
      ;;
    spotify|music|player)
      nohup spotify &>/dev/null || nohup rhythmbox &>/dev/null || nohup vlc &>/dev/null || echo "No music player found"
      ;;
    mail|email|thunderbird)
      nohup thunderbird &>/dev/null || echo "No email client found"
      ;;
    *)
      # Try direct command
      if command -v "$app" &>/dev/null; then
        nohup "$app" &>/dev/null & echo "Opened: $app"
      elif xdg_open --help &>/dev/null 2>&1; then
        xdg-open "$app" &>/dev/null & echo "Opened: $app (via xdg-open)"
      else
        echo "App not found: $app"
        echo "Installed apps:"
        compgen -c 2>/dev/null | sort -u | head -30
      fi
      ;;
  esac
}

# Media playback control
ai_device_media() {
  local action="$1" target="${2:-}"
  case "$action" in
    play|resume)
      playerctl play 2>/dev/null && echo "Playing" || echo "No player active"
      ;;
    pause|stop)
      playerctl pause 2>/dev/null && echo "Paused" || echo "No player active"
      ;;
    next)
      playerctl next 2>/dev/null && echo "Next track" || echo "No player active"
      ;;
    prev|previous)
      playerctl previous 2>/dev/null && echo "Previous track" || echo "No player active"
      ;;
    volume)
      if [ -n "$target" ]; then
        pactl set-sink-volume @DEFAULT_SINK@ "${target}%" 2>/dev/null && echo "Volume: ${target}%"
      else
        pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -1
      fi
      ;;
    mute)
      pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null && echo "Toggled mute"
      ;;
    status)
      playerctl status 2>/dev/null || echo "No player"
      playerctl metadata 2>/dev/null | head -5 || true
      ;;
    *)
      echo "Usage: media play|pause|next|prev|volume|mute|status"
      ;;
  esac
}

# System settings
ai_device_settings() {
  local setting="$1" value="${2:-}"
  case "$setting" in
    wifi|wi-fi)
      if [ "$value" = "on" ] || [ "$value" = "enable" ]; then
        nmcli radio wifi on 2>/dev/null && echo "WiFi: ON"
      elif [ "$value" = "off" ] || [ "$value" = "disable" ]; then
        nmcli radio wifi off 2>/dev/null && echo "WiFi: OFF"
      else
        nmcli radio wifi 2>/dev/null || echo "WiFi status unknown"
      fi
      ;;
    bluetooth)
      if [ "$value" = "on" ] || [ "$value" = "enable" ]; then
        bluetoothctl power on 2>/dev/null && echo "Bluetooth: ON"
      elif [ "$value" = "off" ] || [ "$value" = "disable" ]; then
        bluetoothctl power off 2>/dev/null && echo "Bluetooth: OFF"
      else
        bluetoothctl show 2>/dev/null | grep Powered || echo "Bluetooth status unknown"
      fi
      ;;
    brightness)
      if [ -n "$value" ]; then
        echo "$value" | tee /sys/class/backlight/*/brightness 2>/dev/null && echo "Brightness: $value"
      else
        cat /sys/class/backlight/*/brightness 2>/dev/null || echo "Unknown"
      fi
      ;;
    darkmode|dark-mode)
      if [ "$value" = "on" ]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null && echo "Dark mode: ON"
      elif [ "$value" = "off" ]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null && echo "Dark mode: OFF"
      else
        gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "Unknown"
      fi
      ;;
    *)
      echo "Settings: wifi|bluetooth|brightness|darkmode [on|off|value]"
      ;;
  esac
}

# List installed apps
ai_device_apps() {
  echo "=== Installed Applications ==="
  if [ -d /usr/share/applications ]; then
    for f in /usr/share/applications/*.desktop; do
      [ -f "$f" ] || continue
      local name=$(grep "^Name=" "$f" | head -1 | cut -d= -f2)
      local exec=$(grep "^Exec=" "$f" | head -1 | cut -d= -f2 | awk '{print $1}')
      [ -n "$name" ] && echo "  $name ($exec)"
    done | sort | head -50
  fi
  echo ""
  echo "=== Command-line tools ==="
  compgen -c 2>/dev/null | sort -u | head -50
}

# Screenshot
ai_device_screenshot() {
  local output="${1:-/tmp/screenshot-$(date +%s).png}"
  if command -v gnome-screenshot &>/dev/null; then
    gnome-screenshot -f "$output" 2>/dev/null
  elif command -v scrot &>/dev/null; then
    scrot "$output" 2>/dev/null
  elif command -v maim &>/dev/null; then
    maim "$output" 2>/dev/null
  elif command -v spectacle &>/dev/null; then
    spectacle -b -o "$output" 2>/dev/null
  else
    echo "No screenshot tool found. Install: sudo apt install scrot"
    return 1
  fi
  echo "Screenshot saved: $output"
}

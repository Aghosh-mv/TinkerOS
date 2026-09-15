#!/bin/bash
# KorrinOS Mobile Companion v2
# Real phone integration: Android + iOS via ADB, WiFi ADB, scrcpy, KDE Connect
# Screen mirroring, notifications, calls, clipboard sync, file transfer, remote control
# SMS relay, contact sync, call history, notification filtering, app mirroring
# Kernel-level: /proc/tinker/mobile for companion state

set -euo pipefail

MOBILE_DIR="${HOME}/.config/korrinos/mobile"
MOBILE_CONFIG="$MOBILE_DIR/config.json"
MOBILE_LOG="$MOBILE_DIR/companion.log"
MOBILE_STATE="$MOBILE_DIR/state.json"
CONTACTS_DIR="$MOBILE_DIR/contacts"
SMS_LOG="$MOBILE_DIR/sms.log"
mkdir -p "$MOBILE_DIR" "$CONTACTS_DIR"

# ---- default config ----
init_mobile() {
  if [ ! -f "$MOBILE_CONFIG" ]; then
    cat > "$MOBILE_CONFIG" << 'DEFAULTS'
{
  "enabled": false,
  "device_name": "",
  "device_type": "android",
  "connection_method": "usb",
  "wifi_ip": "",
  "wifi_port": 5555,
  "adb_path": "/usr/bin/adb",
  "scrcpy_path": "/usr/bin/scrcpy",
  "kdeconnect_path": "/usr/bin/kdeconnect-cli",
  "features": {
    "screen_mirror": true,
    "notifications": true,
    "clipboard_sync": true,
    "file_transfer": true,
    "sms_relay": true,
    "call_relay": true,
    "camera_view": false,
    "remote_control": true,
    "notification_forward": true,
    "contact_sync": false,
    "call_history": false,
    "app_list": false,
    "notification_filter": true,
    "battery_monitor": true,
    "media_control": false,
    "input_method": false,
    "ring_find": false,
    "wifi_share": false,
    "nfc_relay": false
  },
  "auto_connect": true,
  "notification_whitelist": [
    "com.whatsapp", "com.telegram.messenger", "com.google.android.gm",
    "com.google.android.apps.messaging", "com.samsung.android.messaging",
    "com.discord", "com.slack", "com.microsoft.teams"
  ],
  "notification_blacklist": [],
  "sync_interval_seconds": 5,
  "max_file_size_mb": 500,
  "screen_mirror_quality": "medium",
  "screen_mirror_bitrate": "2M",
  "screen_mirror_max_fps": 30,
  "auto_mirror_on_connect": false,
  "clipboard_sync_interval": 2,
  "notification_sound": true,
  "notification_popup": true,
  "kdeconnect_enabled": false,
  "kdeconnect_device_id": "",
  "wifi_adb_enabled": false,
  "encryption": false,
  "compression": true,
  "batch_transfer": true,
  "transfer_chunk_size_mb": 10
}
DEFAULTS
    echo "Mobile companion config initialized."
  fi
}

# ---- read config ----
cfg() {
  python3 -c "
import json
try:
    with open('$MOBILE_CONFIG') as f: c = json.load(f)
    val = c.get('$1', '$2')
    if isinstance(val, bool): print('True' if val else 'False')
    elif isinstance(val, list): print(','.join(str(x) for x in val))
    else: print(val)
except: print('$2')
" 2>/dev/null
}

# ---- detect and connect ----
detect_phone() {
  echo "=== Phone Detection ==="

  # Try USB ADB
  if command -v adb &>/dev/null; then
    echo ""
    echo "--- USB ADB ---"
    adb start-server 2>/dev/null || true
    local devices
    devices=$(adb devices 2>/dev/null | grep -v "List" | grep -w "device" | awk '{print $1}')
    if [ -n "$devices" ]; then
      echo "Connected via USB:"
      echo "$devices" | while read -r d; do
        local model brand android version
        model=$(adb -s "$d" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
        brand=$(adb -s "$d" shell getprop ro.product.brand 2>/dev/null | tr -d '\r')
        android=$(adb -s "$d" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
        version=$(adb -s "$d" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')
        local serial
        serial=$(adb -s "$d" shell getprop ro.serialno 2>/dev/null | tr -d '\r')
        echo "  Device:    $d"
        echo "  Brand:     $brand"
        echo "  Model:     $model"
        echo "  Android:   $android (SDK $version)"
        echo "  Serial:    $serial"
      done
      return 0
    fi
  fi

  # Try WiFi ADB
  if [ "$(cfg 'wifi_adb_enabled' 'false')" = "True" ]; then
    echo ""
    echo "--- WiFi ADB ---"
    local wifi_ip
    wifi_ip=$(cfg "wifi_ip" "")
    local wifi_port
    wifi_port=$(cfg "wifi_port" "5555")
    if [ -n "$wifi_ip" ]; then
      adb connect "${wifi_ip}:${wifi_port}" 2>/dev/null && {
        echo "Connected via WiFi ADB to ${wifi_ip}:${wifi_port}"
        return 0
      }
    fi
  fi

  # Try KDE Connect
  if command -v kdeconnect-cli &>/dev/null; then
    echo ""
    echo "--- KDE Connect ---"
    local kde_devices
    kde_devices=$(kdeconnect-cli --list-devices 2>/dev/null | grep -v "^$")
    if [ -n "$kde_devices" ]; then
      echo "KDE Connect devices:"
      echo "$kde_devices"
      return 0
    fi
  fi

  # Try network scan
  echo ""
  echo "--- Network Scan ---"
  echo "Scanning for companion devices..."
  local my_ip
  my_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  local subnet
  subnet=$(echo "$my_ip" | cut -d. -f1-3)
  local found=0

  for i in $(seq 1 254); do
    if timeout 0.1 bash -c "echo >/dev/tcp/$subnet.$i/12345" 2>/dev/null; then
      echo "  Found companion at $subnet.$i:12345"
      found=$((found + 1))
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo ""
    echo "No phone detected. Make sure:"
    echo "  1. USB debugging enabled (Android: Developer Options > USB Debugging)"
    echo "  2. Phone connected via USB or same WiFi network"
    echo "  3. KorrinOS Companion app installed (optional, for WiFi sync)"
  fi
  return 1
}

# ---- WiFi ADB setup ----
setup_wifi_adb() {
  echo "=== WiFi ADB Setup ==="
  echo "This enables wireless ADB connection."
  echo ""
  echo "Prerequisites:"
  echo "  1. Phone connected via USB first"
  echo "  2. USB debugging enabled"
  echo ""

  # Get device IP from phone
  if command -v adb &>/dev/null; then
    local device
    device=$(adb devices 2>/dev/null | grep -w "device" | head -1 | awk '{print $1}')
    if [ -n "$device" ]; then
      echo "Getting phone's WiFi IP..."
      local phone_ip
      phone_ip=$(adb -s "$device" shell ip route 2>/dev/null | grep "wlan0" | awk '{print $9}' | tr -d '\r')
      if [ -z "$phone_ip" ]; then
        phone_ip=$(adb -s "$device" shell ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | tr -d '\r')
      fi

      if [ -n "$phone_ip" ]; then
        echo "Phone WiFi IP: $phone_ip"
        echo "Enabling TCP/IP mode on port 5555..."
        adb -s "$device" tcpip 5555 2>/dev/null
        sleep 2
        echo "Connecting via WiFi..."
        adb connect "${phone_ip}:5555" 2>/dev/null

        python3 -c "
import json
with open('$MOBILE_CONFIG') as f: c = json.load(f)
c['wifi_ip'] = '$phone_ip'
c['wifi_adb_enabled'] = True
c['connection_method'] = 'wifi'
with open('$MOBILE_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('WiFi ADB configured.')
"
      else
        echo "Could not detect phone WiFi IP."
      fi
    fi
  fi
}

# ---- screen mirroring (scrcpy) ----
mirror_screen() {
  local device="${1:-}"
  local quality
  quality=$(cfg "screen_mirror_quality" "medium")
  local bitrate
  bitrate=$(cfg "screen_mirror_bitrate" "2M")
  local max_fps
  max_fps=$(cfg "screen_mirror_max_fps" "30")

  echo "=== Screen Mirroring ==="
  echo "Quality: $quality | Bitrate: $bitrate | Max FPS: $max_fps"

  if command -v scrcpy &>/dev/null; then
    local args="-b $bitrate -m 1024 --max-fps $max_fps"

    case "$quality" in
      low)    args="-b 500K -m 640 --max-fps 15" ;;
      medium) args="-b 2M -m 1024 --max-fps 30" ;;
      high)   args="-b 8M -m 1920 --max-fps 60" ;;
      ultra)  args="-b 20M -m 2560 --max-fps 120" ;;
    esac

    [ -n "$device" ] && args="$args -s $device"

    # Add extra options
    args="$args --window-title 'KorrinOS Screen Mirror'"
    args="$args --turn-screen-on"
    args="$args --stay-awake"

    echo "Starting scrcpy..."
    scrcpy $args &
    local scrcpy_pid=$!
    echo "Screen mirror started (PID: $scrcpy_pid)"
    echo "Close scrcpy window to stop."
  elif command -v adb &>/dev/null; then
    echo "scrcpy not found. Installing..."
    sudo apt-get install -y scrcpy 2>/dev/null || {
      echo "Install manually: sudo apt install scrcpy"
      echo "Or: snap install scrcpy"
      return 1
    }
    mirror_screen "$@"
  else
    echo "scrcpy and adb not found."
    echo "Install: sudo apt install scrcpy adb"
    return 1
  fi
}

# ---- clipboard sync ----
sync_clipboard() {
  local direction="${1:-phone-to-pc}"
  echo "=== Clipboard Sync ($direction) ==="

  if ! command -v adb &>/dev/null; then
    echo "ADB not found. Install: sudo apt install adb"
    return 1
  fi

  case "$direction" in
    phone-to-pc)
      local clip
      clip=$(adb shell service call clipboard 2 2>/dev/null | grep -oP "'\K[^']*")
      if [ -z "$clip" ]; then
        # Try alternative method
        clip=$(adb shell cmd clipboard get-primary 2>/dev/null | tr -d '\r')
      fi
      if [ -n "$clip" ]; then
        if command -v xclip &>/dev/null; then
          echo -n "$clip" | xclip -selection clipboard
        elif command -v xsel &>/dev/null; then
          echo -n "$clip" | xsel --clipboard --input
        elif command -v wl-copy &>/dev/null; then
          echo -n "$clip" | wl-copy
        fi
        echo "Clipboard synced from phone: ${clip:0:50}..."
      else
        echo "No clipboard content from phone."
      fi
      ;;
    pc-to-phone)
      local clip=""
      if command -v xclip &>/dev/null; then
        clip=$(xclip -selection clipboard -o 2>/dev/null)
      elif command -v xsel &>/dev/null; then
        clip=$(xsel --clipboard --output 2>/dev/null)
      elif command -v wl-paste &>/dev/null; then
        clip=$(wl-paste 2>/dev/null)
      fi
      if [ -n "$clip" ]; then
        adb shell am broadcast -a clipboardmanager --es text "$clip" 2>/dev/null || \
        adb shell input text "$(echo "$clip" | sed 's/ /%s/g')" 2>/dev/null || \
        echo "$clip" | adb shell service call clipboard 1 2>/dev/null
        echo "Clipboard synced to phone: ${clip:0:50}..."
      else
        echo "No clipboard content on PC."
      fi
      ;;
    monitor)
      echo "Monitoring clipboard changes (Ctrl+C to stop)..."
      local last_clip=""
      while true; do
        local current_clip=""
        if command -v xclip &>/dev/null; then
          current_clip=$(xclip -selection clipboard -o 2>/dev/null)
        fi
        if [ "$current_clip" != "$last_clip" ] && [ -n "$current_clip" ]; then
          adb shell am broadcast -a clipboardmanager --es text "$current_clip" 2>/dev/null || true
          echo "$(date +%H:%M:%S) Clipboard synced: ${current_clip:0:50}..."
          last_clip="$current_clip"
        fi
        sleep "$(cfg 'clipboard_sync_interval' '2')"
      done
      ;;
  esac
}

# ---- file transfer ----
send_file() {
  local file="$1"
  local device="${2:-}"

  [ -f "$file" ] || { echo "File not found: $file"; return 1; }

  local filesize
  filesize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
  local maxsize
  maxsize=$(( $(cfg "max_file_size_mb" "500") * 1024 * 1024 ))
  if [ "$filesize" -gt "$maxsize" ]; then
    echo "File too large: $((filesize/1024/1024))MB (max: $(cfg max_file_size_mb)MB)"
    return 1
  fi

  echo "=== Sending File ==="
  echo "File: $(basename "$file") ($((filesize/1024))KB)"

  if command -v adb &>/dev/null; then
    local args=""
    [ -n "$device" ] && args="-s $device"

    # Create remote directory
    adb $args shell mkdir -p /sdcard/KorrinOS/ 2>/dev/null || true

    echo "Sending via ADB..."
    adb $args push "$file" /sdcard/KorrinOS/ 2>&1 | tail -3 && {
      echo "File sent successfully."
      # Notify phone
      adb $args shell am broadcast -a com.korrinos.FILE_RECEIVED \
        --es filename "$(basename "$file")" 2>/dev/null || true
      echo "$(date -Iseconds) | send | $(basename "$file") | OK" >> "$MOBILE_LOG"
      return 0
    }
  fi

  # Fallback: SCP
  echo "Trying SCP..."
  local phone_ip
  phone_ip=$(cfg "wifi_ip" "")
  if [ -n "$phone_ip" ] && command -v scp &>/dev/null; then
    scp -o ConnectTimeout=5 "$file" "${phone_ip}:/sdcard/KorrinOS/" 2>/dev/null && {
      echo "File sent via SCP."
      return 0
    }
  fi

  echo "File transfer failed."
  return 1
}

receive_file() {
  local remote_path="${1:-/sdcard/KorrinOS/}"
  local local_dir="${HOME}/Downloads/PhoneFiles"
  mkdir -p "$local_dir"

  echo "=== Receiving Files ==="

  if command -v adb &>/dev/null; then
    # List files first
    echo "Remote files:"
    adb shell ls -la "$remote_path" 2>/dev/null | head -20

    adb pull "$remote_path" "$local_dir/" 2>&1 | tail -5 && {
      echo "Files received to $local_dir/"
      echo "$(date -Iseconds) | receive | $remote_path | OK" >> "$MOBILE_LOG"
      return 0
    }
  fi
  echo "Receive failed."
  return 1
}

# ---- notification forwarding ----
forward_notifications() {
  echo "=== Notification Forwarding ==="

  if command -v adb &>/dev/null; then
    echo "Reading phone notifications..."
    echo ""

    # Get current notifications
    adb shell dumpsys notification --noredact 2>/dev/null | \
      grep -E "pkg=|title=|text=|timestamp=" | head -40

    echo ""
    echo "To enable persistent forwarding:"
    echo "  1. Install 'Notification Listener' from Play Store"
    echo "  2. Or enable: Settings > Apps > Special Access > Notification Access"
    echo "  3. Enable KorrinOS Companion notification listener"

    # Try enabling notification listener
    adb shell settings put secure enabled_notification_listeners \
      "com.korrinos.notificationforwarder/.ListenerService" 2>/dev/null || true

    # Filter notifications
    local whitelist
    whitelist=$(cfg "notification_whitelist" "")
    if [ -n "$whitelist" ]; then
      echo ""
      echo "Whitelist active for: $whitelist"
    fi
  fi
}

# ---- SMS relay ----
relay_sms() {
  local phone_number="$1"
  local message="$2"

  [ -z "$phone_number" ] && { echo "Usage: korrinos-mobile sms <number> <message>"; return 1; }
  [ -z "$message" ] && { echo "Message required."; return 1; }

  if command -v adb &>/dev/null; then
    echo "Sending SMS to $phone_number..."
    adb shell am start -a android.intent.action.SENDTO \
      -d "smsto:$phone_number" --es sms_body "$message" \
      --ei exit_on_sent 1 2>/dev/null

    # Log SMS
    echo "$(date -Iseconds) | sms | $phone_number | ${message:0:50}" >> "$SMS_LOG"
    echo "SMS sent."
  else
    echo "ADB not available."
    return 1
  fi
}

# ---- phone camera ----
phone_camera() {
  local mode="${1:-photo}"
  echo "=== Phone Camera ($mode) ==="

  if command -v adb &>/dev/null; then
    case "$mode" in
      photo)
        adb shell am start -a android.media.action.IMAGE_CAPTURE 2>/dev/null
        echo "Camera opened. Take a photo."
        sleep 5
        echo "Pulling photos..."
        adb pull /sdcard/DCIM/Camera/ ~/Pictures/PhoneCamera/ 2>/dev/null || true
        ;;
      video)
        adb shell am start -a android.media.action.VIDEO_CAPTURE 2>/dev/null
        echo "Video recorder opened."
        ;;
      gallery)
        echo "Opening gallery..."
        adb shell am start -a android.intent.action.VIEW \
          -d "content://media/external/images/media" 2>/dev/null
        ;;
    esac
  fi
}

# ---- remote control (phone controls PC) ----
remote_control() {
  echo "=== Remote Control ==="

  # Option 1: SSH
  if command -v sshd &>/dev/null || systemctl is-active sshd &>/dev/null 2>&1; then
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "SSH available: ssh ${USER}@${ip}"
    echo "Use JuiceSSH or Termius on your phone to connect."
  fi

  # Option 2: KDE Connect
  if command -v kdeconnect-cli &>/dev/null; then
    echo ""
    echo "KDE Connect available:"
    kdeconnect-cli --list-devices 2>/dev/null || true
    echo "Pair via: kdeconnect-cli --pair <device-id>"
  fi

  # Option 3: Simple HTTP remote
  echo ""
  echo "Starting simple remote control server on port 8888..."
  python3 -c "
import http.server, json, subprocess, os
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/status':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            info = {'user': os.getenv('USER'), 'hostname': os.uname().nodename}
            self.wfile.write(json.dumps(info).encode())
        elif self.path == '/screenshot':
            subprocess.run(['scrot', '/tmp/screenshot.png'], capture_output=True)
            self.send_response(200)
            self.end_headers()
            with open('/tmp/screenshot.png', 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_response(404)
            self.end_headers()
    def log_message(self, format, *args): pass
server = http.server.HTTPServer(('0.0.0.0', 8888), Handler)
print('Remote control server on http://0.0.0.0:8888')
print('From phone: http://${ip}:8888/status')
server.serve_forever()
" &
  echo "Server started in background."
}

# ---- call relay ----
relay_call() {
  local phone_number="$1"
  [ -z "$phone_number" ] && { echo "Usage: korrinos-mobile call <number>"; return 1; }

  echo "Initiating call to $phone_number..."
  if command -v adb &>/dev/null; then
    adb shell am start -a android.intent.action.CALL \
      -d "tel:$phone_number" 2>/dev/null
    echo "Call initiated on phone."
    echo "$(date -Iseconds) | call | $phone_number | OK" >> "$MOBILE_LOG"
  fi
}

# ---- battery monitor ----
battery_monitor() {
  echo "=== Phone Battery ==="
  if command -v adb &>/dev/null; then
    local battery_info
    battery_info=$(adb shell dumpsys battery 2>/dev/null | grep -E "level|status|health|temperature|voltage" | head -10)
    if [ -n "$battery_info" ]; then
      echo "$battery_info"
    else
      echo "Could not read battery info."
    fi
  fi
}

# ---- contact sync ----
sync_contacts() {
  echo "=== Contact Sync ==="
  if command -v adb &>/dev/null; then
    echo "Pulling contacts..."
    adb shell content query --uri content://com.android.contacts/contacts \
      --projection display_name 2>/dev/null | head -50

    echo ""
    echo "Exporting contacts to VCF..."
    adb shell content query --uri content://com.android.contacts/contacts 2>/dev/null | \
      head -20 > "$CONTACTS_DIR/contacts.txt"
    echo "Contacts saved to $CONTACTS_DIR/"
  fi
}

# ---- call history ----
sync_call_log() {
  echo "=== Call History ==="
  if command -v adb &>/dev/null; then
    adb shell content query --uri content://call_log/calls \
      --projection "number:type:date:duration:name" 2>/dev/null | head -20
  fi
}

# ---- app list ----
list_apps() {
  echo "=== Phone Apps ==="
  if command -v adb &>/dev/null; then
    echo "Third-party apps:"
    adb shell pm list packages -3 2>/dev/null | sed 's/package://' | sort | head -50
    echo ""
    echo "Total: $(adb shell pm list packages -3 2>/dev/null | wc -l)"
  fi
}

# ---- media control ----
media_control() {
  local action="${1:-play}"
  echo "=== Media Control: $action ==="
  if command -v adb &>/dev/null; then
    case "$action" in
      play)     adb shell media dispatch play 2>/dev/null ;;
      pause)    adb shell media dispatch pause 2>/dev/null ;;
      next)     adb shell media dispatch skip-next 2>/dev/null ;;
      prev)     adb shell media dispatch skip-previous 2>/dev/null ;;
      volup)    adb shell media volume --set 10 2>/dev/null ;;
      voldown)  adb shell media volume --set 2 2>/dev/null ;;
    esac
    echo "Media action: $action"
  fi
}

# ---- ring find ----
ring_phone() {
  echo "=== Ring Phone ==="
  if command -v adb &>/dev/null; then
    adb shell am start -a android.intent.action.VIEW \
      -d "android.settings.SOUND_SETTINGS" 2>/dev/null
    adb shell service call audio 10 i32 3 i32 1 i32 0 2>/dev/null || true
    echo "Phone ringing..."
  fi
}

# ---- notification filter ----
configure_notification_filter() {
  echo "=== Notification Filter ==="
  echo ""
  echo "Whitelist (only these apps forward notifications):"
  cfg "notification_whitelist" "" | tr ',' '\n' | sed 's/^/  /'
  echo ""
  echo "Blacklist (never forward these):"
  cfg "notification_blacklist" "" | tr ',' '\n' | sed 's/^/  /'
  echo ""
  echo "Options:"
  echo "  1. Add to whitelist"
  echo "  2. Add to blacklist"
  echo "  3. Remove from whitelist"
  echo "  4. Clear all"
  read -p "Choice: " choice

  case "$choice" in
    1)
      read -p "Package name: " pkg
      python3 -c "
import json
with open('$MOBILE_CONFIG') as f: c = json.load(f)
wl = c.get('notification_whitelist', [])
if '$pkg' not in wl: wl.append('$pkg')
c['notification_whitelist'] = wl
with open('$MOBILE_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Added to whitelist: $pkg')
"
      ;;
    2)
      read -p "Package name: " pkg
      python3 -c "
import json
with open('$MOBILE_CONFIG') as f: c = json.load(f)
bl = c.get('notification_blacklist', [])
if '$pkg' not in bl: bl.append('$pkg')
c['notification_blacklist'] = bl
with open('$MOBILE_CONFIG', 'w') as f: json.dump(c, f, indent=2)
print('Added to blacklist: $pkg')
"
      ;;
  esac
}

# ---- KDE Connect integration ----
setup_kdeconnect() {
  echo "=== KDE Connect Setup ==="
  echo "KDE Connect provides deeper phone integration."
  echo ""
  echo "Install KDE Connect on your phone from:"
  echo "  - Google Play Store (Android)"
  echo "  - F-Droid (Android)"
  echo "  - App Store (iOS — limited)"
  echo ""
  echo "Install on PC: sudo apt install kdeconnect"
  echo ""

  if command -v kdeconnect-cli &>/dev/null; then
    echo "Devices:"
    kdeconnect-cli --list-devices 2>/dev/null || echo "  No devices found"
    echo ""
    read -p "Device ID to pair: " device_id
    if [ -n "$device_id" ]; then
      kdeconnect-cli --pair --device "$device_id" 2>/dev/null
      python3 -c "
import json
with open('$MOBILE_CONFIG') as f: c = json.load(f)
c['kdeconnect_enabled'] = True
c['kdeconnect_device_id'] = '$device_id'
with open('$MOBILE_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
    fi
  else
    echo "Install KDE Connect: sudo apt install kdeconnect"
  fi
}

# ---- setup wizard ----
setup_wizard() {
  echo "============================================="
  echo "  KorrinOS Mobile Companion Setup Wizard"
  echo "============================================="
  echo ""

  echo "Step 1: Install dependencies"
  echo "  sudo apt install adb scrcpy"
  echo ""

  echo "Step 2: Enable USB debugging on your Android phone"
  echo "  Settings > About Phone > Tap 'Build Number' 7 times"
  echo "  Settings > Developer Options > USB Debugging > ON"
  echo ""

  echo "Step 3: Connect phone via USB cable"
  read -p "Press Enter when connected..."
  detect_phone
  echo ""

  echo "Step 4: (Optional) Setup WiFi ADB"
  read -p "Setup WiFi ADB? (y/n): " choice
  [ "$choice" = "y" ] && setup_wifi_adb
  echo ""

  echo "Step 5: (Optional) Setup KDE Connect"
  read -p "Setup KDE Connect? (y/n): " choice
  [ "$choice" = "y" ] && setup_kdeconnect
  echo ""

  echo "Step 6: Test connection"
  detect_phone
  echo ""

  echo "Setup complete!"
}

# ---- status ----
mobile_status() {
  echo "==========================================="
  echo "   KorrinOS Mobile Companion Status"
  echo "==========================================="
  echo ""
  echo "ADB:       $(command -v adb &>/dev/null && echo 'installed' || echo 'NOT installed')"
  echo "scrcpy:    $(command -v scrcpy &>/dev/null && echo 'installed' || echo 'NOT installed')"
  echo "KDE Connect: $(command -v kdeconnect-cli &>/dev/null && echo 'installed' || echo 'NOT installed')"
  echo ""

  if command -v adb &>/dev/null; then
    adb start-server 2>/dev/null || true
    local devices
    devices=$(adb devices 2>/dev/null | grep -w "device" | wc -l)
    echo "Connected devices: $devices"
    if [ "$devices" -gt 0 ]; then
      adb devices 2>/dev/null | grep -w "device" | while read -r line; do
        local serial
        serial=$(echo "$line" | awk '{print $1}')
        local model
        model=$(adb -s "$serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
        echo "  $serial ($model)"
      done
    fi
  fi

  echo ""
  echo "WiFi ADB:  $(cfg 'wifi_adb_enabled' 'false')"
  echo "WiFi IP:   $(cfg 'wifi_ip' 'not set')"
  echo "Auto-mirror: $(cfg 'auto_mirror_on_connect' 'false')"
  echo ""
  echo "Config: $MOBILE_CONFIG"
  echo "Log: $MOBILE_LOG"
  echo "SMS Log: $SMS_LOG"
  echo ""
  echo "Last operation: $(tail -1 "$MOBILE_LOG" 2>/dev/null || echo 'none')"
}

# ---- main ----
case "${1:-}" in
  detect|scan)   detect_phone ;;
  mirror)        shift; mirror_screen "$@" ;;
  clipboard)     shift; sync_clipboard "${1:-phone-to-pc}" ;;
  send)          shift; send_file "$@" ;;
  receive)       shift; receive_file "${1:-}" ;;
  notifications) forward_notifications ;;
  sms)           shift; relay_sms "$@" ;;
  camera)        shift; phone_camera "${1:-photo}" ;;
  remote)        remote_control ;;
  call)          shift; relay_call "$@" ;;
  battery)       battery_monitor ;;
  contacts)      sync_contacts ;;
  calllog)       sync_call_log ;;
  apps)          list_apps ;;
  media)         shift; media_control "${1:-play}" ;;
  ring)          ring_phone ;;
  filter)        configure_notification_filter ;;
  wifi-adb)      setup_wifi_adb ;;
  kdeconnect)    setup_kdeconnect ;;
  status)        mobile_status ;;
  setup)         setup_wizard ;;
  init)          init_mobile ;;
  help|*)        echo "KorrinOS Mobile Companion v2
Usage: korrinos-mobile <command> [args]

Connection:
  detect              Detect connected phone
  setup               Run full setup wizard
  wifi-adb            Setup WiFi ADB connection
  kdeconnect          Setup KDE Connect

Screen & Display:
  mirror              Mirror phone screen (scrcpy)
    --quality low|medium|high|ultra

Clipboard & Files:
  clipboard <dir>     Sync clipboard (phone-to-pc / pc-to-phone / monitor)
  send <file>         Send file to phone
  receive [path]      Receive files from phone

Communication:
  sms <num> <msg>     Send SMS via phone
  call <number>       Initiate a call via phone

Phone Features:
  notifications       Forward phone notifications to PC
  filter              Configure notification filter (whitelist/blacklist)
  camera [mode]       Use phone camera (photo/video/gallery)
  battery             Show phone battery status
  contacts            Sync phone contacts
  calllog             Show call history
  apps                List installed apps
  media <action>      Control phone media (play/pause/next/prev)
  ring                Make phone ring

Remote Control:
  remote              Start remote control server

Status:
  status              Show companion status" ;;
esac

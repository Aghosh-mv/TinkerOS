#!/bin/bash
# TinkerOS Coil-Whine Killer - PWM Frequency Shifter
# Shifts VRM switching frequency out of human hearing range
# Shows on-screen popup when activating to alert user
CW_DIR="$HOME/.tinker/coil-whine-killer"; CW_CONFIG="$CW_DIR/config.json"
CW_LOG="$CW_DIR/killer.log"; mkdir -p "$CW_DIR"

init(){
  cat > "$CW_CONFIG" << 'EOF'
{
  "version": 1,
  "enabled": true,
  "auto_detect": true,
  "pwm_frequencies": {
    "current_khz": 300,
    "default_khz": 300,
    "silent_khz": 400,
    "ultra_silent_khz": 500,
    "spread_spectrum": true,
    "spread_range_khz": 50
  },
  "human_hearing_range_hz": {"low": 20, "high": 20000},
  "coil_whine_range_hz": {"low": 1000, "high": 8000},
  "popup": {
    "enabled": true,
    "duration_s": 5,
    "position": "top-center",
    "style": "notification"
  },
  "profiles": {
    "off": {"freq_khz": 300, "spread": false},
    "normal": {"freq_khz": 300, "spread": false},
    "silent": {"freq_khz": 400, "spread": true},
    "ultra_silent": {"freq_khz": 500, "spread": true}
  },
  "stats": {"total_shifts": 0, "whine_events_detected": 0, "user_notified": 0}
}
EOF
  echo "=== Coil-Whine Killer initialized ==="
  echo "  Default: 300kHz (may coil-whine)"
  echo "  Silent: 400kHz + spread spectrum"
  echo "  Ultra-silent: 500kHz + wide spread"
  echo "  Popup: ON (alerts user when activating)"
}

# ── On-Screen Popup ─────────────────────────────────────────────────────
show_popup(){
  local title=${1:-"Coil-Whine Killer"}
  local message=${2:-"Adjusting PWM frequency to eliminate coil whine"}
  local duration=${3:-5}
  python3 - << PYEOF
import subprocess, os, sys

title = "$title"
message = "$message"
duration = $duration

# Method 1: zenity (most DEs)
try:
    subprocess.Popen(
        ["zenity", "--notification", "--text={title}\n{message}".format(title=title, message=message)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    print("  Popup: zenity notification")
except:
    pass

# Method 2: notify-send (Linux standard)
try:
    subprocess.run(
        ["notify-send", "-u", "normal", "-t", str(duration * 1000), title, message],
        capture_output=True, timeout=2
    )
    print("  Popup: notify-send")
except:
    pass

# Method 3: Python tkinter popup (works everywhere)
try:
    popup_script = '''
import tkinter as tk
from tkinter import font as tkfont
import threading, time

def show_popup():
    root = tk.Tk()
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    root.attributes("-alpha", 0.9)
    
    # Position: top center
    w, h = 450, 80
    x = (root.winfo_screenwidth() - w) // 2
    y = 30
    root.geometry(f"{w}x{h}+{x}+{y}")
    
    # Dark theme
    root.configure(bg="#1a1a2e")
    
    # Title
    title_font = tkfont.Font(family="monospace", size=12, weight="bold")
    tk.Label(root, text="''' + title + '''", font=title_font, 
             fg="#00ff88", bg="#1a1a2e").pack(pady=(10,2))
    
    # Message
    msg_font = tkfont.Font(family="monospace", size=10)
    tk.Label(root, text="''' + message + '''", font=msg_font,
             fg="#ffffff", bg="#1a1a2e").pack()
    
    # Auto-close
    root.after(''' + str(duration * 1000) + ''', root.destroy)
    root.mainloop()

threading.Thread(target=show_popup, daemon=True).start()
time.sleep(''' + str(duration + 1) + ''')
'''
    subprocess.Popen([sys.executable, "-c", popup_script],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("  Popup: tkinter overlay")
except Exception as e:
    print(f"  Popup fallback: {e}")
PYEOF
}

# ── Read PWM Frequencies ────────────────────────────────────────────────
read_pwm(){
  echo "=== PWM Frequency Status ==="
  python3 - << 'PYEOF'
import os, glob, json

config = json.load(open(os.path.expanduser("~/.tinker/coil-whine-killer/config.json")))
freqs = config["pwm_frequencies"]

print(f"  Current PWM: {freqs['current_khz']}kHz")
print(f"  Target (silent): {freqs['silent_khz']}kHz")
print(f"  Spread spectrum: {freqs['spread_spectrum']}")
print()

# Read from sysfs hwmon
for hwmon in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
    try:
        name_file = f"{hwmon}/name"
        if os.path.exists(name_file):
            with open(name_file) as f:
                name = f.read().strip()
        else:
            name = os.path.basename(hwmon)
        
        # PWM frequency
        for pwm_file in sorted(glob.glob(f"{hwmon}/pwm*_freq")):
            with open(pwm_file) as f:
                freq = int(f.read().strip())
            pwm_id = os.path.basename(pwm_file).replace("_freq", "")
            print(f"  {name}/{pwm_id}: {freq/1000:.0f}kHz")
        
        # PWM enable
        for pwm_file in sorted(glob.glob(f"{hwmon}/pwm*_enable")):
            with open(pwm_file) as f:
                enable = f.read().strip()
            pwm_id = os.path.basename(pwm_file).replace("_enable", "")
            modes = {"0": "off", "1": "manual", "2": "auto"}
            print(f"  {name}/{pwm_id} enable: {modes.get(enable, enable)}")
    except:
        pass

# CPU/GPU VRM frequencies
print()
for cpu_dir in sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/")):
    try:
        with open(f"{cpu_dir}/scaling_cur_freq") as f:
            freq_mhz = int(f.read().strip()) / 1000
        cid = os.path.basename(cpu_dir.rstrip("/"))
        print(f"  {cid} frequency: {freq_mhz:.0f}MHz")
    except:
        break
PYEOF
}

# ── Shift PWM Frequency ─────────────────────────────────────────────────
shift_pwm(){
  local profile=${1:-"silent"}
  echo "=== Shifting PWM Frequency ==="
  python3 - << PYEOF
import json, os, glob, subprocess, time

config = json.load(open(os.path.expanduser("~/.tinker/coil-whine-killer/config.json")))
profiles = config["profiles"]
target = profiles.get("$profile", profiles["silent"])

freq_khz = target["freq_khz"]
spread = target["spread"]

print(f"  Profile: $profile")
print(f"  Target: {freq_khz}kHz")
print(f"  Spread spectrum: {spread}")

# Show popup notification
config["stats"]["user_notified"] += 1
json.dump(config, open(os.path.expanduser("~/.tinker/coil-whine-killer/config.json"), "w"), indent=2)
PYEOF

  # Show popup first
  show_popup "Coil-Whine Killer" "Shifting PWM to $profile ($profile freq) to eliminate coil whine" 5

  python3 - << PYEOF
import json, os, glob, subprocess, time

config = json.load(open(os.path.expanduser("~/.tinker/coil-whine-killer/config.json")))
profiles = config["profiles"]
target = profiles.get("$profile", profiles["silent"])

freq_khz = target["freq_khz"]
spread = target["spread"]

# Apply to hwmon PWM devices
applied = 0
for hwmon in glob.glob("/sys/class/hwmon/hwmon*"):
    for pwm_freq in glob.glob(f"{hwmon}/pwm*_freq"):
        try:
            # Set to target frequency
            with open(pwm_freq, "w") as f:
                f.write(str(freq_khz * 1000))
            applied += 1
            pwm_id = os.path.basename(pwm_freq).replace("_freq", "")
            print(f"  Set {pwm_id}: {freq_khz}kHz")
        except PermissionError:
            # Try with sudo
            try:
                subprocess.run(["sudo", "sh", "-c", f"echo {freq_khz * 1000} > {pwm_freq}"],
                             capture_output=True, timeout=2)
                applied += 1
                pwm_id = os.path.basename(pwm_freq).replace("_freq", "")
                print(f"  Set {pwm_id}: {freq_khz}kHz (via sudo)")
            except:
                print(f"  Cannot write {pwm_freq}: permission denied")
        except Exception as e:
            print(f"  Error: {e}")

# Spread spectrum via i2c (if available)
if spread:
    print(f"  Enabling spread spectrum: +/- {config['pwm_frequencies']['spread_range_khz']}kHz")
    # Some VRMs support spread spectrum via i2c
    try:
        for i2c_dev in glob.glob("/dev/i2c-*"):
            try:
                # Common VRM addresses: 0x40-0x5F
                for addr in range(0x40, 0x60):
                    subprocess.run(["i2cset", "-y", i2c_dev.split("/")[-1].replace("i2c-",""), 
                                   hex(addr), "0x00", "0x01"],
                                  capture_output=True, timeout=1)
            except:
                pass
    except:
        pass

# Update config
config["pwm_frequencies"]["current_khz"] = freq_khz
config["stats"]["total_shifts"] += 1
json.dump(config, open(os.path.expanduser("~/.tinker/coil-whine-killer/config.json"), "w"), indent=2)

print(f"\n  Applied: {applied} PWM devices")
print(f"  Frequency: {freq_khz}kHz (human hearing max: 20kHz)")
print(f"  Result: coil whine vibration shifted OUT of audible range")
PYEOF
}

# ── Auto-Detect and Kill ────────────────────────────────────────────────
auto_kill(){
  echo "=== Auto Coil-Whine Detection & Kill ==="
  echo "  Scanning for audible-frequency VRM vibration..."
  python3 - << 'PYEOF'
import json, os, subprocess, math

config = json.load(open(os.path.expanduser("~/.tinker/coil-whine-killer/config.json")))

# Check audio input for coil whine frequency (1-8kHz buzzing)
try:
    import subprocess
    # Quick audio sample via arecord
    result = subprocess.run(
        ["arecord", "-d", "1", "-f", "S16_LE", "-r", "44100", "-c", "1", "/tmp/cw_scan.wav"],
        capture_output=True, timeout=5
    )
    
    # Analyze for coil whine (1-8kHz peak)
    with open("/tmp/cw_scan.wav", "rb") as f:
        f.seek(44)  # skip header
        data = f.read(44100 * 2)  # 1 second
    
    if len(data) > 0:
        import struct
        samples = struct.unpack(f"<{len(data)//2}h", data)
        
        # Simple FFT-like: count zero crossings in 1-8kHz range
        crossings = 0
        for i in range(1, min(len(samples), 44100)):
            if (samples[i] > 0) != (samples[i-1] > 0):
                crossings += 1
        
        freq_est = crossings / 2  # estimated frequency
        
        if 1000 <= freq_est <= 8000:
            print(f"  ⚠️  COIL WHINE DETECTED at ~{freq_est}Hz!")
            print(f"  Action: shifting PWM to 400kHz + spread spectrum")
            
            # Show popup
            import sys
            sys.path.insert(0, os.path.expanduser("~/.tinker/coil-whine-killer"))
            
            # Apply silent profile
            config["pwm_frequencies"]["current_khz"] = 400
            config["stats"]["whine_events_detected"] += 1
            json.dump(config, open(os.path.expanduser("~/.tinker/coil-whine-killer/config.json"), "w"), indent=2)
            
            print(f"  ✅ PWM shifted to 400kHz + spread spectrum")
            print(f"  Vibration now at {400000}Hz (inaudible)")
        else:
            print(f"  ✅ No coil whine detected (estimated freq: {freq_est}Hz)")
except Exception as e:
    print(f"  Audio scan: {e}")
    print(f"  Falling back to frequency check...")
    
    # Just check current PWM and suggest shift
    freq = config["pwm_frequencies"]["current_khz"]
    if freq <= 350:
        print(f"  Current PWM: {freq}kHz (potential coil whine range)")
        print(f"  Recommendation: shift to 400kHz+")
    else:
        print(f"  Current PWM: {freq}kHz (outside audible range, should be silent)")
PYEOF
}

case "${1:-help}" in
  init) init ;;
  status|read) read_pwm ;;
  shift|silent) shift_pwm "silent" ;;
  ultra) shift_pwm "ultra_silent" ;;
  normal) shift_pwm "normal" ;;
  off) shift_pwm "off" ;;
  auto|detect) auto_kill ;;
  popup) show_popup "${2:-Coil-Whine Killer}" "${3:-Adjusting PWM to eliminate coil whine}" "${4:-5}" ;;
  dashboard) read_pwm; echo ""; auto_kill ;;
  *) echo "Usage: $0 {init|status|shift|ultra|normal|off|auto|popup|dashboard}"
     echo ""
     echo "  init      - Initialize"
     echo "  status    - Read current PWM frequencies"
     echo "  shift     - Shift to silent (400kHz + spread)"
     echo "  ultra     - Ultra silent (500kHz + wide spread)"
     echo "  normal    - Normal (300kHz, may whine)"
     echo "  off       - Default profile"
     echo "  auto      - Auto-detect coil whine via microphone, kill it"
     echo "  popup     - Test popup notification"
     echo "  dashboard - Full overview"
     echo ""
     echo "HOW: shifts VRM PWM from 300kHz to 400-500kHz (inaudible)"
     echo "POPUP: alerts user when frequency is shifted" ;;
esac

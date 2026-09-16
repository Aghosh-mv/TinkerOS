#!/usr/bin/env bash
# knowledge-korrinos.sh — KorrinOS complete knowledge base for AI responses
# This file is sourced by the AI engine to answer questions about the OS

tk_knowledge() {
  local topic="${1:-overview}"
  case "$topic" in
    overview)
      cat <<'EOF'
KorrinOS is a hardware-throughput desktop OS layered on a real Linux kernel — code
inside the Linux code, not a separate layer. It is designed for people who want a
powerful, beautiful, and helpful desktop experience. KorrinOS comes with three
isolated "worlds" that transform the entire OS for different purposes, and ships
with Tinkeria, a built-in agentic AI assistant accessible from any world.

Key facts:
- Built on a real Linux kernel with 27 custom kernel modules in kernel/tinker/
- Three isolated worlds: HACK, NORMAL, GAME — switch with Space+Shift+1/2/3
- Tinkeria: built-in AI assistant, pop it with Ctrl+Alt+Gr from any world
- Searchie: personal search engine for files (Tab+F7)
- 45 territory tools (18 HACK + 13 GAME + 14 SECURE)
- 278+ shell scripts, 25 Python tools, 10 C backends
- 224+ tools in the Control Center
- Custom Plymouth boot animation and GRUB branded boot menu
- Glassmorphism design language throughout
- Ships as a bootable ISO (~7.6 GB) — KorrinOS-v1.3.iso
- Dual Source License v1.0 (Option A public / Option B private, no fee)
EOF
      ;;
    worlds)
      cat <<'EOF'
KorrinOS has THREE isolated worlds — each one transforms the entire desktop:

1. HACK (Space+Shift+1 / Ctrl+Left):
   - The world that does the most work PROTECTING the hacker while HELPING them hack more.
   - Only Tor Browser works here, and only safe approved apps may run.
   - Security tools: amnesia-firewall, canary-honeypot, ephemeral-ram, kill-switch,
     portal-sandbox, reverse-proxy, sdr-isolation, threat-monitor, etc.
   - 18 territory tools for hacking and defense.
   - Keybind: Space+Shift+1 or Ctrl+Left

2. NORMAL (Space+Shift+2 / Ctrl+Up):
   - The MOST PROTECTED world — can still find/hack the user, but CANNOT be hacked.
   - Standard desktop experience with all productivity apps ready.
   - 14 territory tools: app-allowlist, biometric-lock, filevault2, gatekeeper2,
     key-wallet, privacy-ledger, vault-engine, zero-trust-config, etc.
   - Family-friendly defaults, balanced performance and battery life.
   - Keybind: Space+Shift+2 or Ctrl+Up

3. GAME (Space+Shift+3 / Ctrl+Right):
   - MAXIMUM OPTIMIZED world for gaming — perf governor, low-latency scheduler,
     GPU/IO priority, GameMode active.
   - 13 territory tools: game-mode, gpu-lock, lowlat-input, perf-tune,
     controller-haptics, frame-pacing, game-replay-ai, etc.
   - CPU performance governor set to maximum, fan curves tuned for sustained perf.
   - Keybind: Space+Shift+3 or Ctrl+Right

PANIC WIPE: Space+Shift+Escape — emergency wipe.

Switch worlds: tinker-world [game|hack|normal] or use the keybinds.
Every world supports Ctrl+Alt+Gr to pop Tinkeria.
EOF
      ;;
    features)
      cat <<'EOF'
KorrinOS Features:

AI & ASSISTANT:
- Tinkeria: built-in agentic AI assistant. Ask anything, control the computer, get help.
  Pop from any world: Ctrl+Alt+Gr
  CLI: parc-ai ask "question", parc-ai chat "message"
  Can take screenshots, read screen content, manage contacts, set reminders, track budget.

SEARCH & DISCOVERY:
- Searchie: personal search engine indexing files, browser history, and more.
  Launch: Tab+F7 or run `searchie`
  Commands: searchie ask "query", searchie timeline, searchie subsystem list

KERNEL MODULES (27 real kernel C modules in kernel/tinker/):
- thermal_sched: smart thermal management with user hints
- gamemode: automatic gaming performance boost
- energy_sched: battery saver that adapts to your usage
- battery_life: smart battery health management
- oled_wear: prevents OLED burn-in with pixel shifting
- cache_tiering: optimizes CPU cache usage
- coil_whine: spread-spectrum to reduce coil whine noise
- dust_dislodger: fan-shake to clean dust from vents (spec-gated: calibrate first)
- zero_latency_input: ultra-low-latency input handling
- hardware_dna: hardware fingerprinting
- sdgpu: software-defined GPU
- fpga_scaler, cxl_memory, dvfs_shaver, data_shredder, and more
- All wired into real scheduler, cpufreq governor, backlight driver, power supply paths

TERRITORY TOOLS (45 tools):
- HACK (18): amnesia-firewall, app-guard, browser-gate, canary-honeypot,
  ephemeral-ram, gpu-pipeline, hack-defense, hack-gate, hack-mode, hack-ways,
  intent-hardware, kill-switch, masked-proc, panic-wipe, portal-sandbox,
  reverse-proxy, sdr-isolation, split-personality, supply-chain, threat-monitor
- GAME (13): anticheat-consent, audio-focus, controller-haptics, frame-pacing,
  game-mode, game-replay-ai, game-studio, gpu-lock, latency-clean, lowlat-input,
  perf-tune, save-archiver, spectator-box
- SECURE (14): app-allowlist, biometric-lock, canary-monitor, duress-alert,
  filevault2, gatekeeper2, identity-cloud, key-wallet, privacy-ledger,
  secure-mode, sip-guard, traffic-guard, vault-engine, zero-trust-config

BOOT & BRANDING:
- Custom Plymouth boot animation (boot/reboot/shutdown splash)
- GRUB branded boot menu
- GDM greeter themed for KorrinOS
- Three selectable worlds at login

DESIGN:
- Glassmorphism design language throughout the UI
- Frosted glass with blur effects, rounded corners, cold edge glow

SYSTEM TOOLS (224+ in Control Center):
- System: hardware info, power management, display settings, audio
- Gaming: GameMode, controller setup, Proton config, FPS limits
- Hardware: fan control, battery health, OLED protection, thermal management
- Network: WiFi, Bluetooth, VPN, firewall, DNS
- Customization: themes, icons, fonts, animations, glassmorphism
- Security: firewall, encryption, privacy tools, app permissions
- Apps: Flatpak, AppImage, software center
- Advanced: kernel modules, scheduler tuning, memory management
EOF
      ;;
    commands)
      cat <<'EOF'
KorrinOS Commands:

WORLD SWITCHING:
  Space+Shift+1  / Ctrl+Left    Switch to HACK world
  Space+Shift+2  / Ctrl+Up      Switch to NORMAL world
  Space+Shift+3  / Ctrl+Right   Switch to GAME world
  Space+Shift+Escape             Panic wipe
  tinker-world game              Switch to GAME world
  tinker-world hack              Switch to HACK world
  tinker-world normal            Switch to NORMAL world
  tinker-world status            Show current world

AI ASSISTANT:
  Ctrl+Alt+Gr                    Pop Tinkeria from any world
  parc-ai ask "question"       Ask Tinkeria anything
  parc-ai chat "message"       Chat with Tinkeria
  parc-ai screenshot           Take a screenshot (AI reads it)
  parc-ai todo add "task"      Add a todo item
  parc-ai remind "msg" 30m     Set a reminder
  parc-ai contacts             List saved contacts
  parc-ai wallet               Check digital wallet
  parc-ai open firefox         Open an application
  parc-ai history              View conversation history
  parc-ai clear-history        Clear chat history

SEARCHIE (File Search):
  Tab+F7                         Open Searchie
  searchie                       Launch search GUI
  searchie ask "query"           Search your files
  searchie timeline              See file activity timeline
  searchie subsystem list        List search subsystems

SYSTEM:
  korrinos-control-center        Open the Control Center (224+ tools)
  tinker-hardware-info           Show hardware details
  tinker-power save              Set power saving mode
  tinker-power performance       Set performance mode
  tinker-fan auto                Set fan to automatic
  tinker-fan max                 Set fan to maximum
  tinker-display brightness 80   Set brightness
  tinker-audio volume 75         Set volume

GAMING:
  tinker-gamemode on             Enable GameMode
  tinker-gamemode off            Disable GameMode
  tinker-gamemode status         Check GameMode status
  tinker-controller setup        Configure game controller

SECURITY:
  tinker-firewall status         Check firewall
  tinker-firewall enable         Enable firewall
  tinker-privacy scan            Scan privacy settings

MAINTENANCE:
  tinker-update                  Update KorrinOS
  tinker-backup                  Backup your data
  tinker-cleanup                 Clean up disk space
  tinker-dust run                Run dust dislodger (calibrate first)
EOF
      ;;
    ui-layout)
      cat <<'EOF'
KorrinOS Desktop Layout:

TOP BAR (Panel):
- Left: Application menu (KorrinOS logo)
- Center: Clock and date
- Right: System tray (WiFi, Bluetooth, Volume, Battery, User menu)

APPLICATION MENU (click the KorrinOS logo):
- Applications grid (all installed apps)
- Search bar (type to find apps)
- Three world buttons: HACK | NORMAL | GAME
- Favorites section
- Recent apps

FILE MANAGER:
- Standard Linux file manager (Nautilus/Thunar)
- Bookmarks sidebar, preview pane
- Glassmorphism theme applied

CONTROL CENTER:
- Sidebar categories: System, Gaming, Hardware, Network, Customization,
  Security, Apps, Advanced
- 224+ tools across all categories
- Glassmorphism design language

TERMINAL:
- Custom themed terminal with transparency
- Pre-configured with useful aliases
- Tab completion for KorrinOS commands

NOTIFICATION CENTER:
- Slide-in panel from the right
- System notifications, quick settings toggles, calendar view

DESKTOP:
- Clean, minimal glassmorphism design
- Widget support (clock, weather, system monitors)
- Right-click context menu with KorrinOS tools

TINKERAI POPUP:
- Spotlight-style popup (680px wide, top-center) or expandable side panel
- Glassmorphism: frosted glass, real blur, transparency, 18px rounded corners
- Brand row: logo + "TINKER AI" + subtitle + hotkey hint
- Chat-style input field, rich response area with cards and code blocks
- Expandable: popup -> side panel -> full-screen (3 modes)
- Always-on-top frameless window, Esc to close
EOF
      ;;
    troubleshooting)
      cat <<'EOF'
Common KorrinOS Issues & Solutions:

SLOW PERFORMANCE:
- Run: tinker-power performance
- Check: tinker-gamemode status (enable if gaming)
- Clean: tinker-cleanup
- Check thermal: sensors (overheating throttles CPU)
- In GAME world: perf governor and low-latency scheduler are automatic

WIFI NOT WORKING:
- Check: nmcli device status
- Restart: sudo systemctl restart NetworkManager
- Connect: nmcli device wifi list && nmcli device wifi connect "SSID"

BLUETOOTH ISSUES:
- Check: bluetoothctl show
- Restart: sudo systemctl restart bluetooth
- Pair: bluetoothctl scan on && bluetoothctl pair MAC

AUDIO PROBLEMS:
- Check: pactl list sinks
- Restart: pulseaudio -k && pulseaudio --start
- Select device: pactl set-default-sink SINK_NAME

DISPLAY ISSUES:
- Check resolution: xrandr
- Set: xrandr --output HDMI-1 --mode 1920x1080
- Brightness: xbacklight -set 80

APP CRASHES:
- Check logs: journalctl -xe
- Reinstall: sudo apt reinstall package-name
- Reset config: rm -rf ~/.config/app-name

BOOT PROBLEMS:
- Hold Shift at boot for GRUB menu
- Select "Advanced options" for recovery mode
- Run: fsck /dev/sda1 (check filesystem)

WORLD ISSUES:
- If a world fails to switch, try: tinker-world status
- Panic wipe available: Space+Shift+Escape
- Each world is isolated — issues in one don't affect others

DUST DISLODGER:
- Must calibrate first: tinker-dust calibrate
- Then run: tinker-dust run
- Calculates fan rated ceiling, RPM-per-PWM slope, stall-floor
EOF
      ;;
    version)
      cat <<'EOF'
KorrinOS v1.3.0
Kernel: Linux 6.x with 27 custom kernel modules (kernel/tinker/)
Desktop: GNOME (glassmorphism themed)
Based on: Ubuntu/Debian
AI Engine: Tinkeria (Ctrl+Alt+Gr)
ISO Size: ~7.6 GB
License: Dual Source License v1.0 (Option A public / Option B private)
Download: https://sourceforge.net/projects/korrinos/files/v1.3/KorrinOS-v1.3.iso/
EOF
      ;;
    *) echo "Unknown topic: $topic. Available: overview, worlds, features, commands, ui-layout, troubleshooting, version" ;;
  esac
}

tk_random_fact() {
  local facts=(
    "KorrinOS has three isolated worlds — HACK for security, NORMAL for everyday use, GAME for maximum gaming performance."
    "Switch worlds anytime with Space+Shift+1/2/3 or Ctrl+Arrow keys."
    "Tinkeria pops up in any world with Ctrl+Alt+Gr — it can take screenshots and read what's on your screen."
    "The Searchie engine indexes your files so you can find anything instantly with Tab+F7."
    "KorrinOS has 224+ built-in system tools in the Control Center and 45 territory tools."
    "GAME world automatically enables perf governor, low-latency scheduler, and GPU/IO priority."
    "The OLED protection feature shifts pixels to prevent burn-in on OLED screens."
    "KorrinOS uses glassmorphism design — frosted glass with blur effects and 18px rounded corners."
    "You can ask Tinkeria to set reminders, manage contacts, or track your budget."
    "The dust dislodger spins fans at special intervals to clean dust — but you must calibrate first."
    "KorrinOS is built on a real Linux kernel with 27 custom C modules wired into the real scheduler."
    "NORMAL world is the most protected — it can find/hack the user but cannot be hacked."
    "HACK world only allows Tor Browser and safe approved apps to run."
    "Space+Shift+Escape triggers a panic wipe — emergency data destruction."
    "KorrinOS ships as a bootable ISO with branded Plymouth splash and GRUB menu."
    "The kernel modules include thermal_sched, gamemode, energy_sched, battery_life, oled_wear, and more."
  )
  echo "${facts[$((RANDOM % ${#facts[@]}))]}"
}

tk_version() {
  cat <<'EOF'
KorrinOS v1.3.0
Kernel: Linux 6.x with 27 custom kernel modules
Desktop: GNOME (glassmorphism themed)
Based on: Ubuntu/Debian
AI Engine: Tinkeria (Ctrl+Alt+Gr)
ISO: ~7.6 GB bootable image
EOF
}

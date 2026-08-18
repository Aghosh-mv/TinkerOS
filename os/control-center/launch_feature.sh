#!/usr/bin/env bash
# Feature Launcher for TinkerOS Control Center
# Matches the Control Center's run_feature() directory search logic

BASE_DIR="/home/tinkerspace/linux-kernel/os/apps"
LAUNCHED=0
NOT_FOUND=0

# Mapping of Control Center feature names to script names
map_feature() {
    local feature="$1"
    local script_name
    
    case "$feature" in
        # System
        "System Monitor") script_name="system-monitor" ;;
        "Power Manager") script_name="power-manager" ;;
        "Auto Updates") script_name="auto-updates" ;;
        "Backup & Restore") script_name="backup-restore" ;;
        "Rollback Recovery") script_name="rollback-recovery" ;;
        "Fast Boot") script_name="fast-boot" ;;
        "Predictive Intelligence") script_name="predictive-intelligence" ;;
        "Temporal Mapping") script_name="temporal-mapping" ;;
        "Context Aware") script_name="context-aware" ;;
        "Predictive Caching") script_name="predictive-caching" ;;
        "Digital Twin") script_name="digital-twin" ;;
        "Self Healing") script_name="self-healing" ;;
        "Adaptive Power Grid") script_name="adaptive-power-grid" ;;
        "System Cleaner") script_name="system-cleaner" ;;
        "Battery Monitor") script_name="battery-monitor" ;;
        # Gaming
        "FPS Monitor") script_name="fps-monitor" ;;
        "Controller Mapper") script_name="controller-mapper" ;;
        "Game Replay") script_name="game-replay" ;;
        "Streaming Manager") script_name="streaming-manager" ;;
        "Discord Presence") script_name="discord-presence" ;;
        "Wine/Proton Manager") script_name="wine-manager" ;;
        "Emulator Manager") script_name="emulator-manager" ;;
        "Game Saves Sync") script_name="game-saves-sync" ;;
        "Hardware Benchmark") script_name="hardware-benchmark" ;;
        "Performance Graph") script_name="performance-graph" ;;
        "Game Launcher") script_name="game-launcher" ;;
        "Anti-Cheat Helper") script_name="anticheat-helper" ;;
        "Audio Mixer") script_name="audio-mixer" ;;
        "Screenshot Tool") script_name="screenshot-tool" ;;
        "GIF Recorder") script_name="gif-recorder" ;;
        # Hardware
        "Fingerprint Manager") script_name="fingerprint-manager" ;;
        "Webcam Manager") script_name="webcam-manager" ;;
        "Scanner Manager") script_name="scanner-manager" ;;
        "Printer Manager") script_name="printer-manager" ;;
        "USB Manager") script_name="usb-manager" ;;
        "Thunderbolt Manager") script_name="thunderbolt-manager" ;;
        "Docking Station") script_name="docking-station" ;;
        "Display Calibration") script_name="display-calibration" ;;
        "HDR Manager") script_name="hdr-manager" ;;
        "Touchscreen Manager") script_name="touchscreen-manager" ;;
        "Pen/Stylus") script_name="pen-stylus" ;;
        "NFC Manager") script_name="nfc-manager" ;;
        "Serial/UART") script_name="serial-uart" ;;
        "GPIO Manager") script_name="gpio-manager" ;;
        "KVM Switch") script_name="kvm-switch" ;;
        # Network
        "VPN Manager") script_name="vpn-manager" ;;
        "Firewall GUI") script_name="firewall-gui" ;;
        "Network Monitor") script_name="network-monitor" ;;
        "Speed Test") script_name="speed-test" ;;
        "Bandwidth Limiter") script_name="bandwidth-limiter" ;;
        "DNS Manager") script_name="dns-manager" ;;
        "Proxy Manager") script_name="proxy-manager" ;;
        "WiFi Analyzer") script_name="wifi-analyzer" ;;
        "Hotspot Manager") script_name="hotspot-manager" ;;
        "Mesh Network") script_name="mesh-network" ;;
        # Customization
        "Cursor Themes") script_name="cursor-themes" ;;
        "Icon Packs") script_name="icon-packs" ;;
        "GRUB Theme") script_name="grub-theme" ;;
        "Login Theme") script_name="login-theme" ;;
        "Window Animations") script_name="window-animations" ;;
        "Desktop Effects") script_name="desktop-effects" ;;
        "Font Manager") script_name="font-manager" ;;
        "GTK Theme") script_name="gtk-theme" ;;
        "Qt Theme") script_name="qt-theme" ;;
        "Shell Theme") script_name="shell-theme" ;;
        "Conky Stats") script_name="conky-stats" ;;
        "Wallpaper Manager") script_name="wallpaper-manager" ;;
        # Security
        "Password Manager") script_name="password-manager" ;;
        "Security Suite") script_name="security-suite" ;;
        "File Vault") script_name="filevault" ;;
        "Gatekeeper") script_name="gatekeeper" ;;
        "Privacy") script_name="privacy" ;;
        "Firewall") script_name="firewall" ;;
        "Biometric") script_name="biometric" ;;
        "Find My Device") script_name="findmydevice" ;;
        # Apps
        "Software Center") script_name="software-center" ;;
        "Package Manager") script_name="package-manager" ;;
        "Gaming Mode") script_name="gaming-mode" ;;
        "Gaming Support") script_name="gaming-support" ;;
        "File Manager") script_name="file-manager" ;;
        "Quick Notes") script_name="quick-note" ;;
        "Smart Clipboard") script_name="smart-clipboard" ;;
        "OCR Everywhere") script_name="ocr-everywhere" ;;
        "Voice Commands") script_name="voice-commands" ;;
        "Screen Recorder") script_name="screen-recorder" ;;
        # Advanced
        "Focus Mode") script_name="focus-mode" ;;
        "Pomodoro Timer") script_name="pomodoro-timer" ;;
        "Time Tracker") script_name="time-tracker" ;;
        "Screen Time") script_name="screen-time" ;;
        "Parental Controls") script_name="parental-controls" ;;
        "Disk Visualizer") script_name="disk-visualizer" ;;
        "Duplicate Finder") script_name="duplicate-finder" ;;
        "File Versioning") script_name="file-versioning" ;;
        "Regex Tool") script_name="regex-tool" ;;
        "JSON Formatter") script_name="json-formatter" ;;
        "Markdown Editor") script_name="markdown-editor" ;;
        "Global Search") script_name="global-search" ;;
        "Command Palette") script_name="command-palette" ;;
        "Quick Actions") script_name="quick-actions" ;;
        *) script_name="" ;;
    esac
    
    if [ -n "$script_name" ]; then
        # Try multiple directories (same as Control Center run_feature)
        local script=""
        for dir in "$BASE_DIR" "$BASE_DIR/gaming" "$BASE_DIR/hardware" "$BASE_DIR/system" "$BASE_DIR/network" "$BASE_DIR/customization" "$BASE_DIR/security" "$BASE_DIR/apps" "$BASE_DIR/advanced"; do
            if [ -f "$dir/$script_name.sh" ]; then
                script="$dir/$script_name.sh"
                break
            fi
        done
        
        if [ -n "$script" ]; then
            bash "$script" "$2"
            LAUNCHED=$((LAUNCHED + 1))
            echo "LAUNCHED: $feature -> $script_name.sh"
        else
            echo "NOT FOUND: $feature (script: $script_name)"
            NOT_FOUND=$((NOT_FOUND + 1))
        fi
    else
        echo "NO MAPPING: $feature"
        NOT_FOUND=$((NOT_FOUND + 1))
    fi
}

# Launch all features by category
echo "=== TinkerOS Control Center Feature Launcher ==="
echo ""

echo "--- System ---"
for f in "System Monitor" "Power Manager" "Auto Updates" "Backup & Restore" "Rollback Recovery" "Fast Boot" "Predictive Intelligence" "Temporal Mapping" "Context Aware" "Predictive Caching" "Digital Twin" "Self Healing" "Adaptive Power Grid" "System Cleaner" "Battery Monitor"; do map_feature "$f" "$2"; done

echo ""
echo "--- Gaming ---"
for f in "FPS Monitor" "Controller Mapper" "Game Replay" "Streaming Manager" "Discord Presence" "Wine/Proton Manager" "Emulator Manager" "Game Saves Sync" "Hardware Benchmark" "Performance Graph" "Game Launcher" "Anti-Cheat Helper" "Audio Mixer" "Screenshot Tool" "GIF Recorder"; do map_feature "$f" "$2"; done

echo ""
echo "--- Hardware ---"
for f in "Fingerprint Manager" "Webcam Manager" "Scanner Manager" "Printer Manager" "USB Manager" "Thunderbolt Manager" "Docking Station" "Display Calibration" "HDR Manager" "Touchscreen Manager" "Pen/Stylus" "NFC Manager" "Serial/UART" "GPIO Manager" "KVM Switch"; do map_feature "$f" "$2"; done

echo ""
echo "--- Network ---"
for f in "VPN Manager" "Firewall GUI" "Network Monitor" "Speed Test" "Bandwidth Limiter" "DNS Manager" "Proxy Manager" "WiFi Analyzer" "Hotspot Manager" "Mesh Network"; do map_feature "$f" "$2"; done

echo ""
echo "--- Customization ---"
for f in "Cursor Themes" "Icon Packs" "GRUB Theme" "Login Theme" "Window Animations" "Desktop Effects" "Font Manager" "GTK Theme" "Qt Theme" "Shell Theme" "Conky Stats" "Wallpaper Manager"; do map_feature "$f" "$2"; done

echo ""
echo "--- Security ---"
for f in "Password Manager" "Security Suite" "File Vault" "Gatekeeper" "Privacy" "Firewall" "Biometric" "Find My Device"; do map_feature "$f" "$2"; done

echo ""
echo "--- Apps ---"
for f in "Software Center" "Package Manager" "Gaming Mode" "Gaming Support" "File Manager" "Quick Notes" "Smart Clipboard" "OCR Everywhere" "Voice Commands" "Screen Recorder"; do map_feature "$f" "$2"; done

echo ""
echo "--- Advanced ---"
for f in "Focus Mode" "Pomodoro Timer" "Time Tracker" "Screen Time" "Parental Controls" "Disk Visualizer" "Duplicate Finder" "File Versioning" "Regex Tool" "JSON Formatter" "Markdown Editor" "Global Search" "Command Palette" "Quick Actions"; do map_feature "$f" "$2"; done

echo ""
echo "=== Launch Summary ==="
echo "Launched: $LAUNCHED"
echo "Not found: $NOT_FOUND"
echo "Total features: ~130"

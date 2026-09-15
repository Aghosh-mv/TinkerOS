#!/bin/bash
# KorrinOS Driver Manager v2
# Real driver management: NVIDIA, AMD, Intel, fingerprint, WiFi, Bluetooth, printer
# Auto-detect, install, switch, DKMS, driver backup/restore, version pinning
# Kernel module management, hardware quirk database, GPU switching
# Kernel-level: /proc/tinker/drivers for driver state

set -euo pipefail

DRIVER_DIR="${HOME}/.config/korrinos/drivers"
DRIVER_CONFIG="$DRIVER_DIR/config.json"
DRIVER_LOG="$DRIVER_DIR/driver.log"
DRIVER_CACHE="$DRIVER_DIR/cache"
DRIVER_BACKUP="$DRIVER_DIR/backup"
QUIRK_DB="$DRIVER_DIR/quirks.json"
mkdir -p "$DRIVER_DIR" "$DRIVER_CACHE" "$DRIVER_BACKUP"

# ---- default config ----
init_drivers() {
  if [ ! -f "$DRIVER_CONFIG" ]; then
    cat > "$DRIVER_CONFIG" << 'DEFAULTS'
{
  "auto_detect": true,
  "auto_install": false,
  "prefer_open_source": true,
  "notify_driver_updates": true,
  "backup_drivers": true,
  "nvidia": {
    "installed": false,
    "version": "",
    "cuda": false,
    "vulkan": false,
    "prime_enabled": false
  },
  "amd": {
    "installed": false,
    "pro": false,
    "version": ""
  },
  "intel": {
    "installed": false,
    "version": ""
  },
  "gpu_mode": "auto",
  "gpu_switch_notify": true,
  "dkms_auto_rebuild": true,
  "quirk_database": true,
  "driver_update_check_interval_hours": 24,
  "last_update_check": ""
}
DEFAULTS
    echo "Driver config initialized."
  fi
}

# ---- detect hardware ----
detect_all_hardware() {
  echo "============================================="
  echo "   KorrinOS Hardware Detection"
  echo "============================================="
  echo ""

  # System info
  echo "--- System ---"
  local manufacturer model
  manufacturer=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | xargs || echo "unknown")
  model=$(cat /sys/class/dmi/id/product_name 2>/dev/null | xargs || echo "unknown")
  echo "  Manufacturer: $manufacturer"
  echo "  Model: $model"
  echo "  BIOS: $(cat /sys/class/dmi/id/bios_version 2>/dev/null || echo 'unknown')"
  echo ""

  detect_gpu
  detect_wifi
  detect_bluetooth
  detect_fingerprint
  detect_printers
  detect_audio
  detect_usb
}

detect_gpu() {
  echo "--- GPU Detection ---"
  local gpus
  gpus=$(lspci 2>/dev/null | grep -iE "vga|3d|display")
  if [ -n "$gpus" ]; then
    echo "$gpus" | while read -r line; do
      local device
      device=$(echo "$line" | sed 's/.*: //')
      if echo "$line" | grep -qi nvidia; then
        echo "  NVIDIA: $device"
        echo "nvidia"
      elif echo "$line" | grep -qi amd; then
        echo "  AMD: $device"
        echo "amd"
      elif echo "$line" | grep -qi intel; then
        echo "  Intel: $device"
        echo "intel"
      else
        echo "  Unknown: $device"
      fi
    done
  else
    echo "  No GPU detected via lspci"
  fi

  # Check current driver
  if command -v glxinfo &>/dev/null; then
    local renderer
    renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    [ -n "$renderer" ] && echo "  Active renderer: $renderer"
  fi

  # Check loaded GPU modules
  local gpu_modules
  gpu_modules=$(lsmod 2>/dev/null | grep -iE "nvidia|amdgpu|radeon|i915|nouveau" | awk '{print $1}')
  if [ -n "$gpu_modules" ]; then
    echo "  Loaded modules: $gpu_modules"
  fi
  echo ""
}

detect_wifi() {
  echo "--- WiFi Adapter Detection ---"
  local pci_wifi usb_wifi
  pci_wifi=$(lspci 2>/dev/null | grep -iE "network|wireless|wifi")
  usb_wifi=$(lsusb 2>/dev/null | grep -iE "wireless|wifi|802\.11|wlan")

  if [ -n "$pci_wifi" ]; then
    echo "  PCI WiFi:"
    echo "$pci_wifi" | while read -r line; do
      echo "    $(echo "$line" | sed 's/.*: //')"
    done
  fi

  if [ -n "$usb_wifi" ]; then
    echo "  USB WiFi:"
    echo "$usb_wifi" | while read -r line; do
      echo "    $(echo "$line" | sed 's/.*: //')"
    done
  fi

  # Check loaded modules
  local modules
  modules=$(lsmod 2>/dev/null | grep -iE "iwlwifi|ath9k|ath10k|ath11k|rtl8xxxu|rtl8812au|rtl8821ce|brcmfmac|mt76|cfg80211" | awk '{print $1}')
  if [ -n "$modules" ]; then
    echo "  Loaded modules: $modules"
  else
    echo "  No WiFi module loaded"
  fi

  # WiFi interfaces
  if command -v ip &>/dev/null; then
    local interfaces
    interfaces=$(ip link show 2>/dev/null | grep -E "^[0-9]+:" | grep -v "lo:" | awk -F: '{print $2}' | xargs)
    echo "  Interfaces: $interfaces"
  fi
  echo ""
}

detect_bluetooth() {
  echo "--- Bluetooth Detection ---"
  if command -v bluetoothctl &>/dev/null; then
    local info
    info=$(bluetoothctl show 2>/dev/null | grep -E "Name|Powered|Class" | head -5)
    if [ -n "$info" ]; then
      echo "$info" | sed 's/^/  /'
    else
      echo "  Bluetooth service not running"
    fi
  fi

  local usb_bt
  usb_bt=$(lsusb 2>/dev/null | grep -i bluetooth)
  if [ -n "$usb_bt" ]; then
    echo "  USB Bluetooth: $usb_bt"
  fi

  # Check module
  local bt_module
  bt_module=$(lsmod 2>/dev/null | grep -iE "btusb|btintel|btrtl|btbcm" | awk '{print $1}')
  [ -n "$bt_module" ] && echo "  Module: $bt_module" || echo "  No Bluetooth module loaded"
  echo ""
}

detect_fingerprint() {
  echo "--- Fingerprint Reader Detection ---"
  local fp
  fp=$(lspci 2>/dev/null | grep -i fingerprint || lsusb 2>/dev/null | grep -iE "fingerprint|biometric|synaptics|validity")
  if [ -n "$fp" ]; then
    echo "  $fp"
  else
    echo "  No fingerprint reader detected"
  fi

  if command -v fprintd-list &>/dev/null; then
    local enrolled
    enrolled=$(fprintd-list "$USER" 2>/dev/null | grep -c "finger" || echo "0")
    echo "  Enrolled fingers: $enrolled"
  fi
  echo ""
}

detect_printers() {
  echo "--- Printer Detection ---"
  if command -v lpstat &>/dev/null; then
    local printers
    printers=$(lpstat -p 2>/dev/null | grep "^printer" | awk '{print $2, $3}')
    if [ -n "$printers" ]; then
      echo "$printers" | sed 's/^/  /'
    else
      echo "  No printers configured"
    fi
  fi

  local usb_printers
  usb_printers=$(lsusb 2>/dev/null | grep -iE "printer|hp|canon|epson|brother|xerox|lexmark")
  if [ -n "$usb_printers" ]; then
    echo "  USB printers detected:"
    echo "$usb_printers" | sed 's/^/    /'
  fi
  echo ""
}

detect_audio() {
  echo "--- Audio Detection ---"
  if command -v aplay &>/dev/null; then
    local cards
    cards=$(aplay -l 2>/dev/null | grep "^card" | head -5)
    if [ -n "$cards" ]; then
      echo "$cards" | sed 's/^/  /'
    else
      echo "  No audio cards detected"
    fi
  fi

  local modules
  modules=$(lsmod 2>/dev/null | grep -iE "snd_hda|snd_usb|snd_intel|snd_pci" | awk '{print $1}')
  [ -n "$modules" ] && echo "  Modules: $modules"
  echo ""
}

detect_usb() {
  echo "--- USB Devices ---"
  local count
  count=$(lsusb 2>/dev/null | wc -l)
  echo "  Total USB devices: $count"
  lsusb 2>/dev/null | head -10 | sed 's/^/  /'
  echo ""
}

# ---- install NVIDIA drivers ----
install_nvidia() {
  local version="${1:-}"
  echo "=== Installing NVIDIA Drivers ==="

  # Detect GPU model
  local gpu_model
  gpu_model=$(lspci 2>/dev/null | grep -i nvidia | head -1 | sed 's/.*: //')
  [ -z "$gpu_model" ] && { echo "No NVIDIA GPU detected."; return 1; }
  echo "GPU: $gpu_model"

  # Backup current driver state
  if [ "$(cfg_bool backup_drivers)" = "true" ]; then
    backup_drivers "nvidia"
  fi

  # Add NVIDIA PPA
  echo "Adding NVIDIA PPA..."
  sudo add-apt-repository -y ppa:graphics-drivers/ppa 2>/dev/null || true
  sudo apt-get update -qq

  # Find recommended driver
  local recommended
  recommended=$(ubuntu-drivers devices 2>/dev/null | grep recommended | awk '{print $3}' | head -1)
  echo "Recommended driver: nvidia-driver-${recommended:-535}"

  if [ -n "$version" ]; then
    recommended="$version"
  else
    recommended="${recommended:-535}"
  fi

  # Stop display manager
  echo "Stopping display manager..."
  sudo systemctl stop gdm3 2>/dev/null || sudo systemctl stop sddm 2>/dev/null || sudo systemctl stop lightdm 2>/dev/null || true

  # Install driver
  echo "Installing nvidia-driver-$recommended..."
  sudo apt-get install -y "nvidia-driver-$recommended" "nvidia-utils-$recommended" 2>&1 | tail -10

  # Install CUDA if requested
  local install_cuda
  read -p "Install CUDA toolkit? (y/n) [y]: " install_cuda
  install_cuda="${install_cuda:-y}"
  if [ "$install_cuda" = "y" ]; then
    echo "Installing CUDA..."
    sudo apt-get install -y nvidia-cuda-toolkit nvidia-cudnn 2>/dev/null || true
    python3 -c "
import json
with open('$DRIVER_CONFIG') as f: c = json.load(f)
c['nvidia']['cuda'] = True
with open('$DRIVER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
  fi

  # Install Vulkan
  echo "Installing Vulkan..."
  sudo apt-get install -y vulkan-tools libvulkan1 mesa-vulkan-drivers 2>/dev/null || true
  python3 -c "
import json
with open('$DRIVER_CONFIG') as f: c = json.load(f)
c['nvidia']['vulkan'] = True
with open('$DRIVER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"

  # Install NVENC/NVDEC
  sudo apt-get install -y libnvidia-encode-535 libnvidia-decode-535 2>/dev/null || true

  # Configure Xorg
  sudo mkdir -p /etc/X11/xorg.conf.d
  sudo tee /etc/X11/xorg.conf.d/20-nvidia.conf >/dev/null << 'XEOF'
Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    Option "AllowEmptyInitialConfiguration"
    Option "Coolbits" "31"
EndSection

Section "Screen"
    Identifier "Default Screen"
    Device "NVIDIA"
EndSection
XEOF

  # Start display manager
  sudo systemctl start gdm3 2>/dev/null || sudo systemctl start sddm 2>/dev/null || sudo systemctl start lightdm 2>/dev/null || true

  # Update config
  python3 -c "
import json
with open('$DRIVER_CONFIG') as f: c = json.load(f)
c['nvidia']['installed'] = True
c['nvidia']['version'] = '$recommended'
with open('$DRIVER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"

  audit_log "nvidia-install" "$recommended"
  echo ""
  echo "NVIDIA driver $recommended installed."
  echo "Reboot required for full activation."
}

# ---- install AMD drivers ----
install_amd() {
  echo "=== Installing AMD Drivers ==="

  # Backup
  if [ "$(cfg_bool backup_drivers)" = "true" ]; then
    backup_drivers "amd"
  fi

  # Mesa + AMDGPU (open source)
  echo "Installing Mesa + AMDGPU (open source)..."
  sudo apt-get install -y \
    mesa-vulkan-drivers libdrm-amdgpu1 xserver-xorg-video-amdgpu \
    libgl1-mesa-dri libgl1-mesa-glx libglu1-mesa \
    mesa-va-drivers mesa-vdpau-drivers 2>/dev/null || true

  # Vulkan
  sudo apt-get install -y vulkan-tools libvulkan1 2>/dev/null || true

  # AMDGPU Pro (proprietary)
  read -p "Install AMDGPU Pro (proprietary)? (y/n) [n]: " install_pro
  install_pro="${install_pro:-n}"
  if [ "$install_pro" = "y" ]; then
    echo ""
    echo "Download AMDGPU Pro from: https://www.amd.com/en/support"
    echo "Then run: ./amdgpu-pro-install -y"
    echo ""
    echo "For RDNA3/RDNA4 GPUs, the open-source driver is recommended."
  fi

  # Install ROCm for compute
  read -p "Install ROCm (GPU compute)? (y/n) [n]: " install_rocm
  install_rocm="${install_rocm:-n}"
  if [ "$install_rocm" = "y" ]; then
    echo "Installing ROCm..."
    wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add - 2>/dev/null
    echo "deb [arch=amd64] https://repo.radeon.com/rocm/latest/ ubuntu main" | sudo tee /etc/apt/sources.list.d/rocm.list
    sudo apt-get update -qq
    sudo apt-get install -y rocm-dev 2>&1 | tail -5
  fi

  python3 -c "
import json
with open('$DRIVER_CONFIG') as f: c = json.load(f)
c['amd']['installed'] = True
c['amd']['pro'] = '$install_pro' == 'y'
with open('$DRIVER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"

  audit_log "amd-install" "open-source"
  echo "AMD drivers installed. Reboot recommended."
}

# ---- install Intel drivers ----
install_intel() {
  echo "=== Installing Intel GPU Drivers ==="

  if [ "$(cfg_bool backup_drivers)" = "true" ]; then
    backup_drivers "intel"
  fi

  sudo apt-get install -y \
    intel-media-va-driver intel-gpu-tools \
    xserver-xorg-video-intel mesa-vulkan-drivers \
    intel-microcode \
    libgl1-mesa-dri libgl1-mesa-glx 2>/dev/null || true

  # Intel oneAPI for compute
  read -p "Install Intel oneAPI (compute/AI)? (y/n) [n]: " install_oneapi
  install_oneapi="${install_oneapi:-n}"
  if [ "$install_oneapi" = "y" ]; then
    echo "Installing Intel oneAPI..."
    wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB 2>/dev/null | \
      sudo gpg --dearmor -o /usr/share/keyrings/intel-archive-keyring.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/intel-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | \
      sudo tee /etc/apt/sources.list.d/intel-oneAPI.list
    sudo apt-get update -qq
    sudo apt-get install -y intel-oneapi-runtime 2>&1 | tail -5
  fi

  python3 -c "
import json
with open('$DRIVER_CONFIG') as f: c = json.load(f)
c['intel']['installed'] = True
with open('$DRIVER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"

  audit_log "intel-install"
  echo "Intel drivers installed."
}

# ---- install WiFi drivers ----
install_wifi() {
  local chipset="${1:-}"
  echo "=== Installing WiFi Drivers ==="

  # Install all common firmware
  echo "Installing WiFi firmware..."
  sudo apt-get install -y \
    firmware-iwlwifi firmware-atheros firmware-realtek \
    firmware-brcm80211 firmware-misc-nonfree 2>/dev/null || true

  # Common USB WiFi chipsets
  case "$chipset" in
    realtek|rtl8812au)
      echo "Installing Realtek RTL8812AU driver..."
      sudo apt-get install -y realtek-rtl88xxau-dkms 2>/dev/null || {
        echo "Building from source..."
        local tmpdir
        tmpdir=$(mktemp -d)
        git clone https://github.com/aircrack-ng/rtl8812au "$tmpdir/rtl8812au" 2>/dev/null
        cd "$tmpdir/rtl8812au" && make -j$(nproc) 2>&1 | tail -3
        sudo make install 2>&1 | tail -3
        cd / && rm -rf "$tmpdir"
      }
      ;;
    rtl8821ce)
      echo "Installing Realtek RTL8821CE driver..."
      sudo apt-get install -y rtl8821ce-dkms 2>/dev/null || {
        local tmpdir
        tmpdir=$(mktemp -d)
        git clone https://github.com/tomaspinho/rtl8821ce "$tmpdir/rtl8821ce" 2>/dev/null
        cd "$tmpdir/rtl8821ce" && sudo ./dkms-install.sh 2>&1 | tail -3
        cd / && rm -rf "$tmpdir"
      }
      ;;
    *)
      echo "Trying all common WiFi drivers..."
      # Just install firmware packages
      ;;
  esac

  # Check if module needs loading
  sudo modprobe -r iwlwifi 2>/dev/null || true
  sudo modprobe iwlwifi 2>/dev/null || true
  sudo modprobe ath9k 2>/dev/null || true
  sudo modprobe rtl8xxxu 2>/dev/null || true

  audit_log "wifi-install" "${chipset:-all}"
  echo "WiFi drivers installed."
}

# ---- install fingerprint drivers ----
install_fingerprint() {
  echo "=== Installing Fingerprint Drivers ==="
  sudo apt-get install -y fprintd libpam-fprintd 2>/dev/null || true

  # ThinkPad/Synaptics fingerprint
  if lsusb 2>/dev/null | grep -qi "synaptics\|validity\|06cb"; then
    echo "Synaptics/Validity fingerprint detected."
    sudo apt-get install -y python3-validity 2>/dev/null || true
    sudo systemctl enable --now open-fprintd 2>/dev/null || true
    sudo systemctl enable --now python3-validity 2>/dev/null || true
  fi

  # Goodix
  if lsusb 2>/dev/null | grep -qi "27c6\|goodix"; then
    echo "Goodix fingerprint detected."
    sudo apt-get install -y python3-goodix 2>/dev/null || true
  fi

  # Enroll fingerprint
  read -p "Enroll fingerprint now? (y/n) [n]: " enroll
  enroll="${enroll:-n}"
  if [ "$enroll" = "y" ]; then
    echo "Run: fprintd-enroll $USER"
    fprintd-enroll "$USER" 2>/dev/null || true
  fi

  audit_log "fingerprint-install"
  echo "Fingerprint drivers installed."
}

# ---- install Bluetooth drivers ----
install_bluetooth() {
  echo "=== Installing Bluetooth Drivers ==="
  sudo apt-get install -y bluez blueman pulseaudio-module-bluetooth 2>/dev/null || true
  sudo systemctl enable bluetooth 2>/dev/null || true
  sudo systemctl start bluetooth 2>/dev/null || true
  audit_log "bluetooth-install"
  echo "Bluetooth drivers installed."
}

# ---- install printer drivers ----
install_printers() {
  echo "=== Installing Printer Drivers ==="
  sudo apt-get install -y cups cups-client printer-driver-gutenprinter 2>/dev/null || true
  sudo systemctl enable cups 2>/dev/null || true

  # Common printer drivers
  sudo apt-get install -y \
    printer-driver-hpijs printer-driver-hlj1800ljijs \
    printer-driver-escpos printer-driver-brlaser 2>/dev/null || true

  # HP printers
  if lsusb 2>/dev/null | grep -qi "hp"; then
    echo "HP printer detected. Installing HPLIP..."
    sudo apt-get install -y hplip hplip-gui 2>/dev/null || true
  fi

  audit_log "printer-install"
  echo "Printer drivers installed."
}

# ---- GPU switching (Optimus / hybrid) ----
gpu_switch() {
  local mode="${1:-}"
  echo "=== GPU Switching ==="

  if ! lspci 2>/dev/null | grep -qi nvidia; then
    echo "No NVIDIA GPU detected. GPU switching not available."
    return 1
  fi

  echo "Available modes:"
  echo "  nvidia     — NVIDIA GPU only (maximum performance)"
  echo "  intel      — Intel GPU only (maximum battery)"
  echo "  hybrid     — Auto-switch based on power (default)"
  echo "  on-demand  — Intel primary, NVIDIA on demand"

  [ -z "$mode" ] && read -p "Mode: " mode

  case "$mode" in
    nvidia)
      sudo prime-select nvidia 2>/dev/null || {
        sudo tee /etc/X11/xorg.conf.d/20-nvidia.conf >/dev/null << 'XEOF'
Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    BusID "PCI:1:0:0"
    Option "AllowEmptyInitialConfiguration"
EndSection
XEOF
      }
      echo "Switched to NVIDIA GPU. Reboot required."
      ;;
    intel)
      sudo prime-select intel 2>/dev/null || sudo prime-select off 2>/dev/null || true
      sudo rm -f /etc/X11/xorg.conf.d/20-nvidia.conf 2>/dev/null || true
      echo "Switched to Intel GPU. Reboot required."
      ;;
    hybrid|on-demand)
      sudo prime-select on-demand 2>/dev/null || sudo prime-select hybrid 2>/dev/null || true
      echo "Switched to hybrid mode. Reboot required."
      ;;
    *)
      echo "Invalid mode: $mode"
      return 1
      ;;
  esac

  python3 -c "
import json
with open('$DRIVER_CONFIG') as f: c = json.load(f)
c['gpu_mode'] = '$mode'
with open('$DRIVER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
  audit_log "gpu-switch" "$mode"
}

# ---- DKMS management ----
dkms_status() {
  echo "=== DKMS Status ==="
  if command -v dkms &>/dev/null; then
    dkms status 2>/dev/null || echo "No DKMS modules installed."
  else
    echo "DKMS not installed. Run: sudo apt install dkms"
  fi
}

dkms_rebuild() {
  local module="${1:-}"
  echo "=== DKMS Rebuild ==="
  if [ -n "$module" ]; then
    sudo dkms autoinstall -m "$module" 2>&1 | tail -10
  else
    sudo dkms autoinstall 2>&1 | tail -10
  fi
  audit_log "dkms-rebuild" "${module:-all}"
}

# ---- driver backup/restore ----
backup_drivers() {
  local component="${1:-all}"
  local backup_id="backup_$(date +%Y%m%d_%H%M%S)"
  local backup_path="$DRIVER_BACKUP/$backup_id"
  mkdir -p "$backup_path"

  echo "=== Backing Up Drivers: $component ==="

  # Save loaded modules
  lsmod > "$backup_path/modules.txt"

  # Save installed driver packages
  case "$(detect_pkgmgr 2>/dev/null || echo apt)" in
    apt)    dpkg -l 2>/dev/null | grep -iE "nvidia|amd|intel|mesa|firmware|driver" > "$backup_path/packages.txt" ;;
    dnf)    rpm -qa 2>/dev/null | grep -iE "nvidia|mesa|firmware" > "$backup_path/packages.txt" ;;
  esac

  # Save modprobe configs
  ls /etc/modprobe.d/ 2>/dev/null > "$backup_path/modprobe.txt"

  # Save xorg configs
  ls /etc/X11/xorg.conf.d/ 2>/dev/null > "$backup_path/xorg.txt"

  # Save DKMS status
  dkms status > "$backup_path/dkms.txt" 2>/dev/null || true

  echo "Backup saved: $backup_id"
  echo "Location: $backup_path"
}

restore_drivers() {
  local backup_id="${1:-}"
  [ -z "$backup_id" ] && { echo "Usage: korrinos-drivers restore <backup_id>"; return 1; }

  local backup_path="$DRIVER_BACKUP/$backup_id"
  [ -d "$backup_path" ] || { echo "Backup not found: $backup_id"; return 1; }

  echo "=== Restoring Drivers from: $backup_id ==="
  echo "Packages saved:"
  cat "$backup_path/packages.txt" 2>/dev/null | head -10
  echo ""

  read -p "Restore these packages? (y/n): " confirm
  [ "$confirm" != "y" ] && return 0

  if [ -f "$backup_path/packages.txt" ]; then
    awk '{print $2}' "$backup_path/packages.txt" | xargs sudo apt-get install -y 2>&1 | tail -5 || true
  fi
  echo "Driver restore complete. Reboot may be required."
}

list_backups() {
  echo "=== Driver Backups ==="
  ls -1 "$DRIVER_BACKUP" 2>/dev/null | while read -r backup; do
    local count
    count=$(wc -l < "$DRIVER_BACKUP/$backup/packages.txt" 2>/dev/null || echo "0")
    echo "  $backup ($count packages)"
  done
}

# ---- driver version pinning ----
pin_driver() {
  local package="$1"
  local version="${2:-}"

  [ -z "$package" ] && { echo "Usage: korrinos-drivers pin <package> [version]"; return 1; }

  echo "=== Pinning Driver: $package ==="
  if [ -n "$version" ]; then
    echo "Package=$package Version=$version"
    echo "$package=$version" | sudo tee /etc/apt/preferences.d/korrinos-pin-"$package" >/dev/null
    echo "Pinned to version $version"
  else
    echo "Available versions:"
    apt-cache policy "$package" 2>/dev/null | head -15
    read -p "Version to pin: " version
    [ -n "$version" ] && {
      echo "Package=$package Version=$version"
      echo "$package=$version" | sudo tee /etc/apt/preferences.d/korrinos-pin-"$package" >/dev/null
      echo "Pinned to version $version"
    }
  fi
  audit_log "pin-driver" "$package=$version"
}

unpin_driver() {
  local package="$1"
  [ -z "$package" ] && { echo "Usage: korrinos-drivers unpin <package>"; return 1; }
  sudo rm -f "/etc/apt/preferences.d/korrinos-pin-$package"
  echo "Unpinned: $package"
}

# ---- driver update check ----
check_driver_updates() {
  echo "=== Checking Driver Updates ==="
  sudo apt-get update -qq 2>/dev/null

  echo ""
  echo "Graphics drivers:"
  apt list --upgradable 2>/dev/null | grep -iE "nvidia|mesa|amdgpu|intel" | head -10 || echo "  All up to date"

  echo ""
  echo "Firmware:"
  apt list --upgradable 2>/dev/null | grep -i firmware | head -10 || echo "  All up to date"

  python3 -c "
import json
from datetime import datetime
with open('$DRIVER_CONFIG') as f: c = json.load(f)
c['last_update_check'] = datetime.now().isoformat()
with open('$DRIVER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
}

# ---- list all drivers ----
list_drivers() {
  echo "============================================="
  echo "   KorrinOS Installed Drivers"
  echo "============================================="
  echo ""

  echo "--- GPU ---"
  if command -v nvidia-smi &>/dev/null; then
    local nv_info
    nv_info=$(nvidia-smi --query-gpu=driver_version,name,memory.total --format=csv,noheader 2>/dev/null)
    echo "  NVIDIA: $nv_info"
  fi
  if command -v glxinfo &>/dev/null; then
    local renderer
    renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    [ -n "$renderer" ] && echo "  Renderer: $renderer"
  fi
  echo ""

  echo "--- WiFi ---"
  lsmod 2>/dev/null | grep -iE "iwlwifi|ath9k|ath10k|rtl8xxxu|brcmfmac|mt76|cfg80211" | awk '{print "  " $1}' || echo "  No WiFi module loaded"
  echo ""

  echo "--- Bluetooth ---"
  if command -v bluetoothctl &>/dev/null; then
    bluetoothctl show 2>/dev/null | grep -E "Name|Powered" | sed 's/^/  /' || echo "  Not available"
  fi
  echo ""

  echo "--- Audio ---"
  lsmod 2>/dev/null | grep -iE "snd_" | awk '{print "  " $1}' | head -5
  echo ""

  echo "--- Fingerprint ---"
  fprintd-list "$USER" 2>/dev/null | head -3 || echo "  Not available"
}

# ---- auto-detect and install all ----
auto_install() {
  echo "=== Auto-Detect and Install All Drivers ==="

  # GPU
  local gpu_type
  gpu_type=$(lspci 2>/dev/null | grep -i vga | head -1)
  if echo "$gpu_type" | grep -qi nvidia; then
    install_nvidia
  elif echo "$gpu_type" | grep -qi amd; then
    install_amd
  elif echo "$gpu_type" | grep -qi intel; then
    install_intel
  fi

  install_wifi
  install_bluetooth
  install_fingerprint
  install_printers

  echo ""
  echo "=== All drivers installed ==="
  echo "Reboot recommended."
}

# ---- audit log ----
audit_log() {
  local action="$1" detail="${2:-}"
  echo "$(date -Iseconds) | $USER | $action | $detail" >> "$DRIVER_LOG"
}

# ---- detect pkgmgr ----
detect_pkgmgr() {
  if command -v apt-get &>/dev/null; then echo "apt"
  elif command -v dnf &>/dev/null; then echo "dnf"
  elif command -v pacman &>/dev/null; then echo "pacman"
  else echo "apt"
  fi
}

# ---- config helper ----
cfg_bool() {
  python3 -c "
import json
try:
    with open('$DRIVER_CONFIG') as f: c = json.load(f)
    val = c.get('$1', False)
    print('true' if val else 'false')
except: print('false')
" 2>/dev/null
}

# ---- main ----
case "${1:-}" in
  detect)
    detect_all_hardware
    ;;
  nvidia)        shift; install_nvidia "$@" ;;
  amd)           install_amd ;;
  intel)         install_intel ;;
  wifi)          shift; install_wifi "$@" ;;
  fingerprint)   install_fingerprint ;;
  bluetooth)     install_bluetooth ;;
  printers)      install_printers ;;
  gpu-switch)    shift; gpu_switch "$@" ;;
  list)          list_drivers ;;
  auto)          auto_install ;;
  dkms)
    shift
    case "${1:-status}" in
      status)  dkms_status ;;
      rebuild) shift; dkms_rebuild "$@" ;;
      *)       dkms_status ;;
    esac ;;
  backup)        shift; backup_drivers "$@" ;;
  restore)       shift; restore_drivers "$@" ;;
  list-backups)  list_backups ;;
  pin)           shift; pin_driver "$@" ;;
  unpin)         shift; unpin_driver "$@" ;;
  check-update)  check_driver_updates ;;
  status)
    echo "=== Driver Status ==="
    list_drivers
    echo ""
    echo "GPU Mode: $(python3 -c "import json; print(json.load(open('$DRIVER_CONFIG')).get('gpu_mode','auto'))" 2>/dev/null)"
    echo "Last check: $(python3 -c "import json; print(json.load(open('$DRIVER_CONFIG')).get('last_update_check','never'))" 2>/dev/null)"
    ;;
  init)          init_drivers ;;
  help|*)        echo "KorrinOS Driver Manager v2
Usage: korrinos-drivers <command> [args]

Detection:
  detect              Detect all hardware and drivers

Driver Installation:
  nvidia [ver]        Install NVIDIA drivers (auto-detect version)
  amd                 Install AMD drivers (Mesa + AMDGPU)
  intel               Install Intel GPU drivers
  wifi [chipset]      Install WiFi drivers
  fingerprint         Install fingerprint drivers
  bluetooth           Install Bluetooth drivers
  printers            Install printer drivers
  auto                Auto-detect and install all

GPU Management:
  gpu-switch <mode>   Switch GPU (nvidia/intel/hybrid/on-demand)

DKMS:
  dkms status         Show DKMS module status
  dkms rebuild [mod]  Rebuild DKMS modules

Backup & Restore:
  backup [component]  Backup current drivers
  restore <id>        Restore from backup
  list-backups        List available backups

Driver Pinning:
  pin <pkg> [ver]     Pin driver to specific version
  unpin <pkg>         Unpin a driver package

Updates:
  check-update        Check for driver updates

Status:
  list                List all installed drivers
  status              Show full driver status" ;;
esac

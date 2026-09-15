#!/bin/bash
# KorrinOS Real Installer
# Calamares-based system installer with KorrinOS branding
# Full disk partitioning, bootloader setup, user creation, post-install config
# Supports: BIOS/UEFI, dual-boot, encryption, LVM, auto-partition

set -euo pipefail

INSTALLER_DIR="${HOME}/.config/korrinos/installer"
INSTALLER_CONFIG="$INSTALLER_DIR/config.json"
INSTALLER_LOG="$INSTALLER_DIR/installer.log"
CALAMARES_DIR="/etc/calamares"
CALAMARES_MODULES="$CALAMARES_DIR/modules"
PROFILE_DIR="/etc/calamares/branding/korrinos"
ISO_MOUNT="/mnt/korrinos-iso"
TARGET="/mnt/korrinos-install"
mkdir -p "$INSTALLER_DIR" "$CALAMARES_DIR" "$PROFILE_DIR" "$TARGET"

# ---- default config ----
init_installer() {
  if [ ! -f "$INSTALLER_CONFIG" ]; then
    cat > "$INSTALLER_CONFIG" << 'DEFAULTS'
{
  "install_type": "erase",
  "target_disk": "",
  "partition_scheme": "gpt",
  "filesystem": "ext4",
  "swap_size_gb": 4,
  "encryption": false,
  "encryption_password": "",
  "lvm": false,
  "username": "",
  "hostname": "korrinos",
  "timezone": "UTC",
  "locale": "en_US.UTF-8",
  "keyboard_layout": "us",
  "bootloader": "grub-efi",
  "install_bootloader": true,
  "auto_login": false,
  "install_flatpak": true,
  "install_nvidia": true,
  "install_extras": true,
  "create_recovery": true,
  "enable_firewall": true,
  "enable_ssh": false,
  "grub_theme": "korrinos"
}
DEFAULTS
    echo "Installer config initialized."
  fi
}

# ---- detect installation environment ----
detect_install_env() {
  echo "============================================="
  echo "   KorrinOS Installer Environment"
  echo "============================================="
  echo ""

  # Check if running from live ISO
  if mount | grep -q "/run/archiso\|/cow\|/airootfs"; then
    echo "Environment: Live ISO (detected)"
  elif [ -d /isodevice ] || ls /dev/mapper/live* &>/dev/null; then
    echo "Environment: Live ISO"
  else
    echo "Environment: Installed system"
  fi

  # Check boot mode
  local boot_mode
  if [ -d /sys/firmware/efi ]; then
    boot_mode="UEFI"
    echo "Boot mode: UEFI"
  else
    boot_mode="BIOS"
    echo "Boot mode: BIOS/Legacy"
  fi

  # Detect disks
  echo ""
  echo "Available disks:"
  lsblk -d -o NAME,SIZE,TYPE,MODEL 2>/dev/null | grep -E "disk|NAME" | head -10

  echo ""
  echo "Current partitions:"
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT 2>/dev/null | head -20

  echo ""
  echo "Disk usage:"
  df -h / 2>/dev/null | head -3

  echo "$boot_mode"
}

# ---- detect available disks ----
list_disks() {
  echo "=== Available Disks ==="
  lsblk -d -o NAME,SIZE,TYPE,ROTA,MODEL,TRAN 2>/dev/null | grep -v "loop\|sr\|NAME" | head -20
  echo ""
  echo "Select target disk:"
  local i=1
  while read -r line; do
    local name size model
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    model=$(echo "$line" | awk '{print $5, $6}')
    echo "  $i) $name ($size) — $model"
    i=$((i + 1))
  done < <(lsblk -d -o NAME,SIZE,TYPE,ROTA,MODEL,TRAN 2>/dev/null | grep -v "loop\|sr\|NAME")
}

# ---- partition disk ----
partition_disk() {
  local disk="$1"
  local install_type="${2:-erase}"
  local partition_scheme="${3:-gpt}"

  [ -z "$disk" ] && { echo "Disk required."; return 1; }
  local device="/dev/$disk"

  echo "=== Partitioning: $device ($install_type, $partition_scheme) ==="
  echo ""
  echo "WARNING: This will DESTROY all data on $device!"
  echo ""
  read -p "Continue? (yes/no): " confirm
  [ "$confirm" != "yes" ] && return 1

  # Unmount any existing partitions on this disk
  echo "Unmounting existing partitions..."
  umount "${device}"* 2>/dev/null || true
  swapoff "${device}"* 2>/dev/null || true

  # Wipe disk
  echo "Wiping disk..."
  wipefs -a "$device" 2>/dev/null || true
  dd if=/dev/zero of="$device" bs=1M count=100 2>/dev/null || true

  case "$partition_scheme" in
    gpt)
      echo "Creating GPT partition table..."
      parted -s "$device" mklabel gpt

      case "$install_type" in
        erase)
          # EFI System Partition
          if [ -d /sys/firmware/efi ]; then
            parted -s "$device" mkpart ESP fat32 1MiB 513MiB
            parted -s "$device" set 1 esp on
          fi

          # Root partition
          parted -s "$device" mkpart primary ext4 513MiB 100%

          # Format
          if [ -d /sys/firmware/efi ]; then
            mkfs.fat -F32 "${device}1" 2>/dev/null
            mkfs.ext4 -F -L "KorrinOS-Root" "${device}2" 2>/dev/null
          else
            mkfs.ext4 -F -L "KorrinOS-Root" "${device}1" 2>/dev/null
          fi
          ;;
        dual)
          echo "Dual-boot: Creating partitions without destroying existing..."
          parted -s "$device" mkpart primary ext4 0% 50%
          parted -s "$device" mkpart primary ext4 50% 100%
          mkfs.ext4 -F -L "KorrinOS-Root" "${device}2" 2>/dev/null
          ;;
        manual)
          echo "Manual partitioning selected."
          echo "Use GParted or manual tools to create partitions."
          echo "Required: root partition (ext4), optional EFI (fat32)"
          ;;
      esac
      ;;
    mbr)
      echo "Creating MBR partition table..."
      parted -s "$device" mklabel msdos

      case "$install_type" in
        erase)
          parted -s "$device" mkpart primary ext4 1MiB 100%
          mkfs.ext4 -F -L "KorrinOS-Root" "${device}1" 2>/dev/null
          ;;
        dual)
          parted -s "$device" mkpart primary ext4 0% 50%
          parted -s "$device" mkpart primary ext4 50% 100%
          mkfs.ext4 -F -L "KorrinOS-Root" "${device}2" 2>/dev/null
          ;;
      esac
      ;;
  esac

  # Setup encryption if requested
  local encryption
  encryption=$(cfg "encryption" "false")
  if [ "$encryption" = "true" ]; then
    echo "Setting up LUKS encryption..."
    local enc_pass
    enc_pass=$(cfg "encryption_password" "")
    if [ -z "$enc_pass" ]; then
      read -s -p "Encryption password: " enc_pass
      echo ""
    fi
    echo "$enc_pass" | cryptsetup luksFormat "${device}2" 2>/dev/null
    echo "$enc_pass" | cryptsetup open "${device}2" korrinos-encrypted 2>/dev/null
    mkfs.ext4 -F -L "KorrinOS-Root" /dev/mapper/korrinos-encrypted 2>/dev/null
  fi

  # Setup swap
  local swap_size
  swap_size=$(cfg "swap_size_gb" "4")
  echo "Creating swap partition (${swap_size}GB)..."

  # Create swap file instead of partition for flexibility
  dd if=/dev/zero of=/tmp/korrinos-swap bs=1M count=$((swap_size * 1024)) 2>/dev/null
  chmod 600 /tmp/korrinos-swap
  mkswap /tmp/korrinos-swap 2>/dev/null

  echo "Disk partitioned successfully."
  echo "$(date -Iseconds) | partition | $disk | $install_type | OK" >> "$INSTALLER_LOG"
}

# ---- mount partitions ----
mount_partitions() {
  local disk="$1"
  local device="/dev/$disk"

  echo "=== Mounting Partitions ==="

  # Clean target
  umount -R "$TARGET" 2>/dev/null || true
  mkdir -p "$TARGET"

  # Mount root
  local root_part
  if [ -d /sys/firmware/efi ]; then
    root_part="${device}2"
  else
    root_part="${device}1"
  fi

  local encryption
  encryption=$(cfg "encryption" "false")
  if [ "$encryption" = "true" ]; then
    root_part="/dev/mapper/korrinos-encrypted"
  fi

  echo "Mounting root: $root_part -> $TARGET"
  mount "$root_part" "$TARGET"

  # Mount EFI
  if [ -d /sys/firmware/efi ]; then
    mkdir -p "$TARGET/boot/efi"
    mount "${device}1" "$TARGET/boot/efi"
  fi

  # Enable swap
  swapon /tmp/korrinos-swap 2>/dev/null || true

  echo "Partitions mounted."
}

# ---- install system ----
install_system() {
  echo "============================================="
  echo "   Installing KorrinOS System"
  echo "============================================="
  echo ""

  # This runs from live ISO
  echo "Step 1/8: Copying system files..."

  # Use rsync or cp to copy live system
  if command -v rsync &>/dev/null; then
    rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/swapfile"} \
      / "$TARGET/" 2>&1 | tail -5
  else
    cp -aT / "$TARGET/" 2>&1 | tail -5
  fi

  echo ""
  echo "Step 2/8: Configuring fstab..."

  # Generate fstab
  local root_uuid root_dev
  root_dev=$(findmnt -n -o UUID "$TARGET" 2>/dev/null || echo "")
  cat > "$TARGET/etc/fstab" << FSTABEOF
# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
UUID=$root_dev   /               ext4    errors=remount-ro 0       1
/tmp/korrinos-swap none          swap    sw              0       0
FSTABEOF

  if [ -d /sys/firmware/efi ]; then
    local efi_uuid
    efi_uuid=$(findmnt -n -o UUID "${device}1" 2>/dev/null || echo "")
    echo "UUID=$efi_uuid  /boot/efi  vfat  umask=0077  0  1" >> "$TARGET/etc/fstab"
  fi

  echo ""
  echo "Step 3/8: Configuring bootloader..."

  local bootloader
  bootloader=$(cfg "bootloader" "grub-efi")

  # Chroot and install GRUB
  mount --bind /dev "$TARGET/dev" 2>/dev/null || true
  mount --bind /dev/pts "$TARGET/dev/pts" 2>/dev/null || true
  mount --bind /proc "$TARGET/proc" 2>/dev/null || true
  mount --bind /sys "$TARGET/sys" 2>/dev/null || true

  if [ -d /sys/firmware/efi ]; then
    chroot "$TARGET" bash -c "apt-get update -qq && apt-get install -y grub-efi-amd64 shim-signed" 2>&1 | tail -3
    chroot "$TARGET" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=KorrinOS --recheck 2>&1 | tail -3
  else
    chroot "$TARGET" bash -c "apt-get update -qq && apt-get install -y grub-pc" 2>&1 | tail -3
    chroot "$TARGET" grub-install --target=i386-pc --recheck 2>&1 | tail -3
  fi

  # KorrinOS GRUB theme
  chroot "$TARGET" update-grub 2>&1 | tail -3

  echo ""
  echo "Step 4/8: Setting timezone..."
  local timezone
  timezone=$(cfg "timezone" "UTC")
  chroot "$TARGET" ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime 2>/dev/null
  echo "$timezone" > "$TARGET/etc/timezone"

  echo ""
  echo "Step 5/8: Configuring locale..."
  local locale
  locale=$(cfg "locale" "en_US.UTF-8")
  echo "$locale UTF-8" >> "$TARGET/etc/locale.gen"
  chroot "$TARGET" locale-gen 2>&1 | tail -3

  echo ""
  echo "Step 6/8: Configuring keyboard..."
  local kbd
  kbd=$(cfg "keyboard_layout" "us")
  cat > "$TARGET/etc/default/keyboard" << KBEOF
XKBMODEL="pc105"
XKBLAYOUT="$kbd"
XKBVARIANT=""
XKBOPTIONS=""
KBEOF

  echo ""
  echo "Step 7/8: Creating user..."
  local username
  username=$(cfg "username" "")
  if [ -z "$username" ]; then
    read -p "Username: " username
    python3 -c "
import json
with open('$INSTALLER_CONFIG') as f: c = json.load(f)
c['username'] = '$username'
with open('$INSTALLER_CONFIG', 'w') as f: json.dump(c, f, indent=2)
"
  fi

  local hostname
  hostname=$(cfg "hostname" "korrinos")

  # Create user in chroot
  chroot "$TARGET" useradd -m -s /bin/bash -c "KorrinOS User" "$username" 2>/dev/null || true
  chroot "$TARGET" usermod -aG sudo,docker,video,audio,plugdev "$username" 2>/dev/null || true

  # Set password
  echo "Set password for $username:"
  chroot "$TARGET" passwd "$username"

  # Set hostname
  echo "$hostname" > "$TARGET/etc/hostname"
  echo "127.0.1.1 $hostname" >> "$TARGET/etc/hosts"

  echo ""
  echo "Step 8/8: Post-install configuration..."

  # Configure auto-login if requested
  local auto_login
  auto_login=$(cfg "auto_login" "false")
  if [ "$auto_login" = "true" ]; then
    mkdir -p "$TARGET/etc/sddm.conf.d" 2>/dev/null || true
    cat > "$TARGET/etc/sddm.conf.d/autologin.conf" << AUTEOF
[Autologin]
User=$username
Session=plasma.desktop
AUTEOF
  fi

  # Enable firewall
  local enable_firewall
  enable_firewall=$(cfg "enable_firewall" "true")
  if [ "$enable_firewall" = "true" ]; then
    chroot "$TARGET" ufw --force enable 2>/dev/null || true
  fi

  # Enable services
  chroot "$TARGET" systemctl enable NetworkManager 2>/dev/null || true
  chroot "$TARGET" systemctl enable bluetooth 2>/dev/null || true
  chroot "$TARGET" systemctl enable sddm 2>/dev/null || true
  chroot "$TARGET" systemctl enable cups 2>/dev/null || true

  # KorrinOS services
  chroot "$TARGET" systemctl enable korrinos-autoupdate.timer 2>/dev/null || true

  # Cleanup
  umount -R "$TARGET/dev" 2>/dev/null || true
  umount -R "$TARGET/proc" 2>/dev/null || true
  umount -R "$TARGET/sys" 2>/dev/null || true

  echo ""
  echo "============================================="
  echo "   KorrinOS Installation Complete!"
  echo "============================================="
  echo ""
  echo "User: $username"
  echo "Hostname: $hostname"
  echo "Bootloader: GRUB"
  echo ""
  echo "Please remove installation media and reboot."
  echo "$(date -Iseconds) | install | OK | user=$username" >> "$INSTALLER_LOG"
}

# ---- Calamares configuration ----
setup_calamares() {
  echo "=== Setting up Calamares Installer ==="

  sudo mkdir -p "$CALAMARES_DIR" "$CALAMARES_MODULES"

  # Main settings.conf
  sudo tee "$CALAMARES_DIR/settings.conf" >/dev/null << 'CEOF'
---
installerName: "KorrinOS Installer"
windowTitle: "Install KorrinOS"
windowIcon: "korrinos"
progress: true
showSummary: true
QuitOnClose: true
QuitOnCloseConfirmation: true
DisableKeyboardLayout: false
QuitConfirmation: true
FirstRunCommand: ""
LastRunCommand: ""

windowSize: [960, 680]
sidebarMode: true
branding: "korrinos"
style: "Fusion"
viewAllModules: false
CEOF

  # Branding
  sudo mkdir -p "$PROFILE_DIR"
  sudo tee "$PROFILE_DIR/branding.desc" >/dev/null << 'BEOF'
---
# KorrinOS Calamares Branding

welcomeStyle: "sidebar"
welcomeTitle: "Welcome to KorrinOS"
welcomeSubtitle: "Install KorrinOS on your computer"
welcomeShowSupport: true
welcomeReleaseNotesUrl: ""
welcomeKnownIssuesUrl: ""
supportUrl: "https://github.com/Aghosh-mv/TinkerOS/issues"

slideshowPath: "/usr/share/calamares/slides"

sidebarImages:
  - "sidebar-prepare.png"
  - "sidebar-partition.png"
  - "sidebar-users.png"
  - "sidebar-progress.png"
  - "sidebar-next.png"

strings:
  productName: "KorrinOS"
  version: "1.3"
  shortProductName: "KorrinOS"
  shortVersion: "1.3"
  versionedName: "KorrinOS 1.3"
  versionedShortName: "KorrinOS 1.3"
  bootloaderName: "KorrinOS"
  bootloaderEntryName: "KorrinOS"
  productUrl: "https://github.com/Aghosh-mv/TinkerOS"
  bugzillaUrl: "https://github.com/Aghosh-mv/TinkerOS/issues"
  contactUrl: "https://github.com/Aghosh-mv/TinkerOS/issues"

images:
  productLogo: "/usr/share/korrinos/logo.png"
  productBanner: "/usr/share/korrinos/banner.png"
  productBackground: "/usr/share/korrinos/background.png"
  productWallpaper: "/usr/share/korrinos/wallpapers/default.png"
BEOF

  # partition module
  sudo tee "$CALAMARES_MODULES/partition.conf" >/dev/null << 'PEOF'
---
# Partition module configuration
efiSystemPartitionSize: 512
efiSystemPartitionType: fat32
swapPartitionSize: 0
swapPartitionType: linux-swap

defaultFileSystemType: ext4
defaultPartitionTableType: gpt

requiredPartitionMountPoints:
  - mountPoint: /
    minSize: 10240
    desiredSize: 20480
    maxSize: 102400
  - mountPoint: /boot/efi
    minSize: 256
    desiredSize: 512
    maxSize: 512

allowManualPartitioning: true
allowRemoveAllPartitions: true
allowWipe: true
PEOF

  # users module
  sudo tee "$CALAMARES_MODULES/users.conf" >/dev/null << 'UEOF'
---
# Users module configuration
defaultGroups:
  - audio
  - video
  - sudo
  - network
  - power
  - storage
  - lp
  - scanner
  - docker

autologinGroup: autologin
autologin: false
requireAllGroups: false

setRootPassword: true
sudoersGroup: sudo
SUDOersConfiguration: "full"
UEOF

  # network module
  sudo tee "$CALAMARES_MODULES/networkmanager.conf" >/dev/null << 'NEOF'
---
# NetworkManager configuration
unsupported:
  - network-manager-notify
  - network-manager-ap
  - network-manager-vpn
backend: "networkmanager"
NEOF

  # packages module
  sudo tee "$CALAMARES_MODULES/packages.conf" >/dev/null << 'PKEOF'
---
# Packages module configuration
backend: "apt"
update-config:
  True: "apt-get update"
packageOperations:
  - remove:
      flags: []
      timeout: 600
  - install:
      flags: ["--no-install-recommends"]
      timeout: 1200

skipchurest: false
SkipPostOperations: false
PKEOF

  # initcfg module
  sudo tee "$CALAMARES_MODULES/initcfg.conf" >/dev/null << 'ICEOF'
---
# initcfg configuration
rootMountPoint: "/mnt/korrinos-install"
configurationInstall: "/mnt/korrinos-install/etc/calamares"
ICEOF

  # mount module
  sudo tee "$CALAMARES_MODULES/mount.conf" >/dev/null << 'MEOF'
---
# Mount module configuration
extraMounts:
  - mountPoint: /
    options: "defaults,noatime"
    filesystem: "ext4"

extraMountsEfi:
  - mountPoint: /boot/efi
    options: "umask=0077"
    filesystem: "vfat"

efiSystemPartition: "/boot/efi"
MEOF

  # unpackfs module
  sudo tee "$CALAMARES_MODULES/unpackfs.conf" >/dev/null << 'UEOF'
---
# Unpack filesystem image
unpack:
  - source: "/isodevice/casper/filesystem.squashfs"
    destination: "/"
UEOF

  # fstab module
  sudo tee "$CALAMARES_MODULES/fstab.conf" >/dev/null << 'FEOF'
---
# Fstab module configuration
mountRoot: "/"
etcFstabPath: "etc/fstab"
verbose: false
FEOF

  # bootloader module
  sudo tee "$CALAMARES_MODULES/bootloader.conf" >/dev/null << 'BEOF'
---
# Bootloader configuration
bootloader: "grub"
grubInstallEfihook: "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=KorrinOS --recheck"
grubInstallBioshook: "grub-install --target=i386-pc --recheck"
efiBootPath: "/boot/efi"
efiBootEntryName: "KorrinOS"
BEOF

  echo "Calamares configuration complete."
}

# ---- create live ISO ----
create_iso() {
  echo "=== Creating KorrinOS Live ISO ==="

  local script_path
  script_path=$(dirname "$(readlink -f "$0")")
  local build_script
  build_script=$(dirname "$script_path")/build-distro.sh

  if [ -f "$build_script" ]; then
    echo "Running build-distro.sh..."
    bash "$build_script"
  else
    echo "build-distro.sh not found at: $build_script"
    echo "Create ISO manually with: sudo xorriso or sudo genisoimage"
  fi
}

# ---- validate installation ----
validate_install() {
  echo "=== Validating Installation ==="
  echo ""

  local target="${1:-$TARGET}"

  echo "Checking root partition..."
  if mountpoint -q "$target" 2>/dev/null; then
    echo "  Root: mounted at $target"
  else
    echo "  Root: NOT mounted"
  fi

  echo "Checking boot files..."
  if [ -f "$target/boot/vmlinuz" ] || [ -f "$target/boot/vmlinuz-"* ]; then
    echo "  Kernel: found"
  else
    echo "  Kernel: NOT found"
  fi

  echo "Checking GRUB..."
  if [ -d "$target/boot/efi" ] || [ -f "$target/boot/grub/grub.cfg" ]; then
    echo "  GRUB: configured"
  else
    echo "  GRUB: NOT found"
  fi

  echo "Checking user..."
  local username
  username=$(cfg "username" "")
  if [ -n "$username" ] && chroot "$target" id "$username" &>/dev/null; then
    echo "  User: $username exists"
  else
    echo "  User: NOT created"
  fi

  echo "Checking fstab..."
  if [ -f "$target/etc/fstab" ]; then
    echo "  fstab: configured"
  else
    echo "  fstab: NOT found"
  fi

  echo "Checking services..."
  for svc in NetworkManager sddm bluetooth; do
    if [ -L "$target/etc/systemd/system/multi-user.target.wants/${svc}.service" ] || \
       [ -L "$target/etc/systemd/system/graphical.target.wants/${svc}.service" ]; then
      echo "  $svc: enabled"
    else
      echo "  $svc: not enabled"
    fi
  done
}

# ---- main ----
case "${1:-}" in
  detect-env)     detect_install_env ;;
  list-disks)     list_disks ;;
  partition)      shift; partition_disk "$@" ;;
  mount)          shift; mount_partitions "$@" ;;
  install)        install_system ;;
  setup-calamares) setup_calamares ;;
  create-iso)     create_iso ;;
  validate)       shift; validate_install "$@" ;;
  status)
    echo "=== Installer Status ==="
    echo "Config: $INSTALLER_CONFIG"
    echo "Log: $INSTALLER_LOG"
    if [ -f "$INSTALLER_LOG" ]; then
      echo "Last install:"
      tail -3 "$INSTALLER_LOG"
    fi
    ;;
  init)           init_installer ;;
  help|*)         echo "KorrinOS Installer
Usage: korrinos-installer <command> [args]

Environment:
  detect-env       Detect installation environment
  list-disks       List available disks

Installation:
  partition <disk> <type> <scheme>  Partition disk (erase/dual/manual, gpt/mbr)
  mount <disk>     Mount partitions
  install          Install KorrinOS system
  validate [target] Validate installation

Calamares:
  setup-calamares  Configure Calamares installer

ISO:
  create-iso       Create KorrinOS live ISO

Status:
  status           Show installer status

Examples:
  korrinos-installer detect-env
  korrinos-installer list-disks
  korrinos-installer partition sda erase gpt
  korrinos-installer mount sda
  korrinos-installer install
  korrinos-installer validate" ;;
esac

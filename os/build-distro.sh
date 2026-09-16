#!/bin/bash
# KorrinOS REAL Distribution ISO Builder
# Builds a genuine, full desktop Linux distribution (like Ubuntu/Arch/Kali)
# with Xorg/Wayland, a desktop environment, browsers, applications, a real
# package base, AND the 3 isolated worlds (HACK/GAME/NORMAL) baked in.
#
# Structure (standard Ubuntu live-CD / casper layout):
#   rootfs/            <- debootstrap base + packages
#     casper/filesystem.squashfs
#     vmlinuz, initrd
#   KorrinOS-v1.1.iso  <- bootable, multi-GB, real OS
#
# Requires: sudo + debootstrap + mksquashfs + xorriso + internet.

set -euo pipefail

WORLDS="${WORLDS:-all}"

ARCH="${ARCH:-amd64}"
SUITE="${SUITE:-jammy}"                       # Ubuntu 22.04 (Pop base)
MIRROR="${MIRROR:-http://in.archive.ubuntu.com/ubuntu/}"
BUILD="${BUILD:-/home/tinkerspace/build-korrinos}"
ROOTFS="$BUILD/rootfs"
IMAGE="$BUILD/image"
OUT="${OUT:-/home/tinkerspace/linux-kernel/KorrinOS-v1.3.iso}"
SUDO="${SUDO:-sudo}"
if ! sudo -n true 2>/dev/null; then
  echo "ERROR: passwordless sudo required. Run: sudo -v" >&2
  exit 1
fi

NEED="debootstrap mksquashfs xorriso chroot"
for c in debootstrap mksquashfs xorriso; do
  command -v "$c" >/dev/null || { echo "missing: $c"; exit 1; }
done

mkdir -p "$BUILD"

echo "### [1/6] Bootstrapping base system ($SUITE)..."

stage1() {
  "$SUDO" rm -rf "$ROOTFS"
  "$SUDO" debootstrap --arch="$ARCH" --variant=minbase \
    "$SUITE" "$ROOTFS" "$MIRROR"
  # give the chroot working DNS so apt/in-chroot fetch works
  [ -f /etc/resolv.conf ] && "$SUDO" cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
  echo "   base bootstrap done."
}

stage2_install() {
  echo "### [2/6] Installing desktop, apps, package base inside rootfs..."
  # proper full sources so universe/multiverse apps resolve
  "$SUDO" bash -c "cat > '$ROOTFS/etc/apt/sources.list' <<'SRC'
deb $MIRROR $SUITE main restricted universe multiverse
deb $MIRROR $SUITE-updates main restricted universe multiverse
deb $MIRROR $SUITE-security main restricted universe multiverse
deb-src $MIRROR $SUITE main restricted universe multiverse
SRC"
  # bind-mount /proc /sys /dev so apt postinst scripts work inside chroot
  "$SUDO" mkdir -p "$ROOTFS"/{proc,sys,dev,dev/pts}
  "$SUDO" mount --bind /proc  "$ROOTFS/proc"  2>/dev/null || true
  "$SUDO" mount --bind /sys   "$ROOTFS/sys"   2>/dev/null || true
  "$SUDO" mount --bind /dev   "$ROOTFS/dev"   2>/dev/null || true
  mountpoint -q "$ROOTFS/dev/pts" || "$SUDO" mount -t devpts none "$ROOTFS/dev/pts" 2>/dev/null || true

cat > "$BUILD/apt.sh" <<EOF
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
WORLDS="$WORLDS"
apt-get update -y

# ============================================================
#  KorrinOS v1.3 — FULL 30GB DESKTOP DISTRIBUTION
#  Installing EVERYTHING with recommends for a complete OS
# ============================================================

# ---- KERNEL + BOOT ----
echo ">>> Installing kernel and boot system..."
apt-get install -y linux-image-generic linux-headers-generic \
  initramfs-tools initramfs-tools-core initramfs-tools-bin \
  casper live-boot live-config \
  grub-efi-amd64-bin shim-signed mokutil \
  || echo "kernel/boot had issues"
# Note: grub-pc removed — conflicts with grub-efi in chroot

# ---- FULL XFCE DESKTOP (with recommends) ----
echo ">>> Installing XFCE4 desktop..."
apt-get install -y xfce4 xfce4-goodies xfce4-terminal xfce4-panel \
  xfce4-session xfce4-settings xfce4-power-manager \
  lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
  xorg xserver-xorg xserver-xorg-input-all xserver-xorg-video-all \
  xserver-xorg-input-libinput xserver-xorg-input-synaptics \
  x11-xserver-utils x11-utils x11-apps xdg-utils xdg-desktop-portal \
  || echo "desktop had issues"

# ---- DISPLAY MANAGER + COMPOSITOR ----
echo ">>> Installing compositor and display tools..."
apt-get install -y picom dunst xfwm4 \
  arandr autorandr xrandr xprop xdotool xclip xsel \
  nitrogen feh imwheel \
  || echo "compositor had issues"

# ---- AUDIO STACK ----
echo ">>> Installing audio system..."
apt-get install -y pulseaudio pulseaudio-utils pulseaudio-module-bluetooth \
  pavucontrol pavumeter alsa-utils alsa-tools alsa-firmware \
  pipewire pipewire-pulse wireplumber \
  volumeicon sound-theme-freedesktop \
  audacity audacious lmms \
  || echo "audio had issues"

# ---- NETWORKING ----
echo ">>> Installing networking..."
apt-get install -y network-manager network-manager-gnome \
  net-tools wireless-tools iw wpasupplicant \
  openssh-client openssh-server ssh \
  curl wget aria2 axel \
  smbclient samba-common-bin \
  dnsutils traceroute nmap \
  openvpn wireguard-tools \
  bluetooth bluez bluez-tools blueman \
  || echo "networking had issues"

# ---- FILE MANAGER + FILES ----
echo ">>> Installing file managers..."
apt-get install -y thunar thunar-archive-plugin thunar-volman \
  nemo nautilus pcmanfm \
  mousepad leafpad xfburn \
  file-roller engrampa \
  gvfs gvfs-backends gvfs-fuse \
  udisks2 udiskie \
  || echo "file managers had issues"

# ---- WEB BROWSERS ----
echo ">>> Installing browsers..."
apt-get install -y firefox \
  || echo "browsers had issues"

# ---- OFFICE SUITE ----
echo ">>> Installing LibreOffice full..."
apt-get install -y libreoffice libreoffice-l10n-en-us libreoffice-help-en-us \
  libreoffice-writer libreoffice-calc libreoffice-impress \
  libreoffice-draw libreoffice-base libreoffice-math \
  libreoffice-style-adwaita libreoffice-style-colibre \
  libreoffice-gtk3 libreoffice-pdfimport \
  || echo "libreoffice had issues"

# ---- CREATIVE SUITE ----
echo ">>> Installing creative tools..."
apt-get install -y gimp gimp-data gimp-plugin-fig \
  inkscape darktable rawtherapee \
  blender \
  krita \
  obs-studio \
  shotwell shotwell-common \
  eog eog-plugins \
  rhythmbox celluloid mpv \
  imagemagick imagemagick-6.q16 \
  || echo "creative had issues"

# ---- DEVELOPMENT TOOLS ----
echo ">>> Installing development tools..."
apt-get install -y build-essential gcc g++ make cmake \
  python3 python3-pip python3-venv python3-dev python3-numpy \
  default-jdk default-jre \
  git gitk git-gui \
  vim vim-common nano neovim \
  code || true \
  nodejs npm \
  php php-cli \
  ruby \
  go || true \
  rustc cargo || true \
  valgrind gdb strace ltrace \
  cloc sloccount \
  || echo "dev tools had issues"

# ---- SYSTEM TOOLS ----
echo ">>> Installing system tools..."
apt-get install -y htop btop atop glances \
  sysstat iotop iostat \
  lsof lshw lshw-gtk \
  hardinfo inxi neofetch \
  gnome-disk-activity gparted \
  synaptic aptitude dconf-editor \
  gparted testdisk foremost scalpel \
  rsync rdiff-backup \
  timeshift \
  ncdu \
  || echo "sys tools had issues"

# ---- MULTIMEDIA CODECS ----
echo ">>> Installing multimedia codecs..."
apt-get install -y \
  ubuntu-restricted-extras \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav gstreamer1.0-tools \
  ffmpeg ffmpeg-doc \
  libavcodec-extra libavformat-dev libavutil-dev \
  lame flac libvorbis-utils \
  || echo "codecs had issues"

# ---- FONTS ----
echo ">>> Installing fonts..."
apt-get install -y \
  fonts-dejavu fonts-liberation fonts-freefont-ttf \
  fonts-noto fonts-noto-color-emoji fonts-noto-cjk \
  fonts-ubuntu fonts-liberation2 \
  fonts-firacode fonts-hack \
  fonts-croscore fonts-crosextra-carlito \
  msttcorefonts || true \
  || echo "fonts had issues"

# ---- UTILITIES ----
echo ">>> Installing utilities..."
apt-get install -y \
  galculator mate-calc \
  terminator gnome-terminal xfce4-terminal \
  screenshot flameshot \
  clipman parcellite \
  keepassxc \
  filezilla \
  transmission-gtk \
  || echo "utilities had issues"

# ---- SECURITY ----
echo ">>> Installing security tools..."
apt-get install -y ufw gufw apparmor apparmor-utils \
  firejail firetools \
  keepassxc \
  fail2ban \
  lynis rkhunter chkrootkit \
  cryptsetup ecryptfs-utils \
  || echo "security had issues"

# ---- GAMES ----
echo ">>> Installing games..."
dpkg --add-architecture i386 || true
apt-get update -y || true
apt-get install -y \
  steam-installer steam-devices || true \
  lutris || true \
  wine wine32 wine64 || true \
  vulkan-tools mesa-vulkan-drivers mesa-utils \
  mangohud || true \
  0ad 0ad-data \
  supertuxkart supertuxkart-data \
  warzone2100 \
  minetest minetest-server \
  ExtremeTuxRacer \
  freedoom \
  foobillard++ || true \
  || echo "games had issues"

# ---- VIRTUALIZATION ----
echo ">>> Installing virtualization..."
apt-get install -y \
  qemu-kvm qemu-system-x86 qemu-utils \
  libvirt-daemon-system libvirt-clients \
  virt-manager virtinst \
  bridge-utils \
  || echo "virt had issues"

# ---- CONTAINERS ----
echo ">>> Installing containers..."
apt-get install -y \
  docker.io docker-compose || true \
  podman podman-compose || true \
  || echo "containers had issues"

# ---- DOCUMENTATION ----
echo ">>> Installing documentation..."
apt-get install -y \
  man-db manpages manpages-dev manpages-posix manpages-posix-dev \
  info \
  debian-handbook \
  || echo "docs had issues"

# ---- THEMES + ICONS ----
echo ">>> Installing themes..."
apt-get install -y \
  arc-theme arc-icons \
  papirus-icon-theme \
  numix-gtk-theme numix-icon-theme \
  light-themes \
  adwaita-icon-theme adwaita-qt \
  qt5ct qt6ct \
  || echo "themes had issues"

# ---- FINAL CLEANUP (keep big packages, remove caches) ----
echo ">>> Cleaning up..."
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/*.bin
echo ">>> DONE: $(dpkg-query -W -f='\${Installed-Size}\n' | awk '{s+=$1}END{printf "%.0f MB\n", s/1024}') installed"
EOF
  "$SUDO" cp "$BUILD/apt.sh" "$ROOTFS/apt-setup.sh"
  "$SUDO" chroot "$ROOTFS" bash /apt-setup.sh || echo "   apt install had warnings (continuing)"
  "$SUDO" rm -f "$ROOTFS/apt-setup.sh"
  # unmount chroot bind-mounts
  mountpoint -q "$ROOTFS/dev/pts" && "$SUDO" umount "$ROOTFS/dev/pts" 2>/dev/null || true
  mountpoint -q "$ROOTFS/proc" && "$SUDO" umount "$ROOTFS/proc" 2>/dev/null || true
  mountpoint -q "$ROOTFS/sys" && "$SUDO" umount "$ROOTFS/sys" 2>/dev/null || true
  mountpoint -q "$ROOTFS/dev" && "$SUDO" umount "$ROOTFS/dev" 2>/dev/null || true
  echo "   desktop + apps installed."
}

stage3_worlds() {
  echo "### [3/6] Baking KorrinOS worlds + os layer into rootfs..."
  "$SUDO" rm -rf "$ROOTFS/opt/korrinos"
  "$SUDO" mkdir -p "$ROOTFS/opt/korrinos"
  "$SUDO" cp -r /home/tinkerspace/linux-kernel/os "$ROOTFS/opt/korrinos/os"
  "$SUDO" cp /home/tinkerspace/linux-kernel/README.md "$ROOTFS/opt/korrinos/" 2>/dev/null || true
  "$SUDO" cp /home/tinkerspace/linux-kernel/LICENSE "$ROOTFS/opt/korrinos/" 2>/dev/null || true
  "$SUDO" cp /home/tinkerspace/linux-kernel/LICENSE "$ROOTFS/usr/share/doc/korrinos-os-copyright" 2>/dev/null || true

  # World launcher on PATH
  "$SUDO" bash -c 'cat > "$ROOTFS/usr/local/bin/parc-world" <<EOF
#!/bin/bash
exec /opt/korrinos/os/territories/modes.sh "\$@"
EOF
chmod +x /usr/local/bin/parc-world' 2>/dev/null || true

  # KorrinOS CLI on PATH
  "$SUDO" bash -c 'cat > "$ROOTFS/usr/local/bin/korrinos" <<EOF
#!/bin/bash
exec /opt/korrinos/os/parc-ai/parc-ai.sh "\$@"
EOF
chmod +x /usr/local/bin/korrinos' 2>/dev/null || true

  # KorrinOS Apps — make all os/apps/ scripts directly runnable
  "$SUDO" bash -c 'mkdir -p "$ROOTFS/usr/local/bin"
  for f in /opt/korrinos/os/apps/*.sh; do
    [ -f "$ROOTFS\$f" ] || continue
    name=$(basename "\$f" .sh)
    ln -sf "\$f" "$ROOTFS/usr/local/bin/korrinos-\$name" 2>/dev/null || true
  done
  for d in customization gaming hardware network security system; do
    for f in /opt/korrinos/os/apps/\$d/*.sh; do
      [ -f "$ROOTFS\$f" ] || continue
      name=$(basename "\$f" .sh)
      ln -sf "\$f" "$ROOTFS/usr/local/bin/korrinos-\$name" 2>/dev/null || true
    done
    done' 2>/dev/null || true

  # KorrinOS System CLI — all os/system/ scripts on PATH
  "$SUDO" bash -c 'mkdir -p "$ROOTFS/usr/local/bin"
  for d in package-manager update-system cloud-sync mobile-companion enterprise driver-manager hardware-cert installer appstore desktop-env security backup firewall; do
    for f in /opt/korrinos/os/system/\$d/korrinos-*.sh; do
      [ -f "$ROOTFS\$f" ] || continue
      name=\$(basename "\$f" .sh)
      ln -sf "\$f" "$ROOTFS/usr/local/bin/\$name" 2>/dev/null || true
    done
  done' 2>/dev/null || true

  # Systemd services for KorrinOS features
  "$SUDO" mkdir -p "$ROOTFS/etc/systemd/system"

  # Liquid Glass service
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-liquid-glass.service" <<EOF
[Unit]
Description=KorrinOS Liquid Glass Glassmorphism
After=graphical.target
Wants=graphical.target

[Service]
Type=forking
ExecStart=/opt/korrinos/os/parc-ai/korrinos-liquid-glass.sh start
ExecStop=/opt/korrinos/os/parc-ai/korrinos-liquid-glass.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

  # Widgets Panel service
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-widgets-panel.service" <<EOF
[Unit]
Description=KorrinOS Desktop Widgets Panel
After=graphical.target korrinos-liquid-glass.service
Wants=graphical.target

[Service]
Type=forking
ExecStart=/opt/korrinos/os/parc-ai/korrinos-widgets-panel.sh start
ExecStop=/opt/korrinos/os/parc-ai/korrinos-widgets-panel.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

  # Dock service
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-dock.service" <<EOF
[Unit]
Description=KorrinOS Application Dock
After=graphical.target korrinos-liquid-glass.service
Wants=graphical.target

[Service]
Type=forking
ExecStart=/opt/korrinos/os/parc-ai/korrinos-dock.sh start
ExecStop=/opt/korrinos/os/parc-ai/korrinos-dock.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

  # SmoothUI service
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-smoothui.service" <<EOF
[Unit]
Description=KorrinOS Smooth UI Compositor
After=graphical.target
Wants=graphical.target

[Service]
Type=forking
ExecStart=/opt/korrinos/os/parc-ai/korrinos-smoothui.sh start
ExecStop=/opt/korrinos/os/parc-ai/korrinos-smoothui.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

  # Backup timer service
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-backup.service" <<EOF
[Unit]
Description=KorrinOS Backup
After=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/korrinos/os/system/backup/korrinos-backup.sh full
Nice=19
IOSchedulingClass=idle

[Install]
WantedBy=multi-user.target
EOF'

  # Backup timer
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-backup.timer" <<EOF
[Unit]
Description=KorrinOS Backup Timer

[Timer]
OnCalendar=*-*-* 02:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF'

  # Firewall auto-setup service
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-firewall.service" <<EOF
[Unit]
Description=KorrinOS Firewall Setup
Before=network-pre.target

[Service]
Type=oneshot
ExecStart=/opt/korrinos/os/system/firewall/korrinos-firewall.sh setup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF'

  # Health monitor timer
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-health.timer" <<EOF
[Unit]
Description=KorrinOS Health Monitor Timer

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF'

  # Enable services
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-liquid-glass.service 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-widgets-panel.service 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-dock.service 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-smoothui.service 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-autoupdate.timer 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-backup.timer 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-firewall.service 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-health.timer 2>/dev/null || true

  # Health check service (timer references this)
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-health.service" <<EOF
[Unit]
Description=KorrinOS System Health Check

[Service]
Type=oneshot
ExecStart=/opt/korrinos/os/system/security/korrinos-health.sh check
EOF'

  # Enable display manager (LightDM)
  "$SUDO" chroot "$ROOTFS" systemctl enable lightdm.service 2>/dev/null || true

  # Create live user for ISO (korrinos/korrinos)
  "$SUDO" chroot "$ROOTFS" bash -c '
    useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,floppy,audio,dip,video,plugdev,netdev korrinos 2>/dev/null || true
    echo "korrinos:korrinos" | chpasswd 2>/dev/null || true
    echo "root:korrinos" | chpasswd 2>/dev/null || true
    # Auto-login for live session
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/autologin.conf << LGDM
[Seat:*]
autologin-user=korrinos
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
LGDM
  ' 2>/dev/null || echo "   live user setup had warnings"

  # Configure hostname
  "$SUDO" chroot "$ROOTFS" bash -c 'echo "korrinos" > /etc/hostname && echo "127.0.1.1 korrinos" >> /etc/hosts' 2>/dev/null || true

  # Auto-update service (new systems)
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-autoupdate.service" <<EOF
[Unit]
Description=KorrinOS Automatic Updates
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/korrinos/os/system/update-system/korrinos-update.sh full
Nice=19
IOSchedulingClass=idle
TimeoutStartSec=3600

[Install]
WantedBy=multi-user.target
EOF'

  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-autoupdate.timer" <<EOF
[Unit]
Description=KorrinOS Automatic Updates Timer

[Timer]
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
EOF'

  # Cloud sync service
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-cloud-sync.service" <<EOF
[Unit]
Description=KorrinOS Cloud Sync
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/korrinos/os/system/cloud-sync/korrinos-cloud.sh auto-sync
Nice=19
IOSchedulingClass=idle

[Install]
WantedBy=multi-user.target
EOF'

  "$SUDO" bash -c 'cat > "$ROOTFS/etc/systemd/system/korrinos-cloud-sync.timer" <<EOF
[Unit]
Description=KorrinOS Cloud Sync Timer

[Timer]
OnBootSec=120
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF'

  # Enable new services
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-autoupdate.timer 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-cloud-sync.timer 2>/dev/null || true

  # KorrinOS system CLI symlinks (new systems)
  "$SUDO" bash -c 'mkdir -p "$ROOTFS/usr/local/bin"
  for sys in package-manager update-system cloud-sync mobile-companion enterprise driver-manager hardware-cert installer appstore desktop-env; do
    for f in /opt/korrinos/os/system/$sys/*.sh; do
      [ -f "$ROOTFS\$f" ] || continue
      name=$(basename "\$f" .sh)
      ln -sf "\$f" "$ROOTFS/usr/local/bin/\$name" 2>/dev/null || true
    done
  done' 2>/dev/null || true

  # First-boot setup script
  "$SUDO" bash -c 'cat > "$ROOTFS/usr/local/bin/korrinos-firstboot" <<'FBEOF'
#!/bin/bash
# KorrinOS First Boot Setup — runs once on first login
MARKER="/etc/korrinos-firstboot-done"
[ -f "$MARKER" ] && exit 0

echo "Welcome to KorrinOS!"
echo "Running first-boot setup..."

# Set default wallpaper (anime city)
WALLPAPER_DIR="/usr/share/korrinos/wallpapers"
mkdir -p "$WALLPAPER_DIR"
if [ -f /opt/korrinos/os/branding/wallpaper/default.jpg ]; then
  cp /opt/korrinos/os/branding/wallpaper/default.jpg "$WALLPAPER_DIR/default.jpg"
fi
if [ -f /opt/korrinos/os/branding/plymouth/logo.png ]; then
  cp /opt/korrinos/os/branding/plymouth/logo.png "$WALLPAPER_DIR/korrinos-logo.png"
fi

# Set default background for XFCE
if command -v xfconf-query &>/dev/null; then
  xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image \
    -s "$WALLPAPER_DIR/default.jpg" 2>/dev/null || true
  xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/image-style \
    -s 5 2>/dev/null || true
fi

# Set default theme
if command -v xfconf-query &>/dev/null; then
  xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark" 2>/dev/null || true
  xfconf-query -c xsettings -p /Net/IconThemeName -s "Adwaita" 2>/dev/null || true
  xfconf-query -c xsettings -p /Gtk/FontName -s "Sans 10" 2>/dev/null || true
fi

# Auto-mount USB drives
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/korrinos-automount.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=KorrinOS Auto-Mount
Exec=/usr/bin/udiskie --automount --notify
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

# Clipboard manager
cat > ~/.config/autostart/korrinos-clipboard.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=KorrinOS Clipboard
Exec=clipman
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

# Network manager applet
cat > ~/.config/autostart/korrinos-nm-applet.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Network Manager
Exec=nm-applet --indicator
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

# Volume control applet
cat > ~/.config/autostart/korrinos-volume.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Volume Control
Exec=volumeicon
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

# Configure picom autostart
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/korrinos-liquid-glass.desktop << EOF
[Desktop Entry]
Type=Application
Name=KorrinOS Liquid Glass
Exec=/opt/korrinos/os/parc-ai/korrinos-liquid-glass.sh start
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

# Configure KorrinOS menu entry
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/korrinos-terminal.desktop << EOF
[Desktop Entry]
Type=Application
Name=KorrinOS Terminal
Comment=Open KorrinOS Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Categories=System;
EOF

# Desktop entries for os/apps/ tools
cat > ~/.local/share/applications/korrinos-app-store.desktop << EOF
[Desktop Entry]
Type=Application
Name=KorrinOS App Store
Comment=Browse and install apps
Exec=/opt/korrinos/os/apps/app-store.sh gui
Icon=system-software-install
Terminal=false
Categories=System;
EOF

cat > ~/.local/share/applications/korrinos-software-center.desktop << EOF
[Desktop Entry]
Type=Application
Name=Software Center
Comment=KorrinOS Software Center
Exec=/opt/korrinos/os/apps/software-center.sh gui
Icon=system-software-install
Terminal=false
Categories=System;
EOF

cat > ~/.local/share/applications/korrinos-ocr.desktop << EOF
[Desktop Entry]
Type=Application
Name=OCR Everywhere
Comment=Extract text from screen, images, PDFs
Exec=/opt/korrinos/os/apps/ocr-everywhere.sh gui
Icon=text-x-generic
Terminal=false
Categories=Utility;
EOF

cat > ~/.local/share/applications/korrinos-clipboard.desktop << EOF
[Desktop Entry]
Type=Application
Name=Smart Clipboard
Comment=Multi-item clipboard with search
Exec=/opt/korrinos/os/apps/smart-clipboard.sh gui
Icon=edit-paste
Terminal=false
Categories=Utility;
EOF

cat > ~/.local/share/applications/korrinos-screen-recorder.desktop << EOF
[Desktop Entry]
Type=Application
Name=Screen Recorder
Comment=Record your screen
Exec=/opt/korrinos/os/apps/screen-recorder.sh gui
Icon=media-record
Terminal=false
Categories=AudioVideo;
EOF

cat > ~/.local/share/applications/korrinos-game-mode.desktop << EOF
[Desktop Entry]
Type=Application
Name=Game Mode
Comment=Optimize system for gaming
Exec=/opt/korrinos/os/apps/gaming-mode.sh gui
Icon=preferences-system-gaming
Terminal=false
Categories=System;
EOF

touch "$MARKER"
echo "First-boot setup complete."
FBEOF
chmod +x "$ROOTFS/usr/local/bin/korrinos-firstboot" 2>/dev/null || true

  # Add firstboot to /etc/rc.local or autostart
  "$SUDO" bash -c 'cat > "$ROOTFS/etc/profile.d/korrinos-firstboot.sh" <<EOF
[ -x /usr/local/bin/korrinos-firstboot ] && /usr/local/bin/korrinos-firstboot &
EOF'

  # Default wallpaper
  "$SUDO" mkdir -p "$ROOTFS/usr/share/korrinos/wallpapers"
  "$SUDO" cp /home/tinkerspace/linux-kernel/os/branding/plymouth/logo.png "$ROOTFS/usr/share/korrinos/wallpapers/default.png" 2>/dev/null || true

  echo "   worlds + os layer + services baked in."
}

stage4_live() {
  echo "### [4/6] Preparing live image (casper layout)..."
  "$SUDO" rm -rf "$IMAGE"
  "$SUDO" mkdir -p "$IMAGE"/{casper,isolinux,install}
  echo "   staged ($(du -sh "$ROOTFS" | cut -f1) rootfs ready for squashfs)."
}

stage_branding() {
  echo "### [branding] Writing KorrinOS distribution identity into rootfs..."
  "$SUDO" bash -c "cat > '$ROOTFS/etc/os-release' <<'EOS'
PRETTY_NAME=\"KorrinOS 1.3 (jammy)\"
NAME=KorrinOS
VERSION_ID=\"1.3\"
VERSION=\"1.3 (jammy)\"
VERSION_CODENAME=jammy
ID=korrinos
ID_LIKE=ubuntu debian
HOME_URL=https://sourceforge.net/projects/korrinos/
SUPPORT_URL=https://sourceforge.net/projects/korrinos/
BUG_REPORT_URL=https://sourceforge.net/projects/korrinos/
EOS"
  "$SUDO" cp "$ROOTFS/etc/os-release" "$ROOTFS/etc/lsb-release"
  "$SUDO" bash -c "echo 'KorrinOS 1.3 (jammy) \\\\l' > '$ROOTFS/etc/issue'"
  "$SUDO" cp "$ROOTFS/etc/issue" "$ROOTFS/etc/issue.net"
  echo "   KorrinOS identity written (os-release/lsb-release/issue)."
}

# install plymouth + the branded splash/GRUB theme into an existing rootfs
# (used on incremental rebuilds; fresh builds get plymouth via stage2 apt)
stage2b_branding() {
  echo "### [branding] installing plymouth + KorrinOS boot theme into rootfs..."
  "$SUDO" mkdir -p "$ROOTFS"/{proc,sys,dev,dev/pts}
  "$SUDO" mount --bind /proc "$ROOTFS/proc" 2>/dev/null || true
  "$SUDO" mount --bind /sys  "$ROOTFS/sys"  2>/dev/null || true
  "$SUDO" mount --bind /dev  "$ROOTFS/dev"  2>/dev/null || true
  mountpoint -q "$ROOTFS/dev/pts" || "$SUDO" mount -t devpts none "$ROOTFS/dev/pts" 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends plymouth plymouth-themes plymouth-x11" \
    || echo "   plymouth install had warnings"
  "$SUDO" bash "/home/tinkerspace/linux-kernel/os/branding/install-branding.sh" "$ROOTFS" \
    || echo "   branding install had warnings"
  "$SUDO" chroot "$ROOTFS" update-initramfs -u 2>&1 | tail -1 || echo "   initramfs not updated"
  for m in dev/pts proc sys dev; do
    mountpoint -q "$ROOTFS/$m" && "$SUDO" umount "$ROOTFS/$m" 2>/dev/null || true
  done
  echo "   boot branding installed (Plymouth + GRUB theme)."
}

stage5_squashfs() {
  echo "### [5/6] Building squashfs of the full rootfs (compressing)..."
  "$SUDO" rm -f "$IMAGE/casper/filesystem.squashfs"
  "$SUDO" mksquashfs "$ROOTFS" "$IMAGE/casper/filesystem.squashfs" \
    -comp xz -b 1M -no-xattrs -processors "$(nproc)" 2>&1 | tail -4
}

# kernel + initrd into casper (fresh copy from rootfs)
stage5_caspermaterials() {
  "$SUDO" mkdir -p "$IMAGE/casper"
  # Copy kernel from rootfs (installed via apt)
  local kernel_found=""
  for k in "$ROOTFS/boot"/vmlinuz-*; do
    if [ -f "$k" ]; then
      "$SUDO" cp "$k" "$IMAGE/casper/vmlinuz"
      kernel_found=1
      echo "   kernel: $k"
      break
    fi
  done
  if [ -z "$kernel_found" ]; then
    # Fallback: host kernel
    for k in /boot/vmlinuz-*; do
      if [ -f "$k" ]; then
        "$SUDO" cp "$k" "$IMAGE/casper/vmlinuz"
        kernel_found=1
        echo "   kernel (host fallback): $k"
        break
      fi
    done
  fi
  [ -z "$kernel_found" ] && echo "   ERROR: no kernel found!"
  # Copy initrd from rootfs
  local initrd_found=""
  for i in "$ROOTFS/boot"/initrd.img-*; do
    if [ -f "$i" ] && [ ! -s "$IMAGE/casper/initrd" ]; then
      "$SUDO" cp "$i" "$IMAGE/casper/initrd"
      initrd_found=1
      echo "   initrd: $i"
      break
    fi
  done
  if [ -z "$initrd_found" ]; then
    for i in /boot/initrd.img-*; do
      if [ -f "$i" ] && [ ! -s "$IMAGE/casper/initrd" ]; then
        "$SUDO" cp "$i" "$IMAGE/casper/initrd"
        initrd_found=1
        echo "   initrd (host fallback): $i"
        break
      fi
    done
  fi
  [ -z "$initrd_found" ] && echo "   WARN: no initrd copied"
  ls -la "$IMAGE/casper/" | awk '{print $5,$9}'
}

stage6_iso() {
  echo "### [6/6] Building final bootable ISO (iso-level 3, >4GB OK)..."
  # earlier stages (mksquashfs/apt) wrote as root — hand the build dir back
  # to the real user so grub-mk* and xorriso can write without sudo.
  "$SUDO" chown -R "$(id -u):$(id -g)" "$IMAGE" "$BUILD" 2>/dev/null || true
  mkdir -p "$BUILD/grub-img"
  cat > "$BUILD/grub.cfg" <<EOF
set timeout=5
set default=0
loadfont unicode
insmod all_video
insmod gfxterm
terminal_output gfxterm

# KorrinOS GRUB theme
set theme="/boot/grub/themes/korrinos/theme.txt"

menuentry "KorrinOS 1.3 — Start" {
  linux /casper/vmlinuz boot=casper quiet splash
  initrd /casper/initrd
}
menuentry "KorrinOS 1.3 — Safe Graphics" {
  linux /casper/vmlinuz boot=casper quiet splash nomodeset
  initrd /casper/initrd
}
menuentry "KorrinOS 1.3 — Memory Test" {
  linux /casper/vmlinuz boot=casper quiet splash memtest
  initrd /casper/initrd
}
menuentry "Boot from first HDD" {
  set root=(hd0)
  chainloader +1
}
EOF
  grub-mkstandalone --format=x86_64-efi --output="$BUILD/efi.img" \
    --locales="" --fonts="" \
    "boot/grub/grub.cfg=$BUILD/grub.cfg" 2>/dev/null || \
    grub-mkimage -p /boot/grub -O x86_64-efi -o "$BUILD/efi.img" \
      iso9660 at_keyboard gfxterm gfxmenu all_video font terminal configfile normal 2>/dev/null || true
  GRUB_MODS="iso9660 biosdisk part_msdos part_gpt fat ext2 udf normal configfile search search_fs_file linux chain boot reboot gfxterm all_video"
  [ -f /usr/lib/grub/i386-pc/initrd.mod ] && GRUB_MODS="$GRUB_MODS initrd"
  grub-mkimage -p /boot/grub -O i386-pc -o "$BUILD/core.img" $GRUB_MODS 2>&1 | tail -2
  if [ -s "$BUILD/core.img" ]; then
    cat /usr/lib/grub/i386-pc/cdboot.img "$BUILD/core.img" > "$IMAGE/isolinux/isolinux.bin"
  fi
  [ -s "$BUILD/efi.img" ] && mkdir -p "$IMAGE/boot/grub" && cp "$BUILD/efi.img" "$IMAGE/boot/grub/efi.img"
  ls -la "$IMAGE/isolinux/isolinux.bin" "$IMAGE/boot/grub/efi.img" 2>/dev/null | awk '{print $5,$9}'
  xorriso -as mkisofs -quiet \
    -V KorrinOS \
    -iso-level 3 -R -J -joliet-long -full-iso9660-filenames \
    -b isolinux/isolinux.bin -c boot.cat -no-emul-boot \
    -boot-load-size 8 -boot-info-table \
    -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -o "$OUT" "$IMAGE" 2>&1 | tail -3
  echo "BUILT: $OUT"
  du -sh "$OUT"
}

run() {
  stage1 && stage2_install && stage3_worlds && stage_branding && stage2b_branding && stage4_live \
    && stage5_squashfs && stage5_caspermaterials && stage6_iso
  echo "DONE: KorrinOS full distribution ISO ready."
}

rebuild() {
  test -d "$ROOTFS/etc" || { echo "no rootfs yet — run full first"; exit 1; }
  stage2_install && stage3_worlds && stage_branding && stage2b_branding && stage4_live \
    && stage5_squashfs && stage5_caspermaterials && stage6_iso
  echo "DONE: KorrinOS rebuild (kept base rootfs)."
}

# finalize: reuse an already-built rootfs + squashfs; just (re)materialize
# casper kernel/initrd and assemble the ISO. Saves the slow compress step.
finalize() {
  [ -s "$IMAGE/casper/filesystem.squashfs" ] || {
    echo "ERROR: no squashfs at $IMAGE/casper/filesystem.squashfs — run 'build' first"
    exit 1
  }
  echo "### [finalize] reusing existing squashfs, rebuilding casper materials + ISO"
  stage5_caspermaterials && stage6_iso
  echo "DONE: KorrinOS ISO rebuilt from existing squashfs."
}

case "${1:-}" in
  full|build|run) run ;;
  rebuild) rebuild ;;
  finalize) finalize ;;
  base|stage1) stage1 ;;
  *) echo "KorrinOS Distribution Builder
Usage: ${0##*/} <build|rebuild|finalize|base>
Builds a real, full desktop Linux distribution ISO (Ubuntu/Kali-style) with
Xorg/Wayland + desktop + apps + package base + the 3 worlds baked in.
rebuild = keep rootfs, redo apt+worlds+ISO (fast iteration).
finalize = reuse existing squashfs, just rebuild casper materials + ISO." ;;
esac

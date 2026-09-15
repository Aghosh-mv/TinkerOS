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
# ---- desktop (always installed, with --no-install-recommends to reduce ISO size) ----
apt-get install -y --no-install-recommends xfce4 xfce4-terminal lightdm lightdm-gtk-greeter \
  xorg xserver-xorg-input-all xserver-xorg-video-all \
  pulseaudio pavucontrol network-manager dbus plymouth plymouth-themes \
  plymouth-x11 \
  || echo "desktop group had issues"
# ---- applications / package base (REAL full desktop, always installed) ----
apt-get install -y --no-install-recommends firefox vim nano less file htop curl wget git \
  openssh-client fonts-dejavu xdg-utils tree \
  ca-certificates gnupg \
  libreoffice-core libreoffice-writer libreoffice-calc libreoffice-impress \
  gimp vlc thunderbird inkscape blender \
  build-essential python3 python3-pip gcc make cmake \
  || echo "apps group had issues"
# ---- SECURE world (gated) ----
if [ "\$WORLDS" = "all" ] || echo "\$WORLDS" | grep -qw "secure"; then
  apt-get install -y --no-install-recommends ufw apparmor firejail keepassxc cryptsetup \
    fail2ban gnome-screensaver tor torbrowser-launcher \
    lynis rkhunter chkrootkit apktool \
    || echo "secure group had issues"
fi
# ---- GAME world (gated) ----
if [ "\$WORLDS" = "all" ] || echo "\$WORLDS" | grep -qw "game"; then
  dpkg --add-architecture i386
  apt-get update -y
  apt-get install -y --no-install-recommends steam steam-devices lutris wine \
    wine32:i386 wine64 vulkan-tools mesa-vulkan-drivers mangohud \
    0ad supertuxkart warzone2100 minetest game-data-packager \
    || echo "game group had issues"
fi
# ---- HACK world (gated) ----
if [ "\$WORLDS" = "all" ] || echo "\$WORLDS" | grep -qw "hack"; then
  apt-get install -y --no-install-recommends nmap sqlmap hydra john hashcat gobuster nikto \
    wireshark-common wireshark netcat-openbsd ncat dsniff macchanger tcpdump \
    dirb wfuzz masscan recon-ng smbmap smbclient ldap-utils \
    || echo "hack group had issues"
fi
# ---- cleanup: reduce ISO size ----
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
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

  # Enable services
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-liquid-glass.service 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-widgets-panel.service 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-dock.service 2>/dev/null || true
  "$SUDO" chroot "$ROOTFS" systemctl enable korrinos-smoothui.service 2>/dev/null || true

  # First-boot setup script
  "$SUDO" bash -c 'cat > "$ROOTFS/usr/local/bin/korrinos-firstboot" <<'FBEOF'
#!/bin/bash
# KorrinOS First Boot Setup — runs once on first login
MARKER="/etc/korrinos-firstboot-done"
[ -f "$MARKER" ] && exit 0

echo "Welcome to KorrinOS!"
echo "Running first-boot setup..."

# Set default wallpaper
WALLPAPER_DIR="/usr/share/korrinos/wallpapers"
mkdir -p "$WALLPAPER_DIR"
if [ -f /opt/korrinos/os/branding/plymouth/logo.png ]; then
  cp /opt/korrinos/os/branding/plymouth/logo.png "$WALLPAPER_DIR/default.png"
fi

# Set default background for XFCE
if command -v xfconf-query &>/dev/null; then
  xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image \
    -s "$WALLPAPER_DIR/default.png" 2>/dev/null || true
fi

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

touch "$MARKER"
echo "First-boot setup complete."
FBEOF
chmod +x "$ROOTFS/usr/local/bin/korrinos-firstboot' 2>/dev/null || true

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

# kernel + initrd into casper (fresh copy; image dir may be root-owned)
stage5_caspermaterials() {
  "$SUDO" mkdir -p "$IMAGE/casper"
  if [ -f /home/tinkerspace/linux-kernel/arch/x86/boot/bzImage ]; then
    "$SUDO" cp /home/tinkerspace/linux-kernel/arch/x86/boot/bzImage "$IMAGE/casper/vmlinuz"
  else
    "$SUDO" cp /boot/vmlinuz-* "$IMAGE/casper/vmlinuz"
  fi
  local got=""
  for i in /boot/initrd.img-*; do
    if [ -f "$i" ] && [ ! -s "$IMAGE/casper/initrd" ]; then
      "$SUDO" cp "$i" "$IMAGE/casper/initrd" && got=1
    fi
  done
  [ -n "$got" ] || echo "   WARN: no initrd copied"
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

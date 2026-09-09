#!/bin/bash
# TinkerOS REAL Distribution ISO Builder
# Builds a genuine, full desktop Linux distribution (like Ubuntu/Arch/Kali)
# with Xorg/Wayland, a desktop environment, browsers, applications, a real
# package base, AND the 3 isolated worlds (HACK/GAME/NORMAL) baked in.
#
# Structure (standard Ubuntu live-CD / casper layout):
#   rootfs/            <- debootstrap base + packages
#     casper/filesystem.squashfs
#     vmlinuz, initrd
#   TinkerOS-v1.1.iso  <- bootable, multi-GB, real OS
#
# Requires: sudo + debootstrap + mksquashfs + xorriso + internet.

set -euo pipefail

ARCH="${ARCH:-amd64}"
SUITE="${SUITE:-jammy}"                       # Ubuntu 22.04 (Pop base)
MIRROR="${MIRROR:-http://in.archive.ubuntu.com/ubuntu/}"
BUILD="${BUILD:-/home/tinkerspace/build-tinkeros}"
ROOTFS="$BUILD/rootfs"
IMAGE="$BUILD/image"
OUT="${OUT:-/home/tinkerspace/linux-kernel/TinkerOS-v1.2.iso}"
SUDO="${SUDO:-sudo}"

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

cat > "$BUILD/apt.sh" <<'EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
# ---- desktop ----
apt-get install -y xfce4 xfce4-terminal lightdm lightdm-gtk-greeter \
  xorg xserver-xorg-input-all xserver-xorg-video-all \
  pulseaudio pavucontrol network-manager dbus plymouth plymouth-themes \
  plymouth-x11 \
  || echo "desktop group had issues"
# ---- applications / package base (REAL full desktop) ----
apt-get install -y firefox vim nano less file htop curl wget git \
  openssh-client fonts-dejavu xdg-utils tree \
  ca-certificates gnupg \
  libreoffice-core libreoffice-writer libreoffice-calc libreoffice-impress \
  gimp vlc thunderbird inkscape blender \
  build-essential python3 python3-pip gcc make cmake \
  || echo "apps group had issues"
# ---- SECURE / NORMAL world (macos-like desktop security) ----
apt-get install -y ufw apparmor firejail keepassxc cryptsetup \
  fail2ban gnome-screensaver tor torbrowser-launcher \
  lynis rkhunter chkrootkit apktool \
  || echo "secure group had issues"
# ---- GAME world (steam = game mode) ----
dpkg --add-architecture i386
apt-get update -y
apt-get install -y steam steam-devices lutris wine \
  wine32:i386 wine64 vulkan-tools mesa-vulkan-drivers mangohud \
  0ad supertuxkart warzone2100 minetest game-data-packager \
  || echo "game group had issues"
# ---- HACK world (kali = hack mode) — Ubuntu-resolvable Kali-style tools ----
apt-get install -y nmap sqlmap hydra john hashcat gobuster nikto \
  wireshark-common wireshark netcat-openbsd ncat dsniff macchanger tcpdump \
  dirb wfuzz masscan recon-ng smbmap smbclient ldap-utils \
  || echo "hack group had issues"
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
  echo "### [3/6] Baking TinkerOS worlds + os layer into rootfs..."
  "$SUDO" rm -rf "$ROOTFS/opt/tinkeros"
  "$SUDO" mkdir -p "$ROOTFS/opt/tinkeros"
  "$SUDO" cp -r /home/tinkerspace/linux-kernel/os "$ROOTFS/opt/tinkeros/os"
  "$SUDO" cp /home/tinkerspace/linux-kernel/README.md "$ROOTFS/opt/tinkeros/" 2>/dev/null || true
  "$SUDO" cp /home/tinkerspace/linux-kernel/LICENSE "$ROOTFS/opt/tinkeros/" 2>/dev/null || true
  "$SUDO" cp /home/tinkerspace/linux-kernel/LICENSE "$ROOTFS/usr/share/doc/tinkeros-os-copyright" 2>/dev/null || true
  # world launcher on PATH
  "$SUDO" bash -c 'cat > "$ROOTFS/usr/local/bin/tinker-world" <<EOF
#!/bin/bash
exec /opt/tinkeros/os/territories/modes.sh "\$@"
EOF
chmod +x /usr/local/bin/tinker-world' 2>/dev/null || true
  echo "   worlds + os layer baked in."
}

stage4_live() {
  echo "### [4/6] Preparing live image (casper layout)..."
  "$SUDO" rm -rf "$IMAGE"
  "$SUDO" mkdir -p "$IMAGE"/{casper,isolinux,install}
  echo "   staged ($(du -sh "$ROOTFS" | cut -f1) rootfs ready for squashfs)."
}

stage_branding() {
  echo "### [branding] Writing TinkerOS distribution identity into rootfs..."
  "$SUDO" bash -c "cat > '$ROOTFS/etc/os-release' <<'EOS'
PRETTY_NAME=\"TinkerOS 1.2 (jammy)\"
NAME=TinkerOS
VERSION_ID=\"1.2\"
VERSION=\"1.2 (jammy)\"
VERSION_CODENAME=jammy
ID=tinkeros
ID_LIKE=ubuntu debian
HOME_URL=https://sourceforge.net/projects/tinkeros/
SUPPORT_URL=https://sourceforge.net/projects/tinkeros/
BUG_REPORT_URL=https://sourceforge.net/projects/tinkeros/
EOS"
  "$SUDO" cp "$ROOTFS/etc/os-release" "$ROOTFS/etc/lsb-release"
  "$SUDO" bash -c "echo 'TinkerOS 1.2 (jammy) \\\\l' > '$ROOTFS/etc/issue'"
  "$SUDO" cp "$ROOTFS/etc/issue" "$ROOTFS/etc/issue.net"
  echo "   TinkerOS identity written (os-release/lsb-release/issue)."
}

# install plymouth + the branded splash/GRUB theme into an existing rootfs
# (used on incremental rebuilds; fresh builds get plymouth via stage2 apt)
stage2b_branding() {
  echo "### [branding] installing plymouth + TinkerOS boot theme into rootfs..."
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
set timeout=10
menuentry "TinkerOS — tinkerOS normal" {
  linux /casper/vmlinuz boot=casper quiet splash verbose
  initrd /casper/initrd
}
menuentry "TinkerOS — tinkerOS normal (safe graphics)" {
  linux /casper/vmlinuz boot=casper quiet splash nomodeset
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
  grub-mkimage -p /boot/grub -O i386-pc -o "$BUILD/core.img" \
    iso9660 biosdisk part_msdos part_gpt fat ext2 udf normal configfile \
    search search_fs_file linux chain boot reboot gfxterm all_video 2>&1 | tail -2
  if [ -s "$BUILD/core.img" ]; then
    cat /usr/lib/grub/i386-pc/cdboot.img "$BUILD/core.img" > "$IMAGE/isolinux/isolinux.bin"
  fi
  [ -s "$BUILD/efi.img" ] && mkdir -p "$IMAGE/boot/grub" && cp "$BUILD/efi.img" "$IMAGE/boot/grub/efi.img"
  ls -la "$IMAGE/isolinux/isolinux.bin" "$IMAGE/boot/grub/efi.img" 2>/dev/null | awk '{print $5,$9}'
  xorriso -as mkisofs -quiet \
    -V TinkerOS \
    -iso-level 3 -R -J -joliet-long -full-iso9660-filenames \
    -b isolinux/isolinux.bin -c boot.cat -no-emul-boot \
    -boot-load-size 8 -boot-info-table \
    -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -o "$OUT" "$IMAGE" 2>&1 | tail -3
  echo "BUILT: $OUT"
  du -sh "$OUT"
}

run() {
  stage1 && stage2_install && stage3_worlds && stage4_live \
    && stage5_squashfs && stage6_iso
  echo "DONE: TinkerOS full distribution ISO ready."
}

run() {
  stage1 && stage2_install && stage3_worlds && stage_branding && stage2b_branding && stage4_live \
    && stage5_squashfs && stage5_caspermaterials && stage6_iso
  echo "DONE: TinkerOS full distribution ISO ready."
}

rebuild() {
  test -d "$ROOTFS/etc" || { echo "no rootfs yet — run full first"; exit 1; }
  stage2_install && stage3_worlds && stage_branding && stage2b_branding && stage4_live \
    && stage5_squashfs && stage5_caspermaterials && stage6_iso
  echo "DONE: TinkerOS rebuild (kept base rootfs)."
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
  echo "DONE: TinkerOS ISO rebuilt from existing squashfs."
}

case "${1:-}" in
  full|build|run) run ;;
  rebuild) rebuild ;;
  finalize) finalize ;;
  base|stage1) stage1 ;;
  *) echo "TinkerOS Distribution Builder
Usage: ${0##*/} <build|rebuild|finalize|base>
Builds a real, full desktop Linux distribution ISO (Ubuntu/Kali-style) with
Xorg/Wayland + desktop + apps + package base + the 3 worlds baked in.
rebuild = keep rootfs, redo apt+worlds+ISO (fast iteration).
finalize = reuse existing squashfs, just rebuild casper materials + ISO." ;;
esac

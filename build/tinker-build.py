#!/usr/bin/env python3
"""
TinkerOS Master Build Script
Integrates all components, builds ISO, packages, runs tests
"""

import os, sys, json, subprocess, shutil, hashlib, argparse
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional

class TinkerOSBuilder:
    def __init__(self, root: Path, output: Path, profile: str = "standard"):
        self.root = root
        self.output = output
        self.profile = profile
        self.os_dir = root / "os"
        self.kernel_dir = root / "linux-kernel"
        self.build_dir = Path("/tmp/tinker-build")
        self.build_dir.mkdir(parents=True, exist_ok=True)
        
        self.profiles = {
            "minimal": {"desktop": "none", "packages": ["core"]},
            "standard": {"desktop": "xfce", "packages": ["core", "apps", "dev"]},
            "gaming": {"desktop": "xfce", "packages": ["core", "gaming", "drivers"]},
            "developer": {"desktop": "xfce", "packages": ["core", "dev", "containers"]},
            "enterprise": {"desktop": "xfce", "packages": ["core", "security", "management"]},
        }
    
    def run(self, cmd: List[str], cwd: Path = None, check: bool = True) -> subprocess.CompletedProcess:
        print(f"  $ {' '.join(cmd)}")
        return subprocess.run(cmd, cwd=cwd or self.root, check=check, capture_output=True, text=True)
    
    def prepare_kernel(self) -> bool:
        print("📦 Preparing kernel...")
        if not (self.kernel_dir / "Makefile").exists():
            print("  Cloning Linux kernel v7.2.0-rc6...")
            self.run(["git", "clone", "--depth=1", "--branch=v7.2-rc6", 
                     "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git", str(self.kernel_dir)])
        
        # Apply patches
        patches = [
            ("scheduler/fair.c", "NUMA balancing fix"),
            ("scheduler/core.c", "Migration failure fix"),
            ("mm/vmalloc.c", "Huge pgd fix"),
            ("mm/page_alloc.c", "GFP_NOFS fix"),
            ("net/ipv4/tcp_bbr.c", "BBR rate probing"),
        ]
        
        for patch_file, desc in patches:
            patch_path = self.os_dir / ".." / "kernel-patches" / f"{patch_file.replace('/', '-')}.patch"
            if patch_path.exists():
                print(f"  Applying: {desc}")
                self.run(["patch", "-p1", "-i", str(patch_path)], cwd=self.kernel_dir)
        
        # Build kernel modules
        print("  Building kernel modules...")
        self.run(["make", "modules_prepare"], cwd=self.kernel_dir)
        self.run(["make", "M=terminal", "modules"], cwd=self.kernel_dir)
        
        return True
    
    def prepare_rootfs(self) -> Path:
        print("📦 Preparing rootfs...")
        rootfs = self.build_dir / "rootfs"
        if rootfs.exists():
            shutil.rmtree(rootfs)
        rootfs.mkdir(parents=True)
        
        # Bootstrap base
        base_pkgs = ["base-files", "base-passwd", "bash", "coreutils", "dash", "debconf",
                    "debianutils", "diffutils", "dpkg", "e2fsprogs", "findutils",
                    "grep", "gzip", "hostname", "init", "init-system-helpers",
                    "libc6", "libselinux1", "login", "mount", "ncurses-base",
                    "ncurses-bin", "perl-base", "sed", "sysvinit-utils",
                    "tar", "util-linux", "linux-image-generic", "linux-headers-generic",
                    "grub-pc", "grub-efi-amd64", "grub-efi-amd64-signed",
                    "shim-signed", "systemd", "systemd-sysv", "udev",
                    "network-manager", "openssh-server", "sudo", "vim", "curl", "wget"]
        
        subprocess.run([
            "debootstrap", "--arch=amd64", "--include=" + ",".join(base_pkgs),
            "noble", str(rootfs), "http://archive.ubuntu.com/ubuntu/"
        ], check=True)
        
        return rootfs
    
    def install_packages(self, rootfs: Path, packages: List[str]):
        if not packages:
            return
        print(f"  Installing {len(packages)} packages...")
        subprocess.run(["chroot", str(rootfs), "apt", "update"], check=True)
        subprocess.run(["chroot", str(rootfs), "apt", "install", "-y"] + packages, check=True)
    
    def copy_os_files(self, rootfs: Path):
        print("  Copying TinkerOS files...")
        
        # Copy scripts to /usr/lib/tinker
        tinker_lib = rootfs / "usr/lib/tinker"
        tinker_lib.mkdir(parents=True, exist_ok=True)
        
        for subdir in ["system", "apps", "desktop", "ai", "account", "onboarding", 
                       "marketplace", "tinkerai", "tinker-cowork", "terminal-history",
                       "tinker-cowork", "game-console", "mobile-companion", "hardware-cert",
                       "enterprise", "iso-builder-pro", "tinker-cowork"]:
            src = self.os_dir / subdir
            if src.exists():
                dst = tinker_lib / subdir
                shutil.copytree(src, dst, dirs_exist_ok=True)
        
        # Copy bin scripts
        bin_dir = rootfs / "usr/bin"
        for script in tinker_lib.rglob("*.sh"):
            if script.is_file():
                name = script.stem
                target = bin_dir / name
                target.write_text(f"#!/bin/bash\nbash /usr/lib/tinker/{script.relative_to(tinker_lib)} \"$@\"\n")
                target.chmod(0o755)
        
        for script in tinker_lib.rglob("*.py"):
            if script.is_file() and script.name != "__init__.py":
                name = script.stem.replace("_", "-")
                target = bin_dir / name
                target.write_text(f"#!/bin/bash\npython3 /usr/lib/tinker/{script.relative_to(tinker_lib)} \"$@\"\n")
                target.chmod(0o755)
        
        # Copy systemd services
        systemd_dir = rootfs / "etc/systemd/system"
        systemd_src = self.os_dir / "systemd"
        if systemd_src.exists():
            systemd_dir.mkdir(parents=True, exist_ok=True)
            for svc in systemd_src.glob("*.service"):
                shutil.copy2(svc, systemd_dir / svc.name)
            for timer in systemd_src.glob("*.timer"):
                shutil.copy2(timer, systemd_dir / timer.name)
        
        # Copy desktop files
        applications_dir = rootfs / "usr/share/applications"
        applications_dir.mkdir(parents=True, exist_ok=True)
        for desktop in (self.os_dir / "desktop").glob("*.desktop"):
            shutil.copy2(desktop, applications_dir / desktop.name)
        
        # Copy themes, icons, cursors
        for theme_dir in ["themes", "icons", "cursors"]:
            src = self.os_dir / theme_dir
            if src.exists():
                dst = rootfs / "usr/share" / theme_dir
                shutil.copytree(src, dst, dirs_exist_ok=True)
        
        # Copy kernel modules
        modules_dir = rootfs / "lib/modules"
        modules_dir.mkdir(parents=True, exist_ok=True)
        for ko in (self.kernel_dir / "terminal").glob("*.ko"):
            shutil.copy2(ko, modules_dir / ko.name)
        
        # Set permissions
        subprocess.run(["chroot", str(rootfs), "chmod", "+x", "/usr/bin/tinker-*"], check=True)
    
    def configure_system(self, rootfs: Path):
        print("  Configuring system...")
        
        # Hostname
        (rootfs / "etc/hostname").write_text("tinkeros")
        (rootfs / "etc/hosts").write_text("127.0.0.1\tlocalhost\n127.0.1.1\ttinkeros\n")
        
        # Default user
        subprocess.run(["chroot", str(rootfs), "useradd", "-m", "-s", "/bin/bash", "-G", "sudo", "tinkerer"], check=True)
        subprocess.run(["chroot", str(rootfs), "bash", "-c", "echo 'tinkerer:tinkerer' | chpasswd"], check=True)
        
        # Enable services
        services = ["NetworkManager", "systemd-timesyncd", "ssh", "ufw"]
        for svc in services:
            subprocess.run(["chroot", str(rootfs), "systemctl", "enable", svc], check=True)
        
        # GRUB config
        grub_cfg = rootfs / "etc/default/grub"
        content = grub_cfg.read_text()
        content = content.replace('GRUB_TIMEOUT=10', 'GRUB_TIMEOUT=5')
        content = content.replace('GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"', 
                                 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mitigations=off"')
        grub_cfg.write_text(content)
    
    def build_iso(self, rootfs: Path, output_name: str) -> Path:
        print("🏗️  Building ISO...")
        iso_dir = self.build_dir / "iso"
        if iso_dir.exists():
            shutil.rmtree(iso_dir)
        iso_dir.mkdir(parents=True)
        
        # Create casper filesystem
        casper_dir = iso_dir / "casper"
        casper_dir.mkdir(parents=True)
        
        # Copy kernel and initrd
        kernels = list((rootfs / "boot").glob("vmlinuz-*"))
        if kernels:
            latest = max(kernels, key=lambda x: x.stat().st_mtime)
            shutil.copy2(latest, casper_dir / "vmlinuz")
            initrds = list((rootfs / "boot").glob("initrd.img-*"))
            if initrds:
                latest_initrd = max(initrds, key=lambda x: x.stat().st_mtime)
                shutil.copy2(latest_initrd, casper_dir / "initrd")
        
        # Create squashfs
        subprocess.run([
            "mksquashfs", str(rootfs), str(casper_dir / "filesystem.squashfs"),
            "-comp", "zstd", "-b", "1M", "-no-xattrs", "-noappend"
        ], check=True)
        
        # Filesystem size
        size = subprocess.run(["du", "-sx", "--block-size=1", str(rootfs)],
                            capture_output=True, text=True, check=True).stdout.split()[0]
        (casper_dir / "filesystem.size").write_text(size)
        
        # GRUB config
        grub_dir = iso_dir / "boot" / "grub"
        grub_dir.mkdir(parents=True)
        (grub_dir / "grub.cfg").write_text("""
set default=0
set timeout=5

menuentry "TinkerOS" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}
menuentry "TinkerOS (Safe Graphics)" {
    linux /casper/vmlinuz boot=casper quiet splash nomodeset ---
    initrd /casper/initrd
}
""")
        
        # Create ISO
        output_file = self.output / output_name
        subprocess.run([
            "xorriso", "-as", "mkisofs", "-iso-level", "3",
            "-full-iso9660-filenames", "-volid", "TinkerOS",
            "-output", str(output_file),
            "-eltorito-boot", "boot/grub/bios.img", "-no-emul-boot",
            "-boot-load-size", "4", "-boot-info-table", "--grub2-boot-info",
            "-eltorito-catalog", "boot/grub/boot.cat",
            "-eltorito-efi", "boot/grub/efi.img", "-efi-boot-partition",
            "--efi-boot-image", "--protective-msdos-label", str(iso_dir)
        ], check=True)
        
        return output_file
    
    def build(self) -> Path:
        print(f"🚀 Building TinkerOS {self.profile}...")
        
        # Prepare
        self.prepare_kernel()
        rootfs = self.prepare_rootfs()
        
        # Install profile packages
        profile_pkgs = self.profiles.get(self.profile, {}).get("packages", [])
        pkg_map = {
            "core": ["xfce4", "lightdm", "lightdm-gtk-greeter", "thunar", "xfce4-terminal", 
                    "mousepad", "ristretto", "firefox", "vlc", "gimp", "libreoffice",
                    "thunderbird", "network-manager-gnome", "blueman", "pavucontrol"],
            "apps": ["flatpak", "snapd", "gnome-software", "flatseal"],
            "dev": ["code", "git", "docker.io", "docker-compose", "nodejs", "npm",
                   "python3", "python3-pip", "golang", "rustc", "cargo", "default-jdk"],
            "gaming": ["steam", "lutris", "wine", "winetricks", "gamemode", "mangohud",
                      "goverlay", "protonup-qt", "bottles", "discord", "obs-studio"],
            "drivers": ["nvidia-driver-550", "amdgpu-pro", "intel-media-va-driver"],
            "containers": ["podman", "buildah", "skopeo", "kind", "kubectl", "helm"],
            "security": ["apparmor", "auditd", "aide", "rkhunter", "clamav", "ufw",
                        "fail2ban", "logwatch", "veracrypt", "keepassxc"],
            "management": ["timeshift", "cockpit", "ansible", "salt-minion"],
        }
        
        all_packages = []
        for cat in profile_pkgs:
            all_packages.extend(pkg_map.get(cat, []))
        
        self.install_packages(rootfs, all_packages)
        self.copy_os_files(rootfs)
        self.configure_system(rootfs)
        
        # Build ISO
        output_name = f"TinkerOS-{self.profile}-{datetime.now().strftime('%Y%m%d')}-amd64.iso"
        iso_path = self.build_iso(rootfs, output_name)
        
        print(f"\n✅ Build complete: {iso_path}")
        print(f"   Size: {iso_path.stat().st_size / (1024**3):.2f} GB")
        
        return iso_path

def main():
    parser = argparse.ArgumentParser(description="TinkerOS Master Builder")
    parser.add_argument("--profile", choices=["minimal", "standard", "gaming", "developer", "enterprise"],
                       default="standard", help="Build profile")
    parser.add_argument("--output", default="~/Desktop/TinkerOS-ISOs", help="Output directory")
    parser.add_argument("--kernel-only", action="store_true", help="Only build kernel")
    parser.add_argument("--iso-only", action="store_true", help="Only build ISO (skip kernel)")
    args = parser.parse_args()
    
    root = Path(__file__).parent.parent
    output = Path(args.output).expanduser()
    output.mkdir(parents=True, exist_ok=True)
    
    builder = TinkerOSBuilder(root, output, args.profile)
    
    if args.kernel_only:
        builder.prepare_kernel()
    elif args.iso_only:
        rootfs = builder.prepare_rootfs()
        builder.install_packages(rootfs, [])
        builder.copy_os_files(rootfs)
        builder.configure_system(rootfs)
        builder.build_iso(rootfs, f"TinkerOS-{args.profile}-{datetime.now().strftime('%Y%m%d')}-amd64.iso")
    else:
        builder.build()

if __name__ == "__main__":
    main()

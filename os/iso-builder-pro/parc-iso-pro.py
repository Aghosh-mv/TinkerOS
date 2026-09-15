#!/usr/bin/env python3
"""
TinkerOS ISO Builder Pro
Professional ISO creation with customization, testing, and deployment
"""

import os
import json
import subprocess
import shutil
import tempfile
import hashlib
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
from datetime import datetime
import sys

@dataclass
class ISOProfile:
    name: str
    description: str
    base: str = "ubuntu"
    base_version: str = "24.04"
    desktop: str = "xfce"
    kernel: str = "7.2.0-rc6"
    architecture: str = "amd64"
    packages: List[str] = None
    remove_packages: List[str] = None
    flatpaks: List[str] = None
    snaps: List[str] = None
    custom_repos: List[Dict] = None
    kernel_params: List[str] = None
    services_enabled: List[str] = None
    services_disabled: List[str] = None
    users: List[Dict] = None
    timezone: str = "UTC"
    locale: str = "en_US.UTF-8"
    keyboard: str = "us"
    hostname: str = "tinkeros"
    enable_secure_boot: bool = False
    enable_efi: bool = True
    enable_bios: bool = True
    compression: str = "xz"
    output_name: str = ""
    
    def __post_init__(self):
        if self.packages is None: self.packages = []
        if self.remove_packages is None: self.remove_packages = []
        if self.flatpaks is None: self.flatpaks = []
        if self.snaps is None: self.snaps = []
        if self.custom_repos is None: self.custom_repos = []
        if self.kernel_params is None: self.kernel_params = []
        if self.services_enabled is None: self.services_enabled = []
        if self.services_disabled is None: self.services_disabled = []
        if self.users is None: self.users = []
        if not self.output_name:
            self.output_name = f"TinkerOS-{self.name}-{datetime.now().strftime('%Y%m%d')}"

class ISOBuilder:
    def __init__(self, work_dir: str = None):
        self.work_dir = Path(work_dir or "/tmp/tinker-iso-build")
        self.work_dir.mkdir(parents=True, exist_ok=True)
        self.profiles_dir = Path.home() / ".tinker" / "iso-profiles"
        self.profiles_dir.mkdir(parents=True, exist_ok=True)
        self.output_dir = Path.home() / "Desktop" / "TinkerOS-ISOs"
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Built-in profiles
        self.builtin_profiles = {
            "minimal": ISOProfile(
                name="minimal",
                description="Minimal TinkerOS - core system only",
                packages=["linux-generic", "linux-firmware", "grub-efi-amd64", "grub-pc",
                         "systemd", "network-manager", "openssh-server", "sudo", "vim",
                         "curl", "wget", "git", "htop", "btop", "neofetch"],
                desktop="none",
                compression="xz"
            ),
            "standard": ISOProfile(
                name="standard",
                description="Standard TinkerOS - XFCE desktop with essentials",
                desktop="xfce",
                packages=["xfce4", "xfce4-goodies", "lightdm", "lightdm-gtk-greeter",
                         "thunar", "mousepad", "xfce4-terminal", "ristretto",
                         "firefox", "vlc", "gimp", "libreoffice", "thunderbird",
                         "network-manager-gnome", "blueman", "pavucontrol",
                         "gnome-disk-utility", "gnome-system-monitor", "file-roller"],
                flatpaks=["org.mozilla.firefox", "org.videolan.VLC", "org.gimp.GIMP",
                         "org.libreoffice.LibreOffice", "com.discordapp.Discord"],
                services_enabled=["lightdm", "NetworkManager", "bluetooth", "ssh"],
                compression="xz"
            ),
            "gaming": ISOProfile(
                name="gaming",
                description="Gaming TinkerOS - optimized for gaming",
                desktop="xfce",
                kernel_params=["mitigations=off", "processor.max_cstate=1", "intel_idle.max_cstate=0",
                              "nvme_core.default_ps_max_latency_us=0"],
                packages=["xfce4", "lightdm", "steam", "lutris", "wine", "winetricks",
                         "gamemode", "mangohud", "goverlay", "protonup-qt", "bottles",
                         "discord", "obs-studio", "amdgpu-top", "radeontop"],
                flatpaks=["com.valvesoftware.Steam", "net.lutris.Lutris", "com.heroicgameslauncher.hgl",
                         "com.discordapp.Discord", "com.obsproject.Studio"],
                services_enabled=["lightdm", "NetworkManager", "gamemoded"],
                compression="zstd"
            ),
            "developer": ISOProfile(
                name="developer",
                description="Developer TinkerOS - full development environment",
                desktop="xfce",
                packages=["xfce4", "lightdm", "code", "git", "docker.io", "docker-compose",
                         "nodejs", "npm", "python3", "python3-pip", "python3-venv",
                         "golang", "rustc", "cargo", "default-jdk", "maven", "gradle",
                         "postgresql", "redis", "mongodb", "sqlite3", "redis-tools",
                         "kubernetes-cli", "helm", "terraform", "ansible", "vim", "neovim",
                         "tmux", "zsh", "fish", "htop", "btop", "lazygit", "lazydocker"],
                flatpaks=["com.visualstudio.code", "org.postgresql.pgadmin4", "io.dbeaver.DBeaverCommunity",
                         "com.getpostman.Postman", "org.insomnia.Insomnia"],
                services_enabled=["lightdm", "NetworkManager", "docker", "postgresql", "redis"],
                services_disabled=["snapd"],
                compression="xz"
            ),
            "enterprise": ISOProfile(
                name="enterprise",
                description="Enterprise TinkerOS - hardened, managed, compliant",
                desktop="xfce",
                packages=["xfce4", "lightdm", "firefox-esr", "libreoffice", "thunderbird",
                         "timeshift", "apparmor", "auditd", "aide", "rkhunter", "clamav",
                         "ufw", "fail2ban", "logwatch", "sshguard", "gnome-encfs-manager",
                         "veracrypt", "keepassxc", "nextcloud-client", "remmina",
                         "virt-manager", "qemu-kvm", "libvirt-daemon-system"],
                flatpaks=["org.mozilla.firefox", "org.libreoffice.LibreOffice", "org.keepassxc.KeePassXC"],
                services_enabled=["lightdm", "NetworkManager", "apparmor", "auditd", "ufw", "fail2ban", "libvirtd"],
                services_disabled=["bluetooth", "cups", "avahi-daemon", "modemmanager"],
                enable_secure_boot=True,
                compression="xz"
            ),
        }
    
    def save_profile(self, profile: ISOProfile):
        file = self.profiles_dir / f"{profile.name}.json"
        file.write_text(json.dumps(asdict(profile), indent=2))
    
    def load_profile(self, name: str) -> ISOProfile:
        file = self.profiles_dir / f"{name}.json"
        if file.exists():
            data = json.loads(file.read_text())
            return ISOProfile(**data)
        return self.builtin_profiles.get(name)
    
    def list_profiles(self) -> List[str]:
        profiles = list(self.builtin_profiles.keys())
        for f in self.profiles_dir.glob("*.json"):
            profiles.append(f.stem)
        return list(set(profiles))
    
    def build_iso(self, profile_name: str, output: str = None, 
                  test: bool = False, sign: bool = False) -> str:
        profile = self.load_profile(profile_name)
        if not profile:
            raise ValueError(f"Profile not found: {profile_name}")
        
        output_file = output or str(self.output_dir / f"{profile.output_name}.iso")
        
        print(f"Building TinkerOS {profile.name} ISO...")
        print(f"  Base: {profile.base} {profile.base_version}")
        print(f"  Desktop: {profile.desktop}")
        print(f"  Kernel: {profile.kernel}")
        print(f"  Packages: {len(profile.packages)}")
        print(f"  Flatpaks: {len(profile.flatpaks)}")
        print(f"  Output: {output_file}")
        
        # Create build directory
        build_dir = self.work_dir / f"build-{profile.name}-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        if build_dir.exists():
            shutil.rmtree(build_dir)
        build_dir.mkdir(parents=True)
        
        try:
            # Run build steps
            self._prepare_rootfs(build_dir, profile)
            self._install_packages(build_dir, profile)
            self._configure_system(build_dir, profile)
            self._install_flatpaks(build_dir, profile)
            self._setup_bootloader(build_dir, profile)
            self._create_squashfs(build_dir, profile)
            self._create_iso(build_dir, output_file, profile)
            
            if sign:
                self._sign_iso(output_file)
            
            if test:
                self._test_iso(output_file)
            
            # Verify
            sha256 = self._calculate_sha256(output_file)
            size = os.path.getsize(output_file) / (1024**3)
            
            print(f"\n✅ ISO built successfully!")
            print(f"  File: {output_file}")
            print(f"  Size: {size:.2f} GB")
            print(f"  SHA256: {sha256}")
            
            return output_file
            
        finally:
            # Cleanup
            if build_dir.exists():
                shutil.rmtree(build_dir, ignore_errors=True)
    
    def _prepare_rootfs(self, build_dir: Path, profile: ISOProfile):
        print("  Preparing rootfs...")
        rootfs = build_dir / "rootfs"
        rootfs.mkdir()
        
        # Bootstrap base system
        subprocess.run([
            "debootstrap", "--arch", profile.architecture,
            "--include=linux-generic,linux-firmware,grub-efi-amd64,grub-pc",
            profile.base_version, str(rootfs),
            f"http://archive.ubuntu.com/ubuntu/"
        ], check=True)
    
    def _install_packages(self, build_dir: Path, profile: ISOProfile):
        print("  Installing packages...")
        rootfs = build_dir / "rootfs"
        
        # Add custom repos
        for repo in profile.custom_repos:
            repo_line = f"deb {repo['url']} {repo['suite']} {repo['components']}"
            (rootfs / "etc/apt/sources.list.d" / f"{repo['name']}.list").write_text(repo_line)
        
        # Install packages
        if profile.packages:
            pkgs = " ".join(profile.packages)
            subprocess.run([
                "chroot", str(rootfs), "apt", "update"
            ], check=True)
            subprocess.run([
                "chroot", str(rootfs), "apt", "install", "-y"
            ] + profile.packages, check=True)
        
        # Remove packages
        if profile.remove_packages:
            pkgs = " ".join(profile.remove_packages)
            subprocess.run([
                "chroot", str(rootfs), "apt", "remove", "-y"
            ] + profile.remove_packages, check=True)
    
    def _configure_system(self, build_dir: Path, profile: ISOProfile):
        print("  Configuring system...")
        rootfs = build_dir / "rootfs"
        
        # Hostname
        (rootfs / "etc/hostname").write_text(profile.hostname)
        (rootfs / "etc/hosts").write_text(f"127.0.0.1\tlocalhost\n127.0.1.1\t{profile.hostname}\n")
        
        # Timezone
        subprocess.run(["chroot", str(rootfs), "ln", "-sf", 
                       f"/usr/share/zoneinfo/{profile.timezone}", "/etc/localtime"], check=True)
        
        # Locale
        (rootfs / "etc/locale.gen").write_text(f"{profile.locale} UTF-8\n")
        subprocess.run(["chroot", str(rootfs), "locale-gen"], check=True)
        
        # Keyboard
        (rootfs / "etc/default/keyboard").write_text(f'XKBLAYOUT="{profile.keyboard}"\n')
        
        # Users
        for user in profile.users:
            subprocess.run(["chroot", str(rootfs), "useradd", "-m", "-s", "/bin/bash", user["name"]], check=True)
            if "password" in user:
                subprocess.run(["chroot", str(rootfs), "bash", "-c", 
                               f"echo '{user['name']}:{user['password']}' | chpasswd"], check=True)
            if user.get("sudo", False):
                subprocess.run(["chroot", str(rootfs), "usermod", "-aG", "sudo", user["name"]], check=True)
        
        # Default user
        subprocess.run(["chroot", str(rootfs), "useradd", "-m", "-s", "/bin/bash", "tinkerer"], check=True)
        subprocess.run(["chroot", str(rootfs), "usermod", "-aG", "sudo", "tinkerer"], check=True)
        
        # Services
        for svc in profile.services_enabled:
            subprocess.run(["chroot", str(rootfs), "systemctl", "enable", svc], check=True)
        for svc in profile.services_disabled:
            subprocess.run(["chroot", str(rootfs), "systemctl", "disable", svc], check=True)
        
        # Kernel parameters
        if profile.kernel_params:
            params = " ".join(profile.kernel_params)
            grub_cfg = rootfs / "etc/default/grub"
            content = grub_cfg.read_text()
            content = content.replace('GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"',
                                    f'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash {params}"')
            grub_cfg.write_text(content)
    
    def _install_flatpaks(self, build_dir: Path, profile: ISOProfile):
        if not profile.flatpaks:
            return
        print("  Installing Flatpaks...")
        rootfs = build_dir / "rootfs"
        # Flatpak installation happens at first boot via script
        script = rootfs / "usr/local/bin/tinker-flatpak-setup"
        script.parent.mkdir(parents=True, exist_ok=True)
        content = "#!/bin/bash\nflatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo\n"
        for fp in profile.flatpaks:
            content += f"flatpak install -y flathub {fp}\n"
        script.write_text(content)
        script.chmod(0o755)
    
    def _setup_bootloader(self, build_dir: Path, profile: ISOProfile):
        print("  Setting up bootloader...")
        rootfs = build_dir / "rootfs"
        
        # GRUB config
        grub_dir = build_dir / "iso" / "boot" / "grub"
        grub_dir.mkdir(parents=True)
        
        # Copy kernel and initrd
        kernels = list((rootfs / "boot").glob("vmlinuz-*"))
        if kernels:
            latest = max(kernels, key=lambda x: x.stat().st_mtime)
            shutil.copy(latest, build_dir / "iso" / "casper" / "vmlinuz")
            
            initrds = list((rootfs / "boot").glob("initrd.img-*"))
            latest_initrd = max(initrds, key=lambda x: x.stat().st_mtime)
            shutil.copy(latest_initrd, build_dir / "iso" / "casper" / "initrd")
        
        # GRUB config
        (grub_dir / "grub.cfg").write_text(f"""
set default=0
set timeout=10

menuentry "TinkerOS {profile.name}" {{
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}}

menuentry "TinkerOS {profile.name} (Safe Graphics)" {{
    linux /casper/vmlinuz boot=casper quiet splash nomodeset ---
    initrd /casper/initrd
}}

menuentry "TinkerOS {profile.name} (Install)" {{
    linux /casper/vmlinuz boot=casper only-ubiquity quiet splash ---
    initrd /casper/initrd
}}
""")
    
    def _create_squashfs(self, build_dir: Path, profile: ISOProfile):
        print("  Creating squashfs...")
        rootfs = build_dir / "rootfs"
        casper_dir = build_dir / "iso" / "casper"
        casper_dir.mkdir(parents=True)
        
        subprocess.run([
            "mksquashfs", str(rootfs), str(casper_dir / "filesystem.squashfs"),
            "-comp", profile.compression, "-b", "1M", "-no-xattrs", "-noappend"
        ], check=True)
        
        # Filesystem size
        size = subprocess.run(["du", "-sx", "--block-size=1", str(rootfs)],
                            capture_output=True, text=True, check=True).stdout.split()[0]
        (casper_dir / "filesystem.size").write_text(size)
    
    def _create_iso(self, build_dir: Path, output_file: str, profile: ISOProfile):
        print("  Creating ISO...")
        iso_dir = build_dir / "iso"
        
        # EFI boot
        efi_dir = iso_dir / "EFI" / "BOOT"
        efi_dir.mkdir(parents=True)
        
        # Use xorriso
        subprocess.run([
            "xorriso", "-as", "mkisofs",
            "-iso-level", "3",
            "-full-iso9660-filenames",
            "-volid", f"TinkerOS_{profile.name}",
            "-output", output_file,
            "-eltorito-boot", "boot/grub/bios.img",
            "-no-emul-boot", "-boot-load-size", "4",
            "-boot-info-table", "--grub2-boot-info",
            "-eltorito-catalog", "boot/grub/boot.cat",
            "-eltorito-efi", "boot/grub/efi.img",
            "-efi-boot-partition", "--efi-boot-image",
            "--protective-msdos-label",
            str(iso_dir)
        ], check=True)
    
    def _sign_iso(self, iso_file: str):
        print("  Signing ISO...")
        # GPG sign
        subprocess.run(["gpg", "--detach-sign", "--armor", iso_file], check=True)
    
    def _test_iso(self, iso_file: str):
        print("  Testing ISO in QEMU...")
        subprocess.run([
            "qemu-system-x86_64", "-cdrom", iso_file,
            "-m", "2G", "-cpu", "host", "-enable-kvm",
            "-display", "none", "-daemonize"
        ], check=True)
        time.sleep(30)
        subprocess.run(["pkill", "qemu-system-x86_64"])
    
    def _calculate_sha256(self, file_path: str) -> str:
        sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha256.update(chunk)
        return sha256.hexdigest()

def main():
    import argparse
    parser = argparse.ArgumentParser(description="TinkerOS ISO Builder Pro")
    parser.add_argument("profile", help="Profile name")
    parser.add_argument("-o", "--output", help="Output file")
    parser.add_argument("--test", action="store_true", help="Test in QEMU")
    parser.add_argument("--sign", action="store_true", help="GPG sign ISO")
    parser.add_argument("--list", action="store_true", help="List profiles")
    args = parser.parse_args()
    
    builder = ISOBuilder()
    
    if args.list:
        print("Available profiles:")
        for name in builder.list_profiles():
            profile = builder.load_profile(name)
            print(f"  {name}: {profile.description}")
        return
    
    if not args.profile:
        parser.error("Profile required")
    
    builder.build_iso(args.profile, args.output, args.test, args.sign)

if __name__ == "__main__":
    main()

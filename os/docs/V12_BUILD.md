# TinkerOS v1.2 — THE REAL FULL DISTRIBUTION

Goal: a REAL, multi-GB bootable OS. NOT a 600MB stub.

The v1.1 mistake:
- Stock Ubuntu kernel in casper/vmlinuz (NOT our tree's TinkerOS kernel)
- Only a basic desktop + os/ scripts baked in
- Steam, Kali-style tools, secure-mode real apps: NOT installed

## v1.2 build plan (research-backed)

### 1. Kernel — TinkerOS's OWN, compiled from this tree
- `arch/x86/boot/bzImage` built from `linux-kernel` tree with:
  - CONFIG_TINKER_FEATURES=y, CONFIG_TINKER_CORE=y
  - CONFIG_TINKER_THERMAL_SCHED=y, GAMEMODE=y, ENERGY_SCHED=y,
    BATTERY_LIFE=y, OLED_WEAR=y, CACHE_TIERING=y, COIL_WHINE=y, SHREDDER=y
  - gamemode RT-priority boost hook in kernel/sched/syscalls.c
- kernels own initrd built with the host `/boot/initrd.img-*` modules path

### 2. World = mode (user's exact words)
- "steam means the game mode and kali means the hack mode and macos means
  the normal secure mode"
- So the worlds are baked REAL apps, not just scripts:
  - NORMAL/secure = macos-like secure desktop: ufw, apparmor, firejail,
    keepassxc, cryptsetup/luks, gnome-screensaver, fail2ban, tor
  - GAME = real gaming: steam, proton, wine, lutris, vulkan/shaderc,
    mesa-vulkan-drivers, gamemode umbrella, mangohud, + libreoffice etc
  - HACK = real pentest distro (Kali-style): nmap, sqlmap, metasploit,
    aircrack-ng, hashcat, hydra, john, gobuster, nikto, wireshark,
    burpsuite, netcat, ncat, dsniff, macchanger, tcpdump, + our tinker
    hack scripts

### 3. Desktop / apps / base (real full OS)
- xfce4 + lightdm greeter + xorg + pulse + network-manager
- firefox, vim, nano, git, curl, wget, htop, file, tree
- LibreOffice full (writer/calc/impress)  <-- BIG real apps
- GIMP, vlc
- build-essential, python3, pip, gcc, make, cmake
- all those = real multi-GB content

### 4. Baking
- `/opt/tinkeros/os` + worlds + modes.sh + tinker-world launcher
- casper live layout + squashfs (xz or gzip for size/speed balance)
- grub-mkrescue ISO, TinkerOS-v1.2.iso (expect MULTI-GB)

## Verification
- file TinkerOS-v1.2.iso  -> ISO 9660, bootable
- unsquashfs -ll casper/filesystem.squashfs | grep -E opt/tinkeros|usr/bin/nmap|usr/lib/steam
- bzImage inside IS 'TinkerOS' built tree kernel (128MB expected)
- du -sh -> GBs not MBs
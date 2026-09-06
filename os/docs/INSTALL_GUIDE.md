# TinkerOS Installation Guide

## System Requirements

### Minimum
- CPU: 1 GHz dual-core
- RAM: 2 GB
- Storage: 20 GB
- USB: 8 GB for installation media

### Recommended
- CPU: 2 GHz quad-core
- RAM: 4 GB
- Storage: 50 GB SSD
- Network: WiFi or Ethernet

---

## Creating Installation Media

### Linux
```bash
# Find USB device
lsblk

# Write ISO to USB (replace /dev/sdX with your USB)
sudo dd if=TinkerOS.iso of=/dev/sdX bs=4M status=progress
sync
```

### Windows
1. Download Rufus or Etcher
2. Select TinkerOS ISO
3. Select USB device
4. Click Start

### macOS
1. Download Etcher
2. Select TinkerOS ISO
3. Select USB device
4. Click Flash!

---

## Booting from USB

### Enter BIOS/UEFI
- Restart computer
- Press F2, F12, DEL, or ESC during boot
- Navigate to Boot menu

### Select USB
- Move USB to top of boot order
- Save and exit

---

## Installation Steps

### Step 1: Boot TinkerOS
1. Select "Install TinkerOS"
2. Wait for live desktop to load

### Step 2: Start Installer
1. Double-click "Install TinkerOS"
2. Select language
3. Click Continue

### Step 3: Partitioning

#### Option A: Erase Disk (Recommended)
- Erases entire disk
- Creates automatic partitions
- Best for most users

#### Option B: Manual Partitioning
- Create partitions manually
- For advanced users

**Recommended Layout:**
```
/        20GB    ext4    (root)
/boot    1GB     ext4    (boot)
/home    rest    ext4    (home)
swap     2GB     swap    (swap)
```

### Step 4: User Setup
1. Enter your name
2. Create username
3. Set password
4. Choose computer name

### Step 5: Confirm
1. Review settings
2. Click "Install"
3. Wait for installation to complete

### Step 6: Reboot
1. Remove USB when prompted
2. Press Enter
3. System will reboot

---

## Post-Installation

### First Boot
1. Login with your username and password
2. Setup Wizard will start
3. Follow the prompts

### Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### Install Drivers
```bash
sudo ubuntu-drivers autoinstall  # Ubuntu
sudo mhwd -i video-nvidia        # Manjaro
```

### Enable Firewall
```bash
sudo ufw enable
```

---

## Dual Boot Setup

### Windows + TinkerOS
1. Install Windows first
2. Shrink Windows partition
3. Install TinkerOS on free space
4. GRUB will show both OS

### Boot Order
1. Restart computer
2. Press F12 during boot
3. Select operating system

---

## Troubleshooting Installation

### Boot fails
- Try "Safe Graphics" mode
- Disable Secure Boot in BIOS
- Check USB integrity

### No WiFi
- Use Ethernet cable
- Install WiFi drivers manually
- Check hardware compatibility

### Black screen
- Try nomodeset kernel parameter
- Update graphics drivers
- Check monitor compatibility

---

## Post-Install Checklist

- [ ] System updated
- [ ] Drivers installed
- [ ] Firewall enabled
- [ ] User account configured
- [ ] Desktop customized
- [ ] Essential apps installed
- [ ] Backup configured

---

## Getting Help

If you encounter issues:
1. Check installation media
2. Verify hardware compatibility
3. Try live USB first
4. Search online forums
5. Ask community for help

Welcome to TinkerOS!

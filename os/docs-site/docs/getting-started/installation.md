# Installation Guide

## Download

Visit [tinkeros.dev/download](https://tinkeros.dev/download) and download the latest ISO for your architecture.

## Creating Installation Media

### Linux/macOS
```bash
# Find your USB device
lsblk

# Write ISO (replace /dev/sdX with your USB)
sudo dd if=TinkerOS.iso of=/dev/sdX bs=4M status=progress
sync
```

### Windows
1. Download [Rufus](https://rufus.ie) or [Etcher](https://etcher.io)
2. Select the TinkerOS ISO
3. Select your USB drive
3. Click **Start**

## Booting

1. Insert USB and restart computer
2. Enter BIOS/UEFI (usually F2, F12, Del, or Esc)
3. Set USB as first boot device
4. Save and exit

## Installation Steps

1. Select **"Install TinkerOS"** from GRUB menu
2. Choose language
3. Connect to WiFi (optional)
4. Select installation type:
   - **Erase Disk** - Recommended for most users
   - **Manual Partitioning** - Advanced users
5. Create your user account
6. Wait for installation (~5-10 minutes)
7. Remove USB and reboot

## Post-Install

On first boot, the **Setup Wizard** will guide you through:
- Creating your TinkerID
- Choosing theme and preferences
- Installing essential apps
- Enabling advanced features

---

*Need help? Join our [Discord](https://discord.gg/tinkeros) for live support.*

# TinkerOS - A Complete Linux Distribution for Everyone

## Vision
A complete, polished Linux operating system that anyone can use as their permanent daily driver, replacing Windows or macOS. Built on the latest Linux kernel with smart features that "just work."

## Design Principles
1. **Zero Learning Curve** - If you can use Windows, you can use TinkerOS
2. **Hardware First** - Auto-detect and configure all hardware
3. **Gaming Ready** - Steam/Proton out of the box
4. **Developer Friendly** - Tools for coders built-in
5. **Privacy by Default** - No telemetry, no tracking
6. **Beautiful UI** - Modern, clean, responsive design

## System Requirements

### Minimum
- CPU: 64-bit processor (Intel Core 2 Duo / AMD Athlon 64 X2 or newer)
- RAM: 2 GB
- Storage: 20 GB
- GPU: Any with Mesa support
- Network: Ethernet or WiFi

### Recommended
- CPU: Intel Core i5/AMD Ryzen 5 or newer
- RAM: 8 GB
- Storage: 100 GB SSD
- GPU: NVIDIA GTX 1060 / AMD RX 580 or newer
- Network: WiFi 6 or Ethernet

## Features

### Smart Input System
- Accent character picker (long-press any key)
- Smart autocorrect everywhere with ghost text
- Real-time unit converter
- Timestamp converter
- Clipboard history (50 items)
- Emoji picker

### Desktop Experience
- Modern Wayland compositor
- Smooth animations (60fps)
- Multi-monitor support
- Touchpad gestures
- Night light (auto blue light filter)
- Focus mode (block notifications)
- Quick notes widget

### Gaming
- Steam/Proton pre-installed
- NVIDIA/AMD driver auto-detection
- Gaming mode (optimize CPU/GPU/network)
- Controller support
- Low-latency audio

### Developer Tools
- Terminal with autocomplete
- Built-in code editor
- Docker/Podman support
- Git integration
- Language runtimes (Python, Node, Rust, Go)

### Security
- Automatic updates
- Firewall enabled by default
- App sandboxing (Flatpak)
- Full-disk encryption option
- Secure boot support

## Architecture

```
TinkerOS/
├── kernel/          # Custom Linux kernel with smart features
├── system/          # Core system services
│   ├── init/        # System initialization
│   ├── dbus/        # System bus
│   └── systemd/     # Service manager
├── desktop/         # Desktop environment
│   ├── compositor/  # Wayland compositor
│   ├── shell/       # Desktop shell (panels, menus)
│   ├── settings/    # System settings
│   └── apps/        # Core applications
├── apps/            # User applications
│   ├── browser/     # Web browser
│   ├── terminal/    # Terminal emulator
│   ├── files/       # File manager
│   ├── editor/      # Text editor
│   ├── media/       # Media players
│   └── office/      # Office suite
├── drivers/         # Hardware drivers
│   ├── gpu/         # Graphics drivers
│   ├── audio/       # Audio drivers
│   ├── network/     # Network drivers
│   └── input/       # Input device drivers
├── packages/        # Package management
│   ├── apt/         # Package manager
│   ├── flatpak/     # App sandboxing
│   └── snap/        # Universal packages
└── installer/       # System installer
```

## Build Instructions

### Prerequisites
```bash
# Install build dependencies
sudo apt install build-essential libncurses-dev bison flex libssl-dev
sudo apt install libelf-dev dwarves python3
```

### Build Kernel
```bash
cd linux-kernel
make menuconfig  # Configure kernel
make -j$(nproc)  # Build kernel
sudo make modules_install
sudo make install
```

### Build Desktop
```bash
cd os/desktop
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

## Configuration

### Smart Features Config
Access via `/proc/smart_input/` or Settings → Smart Features

### Gaming Mode
Access via Settings → Gaming or run `tinker-gaming-mode`

### System Updates
```bash
tinker-update check    # Check for updates
tinker-update apply    # Apply updates
```

## Support
- Website: https://tinkerOS.org
- Documentation: https://docs.tinkerOS.org
- Community: https://community.tinkerOS.org
- Bug Reports: https://bugs.tinkerOS.org

## License
TinkerOS is free software, licensed under GPL v2.
See COPYING file for details.

## Credits
- Linux Kernel Team
- TinkerOS Contributors
- Open Source Community

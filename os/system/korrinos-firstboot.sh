#!/bin/bash
# KorrinOS First Boot Setup - runs once on first login
MARKER="/etc/korrinos-firstboot-done"
[ -f "$MARKER" ] && exit 0

echo "Welcome to KorrinOS!"
echo "Running first-boot setup..."

# Set default wallpaper
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

# Configure KorrinOS Desktop autostart
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/korrinos-desktop.desktop << EOF
[Desktop Entry]
Type=Application
Name=KorrinOS Desktop
Exec=/opt/korrinos/os/desktop/nibra-style/nibra-shell.sh start
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
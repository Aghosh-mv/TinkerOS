#!/bin/bash
# TinkerOS Desktop Integration
# Integrates with XFCE, GNOME, KDE for seamless experience

set -e

DESKTOP_DIR="$HOME/.tinker/desktop"
CONFIG_FILE="$DESKTOP_DIR/integration.conf"
AUTOSTART_DIR="$HOME/.config/autostart"
PLUGINS_DIR="$HOME/.tinker/plugins"

mkdir -p "$DESKTOP_DIR" "$AUTOSTART_DIR" "$PLUGINS_DIR"

# Initialize
init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Desktop Integration Configuration

# Auto-detect desktop environment
AUTO_DETECT=true

# Preferred DE (xfce, gnome, kde, mate, cinnamon)
PREFERRED_DE=auto

# Enable TinkerOS panel
ENABLE_PANEL=true

# Enable TinkerOS dock
ENABLE_DOCK=true

# Enable TinkerOS app launcher
ENABLE_LAUNCHER=true

# Enable global hotkeys
ENABLE_HOTKEYS=true

# Enable desktop widgets
ENABLE_WIDGETS=false
EOF
    fi
}

# Detect desktop environment
detect_de() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]'
    elif [ -n "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION" | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

# ============================================
# XFCE Integration
# ============================================

setup_xfce() {
    echo "Setting up XFCE integration..."
    
    # Create panel
    if [ ! -d ~/.config/xfce4/panel ]; then
        mkdir -p ~/.config/xfce4/panel
    fi
    
    # Add TinkerOS items to panel
    xfce4-panel --add-item 2>/dev/null || true
    
    # Create desktop launcher
    cat > ~/Desktop/tinker-apps.desktop << 'EOF'
[Desktop Entry]
Name=TinkerOS Apps
Comment=TinkerOS Application Launcher
Exec=/usr/lib/tinker/desktop/app-launcher.sh
Icon=applications-other
Type=Application
Categories=System;
EOF
    chmod +x ~/Desktop/tinker-apps.desktop
    
    # Add to autostart
    cat > "$AUTOSTART_DIR/tinker-desktop.desktop" << 'EOF'
[Desktop Entry]
Name=TinkerOS Desktop
Comment=TinkerOS Desktop Components
Exec=/usr/lib/tinker/desktop/start-desktop.sh
Icon=tinker
Type=Application
X-GNOME-Autostart-enabled=true
EOF
    
    echo "XFCE integration complete"
}

# ============================================
# GNOME Integration
# ============================================

setup_gnome() {
    echo "Setting up GNOME integration..."
    
    # Create GNOME Shell extension
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/tinker@tinkeros"
    mkdir -p "$ext_dir"
    
    cat > "$ext_dir/metadata.json" << 'EOF'
{
    "uuid": "tinker@tinkeros",
    "name": "TinkerOS Desktop",
    "description": "TinkerOS desktop integration",
    "shell-version": ["42", "43", "44"],
    "url": "https://tinkeros.dev"
}
EOF
    
    # Create extension.js
    cat > "$ext_dir/extension.js" << 'EOF'
const St = imports.gi.St;
const Main = imports.ui.main;
const GLib = imports.gi.GLib;

let tinkerPanel;

function init() {
    tinkerPanel = new St.BoxLayout({
        style_class: 'tinker-panel',
        vertical: false
    });
}

function enable() {
    Main.panel._addToChrome(tinkerPanel);
    let indicator = new St.Button({
        child: new St.Label({ text: "TinkerOS" }),
        style_class: 'tinker-button'
    });
    tinkerPanel.add(indicator);
}

function disable() {
    tinkerPanel.destroy();
}
EOF
    
    # Add to autostart
    cat > "$AUTOSTART_DIR/tinker-desktop.desktop" << 'EOF'
[Desktop Entry]
Name=TinkerOS Desktop
Comment=TinkerOS Desktop Components
Exec=/usr/lib/tinker/desktop/start-desktop.sh
Icon=tinker
Type=Application
X-GNOME-Autostart-enabled=true
EOF
    
    echo "GNOME integration complete"
}

# ============================================
# KDE Integration
# ============================================

setup_kde() {
    echo "Setting up KDE integration..."
    
    # Create plasma widget
    local widget_dir="$HOME/.local/share/plasma/plasmoids/tinker"
    mkdir -p "$widget_dir/contents/ui"
    
    cat > "$widget_dir/metadata.desktop" << 'EOF'
[Desktop Entry]
Name=TinkerOS
Comment=TinkerOS Desktop Integration
Type=PlasmaApplet
X-KDE-PluginInfo-Name=tinker
X-KDE-ParentApp=desktop
X-Plasma-API=declarativeappletscript
EOF
    
    # Add to autostart
    cat > "$AUTOSTART_DIR/tinker-desktop.desktop" << 'EOF'
[Desktop Entry]
Name=TinkerOS Desktop
Comment=TinkerOS Desktop Components
Exec=/usr/lib/tinker/desktop/start-desktop.sh
Icon=tinker
Type=Application
X-KDE-AutostartPhase=autostart3
X-KDE-Autostart-enabled=true
EOF
    
    echo "KDE integration complete"
}

# ============================================
# Universal Integration
# ============================================

# Create global hotkeys
setup_hotkeys() {
    echo "Setting up global hotkeys..."
    
    local de=$(detect_de)
    
    case $de in
        xfce|xfce4)
            # XFCE hotkeys
            xfconf-query -c xfce4-keyboard-shortcuts -p "/custom/Custom0" -s "tinker-launcher" 2>/dev/null || true
            ;;
        gnome|ubuntu)
            # GNOME hotkeys
            gsettings set org.gnome.desktop.wm.keybindings show-desktop "['<Super>d']" 2>/dev/null || true
            gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Super>e']" 2>/dev/null || true
            ;;
        kde|plasma)
            # KDE hotkeys
            kwriteconfig5 --file kwinrc --group ModifierOnlyShortcuts --key "ShowDesktop" "tinker-desktop" 2>/dev/null || true
            ;;
    esac
    
    echo "Hotkeys configured"
}

# Create desktop shortcuts
create_shortcuts() {
    echo "Creating desktop shortcuts..."
    
    local shortcuts=(
        "tinker-settings:Settings:preferences-system"
        "tinker-files:Files:system-file-manager"
        "tinker-terminal:Terminal:utilities-terminal"
        "tinker-apps:Apps:applications-other"
    )
    
    for shortcut in "${shortcuts[@]}"; do
        IFS=':' read -r cmd name icon <<< "$shortcut"
        
        cat > ~/Desktop/$name.desktop << EOF
[Desktop Entry]
Name=$name
Comment=TinkerOS $name
Exec=/usr/lib/tinker/apps/$cmd.sh
Icon=$icon
Type=Application
EOF
        chmod +x ~/Desktop/$name.desktop
    done
    
    echo "Shortcuts created"
}

# Setup panel integration
setup_panel() {
    echo "Setting up TinkerOS panel..."
    
    local de=$(detect_de)
    
    case $de in
        xfce|xfce4)
            # Add to XFCE panel
            xfce4-panel --add-item 2>/dev/null || true
            ;;
        gnome|ubuntu)
            # GNOME panel integration
            echo "GNOME panel uses built-in TinkerOS extension"
            ;;
        kde|plasma)
            # KDE panel integration
            echo "KDE panel uses built-in TinkerOS widget"
            ;;
    esac
    
    echo "Panel configured"
}

# Full setup
full_setup() {
    echo "Running full desktop integration..."
    echo ""
    
    local de=$(detect_de)
    echo "Detected desktop: $de"
    echo ""
    
    case $de in
        xfce|xfce4) setup_xfce ;;
        gnome|ubuntu) setup_gnome ;;
        kde|plasma) setup_kde ;;
        *)
            echo "Unknown desktop, using universal setup"
            ;;
    esac
    
    setup_hotkeys
    create_shortcuts
    setup_panel
    
    echo ""
    echo "Desktop integration complete!"
    echo "Please log out and back in for changes to take effect."
}

show_status() {
    echo "Desktop Integration Status:"
    echo ""
    echo "  Desktop: $(detect_de)"
    echo "  Autostart: $([ -f "$AUTOSTART_DIR/tinker-desktop.desktop" ] && echo 'Configured' || echo 'Not configured')"
    echo ""
    echo "Components:"
    echo "  Panel: $(grep "ENABLE_PANEL" "$CONFIG_FILE" | cut -d= -f2)"
    echo "  Dock: $(grep "ENABLE_DOCK" "$CONFIG_FILE" | cut -d= -f2)"
    echo "  Launcher: $(grep "ENABLE_LAUNCHER" "$CONFIG_FILE" | cut -d= -f2)"
    echo "  Hotkeys: $(grep "ENABLE_HOTKEYS" "$CONFIG_FILE" | cut -d= -f2)"
}

show_help() {
    echo "Usage: tinker-desktop-integration [command]"
    echo ""
    echo "Commands:"
    echo "  setup             Full desktop integration"
    echo "  xfce              Setup XFCE integration"
    echo "  gnome             Setup GNOME integration"
    echo "  kde               Setup KDE integration"
    echo "  hotkeys           Setup global hotkeys"
    echo "  shortcuts         Create desktop shortcuts"
    echo "  panel             Setup panel integration"
    echo "  status            Show integration status"
    echo "  help              Show this help"
}

init

case "$1" in
    setup|install) full_setup ;;
    xfce) setup_xfce ;;
    gnome) setup_gnome ;;
    kde) setup_kde ;;
    hotkeys) setup_hotkeys ;;
    shortcuts) create_shortcuts ;;
    panel) setup_panel ;;
    status) show_status ;;
    *) show_help ;;
esac

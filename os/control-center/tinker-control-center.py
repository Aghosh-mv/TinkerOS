#!/usr/bin/env python3
"""
TinkerOS Control Center
Unified GUI for all 130+ TinkerOS features
"""

import sys
import os
import subprocess
import json
from pathlib import Path

# Add control center to path
sys.path.insert(0, str(Path(__file__).parent))

from PyQt6.QtWidgets import *
from PyQt6.QtCore import *
from PyQt6.QtGui import *
from PyQt6.QtSvg import *

class TinkerOSControlCenter(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("TinkerOS Control Center")
        self.setMinimumSize(1200, 800)
        self.setup_ui()
        self.load_features()
        
    def setup_ui(self):
        # Main widget
        central = QWidget()
        self.setCentralWidget(central)
        
        # Main layout
        layout = QHBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        # Sidebar
        self.sidebar = self.create_sidebar()
        layout.addWidget(self.sidebar)
        
        # Content area
        self.content_stack = QStackedWidget()
        layout.addWidget(self.content_stack)
        
        # Apply theme
        self.apply_theme()
        
    def create_sidebar(self):
        sidebar = QFrame()
        sidebar.setObjectName("sidebar")
        sidebar.setFixedWidth(280)
        
        layout = QVBoxLayout(sidebar)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        # Logo/Title
        header = QFrame()
        header.setFixedHeight(100)
        header_layout = QVBoxLayout(header)
        header_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        logo = QLabel("🦝")
        logo.setFont(QFont("Noto Sans", 32))
        logo.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        title = QLabel("TinkerOS")
        title.setFont(QFont("Inter", 18, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setStyleSheet("color: #00D4AA;")
        
        subtitle = QLabel("Control Center")
        subtitle.setFont(QFont("Inter", 11))
        subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        subtitle.setStyleSheet("color: #888;")
        
        header_layout.addWidget(logo)
        header_layout.addWidget(title)
        header_layout.addWidget(subtitle)
        layout.addWidget(header)
        
        # Search
        search = QLineEdit()
        search.setPlaceholderText("🔍 Search settings...")
        search.setStyleSheet("""
            QLineEdit {
                background: #1e1e2e;
                border: none;
                border-radius: 8px;
                padding: 12px 16px;
                color: #fff;
                font-size: 13px;
            }
            QLineEdit:focus {
                background: #252536;
            }
        """)
        search.textChanged.connect(self.filter_features)
        layout.addWidget(search)
        
        # Category buttons
        self.category_buttons = []
        categories = [
            ("🖥️", "System", "system"),
            ("🎮", "Gaming", "gaming"),
            ("🔧", "Hardware", "hardware"),
            ("🌐", "Network", "network"),
            ("🎨", "Customization", "customization"),
            ("🛡️", "Security", "security"),
            ("📦", "Apps", "apps"),
            ("⚙️", "Advanced", "advanced"),
        ]
        
        for icon, name, cat_id in categories:
            btn = QPushButton(f"{icon}  {name}")
            btn.setCheckable(True)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.setStyleSheet("""
                QPushButton {
                    text-align: left;
                    padding: 14px 20px;
                    border: none;
                    color: #ccc;
                    font-size: 13px;
                    font-weight: 500;
                }
                QPushButton:hover {
                    background: #1e1e2e;
                    color: #fff;
                }
                QPushButton:checked {
                    background: #00D4AA;
                    color: #000;
                    font-weight: 600;
                }
            """)
            btn.clicked.connect(lambda checked, c=cat_id: self.show_category(c))
            self.category_buttons.append((btn, cat_id))
            layout.addWidget(btn)
        
        # Set first as checked
        if self.category_buttons:
            self.category_buttons[0][0].setChecked(True)
        
        layout.addStretch()
        
        # Version info
        version = QLabel("TinkerOS v7.2.0-rc6")
        version.setAlignment(Qt.AlignmentFlag.AlignCenter)
        version.setStyleSheet("color: #555; font-size: 11px; padding: 10px;")
        layout.addWidget(version)
        
        return sidebar
    
    def apply_theme(self):
        self.setStyleSheet("""
            QMainWindow {
                background: #0d0d12;
            }
            #sidebar {
                background: #12121a;
                border-right: 1px solid #1e1e2e;
            }
            QStackedWidget {
                background: #0d0d12;
            }
            QScrollArea {
                background: transparent;
                border: none;
            }
            QWidget {
                color: #e0e0e0;
            }
        """)
    
    def load_features(self):
        # Create pages for each category
        self.pages = {}
        
        categories = [
            ("system", "System", [
                ("📊", "System Monitor", "system-monitor"),
                ("⚡", "Power Manager", "power-manager"),
                ("🔄", "Auto Updates", "auto-updates"),
                ("💾", "Backup & Restore", "backup-restore"),
                ("🛡️", "Rollback Recovery", "rollback-recovery"),
                ("🚀", "Fast Boot", "fast-boot"),
                ("🧠", "Predictive Intelligence", "predictive-intelligence"),
                ("⏰", "Temporal Mapping", "temporal-mapping"),
                ("🔮", "Context Aware", "context-aware"),
                ("💾", "Predictive Caching", "predictive-caching"),
                ("🤖", "Digital Twin", "digital-twin"),
                ("🏥", "Self Healing", "self-healing"),
                ("⚡", "Adaptive Power Grid", "adaptive-power-grid"),
                ("🧹", "System Cleaner", "system-cleaner"),
                ("🔋", "Battery Monitor", "battery-monitor"),
            ]),
            ("gaming", "Gaming", [
                ("🎯", "FPS Monitor", "fps-monitor"),
                ("🎮", "Controller Mapper", "controller-mapper"),
                ("⏪", "Game Replay", "game-replay"),
                ("📺", "Streaming Manager", "streaming-manager"),
                ("💬", "Discord Presence", "discord-presence"),
                ("🍷", "Wine/Proton Manager", "wine-manager"),
                ("🕹️", "Emulator Manager", "emulator-manager"),
                ("☁️", "Game Saves Sync", "game-saves-sync"),
                ("📈", "Hardware Benchmark", "hardware-benchmark"),
                ("📊", "Performance Graph", "performance-graph"),
                ("🎮", "Game Launcher", "game-launcher"),
                ("🛡️", "Anti-Cheat Helper", "anticheat-helper"),
                ("🔊", "Audio Mixer", "audio-mixer"),
                ("📸", "Screenshot Tool", "screenshot-tool"),
                ("🎞️", "GIF Recorder", "gif-recorder"),
            ]),
            ("hardware", "Hardware", [
                ("👆", "Fingerprint Manager", "fingerprint-manager"),
                ("📷", "Webcam Manager", "webcam-manager"),
                ("📄", "Scanner Manager", "scanner-manager"),
                ("🖨️", "Printer Manager", "printer-manager"),
                ("🔌", "USB Manager", "usb-manager"),
                ("⚡", "Thunderbolt Manager", "thunderbolt-manager"),
                ("🔗", "Docking Station", "docking-station"),
                ("🎨", "Display Calibration", "display-calibration"),
                ("🌈", "HDR Manager", "hdr-manager"),
                ("👆", "Touchscreen Manager", "touchscreen-manager"),
                ("✏️", "Pen/Stylus", "pen-stylus"),
                ("📱", "NFC Manager", "nfc-manager"),
                ("🔌", "Serial/UART", "serial-uart"),
                ("🔧", "GPIO Manager", "gpio-manager"),
                ("⌨️", "KVM Switch", "kvm-switch"),
            ]),
            ("network", "Network", [
                ("🔒", "VPN Manager", "vpn-manager"),
                ("🛡️", "Firewall GUI", "firewall-gui"),
                ("📊", "Network Monitor", "network-monitor"),
                ("🚀", "Speed Test", "speed-test"),
                ("📏", "Bandwidth Limiter", "bandwidth-limiter"),
                ("🔍", "DNS Manager", "dns-manager"),
                ("🌐", "Proxy Manager", "proxy-manager"),
                ("📶", "WiFi Analyzer", "wifi-analyzer"),
                ("📱", "Hotspot Manager", "hotspot-manager"),
                ("🕸️", "Mesh Network", "mesh-network"),
            ]),
            ("customization", "Customization", [
                ("🖱️", "Cursor Themes", "cursor-themes"),
                ("🎨", "Icon Packs", "icon-packs"),
                ("🔄", "GRUB Theme", "grub-theme"),
                ("🔐", "Login Theme", "login-theme"),
                ("✨", "Window Animations", "window-animations"),
                ("🌊", "Desktop Effects", "desktop-effects"),
                ("🔤", "Font Manager", "font-manager"),
                ("🎨", "GTK Theme", "gtk-theme"),
                ("🎨", "Qt Theme", "qt-theme"),
                ("🐚", "Shell Theme", "shell-theme"),
                ("📊", "Conky Stats", "conky-stats"),
                ("🖼️", "Wallpaper Manager", "wallpaper-manager"),
            ]),
            ("security", "Security", [
                ("🔑", "Password Manager", "password-manager"),
                ("🛡️", "Security Suite", "security-suite"),
                ("🔒", "File Vault", "filevault"),
                ("🛡️", "Gatekeeper", "gatekeeper"),
                ("🔍", "Privacy", "privacy"),
                ("🧱", "Firewall", "firewall"),
                ("👆", "Biometric", "biometric"),
                ("📍", "Find My Device", "findmydevice"),
            ]),
            ("apps", "Apps", [
                ("🏪", "Software Center", "software-center"),
                ("📦", "Package Manager", "package-manager"),
                ("🎮", "Gaming Mode", "gaming-mode"),
                ("🎮", "Gaming Support", "gaming-support"),
                ("📁", "File Manager", "file-manager"),
                ("📝", "Quick Notes", "quick-note"),
                ("📋", "Smart Clipboard", "smart-clipboard"),
                ("👁️", "OCR Everywhere", "ocr-everywhere"),
                ("🎤", "Voice Commands", "voice-commands"),
                ("🎥", "Screen Recorder", "screen-recorder"),
            ]),
            ("advanced", "Advanced", [
                ("🎯", "Focus Mode", "focus-mode"),
                ("🍅", "Pomodoro Timer", "pomodoro-timer"),
                ("⏱️", "Time Tracker", "time-tracker"),
                ("📱", "Screen Time", "screen-time"),
                ("👨‍👩‍👧", "Parental Controls", "parental-controls"),
                ("💾", "Disk Visualizer", "disk-visualizer"),
                ("🔍", "Duplicate Finder", "duplicate-finder"),
                ("📝", "File Versioning", "file-versioning"),
                ("🔍", "Regex Tool", "regex-tool"),
                ("📄", "JSON Formatter", "json-formatter"),
                ("📝", "Markdown Editor", "markdown-editor"),
                ("🔍", "Global Search", "global-search"),
                ("⌘", "Command Palette", "command-palette"),
                ("⚡", "Quick Actions", "quick-actions"),
            ]),
        ]
        
        for cat_id, cat_name, features in categories:
            page = self.create_category_page(cat_name, features)
            self.pages[cat_id] = page
            self.content_stack.addWidget(page)
    
    def create_category_page(self, title, features):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(32, 32, 32, 32)
        layout.setSpacing(24)
        
        # Title
        title_label = QLabel(title)
        title_label.setFont(QFont("Inter", 28, QFont.Weight.Bold))
        title_label.setStyleSheet("color: #fff; margin-bottom: 8px;")
        layout.addWidget(title_label)
        
        # Scroll area for feature cards
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")
        
        content = QWidget()
        content_layout = QVBoxLayout(content)
        content_layout.setSpacing(16)
        content_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        
        # Create feature cards in grid
        for i in range(0, len(features), 3):
            row = QHBoxLayout()
            row.setSpacing(16)
            
            for j in range(3):
                if i + j < len(features):
                    icon, name, cmd = features[i + j]
                    card = self.create_feature_card(icon, name, cmd)
                    row.addWidget(card)
            
            row.addStretch()
            content_layout.addLayout(row)
        
        content_layout.addStretch()
        scroll.setWidget(content)
        layout.addWidget(scroll)
        
        return page
    
    def create_feature_card(self, icon, name, cmd):
        card = QFrame()
        card.setCursor(Qt.CursorShape.PointingHandCursor)
        card.setStyleSheet("""
            QFrame {
                background: #16161f;
                border: 1px solid #1e1e2e;
                border-radius: 12px;
                padding: 20px;
            }
            QFrame:hover {
                background: #1a1a26;
                border-color: #00D4AA;
            }
        """)
        card.setMinimumWidth(300)
        card.setMaximumWidth(350)
        
        layout = QVBoxLayout(card)
        layout.setSpacing(12)
        
        # Icon
        icon_label = QLabel(icon)
        icon_label.setFont(QFont("Noto Sans", 28))
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Name
        name_label = QLabel(name)
        name_label.setFont(QFont("Inter", 14, QFont.Weight.Medium))
        name_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        name_label.setStyleSheet("color: #fff;")
        name_label.setWordWrap(True)
        
        # Action button
        btn = QPushButton("Open")
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.setStyleSheet("""
            QPushButton {
                background: #00D4AA;
                color: #000;
                border: none;
                border-radius: 8px;
                padding: 10px;
                font-weight: 600;
                font-size: 12px;
            }
            QPushButton:hover {
                background: #00E8BB;
            }
        """)
        btn.clicked.connect(lambda: self.run_feature(cmd))
        
        layout.addWidget(icon_label)
        layout.addWidget(name_label)
        layout.addWidget(btn)
        
        return card
    
    def run_feature(self, cmd):
        try:
            # Try to find the script in various locations
            script_paths = [
                f"/home/tinkerspace/linux-kernel/os/apps/{cmd}.sh",
                f"/home/tinkerspace/linux-kernel/os/apps/gaming/{cmd}.sh",
                f"/home/tinkerspace/linux-kernel/os/apps/hardware/{cmd}.sh",
                f"/home/tinkerspace/linux-kernel/os/apps/system/{cmd}.sh",
                f"/home/tinkerspace/linux-kernel/os/apps/network/{cmd}.sh",
                f"/home/tinkerspace/linux-kernel/os/apps/customization/{cmd}.sh",
                f"/home/tinkerspace/linux-kernel/os/apps/security/{cmd}.sh",
                f"/home/tinkerspace/linux-kernel/os/apps/apps/{cmd}.sh",
                f"/home/tinkerspace/linux-kernel/os/system/{cmd}.sh",
                f"/home/tinkerspace/linux-kernel/os/desktop/{cmd}.sh",
            ]
            
            script = None
            for p in script_paths:
                if os.path.exists(p):
                    script = p
                    break
            
            if script:
                subprocess.Popen(["bash", script], start_new_session=True)
                self.statusBar().showMessage(f"Launched: {cmd}", 3000)
            else:
                QMessageBox.warning(self, "Not Found", f"Feature '{cmd}' not found")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to launch: {e}")
    
    def show_category(self, cat_id):
        if cat_id in self.pages:
            self.content_stack.setCurrentWidget(self.pages[cat_id])
            
            # Update button states
            for btn, cid in self.category_buttons:
                btn.setChecked(cid == cat_id)
    
    def filter_features(self, text):
        text = text.lower()
        # Filter logic would go here
        pass


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("TinkerOS Control Center")
    app.setApplicationVersion("1.0")
    
    # Set font
    font = QFont("Inter", 10)
    app.setFont(font)
    
    window = TinkerOSControlCenter()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()

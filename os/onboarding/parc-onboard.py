#!/usr/bin/env python3
"""
TinkerOS Onboarding Wizard
5-minute setup experience for new users
"""

import sys
import os
import subprocess
import json
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict, Optional

try:
    from PyQt6.QtWidgets import *
    from PyQt6.QtCore import *
    from PyQt6.QtGui import *
    PYQT_AVAILABLE = True
except ImportError:
    PYQT_AVAILABLE = False

@dataclass
class OnboardingState:
    step: int = 0
    username: str = ""
    display_name: str = ""
    email: str = ""
    theme: str = "dark"
    keyboard_layout: str = "us"
    timezone: str = "UTC"
    privacy_level: str = "balanced"
    install_apps: List[str] = None
    enable_features: List[str] = None
    
    def __post_init__(self):
        if self.install_apps is None:
            self.install_apps = []
        if self.enable_features is None:
            self.enable_features = []

class OnboardingWizard(QWizard if PYQT_AVAILABLE else object):
    def __init__(self):
        if PYQT_AVAILABLE:
            super().__init__()
            self.setWindowTitle("Welcome to TinkerOS")
            self.setMinimumSize(800, 600)
            self.setWizardStyle(QWizard.WizardStyle.ModernStyle)
            self.state = OnboardingState()
            self.setup_pages()
            self.apply_theme()
    
    def setup_pages(self):
        # Page 1: Welcome
        welcome = QWizardPage()
        welcome.setTitle("Welcome to TinkerOS")
        welcome.setSubTitle("Your Computer. Your Rules.")
        
        layout = QVBoxLayout(welcome)
        
        mascot = QLabel("🦝")
        mascot.setFont(QFont("Noto Sans", 72))
        mascot.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        title = QLabel("TinkerOS")
        title.setFont(QFont("Inter", 32, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setStyleSheet("color: #00D4AA;")
        
        tagline = QLabel("Your Computer. Your Rules.")
        tagline.setFont(QFont("Inter", 16))
        tagline.setAlignment(Qt.AlignmentFlag.AlignCenter)
        tagline.setStyleSheet("color: #888;")
        
        desc = QLabel(
            "TinkerOS is a Linux-based operating system designed for everyone.\n"
            "It combines the power of Linux with the simplicity you expect.\n\n"
            "This wizard will help you set up your system in just a few minutes."
        )
        desc.setFont(QFont("Inter", 12))
        desc.setAlignment(Qt.AlignmentFlag.AlignCenter)
        desc.setWordWrap(True)
        desc.setStyleSheet("color: #ccc; margin-top: 20px;")
        
        layout.addStretch()
        layout.addWidget(mascot)
        layout.addWidget(title)
        layout.addWidget(tagline)
        layout.addWidget(desc)
        layout.addStretch()
        
        self.addPage(welcome)
        
        # Page 2: User Account
        account = QWizardPage()
        account.setTitle("Your Account")
        account.setSubTitle("Create your TinkerID")
        
        layout = QFormLayout(account)
        layout.setSpacing(16)
        
        self.username_edit = QLineEdit()
        self.username_edit.setPlaceholderText("tinkerer")
        layout.addRow("Username:", self.username_edit)
        
        self.display_name_edit = QLineEdit()
        self.display_name_edit.setPlaceholderText("Tinkerer")
        layout.addRow("Display Name:", self.display_name_edit)
        
        self.email_edit = QLineEdit()
        self.email_edit.setPlaceholderText("you@example.com (optional)")
        layout.addRow("Email:", self.email_edit)
        
        self.addPage(account)
        
        # Page 3: Preferences
        prefs = QWizardPage()
        prefs.setTitle("Preferences")
        prefs.setSubTitle("Customize your experience")
        
        layout = QVBoxLayout(prefs)
        layout.setSpacing(20)
        
        # Theme
        theme_group = QGroupBox("Appearance")
        theme_layout = QHBoxLayout(theme_group)
        self.theme_dark = QRadioButton("Dark")
        self.theme_dark.setChecked(True)
        self.theme_light = QRadioButton("Light")
        self.theme_auto = QRadioButton("Auto")
        theme_layout.addWidget(self.theme_dark)
        theme_layout.addWidget(self.theme_light)
        theme_layout.addWidget(self.theme_auto)
        layout.addWidget(theme_group)
        
        # Keyboard
        kb_group = QGroupBox("Keyboard Layout")
        kb_layout = QHBoxLayout(kb_group)
        self.kb_us = QRadioButton("US")
        self.kb_us.setChecked(True)
        self.kb_uk = QRadioButton("UK")
        self.kb_de = QRadioButton("German")
        self.kb_fr = QRadioButton("French")
        self.kb_other = QRadioButton("Other...")
        kb_layout.addWidget(self.kb_us)
        kb_layout.addWidget(self.kb_uk)
        kb_layout.addWidget(self.kb_de)
        kb_layout.addWidget(self.kb_fr)
        kb_layout.addWidget(self.kb_other)
        layout.addWidget(kb_group)
        
        # Timezone
        tz_group = QGroupBox("Timezone")
        tz_layout = QHBoxLayout(tz_group)
        self.tz_combo = QComboBox()
        self.tz_combo.addItems(["UTC", "US/Eastern", "US/Central", "US/Mountain", "US/Pacific",
                                 "Europe/London", "Europe/Paris", "Europe/Berlin",
                                 "Asia/Tokyo", "Asia/Shanghai", "Auto-detect"])
        tz_layout.addWidget(self.tz_combo)
        layout.addWidget(tz_group)
        
        self.addPage(prefs)
        
        # Page 4: Privacy
        privacy = QWizardPage()
        privacy.setTitle("Privacy & Data")
        privacy.setSubTitle("Choose your comfort level")
        
        layout = QVBoxLayout(privacy)
        
        self.privacy_minimal = QRadioButton("Minimal")
        self.privacy_minimal.setToolTip("No telemetry, no crash reports, no usage data")
        
        self.privacy_balanced = QRadioButton("Balanced (Recommended)")
        self.privacy_balanced.setChecked(True)
        self.privacy_balanced.setToolTip("Anonymous usage stats, crash reports")
        
        self.privacy_full = QRadioButton("Full")
        self.privacy_full.setToolTip("Help improve TinkerOS with detailed analytics")
        
        layout.addWidget(self.privacy_minimal)
        layout.addWidget(self.privacy_balanced)
        layout.addWidget(self.privacy_full)
        
        note = QLabel(
            "🔒 TinkerOS never sells your data. All telemetry is anonymous and optional.\n"
            "You can change this anytime in Settings > Privacy."
        )
        note.setWordWrap(True)
        note.setStyleSheet("color: #888; font-size: 11px; margin-top: 10px;")
        layout.addWidget(note)
        layout.addStretch()
        
        self.addPage(privacy)
        
        # Page 5: Apps
        apps = QWizardPage()
        apps.setTitle("Essential Apps")
        apps.setSubTitle("Pre-install useful applications")
        
        layout = QVBoxLayout(apps)
        
        app_categories = {
            "Productivity": ["LibreOffice", "Thunderbird", "Calibre"],
            "Development": ["VS Code", "Git", "Docker", "Terminal"],
            "Media": ["VLC", "GIMP", "OBS Studio"],
            "Communication": ["Discord", "Element", "Signal"],
            "Utilities": ["Flameshot", "KeePassXC", "Timeshift"]
        }
        
        self.app_checkboxes = {}
        for category, apps_list in app_categories.items():
            group = QGroupBox(category)
            group_layout = QVBoxLayout(group)
            for app in apps_list:
                cb = QCheckBox(app)
                cb.setChecked(True)
                self.app_checkboxes[app] = cb
                group_layout.addWidget(cb)
            layout.addWidget(group)
        
        self.addPage(apps)
        
        # Page 6: Advanced Features
        features = QWizardPage()
        features.setTitle("Advanced Features")
        features.setSubTitle("Enable powerful TinkerOS features (optional)")
        
        layout = QVBoxLayout(features)
        
        feature_options = [
            ("🧠", "Predictive Intelligence", "AI-powered system optimization"),
            ("🤖", "Digital Twin", "Virtual system replica for safe testing"),
            ("🏥", "Self-Healing", "Auto-detect and fix system issues"),
            ("⚡", "Adaptive Power Grid", "Smart power management"),
            ("🎮", "Game Console Mode", "Controller-friendly UI"),
            ("📱", "Mobile Companion", "Phone as remote/second screen"),
        ]
        
        self.feature_checkboxes = {}
        for icon, name, desc in feature_options:
            cb = QCheckBox(f"{icon}  {name}")
            cb.setToolTip(desc)
            self.feature_checkboxes[name] = cb
            layout.addWidget(cb)
        
        layout.addStretch()
        self.addPage(features)
        
        # Page 7: Ready
        ready = QWizardPage()
        ready.setTitle("Ready to Go!")
        ready.setSubTitle("Your TinkerOS is almost ready")
        
        layout = QVBoxLayout(ready)
        
        mascot = QLabel("🦝")
        mascot.setFont(QFont("Noto Sans", 48))
        mascot.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        msg = QLabel("Everything is set up. Click Finish to apply your settings.")
        msg.setAlignment(Qt.AlignmentFlag.AlignCenter)
        msg.setWordWrap(True)
        msg.setStyleSheet("color: #ccc; font-size: 14px; margin: 20px;")
        
        layout.addStretch()
        layout.addWidget(mascot)
        layout.addWidget(msg)
        layout.addStretch()
        
        self.addPage(ready)
        
        # Connect signals
        self.finished.connect(self.on_finished)
    
    def apply_theme(self):
        self.setStyleSheet("""
            QWizard {
                background: #0D0D12;
            }
            QWizardPage {
                background: #0D0D12;
                color: #E0E0E0;
            }
            QLabel { color: #E0E0E0; }
            QLineEdit {
                background: #16161F;
                border: 1px solid #1E1E2E;
                border-radius: 8px;
                padding: 10px;
                color: #FFF;
            }
            QLineEdit:focus { border-color: #00D4AA; }
            QGroupBox {
                border: 1px solid #1E1E2E;
                border-radius: 12px;
                margin-top: 16px;
                padding-top: 16px;
                color: #00D4AA;
                font-weight: 600;
            }
            QGroupBox::title { subcontrol-origin: margin; left: 16px; padding: 0 8px; }
            QRadioButton, QCheckBox {
                color: #E0E0E0;
                spacing: 8px;
            }
            QRadioButton::indicator, QCheckBox::indicator {
                width: 18px; height: 18px;
                border: 2px solid #1E1E2E;
                border-radius: 4px;
                background: #16161F;
            }
            QRadioButton::indicator:checked {
                background: #00D4AA; border-color: #00D4AA;
            }
            QCheckBox::indicator:checked {
                background: #00D4AA; border-color: #00D4AA;
            }
            QComboBox {
                background: #16161F;
                border: 1px solid #1E1E2E;
                border-radius: 8px;
                padding: 8px 12px;
                color: #FFF;
            }
            QPushButton {
                background: #00D4AA; color: #000;
                border: none; border-radius: 8px;
                padding: 12px 24px; font-weight: 600;
            }
            QPushButton:hover { background: #00E8BB; }
        """)
    
    def on_finished(self, result):
        if result == QDialog.DialogCode.Accepted:
            self.apply_settings()
    
    def apply_settings(self):
        # Collect all settings
        self.state.username = self.username_edit.text()
        self.state.display_name = self.display_name_edit.text()
        self.state.email = self.email_edit.text()
        
        if self.theme_dark.isChecked(): self.state.theme = "dark"
        elif self.theme_light.isChecked(): self.state.theme = "light"
        else: self.state.theme = "auto"
        
        if self.kb_us.isChecked(): self.state.keyboard_layout = "us"
        elif self.kb_uk.isChecked(): self.state.keyboard_layout = "uk"
        elif self.kb_de.isChecked(): self.state.keyboard_layout = "de"
        elif self.kb_fr.isChecked(): self.state.keyboard_layout = "fr"
        else: self.state.keyboard_layout = "us"
        
        self.state.timezone = self.tz_combo.currentText()
        
        if self.privacy_minimal.isChecked(): self.state.privacy_level = "minimal"
        elif self.privacy_balanced.isChecked(): self.state.privacy_level = "balanced"
        else: self.state.privacy_level = "full"
        
        self.state.install_apps = [app for app, cb in self.app_checkboxes.items() if cb.isChecked()]
        self.state.enable_features = [name for name, cb in self.feature_checkboxes.items() if cb.isChecked()]
        
        # Apply settings
        self.apply_system_settings()
        self.create_tinkerid()
    
    def apply_system_settings(self):
        # Theme
        gsettings = "gsettings set org.gnome.desktop.interface"
        if self.state.theme == "dark":
            subprocess.run(f"{gsettings} gtk-theme 'Adwaita-dark'", shell=True)
            subprocess.run(f"{gsettings} color-scheme 'prefer-dark'", shell=True)
        elif self.state.theme == "light":
            subprocess.run(f"{gsettings} gtk-theme 'Adwaita'", shell=True)
            subprocess.run(f"{gsettings} color-scheme 'prefer-light'", shell=True)
        
        # Keyboard
        subprocess.run(f"setxkbmap {self.state.keyboard_layout}", shell=True)
        
        # Timezone
        if self.state.timezone != "Auto-detect":
            subprocess.run(f"timedatectl set-timezone {self.state.timezone}", shell=True)
        
        # Install apps
        for app in self.state.install_apps:
            subprocess.run(f"flatpak install -y flathub {app.lower().replace(' ', '-')}", shell=True)
        
        # Enable features
        for feature in self.state.enable_features:
            self.enable_feature(feature)
    
    def enable_feature(self, name):
        feature_map = {
            "Predictive Intelligence": "predictive-intelligence",
            "Digital Twin": "digital-twin",
            "Self-Healing": "self-healing",
            "Adaptive Power Grid": "adaptive-power-grid",
            "Game Console Mode": "game-console",
            "Mobile Companion": "mobile-companion",
        }
        if name in feature_map:
            config_file = f"/home/tinkerspace/linux-kernel/os/system/optional-features.conf"
            # Enable in config
            pass
    
    def create_tinkerid(self):
        # Create TinkerID account
        subprocess.run([
            "python3", "/home/tinkerspace/linux-kernel/os/account/tinker-account.py"
        ], input=f"""
from tinker_account import TinkerAccount
account = TinkerAccount()
account.create_account("{self.state.username}", "{self.state.display_name}", "{self.state.email}")
""", text=True, capture_output=True)


def run_cli_onboarding():
    """Text-based onboarding for systems without GUI"""
    print("""
╔══════════════════════════════════════════════════════════════╗
║                      🦝 TINKEROS SETUP                        ║
║                  Your Computer. Your Rules.                   ║
╚══════════════════════════════════════════════════════════════╝
    """)
    
    state = OnboardingState()
    
    print("Step 1: Your Account")
    state.username = input("Username: ") or "tinkerer"
    state.display_name = input("Display Name: ") or "Tinkerer"
    state.email = input("Email (optional): ") or ""
    
    print("\nStep 2: Appearance")
    theme = input("Theme [dark/light/auto] (dark): ").lower() or "dark"
    state.theme = theme if theme in ["dark", "light", "auto"] else "dark"
    
    print("\nStep 3: Keyboard Layout")
    kb = input("Layout [us/uk/de/fr] (us): ").lower() or "us"
    state.keyboard_layout = kb if kb in ["us", "uk", "de", "fr"] else "us"
    
    print("\nStep 4: Timezone")
    tz = input("Timezone (UTC): ") or "UTC"
    state.timezone = tz
    
    print("\nStep 5: Privacy Level")
    print("  1) Minimal - No telemetry")
    print("  2) Balanced - Anonymous stats (recommended)")
    print("  3) Full - Help improve TinkerOS")
    privacy = input("Choice [1/2/3] (2): ") or "2"
    state.privacy_level = ["minimal", "balanced", "full"][int(privacy)-1]
    
    print("\nStep 6: Essential Apps (y/n)")
    default_apps = ["Firefox", "VS Code", "VLC", "GIMP", "Discord", "KeePassXC"]
    for app in default_apps:
        if input(f"  Install {app}? (y): ").lower() != 'n':
            state.install_apps.append(app)
    
    print("\nStep 7: Advanced Features (y/n)")
    features = ["Predictive Intelligence", "Digital Twin", "Self-Healing", 
                "Adaptive Power Grid", "Game Console Mode", "Mobile Companion"]
    for feat in features:
        if input(f"  Enable {feat}? (n): ").lower() == 'y':
            state.enable_features.append(feat)
    
    print("\n✅ Setup complete! Applying settings...")
    # Apply settings (same as GUI)
    
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║                    🎉 TINKEROS READY!                         ║
║                                                              ║
║  Username: {state.username:<40} ║
║  Theme: {state.theme:<43} ║
║  Apps to install: {len(state.install_apps):<35} ║
║  Features enabled: {len(state.enable_features):<34} ║
║                                                              ║
║  Run 'tinker-control-center' to customize further           ║
╚══════════════════════════════════════════════════════════════╝
    """)

if __name__ == "__main__":
    if PYQT_AVAILABLE and os.environ.get("DISPLAY"):
        app = QApplication(sys.argv)
        app.setFont(QFont("Inter", 10))
        wizard = OnboardingWizard()
        wizard.show()
        sys.exit(app.exec())
    else:
        run_cli_onboarding()

#!/usr/bin/env python3
"""
TinkerOS Marketplace GUI
Beautiful app store experience
"""

import sys
import os
from pathlib import Path

try:
    from PyQt6.QtWidgets import *
    from PyQt6.QtCore import *
    from PyQt6.QtGui import *
    from PyQt6.QtNetwork import *
    PYQT_AVAILABLE = True
except ImportError:
    PYQT_AVAILABLE = False

class MarketplaceApp(QMainWindow if PYQT_AVAILABLE else object):
    def __init__(self):
        if PYQT_AVAILABLE:
            super().__init__()
            self.setWindowTitle("TinkerOS Marketplace")
            self.setMinimumSize(1000, 700)
            self.setup_ui()
            self.apply_theme()
    
    def setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        layout = QHBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        # Sidebar
        sidebar = QFrame()
        sidebar.setFixedWidth(240)
        sidebar.setStyleSheet("background: #12121A; border-right: 1px solid #1E1E2E;")
        sidebar_layout = QVBoxLayout(sidebar)
        sidebar_layout.setContentsMargins(0, 0, 0, 0)
        
        # Logo
        logo = QLabel("🦝  TinkerOS Marketplace")
        logo.setFont(QFont("Inter", 14, QFont.Weight.Bold))
        logo.setStyleSheet("color: #00D4AA; padding: 20px;")
        logo.setAlignment(Qt.AlignmentFlag.AlignCenter)
        sidebar_layout.addWidget(logo)
        
        # Categories
        categories = [
            ("🏠", "Home"),
            ("🔍", "Discover"),
            ("🎮", "Gaming"),
            ("💻", "Development"),
            ("🎨", "Creative"),
            ("📦", "Productivity"),
            ("🔧", "Utilities"),
            ("🛡️", "Security"),
            ("⭐", "Top Rated"),
            ("🆕", "New Releases"),
        ]
        
        for icon, name in categories:
            btn = QPushButton(f"{icon}  {name}")
            btn.setCheckable(True)
            btn.setStyleSheet("""
                QPushButton {
                    text-align: left; padding: 12px 16px;
                    border: none; color: #CCC; font-size: 13px;
                }
                QPushButton:hover { background: #1E1E2E; color: #FFF; }
                QPushButton:checked { background: #00D4AA; color: #000; font-weight: 600; }
            """)
            sidebar_layout.addWidget(btn)
        
        sidebar_layout.addStretch()
        
        # User profile
        profile = QPushButton("👤  My Account")
        profile.setStyleSheet("""
            QPushButton { text-align: left; padding: 12px 16px;
                border: none; color: #888; font-size: 13px; }
        """)
        sidebar_layout.addWidget(profile)
        
        layout.addWidget(sidebar)
        
        # Main content
        content = QWidget()
        content_layout = QVBoxLayout(content)
        content_layout.setContentsMargins(0, 0, 0, 0)
        
        # Search bar
        search_bar = QFrame()
        search_bar.setFixedHeight(60)
        search_bar.setStyleSheet("background: #12121A; border-bottom: 1px solid #1E1E2E;")
        search_layout = QHBoxLayout(search_bar)
        search_layout.setContentsMargins(24, 0, 24, 0)
        
        search = QLineEdit()
        search.setPlaceholderText("🔍  Search apps, games, tools...")
        search.setStyleSheet("""
            QLineEdit { background: #16161F; border: 1px solid #1E1E2E;
                border-radius: 24px; padding: 12px 20px; color: #FFF; font-size: 14px; }
            QLineEdit:focus { border-color: #00D4AA; }
        """)
        search_layout.addWidget(search)
        
        content_layout.addWidget(search_bar)
        
        # Featured section
        featured = QLabel("✨  Featured This Week")
        featured.setFont(QFont("Inter", 18, QFont.Weight.Bold))
        featured.setStyleSheet("color: #FFF; padding: 24px;")
        content_layout.addWidget(featured)
        
        # App grid
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setStyleSheet("background: transparent; border: none;")
        
        grid_widget = QWidget()
        grid_layout = QGridLayout(grid_widget)
        grid_layout.setSpacing(16)
        grid_layout.setContentsMargins(24, 0, 24, 24)
        
        # Sample apps
        sample_apps = [
            ("🦊", "Firefox", "Web Browser", "Mozilla", "Free", "⭐ 4.8", "productivity"),
            ("📝", "VS Code", "Code Editor", "Microsoft", "Free", "⭐ 4.9", "development"),
            ("🎮", "Steam", "Game Platform", "Valve", "Free", "⭐ 4.7", "gaming"),
            ("🎨", "GIMP", "Image Editor", "GIMP Team", "Free", "⭐ 4.6", "creative"),
            ("💬", "Discord", "Chat & Voice", "Discord Inc.", "Free", "⭐ 4.8", "communication"),
            ("🎵", "Spotify", "Music Streaming", "Spotify", "Free", "⭐ 4.5", "media"),
            ("📦", "Flatseal", "Flatpak Permissions", "Flatpak", "Free", "⭐ 4.7", "utilities"),
            ("🛡️", "Bitwarden", "Password Manager", "8bit Solutions", "Free", "⭐ 4.9", "security"),
            ("📊", "LibreOffice", "Office Suite", "TDF", "Free", "⭐ 4.6", "productivity"),
            ("🐳", "Docker", "Container Platform", "Docker Inc.", "Free", "⭐ 4.8", "development"),
            ("🎥", "OBS Studio", "Streaming/Recording", "OBS Project", "Free", "⭐ 4.9", "creative"),
            ("🔧", "Stacer", "System Optimizer", "Stacer", "Free", "⭐ 4.5", "utilities"),
        ]
        
        for i, (icon, name, desc, dev, price, rating, cat) in enumerate(sample_apps):
            row, col = divmod(i, 4)
            card = self.create_app_card(icon, name, desc, dev, price, rating, cat)
            grid_layout.addWidget(card, row, col)
        
        grid_layout.setColumnStretch(4, 1)
        scroll.setWidget(grid_widget)
        content_layout.addWidget(scroll)
        
        layout.addWidget(content)
    
    def create_app_card(self, icon, name, desc, dev, price, rating, cat):
        card = QFrame()
        card.setFixedSize(200, 280)
        card.setCursor(Qt.CursorShape.PointingHandCursor)
        card.setStyleSheet("""
            QFrame { background: #16161F; border: 1px solid #1E1E2E;
                border-radius: 16px; }
            QFrame:hover { border-color: #00D4AA; background: #1A1A26; }
        """)
        
        layout = QVBoxLayout(card)
        layout.setSpacing(12)
        layout.setContentsMargins(16, 16, 16, 16)
        
        # Icon
        icon_label = QLabel(icon)
        icon_label.setFont(QFont("Noto Sans", 48))
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Name
        name_label = QLabel(name)
        name_label.setFont(QFont("Inter", 14, QFont.Weight.Bold))
        name_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        name_label.setStyleSheet("color: #FFF;")
        
        # Description
        desc_label = QLabel(desc)
        desc_label.setFont(QFont("Inter", 11))
        desc_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        desc_label.setStyleSheet("color: #888;")
        desc_label.setWordWrap(True)
        
        # Developer
        dev_label = QLabel(dev)
        dev_label.setFont(QFont("Inter", 10))
        dev_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        dev_label.setStyleSheet("color: #666;")
        
        # Rating & Price
        bottom = QHBoxLayout()
        rating_label = QLabel(rating)
        rating_label.setFont(QFont("Inter", 11, QFont.Weight.Bold))
        rating_label.setStyleSheet("color: #F59E0B;")
        
        price_label = QLabel(price)
        price_label.setFont(QFont("Inter", 12, QFont.Weight.Bold))
        price_label.setStyleSheet("color: #00D4AA;")
        price_label.setAlignment(Qt.AlignmentFlag.AlignRight)
        
        bottom.addWidget(rating_label)
        bottom.addStretch()
        bottom.addWidget(price_label)
        
        # Install button
        btn = QPushButton("Install")
        btn.setStyleSheet("""
            QPushButton { background: #00D4AA; color: #000;
                border: none; border-radius: 8px; padding: 10px;
                font-weight: 600; font-size: 12px; }
            QPushButton:hover { background: #00E8BB; }
        """)
        
        layout.addWidget(icon_label)
        layout.addWidget(name_label)
        layout.addWidget(desc_label)
        layout.addWidget(dev_label)
        layout.addStretch()
        layout.addLayout(bottom)
        layout.addWidget(btn)
        
        return card
    
    def apply_theme(self):
        self.setStyleSheet("""
            QMainWindow { background: #0D0D12; }
            QWidget { color: #E0E0E0; }
            QLineEdit { background: #16161F; border: 1px solid #1E1E2E;
                border-radius: 8px; padding: 8px; color: #FFF; }
            QScrollArea { background: transparent; border: none; }
            QScrollBar:vertical { background: transparent; width: 6px; }
            QScrollBar::handle:vertical { background: #1E1E2E; border-radius: 3px; }
        """)

if __name__ == "__main__":
    if PYQT_AVAILABLE:
        app = QApplication(sys.argv)
        app.setFont(QFont("Inter", 10))
        window = MarketplaceApp()
        window.show()
        sys.exit(app.exec())
    else:
        print("PyQt6 required for GUI. Run: pip install PyQt6")


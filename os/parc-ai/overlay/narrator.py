#!/usr/bin/env python3
"""
VOKK v4 Narrator — Glassmorphism overlay that narrates what VOKK v4 is doing
Shows a small popup in the corner and updates in real-time
"""

import sys
import os
import time
from PyQt6.QtWidgets import QApplication, QWidget, QLabel, QVBoxLayout, QHBoxLayout
from PyQt6.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, QPoint, pyqtSignal
from PyQt6.QtGui import QFont, QColor, QPainter, QPainterPath, QLinearGradient


class GlassmorphismWidget(QWidget):
    """Glassmorphism popup widget"""
    
    def __init__(self):
        super().__init__()
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setFixedWidth(380)
        self.setFixedHeight(120)
        
        # Position at bottom-right
        screen = QApplication.primaryScreen().geometry()
        self.move(screen.width() - 400, screen.height() - 180)
        
        # Layout
        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 12, 16, 12)
        
        # Title
        self.title = QLabel("🤖 VOKK v4")
        self.title.setFont(QFont("Ubuntu Sans", 11, QFont.Weight.Bold))
        self.title.setStyleSheet("color: rgb(200, 215, 255); background: transparent;")
        layout.addWidget(self.title)
        
        # Message
        self.message = QLabel("Ready...")
        self.message.setFont(QFont("Ubuntu Sans", 10))
        self.message.setStyleSheet("color: rgb(220, 230, 255); background: transparent;")
        self.message.setWordWrap(True)
        layout.addWidget(self.message)
        
        # Status dots
        self.status_layout = QHBoxLayout()
        self.dots = []
        for i in range(3):
            dot = QLabel("●")
            dot.setFont(QFont("Ubuntu Sans", 8))
            dot.setStyleSheet("color: rgb(100, 120, 160); background: transparent;")
            self.status_layout.addWidget(dot)
            self.dots.append(dot)
        self.status_layout.addStretch()
        layout.addLayout(self.status_layout)
        
        # Animation
        self.dot_timer = QTimer()
        self.dot_timer.timeout.connect(self.animate_dots)
        self.dot_index = 0
        
        # Fade in animation
        self.fade_anim = None
        
    def paintEvent(self, event):
        """Draw glassmorphism background"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        # Glass background
        path = QPainterPath()
        path.addRoundedRect(0, 0, self.width(), self.height(), 16, 16)
        
        # Gradient
        gradient = QLinearGradient(0, 0, 0, self.height())
        gradient.setColorAt(0, QColor(26, 30, 42, 180))
        gradient.setColorAt(1, QColor(16, 20, 30, 200))
        
        painter.fillPath(path, gradient)
        
        # Border
        painter.setPen(QColor(100, 130, 200, 80))
        painter.drawPath(path)
        
        painter.end()
    
    def animate_dots(self):
        """Animate status dots"""
        for i, dot in enumerate(self.dots):
            if i <= self.dot_index:
                dot.setStyleSheet("color: rgb(100, 200, 150); background: transparent;")
            else:
                dot.setStyleSheet("color: rgb(100, 120, 160); background: transparent;")
        self.dot_index = (self.dot_index + 1) % 4
    
    def show_narration(self, message, duration=3000):
        """Show narration with auto-hide"""
        self.message.setText(message)
        self.dot_index = 0
        self.dot_timer.start(300)
        self.show()
        
        # Fade in
        self.setWindowOpacity(0)
        self.fade_anim = QPropertyAnimation(self, b"windowOpacity")
        self.fade_anim.setDuration(200)
        self.fade_anim.setStartValue(0.0)
        self.fade_anim.setEndValue(1.0)
        self.fade_anim.start()
        
        # Auto hide
        if duration > 0:
            QTimer.singleShot(duration, self.hide_narration)
    
    def hide_narration(self):
        """Fade out"""
        self.fade_anim = QPropertyAnimation(self, b"windowOpacity")
        self.fade_anim.setDuration(300)
        self.fade_anim.setStartValue(1.0)
        self.fade_anim.setEndValue(0.0)
        self.fade_anim.finished.connect(self.hide)
        self.fade_anim.start()


class Narrator:
    """VOKK v4 Narrator — controls the overlay"""
    
    _instance = None
    _app = None
    
    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            if cls._app is None:
                cls._app = QApplication(sys.argv)
            cls._instance = GlassmorphismWidget()
        return cls._instance
    
    @classmethod
    def narrate(cls, message, duration=3000):
        """Show a narration message"""
        widget = cls.get_instance()
        widget.show_narration(message, duration)
        cls._app.processEvents()
    
    @classmethod
    def hide(cls):
        """Hide the narration"""
        if cls._instance:
            cls._instance.hide_narration()


def main():
    """Show a single narration message"""
    if len(sys.argv) < 2:
        print("Usage: narrator.py <message> [duration_ms]")
        sys.exit(1)
    
    message = sys.argv[1]
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else 3000
    
    app = QApplication.instance() or QApplication(sys.argv)
    
    widget = GlassmorphismWidget()
    widget.show_narration(message, duration)
    widget.show()
    
    # Process events and wait
    timer = QTimer()
    timer.singleShot(duration + 500, app.quit)
    app.exec()


if __name__ == "__main__":
    main()

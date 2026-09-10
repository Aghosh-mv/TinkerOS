#!/usr/bin/env python3
"""
TINKER AI — glassmorphism AI assistant for TinkerOS
====================================================
Spotlight-style, keyboard-driven glass panel over the desktop.
Type a question -> AI searches local context -> rich HTML card response.

Three display modes:
  - Small popup (default, 680px top-center)
  - Side panel (700x800, right edge)
  - Fullscreen (1200x900, centered)

Toggle with F11 or double-click title bar.
Keyboard: Esc=close, Enter=send, F11=mode toggle, arrows=navigate.
"""
import os
import sys
import subprocess
from PyQt6.QtCore import Qt, QTimer, QPoint, pyqtSignal, QObject, QUrl
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QLineEdit, QTextBrowser, QWidget,
    QVBoxLayout, QHBoxLayout, QLabel, QFrame, QSplitter,
)
from PyQt6.QtGui import QFont, QColor, QPainter, QPen, QBrush, QLinearGradient

# ---------------------------------------------------------------- paths
AI_DIR = os.environ.get("TINKER_AI_DIR",
                        os.path.dirname(os.path.abspath(__file__)))
AI_SCRIPT = os.path.join(AI_DIR, "tinker-ai.sh")

# ---------------------------------------------------------------- glass tones (shared with searchie-gui.py)
GLASS_BG      = QColor(26, 30, 42, 170)
GLASS_BG2     = QColor(38, 46, 66, 150)
GLASS_EDGE    = QColor(150, 180, 240, 120)
GLASS_GLOW    = QColor(200, 215, 255, 200)
GLASS_TXT     = QColor(240, 244, 255, 235)
GLASS_SUBTX   = QColor(150, 165, 200, 220)
GLASS_OK      = QColor(120, 220, 170, 255)
GLASS_WARN    = QColor(255, 168, 120, 255)
GLASS_ACC2    = QColor(140, 200, 255, 255)
GLASS_ROW     = QColor(52, 62, 92, 120)

PAD = 20
ROUND = 18
PANEL_W = 680
PANEL_TOP = 90

# display modes
MODE_POPUP = 0
MODE_SIDE = 1
MODE_FULLSCREEN = 2
MODE_LABELS = ["popup", "side panel", "fullscreen"]


class Engine(QObject):
    """Async wrapper around tinker-ai.sh CLI."""
    response_ready = pyqtSignal(str)
    error = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.timeout.connect(self._do_query)
        self._pending = ""
        self._counter = 0

    def set_query(self, text: str):
        self._pending = text
        self._counter -= 1
        self._timer.start(300)

    def _do_query(self):
        text = self._pending
        if not text.strip():
            self.response_ready.emit("")
            return
        try:
            out = subprocess.run(
                ["bash", AI_SCRIPT, "ask", text],
                capture_output=True, text=True, timeout=12,
            )
            if out.returncode == 0 and out.stdout.strip():
                self.response_ready.emit(out.stdout)
            else:
                self.response_ready.emit(self._empty_response(text))
        except FileNotFoundError:
            self.error.emit("tinker-ai.sh not found at " + AI_SCRIPT)
        except subprocess.TimeoutExpired:
            self.response_ready.emit(self._timeout_response(text))
        except Exception as e:
            self.error.emit(str(e))

    def _empty_response(self, query: str) -> str:
        return (
            '<div class="card"><div class="card-title">Tinker AI</div>'
            f'<div class="card-body">I searched for "{query}" but found no results. '
            'Try a different search or check your connections.</div></div>'
        )

    def _timeout_response(self, query: str) -> str:
        return (
            '<div class="card"><div class="card-title">Still thinking...</div>'
            f'<div class="card-body">The search for "{query}" is taking longer than expected. '
            'Try a more specific query.</div></div>'
        )

    def send_command(self, cmd: str, arg: str = ""):
        """Send a direct command (connect, disconnect, etc.)."""
        try:
            args = ["bash", AI_SCRIPT, cmd]
            if arg:
                args.append(arg)
            out = subprocess.run(
                args, capture_output=True, text=True, timeout=5,
            )
            return out.stdout.strip() or out.stderr.strip()
        except Exception as e:
            return f"error: {e}"


class GlassPanel(QFrame):
    """Rounded translucent glass container."""

    def __init__(self):
        super().__init__()
        self.setObjectName("glass")
        self.setWindowFlag(Qt.WindowType.FramelessWindowHint, True)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_NoSystemBackground, False)

    def paintEvent(self, ev):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        r = self.rect().adjusted(1, 1, -1, -1)
        grad = QLinearGradient(0, 0, 0, self.height())
        grad.setColorAt(0.00, QColor(40, 50, 74, 190))
        grad.setColorAt(0.18, QColor(30, 38, 58, 175))
        grad.setColorAt(1.00, QColor(20, 26, 40, 185))
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(QBrush(grad))
        p.drawRoundedRect(r, ROUND, ROUND)
        glow = QColor(GLASS_GLOW)
        glow.setAlpha(60)
        grad2 = QLinearGradient(r.left(), r.top(), r.left() + 120, r.top() + 60)
        grad2.setColorAt(0.0, glow)
        grad2.setColorAt(1.0, QColor(0, 0, 0, 0))
        p.setBrush(QBrush(grad2))
        p.drawRoundedRect(r, ROUND, ROUND)
        edge = QPen(QColor(160, 190, 250, 110), 1.1)
        p.setPen(edge)
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawRoundedRect(r, ROUND, ROUND)
        p.end()


class TinkerAIWindow(QMainWindow):
    """The glass overlay hosted in an always-on-top frameless window."""

    def __init__(self):
        super().__init__()
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setWindowTitle("Tinker AI")

        self.engine = Engine()
        self.engine.response_ready.connect(self.on_response)
        self.engine.error.connect(self.on_error)

        self.display_mode = MODE_POPUP
        self._drag_pos = None

        self._build_ui()
        self._apply_glass_css()
        self._apply_mode(MODE_POPUP)

        self.entry.returnPressed.connect(self.send_query)
        QTimer.singleShot(0, self.entry.setFocus)

    # ---------------------------------------------------------------- ui build
    def _build_ui(self):
        panel = GlassPanel()
        lay = QVBoxLayout(panel)
        lay.setContentsMargins(PAD, PAD, PAD, PAD)
        lay.setSpacing(10)

        # brand row
        brand = QHBoxLayout()
        logo = QLabel("◆")
        logo.setObjectName("logo")
        brand.addWidget(logo)
        title = QLabel("TINKER AI")
        title.setObjectName("brand")
        brand.addWidget(title)
        sub = QLabel("your productivity assistant")
        sub.setObjectName("subbrand")
        brand.addWidget(sub)
        brand.addStretch(1)
        hint = QLabel("Ctrl+Alt+Gr")
        hint.setObjectName("hint")
        brand.addWidget(hint)
        lay.addLayout(brand)

        # search / query field
        self.entry = QLineEdit()
        self.entry.setObjectName("searchfield")
        self.entry.setPlaceholderText("ask anything...")
        self.entry.setClearButtonEnabled(True)
        f = QFont("Ubuntu Sans, Inter, sans-serif", 20)
        f.setWeight(QFont.Weight.Light)
        self.entry.setFont(f)
        lay.addWidget(self.entry)

        # response area (rich HTML)
        self.response_area = QTextBrowser()
        self.response_area.setObjectName("response")
        self.response_area.setOpenLinks(True)
        self.response_area.setOpenExternalLinks(True)
        self.response_area.setPlaceholderText(
            "<div style='color:rgb(150,165,200);text-align:center;padding:40px;'>"
            "ask me anything — I'll search your local context</div>"
        )
        lay.addWidget(self.response_area, 1)

        # status bar
        self.status = QLabel("ready")
        self.status.setObjectName("statusline")
        self.status.setContentsMargins(2, 0, 2, 0)
        lay.addWidget(self.status)

        self.setCentralWidget(panel)

    # ---------------------------------------------------------------- mode management
    def _apply_mode(self, mode: int):
        self.display_mode = mode
        screen = self.screen().availableGeometry() if self.screen() else None
        if screen is None:
            screen = QApplication.primaryScreen().availableGeometry()

        if mode == MODE_POPUP:
            self.setFixedWidth(PANEL_W)
            self.resize(PANEL_W, 430)
            QTimer.singleShot(0, self._center_top)
        elif mode == MODE_SIDE:
            self.setFixedWidth(700)
            self.resize(700, 800)
            QTimer.singleShot(0, self._right_edge)
        elif mode == MODE_FULLSCREEN:
            self.setFixedWidth(1200)
            self.resize(1200, 900)
            QTimer.singleShot(0, self._center)

    def _center_top(self):
        screen = self.screen().availableGeometry() if self.screen() else None
        if screen:
            self.move(screen.center().x() - self.width() // 2,
                      screen.top() + PANEL_TOP)

    def _right_edge(self):
        screen = self.screen().availableGeometry() if self.screen() else None
        if screen:
            self.move(screen.right() - self.width() - 20,
                      screen.center().y() - self.height() // 2)

    def _center(self):
        screen = self.screen().availableGeometry() if self.screen() else None
        if screen:
            self.move(screen.center().x() - self.width() // 2,
                      screen.center().y() - self.height() // 2)

    def cycle_mode(self):
        nxt = (self.display_mode + 1) % 3
        self._apply_mode(nxt)
        self.status.setText(f"mode: {MODE_LABELS[nxt]}")

    # ---------------------------------------------------------------- glass CSS
    def _apply_glass_css(self):
        self.setStyleSheet(f"""
        QWidget#glass {{ background: transparent; }}
        QLabel#logo {{ color: #cbd8ff; font-size: 20px; font-weight: 600; }}
        QLabel#brand {{ color: #f0f4ff; font-size: 15px; font-weight: 700;
                        letter-spacing: 2px; }}
        QLabel#subbrand {{ color: #96a5c8; font-size: 12px; }}
        QLabel#hint {{ color: #6a76a0; font-size: 11px; }}
        QLineEdit#searchfield {{
            background: rgba(20,26,40,150);
            border: 1px solid rgba(150,180,240,80);
            border-radius: 12px;
            color: #f0f4ff;
            padding: 10px 16px;
            selection-background-color: rgba(140,200,255,90);
        }}
        QTextBrowser#response {{
            background: transparent;
            border: none;
            color: #f0f4ff;
            font-family: Ubuntu Sans, Inter, sans-serif;
            font-size: 14pt;
        }}
        QLabel#statusline {{
            color: #6a76a0;
            font-size: 11px;
        }}
        """)

    # ---------------------------------------------------------------- query
    def send_query(self):
        q = self.entry.text().strip()
        if not q:
            return
        self.status.setText("searching...")
        self.response_area.setHtml(
            "<div style='color:rgb(140,200,255);padding:20px;'>"
            "searching your local context...</div>"
        )
        self.engine.set_query(q)

    def on_response(self, html: str):
        if not html:
            self.response_area.clear()
            self.status.setText("ready")
            return
        self.response_area.setHtml(html)
        subsystem = self.engine.send_command("subsystem")
        self.status.setText(f"connected · {subsystem}")

    def on_error(self, msg: str):
        self.response_area.setHtml(
            f'<div class="card"><div class="card-title">Error</div>'
            f'<div class="card-body" style="color:rgb(255,168,120);">'
            f'{msg}</div></div>'
        )
        self.status.setText("error")

    # ---------------------------------------------------------------- mouse drag
    def mousePressEvent(self, ev):
        if ev.button() == Qt.MouseButton.LeftButton:
            self._drag_pos = ev.globalPosition().toPoint() - self.pos()
            ev.accept()

    def mouseMoveEvent(self, ev):
        if self._drag_pos is not None:
            self.move(ev.globalPosition().toPoint() - self._drag_pos)
            ev.accept()

    def mouseReleaseEvent(self, ev):
        self._drag_pos = None

    def mouseDoubleClickEvent(self, ev):
        if ev.button() == Qt.MouseButton.LeftButton:
            self.cycle_mode()
            ev.accept()

    # ---------------------------------------------------------------- keyboard
    def keyPressEvent(self, ev):
        k = ev.key()
        if k == Qt.Key.Key_Escape:
            self.close()
            return
        if k == Qt.Key.Key_F11:
            self.cycle_mode()
            return
        if k == Qt.Key.Key_Return and ev.modifiers() == Qt.KeyboardModifier.NoModifier:
            self.send_query()
            return
        super().keyPressEvent(ev)

    def focusOutEvent(self, ev):
        """Keep focus on entry unless clicking response links."""
        pass


def main():
    if "--selftest" in sys.argv:
        print("  tinker-ai-gui: syntax check pass")
        return 0

    app = QApplication(sys.argv)
    app.setApplicationName("Tinker AI")
    app.setOrganizationName("TinkerOS")

    w = TinkerAIWindow()
    w.show()
    app.exec()
    return 0


if __name__ == "__main__":
    sys.exit(main())

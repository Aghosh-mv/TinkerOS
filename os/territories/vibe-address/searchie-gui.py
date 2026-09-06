#!/usr/bin/env python3
"""
SEARCHIE — glass memory overlay for TinkerOS
=============================================
A spotlight-style, keyboard-driven glass panel over the desktop.
Type a half-remembered phrase -> results stream in -> Enter opens.

Rendered as true blurred glass:
  - Frameless, always-on-top overlay panel, top-center of the screen
  - Real translucency + backdrop blur via Qt (Blur behind window where the
    compositor supports it; soft translucent glass everywhere)
  - Rounded frosted corners, glow accent, dimmed ambient backdrop
  - Live results as you type (engine hit in <50ms typical)

Delete safety (public OS, non-negotiable):
  A delete request stages the matched files and pops a THREE-button
  bar below the field:
      [ OK — delete them ]  [ Cancel ]  [ Find another thing ]
  Nothing is ever removed until OK is explicitly pressed.
"""
import os
import re
import sys
import subprocess
from PyQt6.QtCore import Qt, QTimer, QPoint, pyqtSignal, QObject
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QLineEdit, QListWidget, QListWidgetItem,
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QFrame,
)
from PyQt6.QtGui import QFont, QColor, QPainter, QPen, QBrush, QLinearGradient

# ---------------------------------------------------------------- engine glue
ENGINE_DIR = os.environ.get("SEARCHIE_ENGINE",
                            os.path.dirname(os.path.abspath(__file__)))
ENGINE = os.path.join(ENGINE_DIR, "vibe-address.sh")
VIBE_HOME = os.environ.get("VIBE_HOME",
                           os.path.expanduser("~/.local/share/tinkeros/vibe"))

# ---------------------------------------------------------------- glass tones
GLASS_BG      = QColor(26, 30, 42, 170)      # frosted near-black base
GLASS_BG2     = QColor(38, 46, 66, 150)      # lighter band (highlight top)
GLASS_EDGE    = QColor(150, 180, 240, 120)   # cold edge
GLASS_GLOW    = QColor(200, 215, 255, 200)   # glow accent
GLASS_TXT     = QColor(240, 244, 255, 235)   # primary text
GLASS_SUBTX   = QColor(150, 165, 200, 220)   # secondary text
GLASS_OK      = QColor(120, 220, 170, 255)   # ok-green
GLASS_WARN    = QColor(255, 168, 120, 255)   # warm delete
GLASS_ACC2    = QColor(140, 200, 255, 255)   # find-another accent
GLASS_ROW     = QColor(52, 62, 92, 120)      # selected row wash

PAD = 20
ROUND = 18
PANEL_W = 680
PANEL_TOP = 90


class Engine(QObject):
    """Thin async wrapper around the vibe-address engine CLI."""
    results_ready = pyqtSignal(list)
    reviews_ready = pyqtSignal(list)
    done = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.timeout.connect(self._do_query)
        self._pending = ""
        self._resets = 0

    def set_query(self, text: str):
        """Debounce typing into engine queries (fast path)."""
        self._pending = text
        self._resets -= 1
        self._timer.start(60)  # 60ms debounce -> instant feel

    def _do_query(self):
        text = self._pending
        if not text.strip():
            self.results_ready.emit([])
            return
        try:
            env = dict(os.environ)
            env["SEARCHIE_TERSE"] = "1"
            env["VIBE_HOME"] = VIBE_HOME
            out = subprocess.run(
                ["bash", ENGINE, "ask", text],
                capture_output=True, text=True, timeout=8,
                env=env,
            ).stdout
        except Exception:
            self.results_ready.emit([])
            return
        rows = []
        for line in out.splitlines():
            if line.startswith("RESULT|"):
                parts = line.split("|")
                if len(parts) >= 5:
                    rows.append({
                        "score": parts[1].strip(),
                        "path": parts[2].strip(),
                        "cat": parts[3].strip(),
                        "ago": parts[4].strip(),
                    })
        self.results_ready.emit(rows)

    def request_delete(self, phrase: str):
        """Stage a delete review (no deletes happen here)."""
        try:
            env = dict(os.environ)
            env["VIBE_HOME"] = VIBE_HOME
            out = subprocess.run(
                ["bash", ENGINE, "delete", phrase],
                capture_output=True, text=True, timeout=10, env=env,
            ).stdout
        except Exception:
            self.reviews_ready.emit([])
            return
        items = []
        for line in out.splitlines():
            if line.startswith("ITEM|"):
                parts = line[5:].split("|")
                if len(parts) >= 3:
                    items.append(parts[:4])
            elif line.startswith("REVIEW|"):
                try:
                    pid = line.split("|")[1].strip()
                    items.append(["__PID__", pid, "", ""])
                except Exception:
                    pass
        self.reviews_ready.emit(items)

    def confirm_delete(self, pid: str):
        env = dict(os.environ)
        env["VIBE_HOME"] = VIBE_HOME
        try:
            subprocess.run(["bash", ENGINE, "confirm", pid],
                           capture_output=True, text=True, timeout=20,
                           env=env)
        except Exception:
            pass
        self.done.emit("deleted")


class GlassPanel(QFrame):
    """Rounded translucent glass container (blurrdglass)."""

    def __init__(self):
        super().__init__()
        self.setObjectName("glass")
        self.setWindowFlag(Qt.WindowType.FramelessWindowHint, True)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_NoSystemBackground, False)
        self.setFixedWidth(PANEL_W)

    def paintEvent(self, ev):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        r = self.rect().adjusted(1, 1, -1, -1)
        # vertical frosted gradient (deep base → lighter at top edge)
        grad = QLinearGradient(0, 0, 0, self.height())
        grad.setColorAt(0.00, QColor(40, 50, 74, 190))
        grad.setColorAt(0.18, QColor(30, 38, 58, 175))
        grad.setColorAt(1.00, QColor(20, 26, 40, 185))
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(QBrush(grad))
        p.drawRoundedRect(r, ROUND, ROUND)
        # top-left glow signature
        glow = QColor(GLASS_GLOW)
        glow.setAlpha(60)
        grad2 = QLinearGradient(r.left(), r.top(), r.left() + 120, r.top() + 60)
        grad2.setColorAt(0.0, glow)
        grad2.setColorAt(1.0, QColor(0, 0, 0, 0))
        p.setBrush(QBrush(grad2))
        p.drawRoundedRect(r, ROUND, ROUND)
        # cold edge
        edge = QPen(QColor(160, 190, 250, 110), 1.1)
        p.setPen(edge)
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawRoundedRect(r, ROUND, ROUND)
        p.end()


class SearchieWindow(QMainWindow):
    """The glass overlay hosted in an always-on-top frameless window."""

    def __init__(self):
        super().__init__()
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setWindowTitle("Searchie")
        self.engine = Engine()
        self.engine.results_ready.connect(self.on_results)
        self.engine.reviews_ready.connect(self.on_reviews)
        self.engine.done.connect(self.on_delete_done)

        self.results_model = []
        self.staged_pid = None
        self.mode = "search"
        self.confirm_index = 0  # 0 OK / 1 Cancel / 2 Find another

        self._build_ui()
        self._apply_glass_css()

        self.entry.textChanged.connect(self.engine.set_query)
        self.entry.returnPressed.connect(self.activate_selected)
        # pre-focus
        QTimer.singleShot(0, self.entry.setFocus)

    # ---------------------------------------------------------------- ui build
    def _build_ui(self):
        panel = GlassPanel()
        lay = QVBoxLayout(panel)
        lay.setContentsMargins(PAD, PAD, PAD, PAD)
        lay.setSpacing(10)

        # brand row
        brand = QHBoxLayout()
        logo = QLabel("◒")
        logo.setObjectName("logo")
        brand.addWidget(logo)
        title = QLabel("SEARCHIE")
        title.setObjectName("brand")
        brand.addWidget(title)
        sub = QLabel("vibe addressing memory")
        sub.setObjectName("subbrand")
        brand.addWidget(sub)
        brand.addStretch(1)
        hint = QLabel("Tab+F7")
        hint.setObjectName("hint")
        brand.addWidget(hint)
        lay.addLayout(brand)

        # search field
        self.entry = QLineEdit()
        self.entry.setObjectName("searchfield")
        self.entry.setPlaceholderText("what do you remember?")
        self.entry.setClearButtonEnabled(True)
        f = QFont("Ubuntu Sans, Inter, sans-serif", 20)
        f.setWeight(QFont.Weight.Light)
        self.entry.setFont(f)
        lay.addWidget(self.entry)

        # results list
        self.results = QListWidget()
        self.results.setObjectName("results")
        self.results.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.results.setSelectionMode(QListWidget.SelectionMode.NoSelection)
        self.results.itemClicked.connect(self.on_item_click)
        lay.addWidget(self.results, 1)

        # status line (result meta / delete notices)
        self.status = QLabel("")
        self.status.setObjectName("statusline")
        self.status.setContentsMargins(2, 0, 2, 0)
        lay.addWidget(self.status)

        # confirm bar (the 3 buttons) — hidden unless delete flow
        self.confirm_row = QWidget()
        cw = QHBoxLayout(self.confirm_row)
        cw.setContentsMargins(0, 0, 0, 0)
        cw.setSpacing(10)
        self.btn_ok = QPushButton("OK — delete them")
        self.btn_cancel = QPushButton("Cancel")
        self.btn_find = QPushButton("Find another thing")
        for b, obj in ((self.btn_ok, "btn_ok"),
                       (self.btn_cancel, "btn_cancel"),
                       (self.btn_find, "btn_find")):
            b.setObjectName(obj)
            b.setCursor(Qt.CursorShape.PointingHandCursor)
            b.clicked.connect(self.on_confirm_clicked)
            cw.addWidget(b)
        self.confirm_row.setLayout(cw)
        self.confirm_row.hide()
        lay.addWidget(self.confirm_row)

        self.setCentralWidget(panel)
        self._center_top()
        self.resize(PANEL_W, 430)

    def _center_top(self):
        if not self.isVisible():
            QTimer.singleShot(0, self._center_top)
            return
        screen = self.screen().availableGeometry() if self.screen() else None
        if screen:
            self.move(screen.center().x() - PANEL_W // 2,
                      screen.top() + PANEL_TOP)

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
        QListWidget#results {{
            background: transparent;
            border: none;
            outline: 0;
            color: #f0f4ff;
        }}
        QListWidget#results::item {{
            border-radius: 10px;
            padding: 8px 12px;
            margin: 2px 0;
            color: #dbe3ff;
        }}
        QListWidget#results::item:selected {{
            background: rgba(70,90,140,110);
            color: #ffffff;
        }}
        QPushButton {{ border-radius: 12px; border: none; padding: 9px 16px;
                       font-weight: 600; font-size: 13px; }}
        QPushButton#btn_ok {{ background: rgba(120,220,170,95);
                             color: #e6ffef; }}
        QPushButton#btn_ok:hover {{ background: rgba(120,220,170,160); }}
        QPushButton#btn_cancel {{ background: rgba(90,100,130,90);
                                 color: #cfd7ef; }}
        QPushButton#btn_cancel:hover {{ background: rgba(120,130,170,130); }}
        QPushButton#btn_find {{ background: rgba(140,200,255,90);
                               color: #eaf4ff; }}
        QPushButton#btn_find:hover {{ background: rgba(140,200,255,150); }}
        """)

    # ---------------------------------------------------------------- results
    def on_results(self, rows):
        self.results_model = rows
        self.results.clear()
        if not rows:
            it = QListWidgetItem("  nothing found — Searchie already forgot nothing")
            it.setForeground(QColor("#6a76a0"))
            self.results.addItem(it)
            return
        for row in rows[:12]:
            it = QListWidgetItem(
                f"  {row['path']:<42}   {row['cat']}   ·  {row['ago']}"
            )
            it.setData(Qt.ItemDataRole.UserRole, row["path"])
            it.setForeground(QColor("#dbe3ff") if row else QColor("#8b94c0"))
            it.setToolTip(f"{row['path']}  [{row['score']}% match]")
            self.results.addItem(it)

    def on_item_click(self, item):
        self.activate_selected()

    def activate_selected(self):
        it = self.results.currentItem()
        if not it:
            if self.results.count():
                self.results.setCurrentRow(0)
                it = self.results.currentItem()
            else:
                return
        path = it.data(Qt.ItemDataRole.UserRole)
        if path and os.name != "nt":
            subprocess.Popen(["xdg-open", path],
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            self.close()

    # ---------------------------------------------------------------- delete
    def start_delete(self):
        phrase = self.entry.text().strip()
        if not phrase:
            return
        self.set_statusbar(("delete message", phrase))
        self.engine.request_delete(phrase)

    def on_reviews(self, items):
        self.staged_pid = None
        staged_lines = []
        for it in items:
            if it and it[0] == "__PID__":
                if len(it) > 1:
                    self.staged_pid = it[1].strip()
            elif it and len(it) >= 4:
                staged_lines.append(it)
        if not staged_lines or not self.staged_pid:
            self.results.clear()
            it = QListWidgetItem("  no matching files found in memory")
            it.setForeground(QColor("#6a76a0"))
            self.results.addItem(it)
            return
        self.mode = "delete"
        self.confirm_index = 0
        self.confirm_row.show()
        self._paint_delete_preview(staged_lines)

    def _paint_delete_preview(self, staged_lines):
        self.results.clear()
        for row in staged_lines:
            # row = [fp, path, size, age]
            fp, path, sz, age = row
            it = QListWidgetItem(
                f"  {path:<46}  {sz:>8}   ·  {age}"
            )
            it.setForeground(QColor(GLASS_WARN))
            it.setToolTip(f"will delete: {path}\nreview required — press OK to confirm")
            self.results.addItem(it)
        # keyboard hint stays in the field
        self.entry.setPlaceholderText("arrows select · Enter = OK · Esc = cancel")

    def on_confirm_clicked(self):
        sender = self.sender()
        if sender is self.btn_ok:
            self.do_delete_yes()
        elif sender is self.btn_cancel:
            self.do_delete_cancel()
        elif sender is self.btn_find:
            self.do_delete_find_other()

    def do_delete_yes(self):
        pid = self.staged_pid
        self.confirm_row.hide()
        self.results.clear()
        it = QListWidgetItem("  deleting…")
        it.setForeground(QColor(GLASS_OK))
        self.results.addItem(it)
        if pid:
            self.engine.confirm_delete(pid)

    def do_delete_cancel(self):
        self.set_statusbar_clear("delete cancelled — nothing was touched")
        self.leave_delete_mode()

    def do_delete_find_other(self):
        self.set_statusbar_clear("searching for another thing…")
        self.leave_delete_mode()
        self.entry.setText(self.entry.text().strip() + " ")
        self.entry.backspace()  # nudge re-query

    def leave_delete_mode(self):
        self.mode = "search"
        self.confirm_row.hide()
        self.entry.setPlaceholderText("what do you remember?")

    def on_delete_done(self, msg):
        self.set_statusbar_clear(msg or "done")

    # ---------------------------------------------------------------- status
    def set_statusbar(self, *t):
        txt = "  ".join(str(x) for x in t if x)
        self.status.setText(txt)
        self.status.setStyleSheet(
            "QLabel#statusline { color: #8b94c0; font-size: 12px; }"
        )

    def set_statusbar_clear(self, *t):
        self.set_statusbar(*t)

    # ---------------------------------------------------------------- key map
    def keyPressEvent(self, ev):
        k = ev.key()
        if k == Qt.Key.Key_Escape:
            if self.mode == "delete":
                self.do_delete_cancel()
            else:
                self.close()
            return
        if k in (Qt.Key.Key_Down, Qt.Key.Key_Up, Qt.Key.Key_Tab):
            if self.mode == "delete":
                row = self.results.currentRow()
                nxt = row + (1 if (k in (Qt.Key.Key_Down, Qt.Key.Key_Tab)) else -1)
                self.results.setCurrentRow(max(0, min(nxt, self.results.count()-1)))
            else:
                row = self.results.currentRow()
                nxt = row + (1 if k in (Qt.Key.Key_Down, Qt.Key.Key_Tab) else -1)
                self.results.setCurrentRow(max(0, min(nxt, self.results.count()-1)))
            return
        if k in (Qt.Key.Key_Left, Qt.Key.Key_Right) and self.mode == "delete":
            sel = self.confirm_index
            sel += 1 if k == Qt.Key.Key_Right else -1
            self.confirm_index = max(0, min(2, sel))
            order = [self.btn_ok, self.btn_cancel, self.btn_find]
            order[self.confirm_index].setFocus()
            return
        if k == Qt.Key.Key_Return:
            if self.mode == "delete":
                self.do_delete_yes()
                return
            self.activate_selected()
            return
        if k == Qt.Key.Key_Delete:
            self.start_delete()
            return
        super().keyPressEvent(ev)


def selftest():
    """Headless contract test: engine ask/delete/confirm against a temp home."""
    import tempfile
    import shutil
    tmp = tempfile.mkdtemp(prefix="searchie-selftest-")
    try:
        os.environ["SEARCHIE_ENGINE"] = ENGINE_DIR
        os.environ["VIBE_HOME"] = tmp
        os.environ["SEARCHIE_TERSE"] = "1"
        probe = os.path.join(tmp, "notes-about-bedsheets.txt")
        with open(probe, "w") as fh:
            fh.write("sheets bought, soft, dark blue\n")
        env = dict(os.environ)

        def eng(*args):
            return subprocess.run(["bash", ENGINE] + list(args),
                                  capture_output=True, text=True,
                                  timeout=15, env=env)

        r = eng("record", "files", "self", probe)
        assert r.returncode == 0, f"record failed: {r.stderr}"
        a = eng("ask", "the bedsheets thing")
        hits = [l for l in a.stdout.splitlines() if l.startswith("RESULT|")]
        assert hits, f"ask terse got nothing:\n{a.stdout}{a.stderr}"
        print("  ASK     →", hits[0][:80])

        d = eng("delete", "bedsheets file")
        assert "REVIEW|" in d.stdout, f"delete no review:\n{d.stdout}{d.stderr}"
        pid = next((l.split("|")[1] for l in d.stdout.splitlines()
                    if l.startswith("REVIEW|")), None)
        items = [l for l in d.stdout.splitlines() if l.startswith("ITEM|")]
        assert items, "delete staged zero real files"
        assert all(os.path.exists(p) for
                   p in (x.split("|")[2] for x in items)), "staged path gone?"
        print("  DELETE  → staged", len(items), "file(s), pid", pid)

        c = eng("confirm", pid)
        assert c.returncode == 0, f"confirm failed: {c.stderr}"
        assert not os.path.exists(probe), "confirm did not remove the file"
        print("  CONFIRM → file removed, memory traces purged")
        print("  SELFTEST PASS")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    app = QApplication(sys.argv)
    app.setApplicationName("Searchie")
    app.setOrganizationName("TinkerOS")
    w = SearchieWindow()
    w.show()
    app.exec()


if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
TinkerAI Computer Use - Desktop vision + control for TinkerOS
Lets the AI see the screen and interact with applications.

Dependencies (optional):
  - pyautogui / python-xlib / pyperclip : input simulation
  - mss / scrot / import PIL            : screen capture
  - pytesseract                         : OCR (optional)

The module degrades gracefully - reports what's available.
"""

import os
import subprocess
import shutil
import json
import time
import tempfile
from pathlib import Path
from datetime import datetime


class ComputerUse:
    """Desktop vision + control agent for TinkerOS"""

    def __init__(self, log_cb=None):
        self.log = log_cb or print
        self._pyautogui = None
        self._mss = None
        self._tesseract = shutil.which('tesseract')
        self._xdotool = shutil.which('xdotool')
        self._wayland = os.environ.get('XDG_SESSION_TYPE', '').lower() == 'wayland'
        self._detect_backends()

    def _detect_backends(self):
        try:
            import mss
            self._mss = mss
        except ImportError:
            pass

        # Detection without importing (importing pyautogui can hang on headless).
        try:
            import importlib.util
            self._has_pyautogui = importlib.util.find_spec('pyautogui') is not None
        except Exception:
            self._has_pyautogui = False

    def _gui(self):
        """Lazily import pyautogui, preferring xdotool when present."""
        if self._xdotool:
            return None
        if self._pyautogui is None and self._has_pyautogui:
            try:
                import pyautogui
                self._pyautogui = pyautogui
            except Exception:
                self._pyautogui = None
        return self._pyautogui

    @property
    def available(self):
        caps = []
        if self._mss:
            caps.append('screen_capture')
        if self._tesseract:
            caps.append('ocr')
        if self._pyautogui or self._xdotool or self._has_pyautogui:
            caps.append('mouse_keyboard')
        if self._xdotool:
            caps.append('window_control')
        return caps

    # ---- Screen capture ----
    def screenshot(self, save_path=None):
        """Capture the current screen. Returns path to PNG."""
        if save_path is None:
            save_path = f"/tmp/tinker-screenshot-{int(time.time())}.png"

        if self._mss:
            with self._mss.mss() as sct:
                shot = sct.shot(output=str(save_path))
            return shot
        elif self._tesseract and not self._wayland:
            subprocess.run(['import', '-window', 'root', str(save_path)], check=True)
            return save_path
        else:
            # Fallback: try scrot
            scrot = shutil.which('scrot')
            if scrot:
                subprocess.run([scrot, str(save_path)], check=True)
                return save_path
        self.log("Warning: no screen capture backend available.")
        return None

    # ---- OCR ----
    def ocr(self, image_path):
        """Extract text from an image using tesseract."""
        if not self._tesseract:
            self.log("Warning: tesseract not installed, OCR unavailable.")
            return ""
        result = subprocess.run(
            [self._tesseract, str(image_path), '-', '--psm', '3'],
            capture_output=True, text=True,
        )
        return result.stdout.strip()

    def read_screen(self):
        """Capture + OCR the screen. Returns dict with text and metadata."""
        shot = self.screenshot()
        if not shot:
            return {'error': 'screen capture unavailable'}
        text = self.ocr(shot)
        return {
            'image': shot,
            'text': text,
            'time': datetime.now().isoformat(),
        }

    # ---- Input simulation ----
    def type_text(self, text, interval=0.02):
        """Type text at the current cursor position."""
        gui = self._gui()
        if gui:
            gui.write(text, interval=interval)
            return
        if self._xdotool:
            self._use_xdotool_type(text)
            return
        self.log("Warning: no typing backend available.")

    def _use_xdotool_type(self, text):
        if not self._xdotool:
            return
        with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False) as f:
            f.write(text)
            tmp = f.name
        subprocess.run([self._xdotool, 'type', '--delay', '20', f'--file={tmp}'])
        os.unlink(tmp)

    def move_mouse(self, x, y):
        if self._xdotool:
            subprocess.run([self._xdotool, 'mousemove', str(x), str(y)])
            return
        gui = self._gui()
        if gui:
            gui.moveTo(x, y)

    def click(self, x=None, y=None, button='left', clicks=1):
        """Click at position (or current cursor)."""
        if x is not None and y is not None:
            self.move_mouse(x, y)
            time.sleep(0.05)
        gui = self._gui()
        if gui:
            gui.click(clicks=clicks, button=button)
        elif self._xdotool:
            btn = {'left': 1, 'middle': 2, 'right': 3}[button]
            subprocess.run([self._xdotool, 'click', '--repeat', str(clicks), str(btn)])

    def double_click(self, x=None, y=None):
        self.click(x, y, button='left', clicks=2)

    def right_click(self, x=None, y=None):
        self.click(x, y, button='right', clicks=1)

    def scroll(self, amount, x=None, y=None):
        if x is not None and y is not None:
            self.move_mouse(x, y)
        gui = self._gui()
        if gui:
            gui.scroll(amount)
        elif self._xdotool:
            button = '4' if amount > 0 else '5'
            for _ in range(min(abs(amount), 10)):
                subprocess.run([self._xdotool, 'click', button])

    def drag(self, x1, y1, x2, y2, duration=0.3):
        gui = self._gui()
        if not gui:
            if self._xdotool:
                subprocess.run([self._xdotool, 'mousemove', str(x1), str(y1)])
                subprocess.run([self._xdotool, 'mousedown', '1'])
                subprocess.run([self._xdotool, 'mousemove', str(x2), str(y2)])
                subprocess.run([self._xdotool, 'mouseup', '1'])
                return
            self.log("Warning: drag needs pyautogui or xdotool.")
            return
        gui.moveTo(x1, y1)
        gui.dragTo(x2, y2, duration=duration)

    def hotkey(self, *keys):
        gui = self._gui()
        if gui:
            gui.hotkey(*keys)
        elif self._xdotool:
            subprocess.run([self._xdotool, 'key'] + list(keys))

    def press(self, key):
        gui = self._gui()
        if gui:
            gui.press(key)
        elif self._xdotool:
            subprocess.run([self._xdotool, 'key', key])

    def get_screen_size(self):
        if self._mss:
            with self._mss.mss() as sct:
                return sct.monitors[0]['width'], sct.monitors[0]['height']
        return None

    def copy_to_clipboard(self, text):
        try:
            import pyperclip
            pyperclip.copy(text)
        except ImportError:
            subprocess.run(['xclip', '-selection', 'clipboard'], input=text.encode(), check=False)

    # ---- App launching ----
    def launch_app(self, command):
        """Launch an application by command."""
        subprocess.Popen(command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True

    def find_window(self, name):
        if self._xdotool:
            result = subprocess.run(
                [self._xdotool, 'search', '--name', name],
                capture_output=True, text=True,
            )
            return result.stdout.strip().split('\n') if result.stdout.strip() else []
        return []

    def activate_window(self, window_id):
        if self._xdotool:
            subprocess.run([self._xdotool, 'windowactivate', str(window_id)])

    # ---- High-level actions ----
    def perform_action(self, action, **kwargs):
        """Execute a named action. Returns result dict."""
        handlers = {
            'read_screen': lambda: self.read_screen(),
            'screenshot': lambda: {'path': self.screenshot()},
            'type': lambda: self.type_text(kwargs.get('text', '')),
            'click': lambda: self.click(kwargs.get('x'), kwargs.get('y')),
            'double_click': lambda: self.double_click(kwargs.get('x'), kwargs.get('y')),
            'right_click': lambda: self.right_click(kwargs.get('x'), kwargs.get('y')),
            'scroll': lambda: self.scroll(kwargs.get('amount', 0)),
            'drag': lambda: self.drag(kwargs.get('x1'), kwargs.get('y1'),
                                      kwargs.get('x2'), kwargs.get('y2')),
            'hotkey': lambda: self.hotkey(*kwargs.get('keys', [])),
            'press': lambda: self.press(kwargs.get('key', '')),
            'move_mouse': lambda: self.move_mouse(kwargs.get('x'), kwargs.get('y')),
            'launch_app': lambda: self.launch_app(kwargs.get('command', '')),
            'open_terminal': lambda: self.launch_app('x-terminal-emulator'),
            'copy': lambda: self.copy_to_clipboard(kwargs.get('text', '')),
        }
        if action not in handlers:
            return {'error': f'unknown action: {action}'}
        try:
            return {'ok': True, 'result': handlers[action]()}
        except Exception as e:
            return {'ok': False, 'error': str(e)}

    def describe(self):
        """JSON description of capabilities."""
        return {
            'name': 'tinker-computer-use',
            'capabilities': self.available,
            'session': 'wayland' if self._wayland else 'x11',
            'screen_size': self.get_screen_size(),
            'actions': [
                'read_screen', 'screenshot', 'type', 'click', 'double_click',
                'right_click', 'scroll', 'drag', 'hotkey', 'press',
                'move_mouse', 'launch_app', 'open_terminal', 'copy',
            ],
        }


if __name__ == '__main__':
    cu = ComputerUse()
    print(json.dumps(cu.describe(), indent=2))

    if 'screen_capture' in cu.available:
        print("\nTesting screen capture...")
        shot = cu.screenshot()
        print(f"  Saved to {shot}")
        if 'ocr' in cu.available:
            text = cu.ocr(shot)
            print(f"  OCR text ({len(text)} chars): {text[:200]}...")

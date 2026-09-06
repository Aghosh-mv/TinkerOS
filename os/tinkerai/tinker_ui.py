#!/usr/bin/env python3
"""
TinkerOS Desktop - Modern UI for TinkerAI
=========================================
A friendly, button-driven desktop front-end for the on-device TinkerAI agent.
Instead of a developer terminal, this gives you a clean dark-themed window with
quick-action buttons and a live chat, talking to the agent over a JSON pipe.

Usage:
  python3.10 tinker_ui.py                 # GUI (requires tkinter)
  python3.10 tinker_ui.py --cli-fallback  # if tkinter is missing, use CLI

The agent subprocess is launched with `python3` (numpy build).
"""
import sys, os, json, subprocess, threading, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
AGENT = HERE / "tinker_ai.py"
PY = sys.executable

# Prefer the python that has numpy for the agent; the GUI runs under whatever
# interpreter provides tkinter.
AGENT_PY = os.environ.get("TINKER_AI_PY", "python3")


class Theme:
    bg = "#1b1c20"
    panel = "#25272b"
    btn = "#31343a"
    btn_hi = "#3f434a"
    accent = "#4f9eff"
    text = "#e6e6e9"
    muted = "#9aa0a6"
    green = "#3db86b"
    red = "#d95353"
    border = "#3a3d42"


BUTTONS = [
    ("Help", "help", "help"),
    ("CPU", "cpu usage", "system"),
    ("Memory", "memory usage", "system"),
    ("Disk", "disk space", "system"),
    ("Battery", "battery level", "system"),
    ("Temperature", "temperature", "system"),
    ("System Health", "system health", "system"),
    ("Gaming Mode", "max performance", "power"),
    ("Battery Saver", "save battery", "power"),
    ("Balanced", "balanced", "power"),
    ("Shutdown", "shutdown", "power"),
    ("Launch Terminal", "open terminal", "apps"),
    ("Install App", "install firefox", "apps"),
    ("Dark Mode", "dark mode", "theme"),
    ("Light Mode", "light mode", "theme"),
    ("What's on Screen", "what is on screen", "computer"),
    ("Screenshot", "screenshot", "computer"),
    ("Tell me a joke", "joke", "fun"),
    ("Date", "what is the date", "fun"),
    ("Time", "what time is it", "fun"),
]


def run_gui():
    import tkinter as tk
    from tkinter import ttk

    root = tk.Tk()
    root.title("TinkerAI")
    root.configure(bg=Theme.bg)
    root.geometry("560x720")
    root.minsize(480, 600)

    # ---- Agent subprocess (JSON pipe) ----
    proc = subprocess.Popen(
        [AGENT_PY, str(AGENT), "--serve"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        text=True, bufsize=1,
        cwd=str(HERE),
    )
    proc_lock = threading.Lock()

    def send_query(query, out_widget, status_widget):
        def worker():
            status_widget.config(text="Thinking...", foreground=Theme.accent)
            try:
                with proc_lock:
                    proc.stdin.write(query + "\n")
                    proc.stdin.flush()
                    # read one JSON line per query
                    resp_line = ""
                    while True:
                        line = proc.stdout.readline()
                        if line:
                            resp_line = line.strip()
                            if resp_line.startswith("{"):
                                break
                obj = json.loads(resp_line)
                reply = obj.get("reply", "")
                plan = obj.get("plan", "")
            except Exception as e:
                reply = f"Sorry, I ran into an error: {e}"
                plan = "error"
            append_message(out_widget, "TinkerAI", reply, is_bot=True)
            status_widget.config(text=("done · plan: " + plan) if plan else "done",
                                 foreground=Theme.muted)
        threading.Thread(target=worker, daemon=True).start()

    # ---- Layout ----
    main = tk.Frame(root, bg=Theme.bg)
    main.pack(fill="both", expand=True, padx=12, pady=12)

    # Header
    tk.Label(main, text="TinkerAI", font=("Segoe UI", 16, "bold"),
             fg=Theme.accent, bg=Theme.bg).pack(anchor="w")
    tk.Label(main, text="on-device AI for TinkerOS", font=("Segoe UI", 9),
             fg=Theme.muted, bg=Theme.bg).pack(anchor="w", pady=(2, 12))

    # Quick-action buttons
    grid_wrap = tk.Frame(main, bg=Theme.bg)
    grid_wrap.pack(fill="x", pady=(0, 12))
    cols = 4
    for i, (label, q, _group) in enumerate(BUTTONS):
        r, c = divmod(i, cols)
        b = tk.Button(grid_wrap, text=label,
                      command=lambda txt=q: on_quick(txt),
                      font=("Segoe UI", 9, "bold"), fg=Theme.text,
                      bg=Theme.btn, activebackground=Theme.btn_hi,
                      activeforeground=Theme.text,
                      highlightbackground=Theme.border,
                      highlightthickness=1, padx=6, pady=6)
        b.grid(row=r, column=c, sticky="nsew", padx=4, pady=4)
    for c in range(cols):
        grid_wrap.grid_columnconfigure(c, weight=1)

    # Chat log
    chat = tk.Frame(main, bg=Theme.bg)
    chat.pack(fill="both", expand=True)
    tk.Label(chat, text="Assistant", font=("Segoe UI", 9),
             fg=Theme.muted, bg=Theme.bg).pack(anchor="w")
    out = tk.Text(chat, wrap="word", height=16, font=("Segoe UI", 10),
                  bg=Theme.panel, fg=Theme.text, insertbackground=Theme.accent,
                  relief="flat", highlightbackground=Theme.border,
                  highlightthickness=1)
    out.pack(fill="both", expand=True, pady=(4, 8))
    out.configure(state="disabled")

    # Input row
    row = tk.Frame(main, bg=Theme.bg)
    row.pack(fill="x")
    entry = tk.Entry(row, font=("Segoe UI", 10), bg=Theme.panel, fg=Theme.text,
                     insertbackground=Theme.accent, relief="flat",
                     highlightbackground=Theme.border, highlightthickness=1)
    entry.pack(side="left", fill="x", expand=True, padx=(0, 8), ipady=6, ipadx=8)
    entry.insert(0, "Ask TinkerAI anything...")
    entry.config(fg=Theme.muted)

    def on_enter(e):
        if e["type"] == "FocusIn":
            if entry.get() == "Ask TinkerAI anything...":
                entry.delete(0, "end"); entry.config(fg=Theme.text)
        elif e["type"] == "FocusOut":
            if not entry.get():
                entry.insert(0, "Ask TinkerAI anything..."); entry.config(fg=Theme.muted)

    entry.bind("<FocusIn>", on_enter)
    entry.bind("<FocusOut>", on_enter)

    def do_send():
        q = entry.get().strip()
        if not q or q == "Ask TinkerAI anything...":
            return
        append_message(out, "You", q, is_bot=False)
        entry.delete(0, "end"); entry.config(fg=Theme.text)
        send_query(q, out, status)
    send_btn = tk.Button(row, text="Send", command=do_send,
                         font=("Segoe UI", 9, "bold"), fg=Theme.text,
                         bg=Theme.accent, activebackground="#3d84e6")
    send_btn.pack(side="right")

    def on_quick(q):
        append_message(out, "You", q, is_bot=False)
        send_query(q, out, status)

    # Status line
    status = tk.Label(main, text="Idle · ready", font=("Segoe UI", 8),
                      fg=Theme.muted, bg=Theme.bg, anchor="w")
    status.pack(fill="x", pady=(8, 0))

    def append_message(text_widget, speaker, msg, is_bot=False):
        text_widget.configure(state="normal")
        tag = "bot" if is_bot else "user"
        name_color = Theme.accent if is_bot else Theme.green
        text_widget.insert("end", f"{speaker}: ", (tag, "name"))
        text_widget.insert("end", msg + "\n\n")
        text_widget.tag_config("name", foreground=name_color, font=("Segoe UI", 10, "bold"))
        text_widget.tag_config("user", foreground=Theme.text)
        text_widget.tag_config("bot", foreground=Theme.text)
        text_widget.see("end")
        text_widget.configure(state="disabled")

    entry.bind("<Return>", lambda e: do_send())

    def on_closing():
        try:
            with proc_lock:
                proc.stdin.write("EXIT\n"); proc.stdin.flush()
        except Exception:
            pass
        try:
            proc.terminate(); proc.wait(timeout=3)
        except Exception:
            pass
        root.destroy()

    root.protocol("WM_DELETE_WINDOW", on_closing)
    root.mainloop()


def run_cli_fallback():
    print("tinkerai CLI")
    proc = subprocess.Popen([AGENT_PY, str(AGENT)], text=True)
    sys.exit(proc.wait())


if __name__ == "__main__":
    try:
        run_gui()
    except ImportError as e:
        # tkinter not available
        print(f"GUI unavailable ({e}); falling back to CLI.")
        run_cli_fallback()

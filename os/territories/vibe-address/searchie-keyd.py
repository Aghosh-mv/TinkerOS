#!/usr/bin/env python3
"""
SEARCHIE-KEYD — literal Tab+F7 global hotkey daemon (X11)
==========================================================
Tap = hold Tab, then press F7 within the window: Searchie opens.
A real two-key chord that GNOME / xbindkeys cannot express natively
(GNOME only binds MODIFIER + key; xbindkeys needs >= 1 modifier).

Implements the chord by streaming raw keyboard events through XInput2
(`xinput test-xi2`), which reports keycodes up/down without any grabs —
nothing is stolen from the running desktop. Works on plain X11 and
inside Xvfb (testable). On Wayland this daemon exits silently; the
`searchie bind-f7` installer then uses a gsettings accelerator instead.

Uses: xinput, sh -c. No Python X11 bindings required.
"""
import os
import re
import signal
import subprocess
import sys
import time

GRAB_WINDOW_MS = 320      # max gap between Tab-down and F7-down
CHORD_DRAIN_MS = 80       # ignore repeat-rate F7 keydowns after firing
LAUNCHER = os.environ.get(
    "SEARCHIE_LAUNCHER",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "searchie"),
)

EVENT_RE = re.compile(r"EVENT type [0-9]+ \((RawKeyPress|RawKeyRelease|RawButtonPress|RawButtonRelease)\)")
DETAIL_RE = re.compile(r"detail:\s+(\d+)")

# X keycodes are physical; resolve Tab/F7 once from `xmodmap -pk`.
def resolve_keycodes():
    """Return (tab_keycode, f7_keycode) or (0,0)."""
    tab = f7 = 0
    try:
        out = subprocess.run(["xmodmap", "-pk"], capture_output=True, text=True,
                             timeout=5).stdout
    except Exception:
        return 0, 0
    for line in out.splitlines():
        m = re.match(r"\s*(\d+)\s+0x[0-9a-fA-F]+\s+\(?(Tab|F7)\b", line)
        if m:
            if m.group(2) == "Tab":
                tab = int(m.group(1))
            elif m.group(2) == "F7":
                f7 = int(m.group(1))
    return tab, f7


def pick_device():
    """Id of the master XInput2 virtual core keyboard."""
    try:
        out = subprocess.run(["xinput", "list"], capture_output=True, text=True,
                             timeout=5).stdout
    except Exception:
        return None
    for line in out.splitlines():
        if "Virtual core keyboard" in line and "pointer" not in line:
            m = re.search(r"id=(\d+)", line)
            if m:
                return m.group(1)
    # fallback: the first keyboard slave
    return None


def launch():
    subprocess.Popen([LAUNCHER], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    if os.environ.get("WAYLAND_DISPLAY"):
        print("searchie-keyd: Wayland session — no Tab+F7 chord; "
              "use the gsettings fallback binding instead.", file=sys.stderr)
        sys.exit(0)
    if not os.environ.get("DISPLAY"):
        print("searchie-keyd: no display — nothing to do.", file=sys.stderr)
        sys.exit(0)

    tab_kc, f7_kc = resolve_keycodes()
    if not (tab_kc and f7_kc):
        print("searchie-keyd: cannot resolve Tab/F7 keycodes (xmodmap?)",
              file=sys.stderr)
        sys.exit(2)

    dev = pick_device()
    if not dev:
        print("searchie-keyd: no virtual keyboard (xinput?)", file=sys.stderr)
        sys.exit(2)

    stop = {"flag": False}
    debug = os.environ.get("SEARCHIE_KEYD_DEBUG") == "1"

    def _stop(_s, _f):
        stop["flag"] = True
        sys.exit(0)

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    try:
        proc = subprocess.Popen(["xinput", "test-xi2", dev],
                                stdout=subprocess.PIPE, text=True,
                                bufsize=1)
    except Exception as e:
        print(f"searchie-keyd: cannot start xinput: {e}", file=sys.stderr)
        sys.exit(2)

    tab_down = False
    last_f7 = 0.0
    pending_f7 = False
    evtype = ""
    print(f"searchie-keyd: Tab+F7 chord live (tab={tab_kc} f7={f7_kc})",
          file=sys.stderr)

    for raw in proc.stdout:
        if stop["flag"]:
            break
        line = raw.strip()
        em = EVENT_RE.search(line)
        if em:
            evtype = em.group(1)
            if debug:
                print(f"[dbg] event={evtype}", file=sys.stderr, flush=True)
            continue
        m = DETAIL_RE.match(line)
        if not m:
            continue
        kc = int(m.group(1))
        if debug:
            print(f"[dbg] detail={kc} evtype={evtype}", file=sys.stderr, flush=True)
        now = time.monotonic()
        if kc == tab_kc and evtype == "RawKeyPress":
            tab_down = True
        elif kc == tab_kc and evtype == "RawKeyRelease":
            tab_down = False
            pending_f7 = False
        elif kc == f7_kc and evtype == "RawKeyPress" and tab_down:
            if now - last_f7 > (CHORD_DRAIN_MS / 1000.0):
                launch()
                last_f7 = now
                pending_f7 = True
        elif kc == f7_kc and evtype == "RawKeyRelease":
            pending_f7 = False


if __name__ == "__main__":
    main()
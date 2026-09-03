#!/usr/bin/env python3
"""
Taskbar AI Launcher for TinkerAI

This script acts as the taskbar integration point. When clicked,
it reads the current screen context, summarizes it, and then answers
user questions using local AI capabilities.

Protocol: --serve flag for communicating queries
"""

import os, sys, json, subprocess, time
from pathlib import Path

# Add tinkerai to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tinker_ai import TinkerHarness

HARNESS_PATH = "/home/tinkerspace/linux-kernel/os/tinkerai/tinker_ai.py"


def send_query_to_harness(query):
    """Send a query to the harness via --serve protocol."""
    import subprocess as sp
    try:
        proc = subprocess.Popen(
            ["python3", HARNESS_PATH, "--serve"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
        )
        try:
            with proc.stdin:
                proc.stdin.write(query + "\n")
                proc.stdin.flush()
                line = proc.stdout.readline().strip()
                if line.startswith("{"):
                    return json.loads(line)
        except Exception:
            return {"reply": "Error communicating", "plan": "error"}
        finally:
            try:
                proc.stdin.write("EXIT\n")
                proc.stdin.flush()
            except Exception:
                pass
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()
    except Exception:
        return {"reply": "Communication error", "plan": "error"}
    return {"reply": "No response", "plan": "error"}


def _collect_context():
    """Gather real OS/screen context for the AI to reason about."""
    lines = []
    try:
        win = subprocess.run(
            ["xdotool", "getactivewindow", "getwindowname"],
            capture_output=True, text=True, timeout=3,
        ).stdout.strip()
        lines.append(f"Active window: {win or 'unknown'}")
    except Exception:
        lines.append("Active window: unavailable (no X session)")

    try:
        load = os.getloadavg()
        lines.append(f"CPU load: {load[0]:.2f} (1m)")
    except Exception:
        pass

    try:
        with open("/proc/meminfo") as f:
            mem = dict(l.split(":", 1) for l in f if ":" in l)
        total = int(mem.get("MemTotal", "0").split()[0]) / 1024 / 1024
        avail = int(mem.get("MemAvailable", "0").split()[0]) / 1024 / 1024
        pct = int(100 * (1 - avail / total)) if total else 0
        lines.append(f"RAM: {pct}% used")
    except Exception:
        pass

    try:
        procs = subprocess.run(
            ["ps", "-eo", "comm", "--sort=-%cpu"],
            capture_output=True, text=True, timeout=3,
        ).stdout.split()
        top = [p for p in procs[1:6] if p != "ps"]
        lines.append("Top processes: " + ", ".join(top))
    except Exception:
        pass

    try:
        for s in sorted(Path("/sys/class/power_supply").glob("*")):
            if (s / "type").read_text().strip() == "Battery":
                lines.append(f"Battery: {s.name}")
    except Exception:
        pass

    if not lines:
        lines.append("TinkerAI is running on TinkerOS with access to system tools.")
    return "\n".join(lines)


def taskbar_interface():
    """Main taskbar interface - reads context and answers questions."""
    harness = TinkerHarness()
    
    # Read real screen/system context (was a hardcoded placeholder)
    context = _collect_context()
    
    # If there's a query argument, use it; otherwise show status
    if len(sys.argv) > 1 and sys.argv[1] != "--context":
        query = " ".join(sys.argv[1:])
        result = send_query_to_harness(query)
        return result.get("reply", str(result))
    elif "--context" in sys.argv:
        return context
    else:
        # Show available skills
        help_text = harness._t_help()
        return help_text + "\n\n" + context


if __name__ == "__main__":
    result = taskbar_interface()
    print(result)

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


def taskbar_interface():
    """Main taskbar interface - reads context and answers questions."""
    harness = TinkerHarness()
    
    # Read context from screen (placeholder - would use computer_use in full implementation)
    context = "TinkerAI is running on TinkerOS with access to system tools."
    
    # If there's a query argument, use it; otherwise show status
    if len(sys.argv) > 1:
        query = " ".join(sys.argv[1:])
        result = send_query_to_harness(query)
        return result.get("reply", str(result))
    else:
        # Show available skills
        help_text = harness._t_help()
        return help_text


if __name__ == "__main__":
    result = taskbar_interface()
    print(result)

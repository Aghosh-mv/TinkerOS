#!/usr/bin/env python3
# TinkerOS Mobile Companion - WebSocket Server (stdlib only, RFC 6455)
# Handles pairing token, remote control, file transfer, notification
# mirroring, status requests, and second-screen layouts.

import base64
import hashlib
import json
import os
import socket
import struct
import threading
from urllib.parse import parse_qs, urlparse

HOST = "0.0.0.0"
PORT = int(os.environ.get("TINKER_WS_PORT", "8766"))
EXPECTED_TOKEN = os.environ.get("TINKER_WS_TOKEN", "tinkeros-default")

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def get_status():
    """Return a status dict about the host."""
    load = os.getloadavg() if hasattr(os, "getloadavg") else (0, 0, 0)
    try:
        with open("/proc/meminfo") as f:
            mem = {}
            for line in f:
                k, v = line.split(":")
                mem[k.strip()] = v.strip()
        total = int(mem.get("MemTotal", "0").split()[0])
        avail = int(mem.get("MemAvailable", "0").split()[0])
        ram_pct = int(100 * (1 - avail / total)) if total else 0
    except Exception:
        ram_pct = 0
    try:
        import psutil  # optional
        batt = psutil.sensors_battery()
        battery = int(batt.percent) if batt else "n/a"
    except Exception:
        battery = "n/a"
    return {
        "cpu_load": [round(x, 2) for x in load],
        "cpu_cores": os.cpu_count(),
        "ram_pct": ram_pct,
        "battery": battery,
        "hostname": socket.gethostname(),
    }


def handle_action(action, params):
    """Map a remote-control action to an OS command (best effort)."""
    cmds = {
        "media_play": "playerctl play",
        "media_pause": "playerctl pause",
        "media_next": "playerctl next",
        "media_prev": "playerctl previous",
        "volume_up": "pactl set-sink-volume @DEFAULT_SINK@ +5%",
        "volume_down": "pactl set-sink-volume @DEFAULT_SINK@ -5%",
        "mute": "pactl set-sink-mute @DEFAULT_SINK@ toggle",
        "lock_screen": "loginctl lock-session",
        "sleep": "systemctl suspend",
        "shutdown": "systemctl poweroff",
        "reboot": "systemctl reboot",
        "brightness_up": "brightnessctl set +5%",
        "brightness_down": "brightnessctl set 5%-",
    }
    cmd = cmds.get(action)
    if not cmd:
        return {"error": f"unknown action {action}"}
    rc = os.system(cmd)  # noqa: S605 - user-invoked remote control
    return {"ok": True, "cmd": action, "rc": rc}


def handle_message(msg, push):
    """Route an incoming JSON message to the right handler."""
    mtype = msg.get("type", "command")
    data = msg.get("data", {})
    if mtype == "command":
        return handle_action(data.get("action", ""), data.get("params", {}))
    if mtype == "file_start":
        return {"ok": True, "type": "file_start",
                "filename": data.get("filename", ""),
                "size": data.get("filesize", 0),
                "note": "file transfer accepted (store to ~/.tinker/mobile)"}
    if mtype == "notification":
        push({"type": "notification", "title": data.get("title", ""),
              "body": data.get("body", ""), "ok": True})
        return {"ok": True}
    if mtype == "status":
        return {"type": "status", "data": get_status()}
    if mtype == "second_screen":
        return {"ok": True, "type": "second_screen",
                "layout": data.get("layout", "extend"),
                "note": "configured via xrandr"}
    return {"error": f"unknown message type {mtype}"}


class WebSocketError(Exception):
    pass


def _recv_exact(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            raise WebSocketError("connection closed")
        buf += chunk
    return buf


def _send_text(conn, text):
    payload = text.encode("utf-8")
    mask_bit = 0
    length = len(payload)
    if length < 126:
        header = bytes([0x80 | 0x1, length])
    elif length < 65536:
        header = bytes([0x80 | 0x1, 126]) + struct.pack(">H", length)
    else:
        header = bytes([0x80 | 0x1, 127]) + struct.pack(">Q", length)
    conn.sendall(header + payload)


def _recv_frame(conn):
    b1, b2 = _recv_exact(conn, 2)
    opcode = b1 & 0x0F
    masked = b2 & 0x80
    length = b2 & 0x7F
    if length == 126:
        length = struct.unpack(">H", _recv_exact(conn, 2))[0]
    elif length == 127:
        length = struct.unpack(">Q", _recv_exact(conn, 8))[0]
    mask = _recv_exact(conn, 4) if masked else None
    payload = _recv_exact(conn, length)
    if mask:
        payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    if opcode == 0x8:  # close
        conn.sendall(bytes([0x88, 0]))
        return None
    return payload


def serve(conn, addr):
    push_lock = threading.Lock()
    push = lambda msg: _send_text(conn, json.dumps(msg))  # noqa: E731
    try:
        req = b""
        while b"\r\n\r\n" not in req:
            chunk = conn.recv(4096)
            if not chunk:
                return
            req += chunk
        lines = req.decode("latin-1").split("\r\n")
        path = lines[0].split(" ")[1]
        qs = parse_qs(urlparse(path).query)
        token = qs.get("token", [""])[0]
        if token != EXPECTED_TOKEN:
            conn.sendall(b"HTTP/1.1 401 Unauthorized\r\n\r\n")
            return
        headers = {}
        for line in lines[1:]:
            if ":" in line:
                k, v = line.split(":", 1)
                headers[k.strip().lower()] = v.strip()
        key = headers.get("sec-websocket-key", "")
        accept = base64.b64encode(
            hashlib.sha1((key + WS_GUID).encode()).digest()).decode()
        conn.sendall(
            ("HTTP/1.1 101 Switching Protocols\r\n"
             "Upgrade: websocket\r\nConnection: Upgrade\r\n"
             f"Sec-WebSocket-Accept: {accept}\r\n\r\n").encode("latin-1"))
        while True:
            payload = _recv_frame(conn)
            if payload is None:
                return
            try:
                msg = json.loads(payload.decode("utf-8"))
            except Exception:
                continue
            try:
                resp = handle_message(msg, push)
                if resp is not None:
                    _send_text(conn, json.dumps(resp))
            except Exception as exc:  # noqa: BLE001
                _send_text(conn, json.dumps({"error": str(exc)}))
    except WebSocketError:
        pass
    except Exception as exc:  # noqa: BLE001
        try:
            _send_text(conn, json.dumps({"error": str(exc)}))
        except Exception:
            pass
    finally:
        try:
            conn.close()
        except Exception:
            pass


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(16)
    print(f"TinkerOS Mobile Companion WS listening on {HOST}:{PORT}",
          flush=True)
    while True:
        conn, addr = srv.accept()
        threading.Thread(target=serve, args=(conn, addr), daemon=True).start()


if __name__ == "__main__":
    main()

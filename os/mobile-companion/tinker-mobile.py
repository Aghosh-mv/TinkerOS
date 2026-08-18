#!/usr/bin/env python3
"""
TinkerOS Mobile Companion Protocol
Phone as remote, second screen, file transfer, notifications mirror
"""

import os
import json
import asyncio
import websockets
import sqlite3
import hashlib
import secrets
import qrcode
import base64
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional
from datetime import datetime
from enum import Enum
import sys

class DeviceType(Enum):
    PHONE = "phone"
    TABLET = "tablet"
    WATCH = "watch"

class ConnectionType(Enum):
    LOCAL = "local"      # Same network (mDNS/Bonjour)
    TAILSCALE = "tailscale"  # Via Tailscale mesh
    INTERNET = "internet"    # Via relay server

@dataclass
class MobileDevice:
    id: str
    name: str
    type: DeviceType
    os: str
    app_version: str
    public_key: str
    capabilities: List[str]
    paired_at: str
    last_seen: str
    trusted: bool = True

@dataclass
class Notification:
    id: str
    app: str
    title: str
    body: str
    timestamp: str
    actions: List[Dict] = None
    priority: str = "normal"

@dataclass
class FileTransfer:
    id: str
    filename: str
    size: int
    mime_type: str
    sender_id: str
    receiver_id: str
    status: str
    progress: float = 0.0
    created_at: str = ""

class MobileCompanionServer:
    def __init__(self, data_dir: str = None):
        self.data_dir = Path(data_dir or os.path.expanduser("~/.tinker/mobile"))
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.data_dir / "mobile.db"
        self.downloads_dir = self.data_dir / "downloads"
        self.downloads_dir.mkdir(exist_ok=True)
        self.init_db()
        self.connected_devices = {}
        self.notification_queue = asyncio.Queue()
    
    def init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS devices (
                    id TEXT PRIMARY KEY,
                    name TEXT, type TEXT, os TEXT, app_version TEXT,
                    public_key TEXT, capabilities TEXT,
                    paired_at TEXT, last_seen TEXT, trusted BOOLEAN
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS notifications (
                    id TEXT PRIMARY KEY,
                    device_id TEXT, app TEXT, title TEXT, body TEXT,
                    timestamp TEXT, actions TEXT, priority TEXT,
                    FOREIGN KEY (device_id) REFERENCES devices(id)
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS file_transfers (
                    id TEXT PRIMARY KEY,
                    filename TEXT, size INTEGER, mime_type TEXT,
                    sender_id TEXT, receiver_id TEXT, status TEXT,
                    progress REAL, created_at TEXT, completed_at TEXT
                )
            """)
    
    def generate_pairing_code(self) -> str:
        """Generate 6-digit pairing code"""
        return f"{secrets.randbelow(1000000):06d}"
    
    def generate_qr_code(self, pairing_code: str, server_url: str) -> str:
        """Generate QR code for mobile app pairing"""
        data = f"tinker://pair?code={pairing_code}&url={server_url}"
        qr = qrcode.make(data)
        buffer = io.BytesIO()
        qr.save(buffer, format="PNG")
        return base64.b64encode(buffer.getvalue()).decode()
    
    def pair_device(self, device: MobileDevice, pairing_code: str) -> bool:
        """Pair mobile device with desktop"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT OR REPLACE INTO devices (id, name, type, os, app_version,
                    public_key, capabilities, paired_at, last_seen, trusted)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (device.id, device.name, device.type.value, device.os, device.app_version,
                  device.public_key, json.dumps(device.capabilities),
                  device.paired_at, device.last_seen, device.trusted))
        return True
    
    def get_paired_devices(self) -> List[MobileDevice]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute("SELECT * FROM devices WHERE trusted=1").fetchall()
            return [MobileDevice(
                id=r["id"], name=r["name"], type=DeviceType(r["type"]), os=r["os"],
                app_version=r["app_version"], public_key=r["public_key"],
                capabilities=json.loads(r["capabilities"]) if r["capabilities"] else [],
                paired_at=r["paired_at"], last_seen=r["last_seen"], trusted=bool(r["trusted"])
            ) for r in rows]
    
    async def send_notification(self, device_id: str, notification: Notification) -> bool:
        """Send notification to mobile device"""
        if device_id in self.connected_devices:
            ws = self.connected_devices[device_id]
            await ws.send(json.dumps({
                "type": "notification",
                "data": asdict(notification)
            }))
        
        # Store in DB for history
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT INTO notifications (id, device_id, app, title, body, timestamp, actions, priority)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (notification.id, device_id, notification.app, notification.title,
                  notification.body, notification.timestamp, json.dumps(notification.actions or []), notification.priority))
        return True
    
    async def mirror_desktop_notifications(self):
        """Mirror desktop notifications to mobile"""
        # In production: listen to D-Bus for org.freedesktop.Notifications
        pass
    
    async def handle_file_transfer(self, transfer: FileTransfer, ws) -> bool:
        """Handle incoming file transfer"""
        transfer.id = f"ft_{secrets.token_hex(8)}"
        transfer.created_at = datetime.utcnow().isoformat()
        transfer.status = "receiving"
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT INTO file_transfers (id, filename, size, mime_type,
                    sender_id, receiver_id, status, progress, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (transfer.id, transfer.filename, transfer.size, transfer.mime_type,
                  transfer.sender_id, transfer.receiver_id, transfer.status,
                  transfer.progress, transfer.created_at))
        
        # Receive file in chunks
        file_path = self.downloads_dir / transfer.filename
        received = 0
        
        async for chunk in ws:
            if isinstance(chunk, bytes):
                with open(file_path, "ab") as f:
                    f.write(chunk)
                received += len(chunk)
                transfer.progress = received / transfer.size
                
                # Update progress in DB
                with sqlite3.connect(self.db_path) as conn:
                    conn.execute("UPDATE file_transfers SET progress=? WHERE id=?",
                               (transfer.progress, transfer.id))
                
                if received >= transfer.size:
                    transfer.status = "completed"
                    with sqlite3.connect(self.db_path) as conn:
                        conn.execute("UPDATE file_transfers SET status=?, completed_at=? WHERE id=?",
                                   ("completed", datetime.utcnow().isoformat(), transfer.id))
                    break
        
        return True
    
    async def remote_control(self, device_id: str, command: Dict) -> Dict:
        """Handle remote control commands from mobile"""
        cmd = command.get("action")
        params = command.get("params", {})
        
        if cmd == "media_play":
            os.system("playerctl play")
        elif cmd == "media_pause":
            os.system("playerctl pause")
        elif cmd == "media_next":
            os.system("playerctl next")
        elif cmd == "media_prev":
            os.system("playerctl previous")
        elif cmd == "volume_up":
            os.system("pactl set-sink-volume @DEFAULT_SINK@ +5%")
        elif cmd == "volume_down":
            os.system("pactl set-sink-volume @DEFAULT_SINK@ -5%")
        elif cmd == "volume_mute":
            os.system("pactl set-sink-mute @DEFAULT_SINK@ toggle")
        elif cmd == "lock_screen":
            os.system("xdg-screensaver lock")
        elif cmd == "sleep":
            os.system("systemctl suspend")
        elif cmd == "shutdown":
            os.system("systemctl poweroff")
        elif cmd == "reboot":
            os.system("systemctl reboot")
        elif cmd == "run_command":
            os.system(params.get("command", ""))
        elif cmd == "type_text":
            os.system(f"xdotool type '{params.get('text', '')}'")
        elif cmd == "key_press":
            os.system(f"xdotool key {params.get('key', '')}")
        elif cmd == "mouse_move":
            os.system(f"xdotool mousemove {params.get('x', 0)} {params.get('y', 0)}")
        elif cmd == "mouse_click":
            os.system(f"xdotool click {params.get('button', 1)}")
        elif cmd == "screenshot":
            os.system("gnome-screenshot -a -f /tmp/mobile_screenshot.png")
            return {"success": True, "file": "/tmp/mobile_screenshot.png"}
        
        return {"success": True}
    
    def get_system_status(self) -> Dict:
        """Get system status for mobile dashboard"""
        cpu = subprocess.run(["cat", "/proc/loadavg"], capture_output=True, text=True).stdout.strip()
        mem = subprocess.run(["free", "-h"], capture_output=True, text=True).stdout.strip()
        disk = subprocess.run(["df", "-h", "/"], capture_output=True, text=True).stdout.strip()
        battery = subprocess.run(["cat", "/sys/class/power_supply/BAT0/capacity"], 
                               capture_output=True, text=True).stdout.strip() if os.path.exists("/sys/class/power_supply/BAT0") else "N/A"
        
        return {
            "cpu_load": cpu,
            "memory": mem,
            "disk": disk,
            "battery": battery,
            "timestamp": datetime.utcnow().isoformat()
        }

class MobileCompanionCLI:
    def __init__(self):
        self.server = MobileCompanionServer()
    
    def pair(self, name: str):
        """Pair a new mobile device"""
        code = self.server.generate_pairing_code()
        print(f"Pairing code: {code}")
        print("Enter this code in the TinkerOS mobile app")
        print("Or scan the QR code:")
        qr_b64 = self.server.generate_qr_code(code, "ws://localhost:8766")
        print(f"QR Code (base64): {qr_b64[:50]}...")
    
    def list_devices(self):
        devices = self.server.get_paired_devices()
        for d in devices:
            print(f"  {d.name} ({d.type.value}) - {d.os} - Last seen: {d.last_seen}")
    
    def send_notification(self, device_id: str, title: str, body: str):
        notif = Notification(
            id=f"notif_{secrets.token_hex(6)}",
            app="TinkerOS",
            title=title,
            body=body,
            timestamp=datetime.utcnow().isoformat()
        )
        asyncio.run(self.server.send_notification(device_id, notif))
        print("Notification sent")

if __name__ == "__main__":
    import subprocess
    import io
    
    cli = MobileCompanionCLI()
    
    if len(sys.argv) < 2:
        print("Usage: tinker-mobile [pair|list|notify|status]")
        sys.exit(1)
    
    if sys.argv[1] == "pair":
        cli.pair(sys.argv[2] if len(sys.argv) > 2 else "Phone")
    elif sys.argv[1] == "list":
        cli.list_devices()
    elif sys.argv[1] == "notify":
        cli.send_notification(sys.argv[2], sys.argv[3], sys.argv[4])
    elif sys.argv[1] == "status":
        status = cli.server.get_system_status()
        print(json.dumps(status, indent=2))
    else:
        print("Unknown command")


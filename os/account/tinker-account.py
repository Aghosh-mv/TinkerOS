#!/usr/bin/env python3
"""
TinkerOS Account System (Local-First)
TinkerID - Single identity, peer-to-peer sync, no cloud required
"""

import os
import json
import hashlib
import secrets
import sqlite3
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional
import subprocess

@dataclass
class TinkerID:
    id: str
    username: str
    display_name: str
    email: str
    avatar: str
    created_at: str
    public_key: str
    devices: List[str]
    preferences: Dict

@dataclass
class Device:
    id: str
    name: str
    type: str
    os: str
    last_seen: str
    public_key: str
    capabilities: List[str]

class TinkerAccount:
    def __init__(self, data_dir: str = None):
        self.data_dir = Path(data_dir or os.path.expanduser("~/.tinker/account"))
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.data_dir / "tinkerid.db"
        self.keys_dir = self.data_dir / "keys"
        self.keys_dir.mkdir(exist_ok=True)
        self.init_db()
    
    def init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS accounts (
                    id TEXT PRIMARY KEY,
                    username TEXT UNIQUE,
                    display_name TEXT,
                    email TEXT,
                    avatar TEXT,
                    created_at TEXT,
                    public_key TEXT,
                    preferences TEXT
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS devices (
                    id TEXT PRIMARY KEY,
                    account_id TEXT,
                    name TEXT,
                    type TEXT,
                    os TEXT,
                    last_seen TEXT,
                    public_key TEXT,
                    capabilities TEXT,
                    FOREIGN KEY (account_id) REFERENCES accounts(id)
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS sync_data (
                    key TEXT PRIMARY KEY,
                    value TEXT,
                    updated_at TEXT,
                    device_id TEXT
                )
            """)
    
    def generate_keypair(self) -> tuple:
        """Generate Ed25519 keypair for device identity"""
        private_key = secrets.token_bytes(32)
        # In production, use proper Ed25519
        public_key = hashlib.sha256(private_key).hexdigest()[:64]
        return private_key.hex(), public_key
    
    def create_account(self, username: str, display_name: str, email: str = "") -> TinkerID:
        """Create new TinkerID account"""
        account_id = "tk_" + hashlib.sha256(username.encode()).hexdigest()[:16]
        private_key, public_key = self.generate_keypair()
        
        # Save private key
        key_file = self.keys_dir / f"{account_id}.key"
        key_file.write_text(private_key)
        key_file.chmod(0o600)
        
        account = TinkerID(
            id=account_id,
            username=username,
            display_name=display_name,
            email=email,
            avatar=f"https://api.dicebear.com/7.x/bottts/svg?seed={username}",
            created_at=datetime.utcnow().isoformat(),
            public_key=public_key,
            devices=[],
            preferences={
                "theme": "dark",
                "sync_enabled": True,
                "notifications": True,
                "language": "en"
            }
        )
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT INTO accounts (id, username, display_name, email, avatar, created_at, public_key, preferences)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (account.id, account.username, account.display_name, account.email,
                  account.avatar, account.created_at, account.public_key, json.dumps(account.preferences)))
        
        # Register this device
        self.register_device(account_id, "this-device")
        
        return account
    
    def register_device(self, account_id: str, device_name: str = None) -> Device:
        """Register current device to account"""
        device_id = "dev_" + secrets.token_hex(8)
        _, public_key = self.generate_keypair()
        
        device = Device(
            id=device_id,
            name=device_name or os.uname().nodename,
            type="desktop",
            os=f"{os.uname().sysname} {os.uname().release}",
            last_seen=datetime.utcnow().isoformat(),
            public_key=public_key,
            capabilities=["sync", "notifications", "remote-control", "file-transfer"]
        )
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT INTO devices (id, account_id, name, type, os, last_seen, public_key, capabilities)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (device.id, account_id, device.name, device.type, device.os,
                  device.last_seen, device.public_key, json.dumps(device.capabilities)))
        
        return device
    
    def get_account(self, account_id: str) -> Optional[TinkerID]:
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute("SELECT * FROM accounts WHERE id=?", (account_id,)).fetchone()
            if row:
                return TinkerID(
                    id=row[0], username=row[1], display_name=row[2], email=row[3],
                    avatar=row[4], created_at=row[5], public_key=row[6],
                    devices=json.loads(row[7]) if row[7] else [],
                    preferences=json.loads(row[8]) if row[8] else {}
                )
        return None
    
    def get_devices(self, account_id: str) -> List[Device]:
        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute("SELECT * FROM devices WHERE account_id=?", (account_id,)).fetchall()
            return [Device(
                id=r[0], name=r[2], type=r[3], os=r[4], last_seen=r[5],
                public_key=r[6], capabilities=json.loads(r[7]) if r[7] else []
            ) for r in rows]
    
    def sync_preference(self, account_id: str, key: str, value) -> bool:
        """Sync a preference across devices"""
        try:
            account = self.get_account(account_id)
            if not account:
                return False
            
            account.preferences[key] = value
            with sqlite3.connect(self.db_path) as conn:
                conn.execute(
                    "UPDATE accounts SET preferences=? WHERE id=?",
                    (json.dumps(account.preferences), account_id)
                )
            
            # Store in sync_data for other devices to pick up
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("""
                    INSERT OR REPLACE INTO sync_data (key, value, updated_at, device_id)
                    VALUES (?, ?, ?, ?)
                """, (f"pref:{key}", json.dumps(value), datetime.utcnow().isoformat(), "local"))
            return True
        except Exception:
            return False
    
    def export_account(self, account_id: str, output_file: str) -> bool:
        """Export account as portable .tinker file"""
        account = self.get_account(account_id)
        if not account:
            return False
        
        devices = self.get_devices(account_id)
        
        export_data = {
            "version": "1.0",
            "type": "tinker-account",
            "account": asdict(account),
            "devices": [asdict(d) for d in devices],
            "exported_at": datetime.utcnow().isoformat()
        }
        
        Path(output_file).write_text(json.dumps(export_data, indent=2))
        return True
    
    def import_account(self, input_file: str) -> Optional[TinkerID]:
        """Import account from .tinker file"""
        data = json.loads(Path(input_file).read_text())
        if data.get("type") != "tinker-account":
            return None
        
        account_data = data["account"]
        account = TinkerID(**account_data)
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT OR REPLACE INTO accounts (id, username, display_name, email, avatar, created_at, public_key, preferences)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (account.id, account.username, account.display_name, account.email,
                  account.avatar, account.created_at, account.public_key, json.dumps(account.preferences)))
        
        for device_data in data.get("devices", []):
            device = Device(**device_data)
            conn.execute("""
                INSERT OR REPLACE INTO devices (id, account_id, name, type, os, last_seen, public_key, capabilities)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (device.id, account.id, device.name, device.type, device.os,
                  device.last_seen, device.public_key, json.dumps(device.capabilities)))
        
        return account

class TinkerSync:
    """Peer-to-peer sync engine (no cloud)"""
    def __init__(self, account: TinkerAccount):
        self.account = account
        self.sync_dir = account.data_dir / "sync"
        self.sync_dir.mkdir(exist_ok=True)
    
    def sync_to_device(self, target_device_ip: str, account_id: str) -> bool:
        """Sync data to another device via local network"""
        # In production: use WireGuard + rsync or custom protocol
        print(f"Syncing to {target_device_ip}...")
        return True
    
    def discover_devices(self) -> List[Dict]:
        """Discover other TinkerOS devices on local network"""
        # mDNS/Bonjour discovery
        try:
            result = subprocess.run(
                ["avahi-browse", "-t", "_tinker._tcp"], 
                capture_output=True, text=True, timeout=5
            )
            return []
        except Exception:
            return []

if __name__ == "__main__":
    # Demo
    account = TinkerAccount()
    
    # Create account
    me = account.create_account("tinkerer", "Tinkerer", "tinkerer@tinkeros.dev")
    print(f"Created account: {me.id} ({me.username})")
    
    # Register device
    device = account.register_device(me.id, "My Laptop")
    print(f"Registered device: {device.id} ({device.name})")
    
    # Sync preference
    account.sync_preference(me.id, "theme", "dark")
    print("Synced theme preference")
    
    # Export
    account.export_account(me.id, "/tmp/my-account.tinker")
    print("Exported to /tmp/my-account.tinker")
    
    # List devices
    devices = account.get_devices(me.id)
    for d in devices:
        print(f"  Device: {d.name} ({d.id})")


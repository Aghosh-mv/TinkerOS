#!/usr/bin/env python3
"""
TinkerOS Hardware Certification Database
Community-driven hardware compatibility with automated testing
"""

import os, json, sqlite3, hashlib, subprocess, platform
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
from datetime import datetime
from enum import Enum
import sys

class CertificationLevel(Enum):
    UNTESTED = "untested"
    WORKS = "works"
    PARTIAL = "partial"
    BROKEN = "broken"
    CERTIFIED = "certified"

class ComponentType(Enum):
    LAPTOP = "laptop"
    DESKTOP = "desktop"
    GPU = "gpu"
    CPU = "cpu"
    MOTHERBOARD = "motherboard"
    WIFI = "wifi"
    AUDIO = "audio"
    WEBCAM = "webcam"
    FINGERPRINT = "fingerprint"
    THUNDERBOLT = "thunderbolt"
    DOCK = "dock"
    MONITOR = "monitor"
    PERIPHERAL = "peripheral"

@dataclass
class HardwareEntry:
    id: str
    name: str
    vendor: str
    model: str
    component_type: ComponentType
    certification: CertificationLevel
    kernel_version: str
    tinkeros_version: str
    works_oob: bool  # works out of box
    needs_firmware: bool
    needs_dkms: bool
    notes: str
    submitter: str
    submitted_at: str
    verified_by: List[str]
    test_results: Dict
    upvotes: int = 0
    downvotes: int = 0

@dataclass
class TestSuite:
    id: str
    name: str
    component_type: ComponentType
    tests: List[Dict]
    kernel_min: str
    tinkeros_min: str

class HardwareCertDB:
    def __init__(self, data_dir: str = None):
        self.data_dir = Path(data_dir or os.path.expanduser("~/.tinker/hardware-cert"))
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.data_dir / "hardware-cert.db"
        self.init_db()
        self.load_test_suites()
    
    def init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""CREATE TABLE IF NOT EXISTS hardware (
                id TEXT PRIMARY KEY, name TEXT, vendor TEXT, model TEXT,
                component_type TEXT, certification TEXT, kernel_version TEXT,
                tinkeros_version TEXT, works_oob BOOLEAN, needs_firmware BOOLEAN,
                needs_dkms BOOLEAN, notes TEXT, submitter TEXT, submitted_at TEXT,
                verified_by TEXT, test_results TEXT, upvotes INTEGER, downvotes INTEGER)""")
            conn.execute("""CREATE TABLE IF NOT EXISTS test_suites (
                id TEXT PRIMARY KEY, name TEXT, component_type TEXT,
                tests TEXT, kernel_min TEXT, tinkeros_min TEXT)""")
            conn.execute("""CREATE TABLE IF NOT EXISTS votes (
                id TEXT PRIMARY KEY, hardware_id TEXT, voter TEXT, vote INTEGER,
                voted_at TEXT)""")
            conn.execute("""CREATE TABLE IF NOT EXISTS verification (
                id TEXT PRIMARY KEY, hardware_id TEXT, verifier TEXT,
                verified_at TEXT, test_log TEXT)""")
    
    def load_test_suites(self):
        suites = [
            TestSuite("gpu_basic", "GPU Basic", ComponentType.GPU,
                [{"name": "drm", "cmd": "ls /dev/dri"}, {"name": "glx", "cmd": "glxinfo | grep OpenGL"},
                 {"name": "vulkan", "cmd": "vulkaninfo | grep deviceName"}],
                "5.10", "1.0"),
            TestSuite("wifi_basic", "WiFi Basic", ComponentType.WIFI,
                [{"name": "interface", "cmd": "ip link | grep wl"},
                 {"name": "scan", "cmd": "nmcli device wifi list"},
                 {"name": "connect", "cmd": "nmcli device wifi connect"}],
                "5.10", "1.0"),
            TestSuite("audio_basic", "Audio Basic", ComponentType.AUDIO,
                [{"name": "pulseaudio", "cmd": "pactl info"},
                 {"name": "alsa", "cmd": "aplay -l"},
                 {"name": "pipewire", "cmd": "pw-cli info 0"}],
                "5.10", "1.0"),
            TestSuite("webcam_basic", "Webcam Basic", ComponentType.WEBCAM,
                [{"name": "v4l2", "cmd": "v4l2-ctl --list-devices"},
                 {"name": "test", "cmd": "ffmpeg -f v4l2 -i /dev/video0 -t 1 -f null -"}],
                "5.10", "1.0"),
        ]
        with sqlite3.connect(self.db_path) as conn:
            for suite in suites:
                conn.execute("""INSERT OR IGNORE INTO test_suites VALUES (?,?,?,?,?,?)""",
                    (suite.id, suite.name, suite.component_type.value,
                     json.dumps(suite.tests), suite.kernel_min, suite.tinkeros_min))
    
    def add_hardware(self, hw: HardwareEntry) -> bool:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""INSERT OR REPLACE INTO hardware VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (hw.id, hw.name, hw.vendor, hw.model, hw.component_type.value,
                 hw.certification.value, hw.kernel_version, hw.tinkeros_version,
                 hw.works_oob, hw.needs_firmware, hw.needs_dkms, hw.notes,
                 hw.submitter, hw.submitted_at, json.dumps(hw.verified_by),
                 json.dumps(hw.test_results), hw.upvotes, hw.downvotes))
        return True
    
    def get_hardware(self, hw_id: str) -> Optional[HardwareEntry]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute("SELECT * FROM hardware WHERE id=?", (hw_id,)).fetchone()
            if row: return HardwareEntry(id=row["id"], name=row["name"], vendor=row["vendor"],
                model=row["model"], component_type=ComponentType(row["component_type"]),
                certification=CertificationLevel(row["certification"]),
                kernel_version=row["kernel_version"], tinkeros_version=row["tinkeros_version"],
                works_oob=bool(row["works_oob"]), needs_firmware=bool(row["needs_firmware"]),
                needs_dkms=bool(row["needs_dkms"]), notes=row["notes"],
                submitter=row["submitter"], submitted_at=row["submitted_at"],
                verified_by=json.loads(row["verified_by"]), test_results=json.loads(row["test_results"]),
                upvotes=row["upvotes"], downvotes=row["downvotes"])
        return None
    
    def search(self, query: str = "", component_type: ComponentType = None,
               certification: CertificationLevel = None, vendor: str = "") -> List[HardwareEntry]:
        sql = "SELECT * FROM hardware WHERE 1=1"
        params = []
        if query: sql += " AND (name LIKE ? OR model LIKE ?)"; params.extend([f"%{query}%", f"%{query}%"])
        if component_type: sql += " AND component_type=?"; params.append(component_type.value)
        if certification: sql += " AND certification=?"; params.append(certification.value)
        if vendor: sql += " AND vendor LIKE ?"; params.append(f"%{vendor}%")
        sql += " ORDER BY upvotes DESC, submitted_at DESC"
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(sql, params).fetchall()
            return [HardwareEntry(id=r["id"], name=r["name"], vendor=r["vendor"], model=r["model"],
                component_type=ComponentType(r["component_type"]), certification=CertificationLevel(r["certification"]),
                kernel_version=r["kernel_version"], tinkeros_version=r["tinkeros_version"],
                works_oob=bool(r["works_oob"]), needs_firmware=bool(r["needs_firmware"]),
                needs_dkms=bool(r["needs_dkms"]), notes=r["notes"], submitter=r["submitter"],
                submitted_at=r["submitted_at"], verified_by=json.loads(r["verified_by"]),
                test_results=json.loads(r["test_results"]), upvotes=r["upvotes"], downvotes=r["downvotes"]) for r in rows]
    
    def run_tests(self, component_type: ComponentType, hw_id: str) -> Dict:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            suites = conn.execute("SELECT * FROM test_suites WHERE component_type=?", (component_type.value,)).fetchall()
        
        results = {}
        for suite in suites:
            tests = json.loads(suite["tests"])
            suite_results = {}
            for test in tests:
                try:
                    result = subprocess.run(test["cmd"], shell=True, capture_output=True, text=True, timeout=30)
                    suite_results[test["name"]] = {"passed": result.returncode == 0, "output": result.stdout[:500]}
                except Exception as e:
                    suite_results[test["name"]] = {"passed": False, "error": str(e)}
            results[suite["name"]] = suite_results
        
        # Update hardware entry
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("UPDATE hardware SET test_results=? WHERE id=?", (json.dumps(results), hw_id))
        
        return results
    
    def vote(self, hw_id: str, voter: str, vote: int) -> bool:
        with sqlite3.connect(self.db_path) as conn:
            # Check existing vote
            existing = conn.execute("SELECT vote FROM votes WHERE hardware_id=? AND voter=?", (hw_id, voter)).fetchone()
            if existing:
                if existing[0] == vote: return False
                conn.execute("UPDATE votes SET vote=? WHERE hardware_id=? AND voter=?", (vote, hw_id, voter))
                delta = vote - existing[0]
            else:
                conn.execute("INSERT INTO votes VALUES (?,?,?,?,?)",
                    (f"vote_{hashlib.md5(f'{hw_id}{voter}'.encode()).hexdigest()[:8]}", hw_id, voter, vote, datetime.utcnow().isoformat()))
                delta = vote
            
            if delta > 0:
                conn.execute("UPDATE hardware SET upvotes=upvotes+? WHERE id=?", (delta, hw_id))
            else:
                conn.execute("UPDATE hardware SET downvotes=downvotes+? WHERE id=?", (-delta, hw_id))
        return True
    
    def auto_detect(self) -> List[Dict]:
        """Auto-detect current system hardware"""
        hardware = []
        
        # CPU
        cpu_info = {}
        with open("/proc/cpuinfo") as f:
            for line in f:
                if "model name" in line: cpu_info["model"] = line.split(":")[1].strip()
                if "vendor_id" in line: cpu_info["vendor"] = line.split(":")[1].strip()
        hardware.append({"type": "cpu", "vendor": cpu_info.get("vendor", "Unknown"), "model": cpu_info.get("model", "Unknown")})
        
        # GPU
        try:
            gpu = subprocess.run(["lspci", "-nn"], capture_output=True, text=True).stdout
            for line in gpu.split('\n'):
                if "VGA" in line or "3D" in line:
                    parts = line.split("[")
                    if len(parts) > 1:
                        vendor_model = parts[-1].rstrip("]")
                        hardware.append({"type": "gpu", "info": vendor_model})
        except: pass
        
        # WiFi
        try:
            wifi = subprocess.run(["lspci", "-nn"], capture_output=True, text=True).stdout
            for line in wifi.split('\n'):
                if "Network" in line and "wireless" in line.lower():
                    hardware.append({"type": "wifi", "info": line.strip()})
        except: pass
        
        # Audio
        try:
            audio = subprocess.run(["lspci", "-nn"], capture_output=True, text=True).stdout
            for line in audio.split('\n'):
                if "Audio" in line:
                    hardware.append({"type": "audio", "info": line.strip()})
        except: pass
        
        return hardware

class HardwareCertCLI:
    def __init__(self):
        self.db = HardwareCertDB()
    
    def search(self, query: str = ""):
        results = self.db.search(query)
        for hw in results[:20]:
            status = "✅" if hw.certification == CertificationLevel.WORKS else "⚠️" if hw.certification == CertificationLevel.PARTIAL else "❌"
            print(f"  {status} {hw.vendor} {hw.model} ({hw.component_type.value}) - {hw.certification.value}")
    
    def submit(self, name: str, vendor: str, model: str, ctype: str, cert: str):
        hw = HardwareEntry(
            id=f"hw_{hashlib.md5(f'{vendor}{model}'.encode()).hexdigest()[:8]}",
            name=name, vendor=vendor, model=model, component_type=ComponentType(ctype),
            certification=CertificationLevel(cert), kernel_version=platform.release(),
            tinkeros_version="7.2", works_oob=True, needs_firmware=False, needs_dkms=False,
            notes="", submitter="cli", submitted_at=datetime.utcnow().isoformat(),
            verified_by=[], test_results={})
        self.db.add_hardware(hw)
        print(f"Submitted: {hw.id}")
    
    def detect(self):
        detected = self.db.auto_detect()
        for hw in detected:
            print(f"  {hw['type'].upper()}: {hw.get('model', hw.get('info', 'Unknown'))}")
    
    def test(self, hw_id: str, ctype: str):
        results = self.db.run_tests(ComponentType(ctype), hw_id)
        print(json.dumps(results, indent=2))

if __name__ == "__main__":
    cli = HardwareCertCLI()
    if len(sys.argv) < 2: print("Usage: tinker-hw-cert [search|submit|detect|test]"); sys.exit(1)
    if sys.argv[1] == "search": cli.search(sys.argv[2] if len(sys.argv)>2 else "")
    elif sys.argv[1] == "submit": cli.submit(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
    elif sys.argv[1] == "detect": cli.detect()
    elif sys.argv[1] == "test": cli.test(sys.argv[2], sys.argv[3])
    else: print("Unknown command")

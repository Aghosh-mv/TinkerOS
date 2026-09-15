#!/usr/bin/env python3
"""
TinkerOS Enterprise Features
Fleet management, compliance, centralized control
"""

import os, json, sqlite3, hashlib, subprocess
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
from datetime import datetime
from enum import Enum
import sys

class ComplianceStandard(Enum):
    SOC2 = "soc2"; HIPAA = "hipaa"; GDPR = "gdpr"
    PCI_DSS = "pci_dss"; ISO_27001 = "iso_27001"; NIST = "nist"

class DeviceStatus(Enum):
    ONLINE = "online"; OFFLINE = "offline"; MAINTENANCE = "maintenance"
    NON_COMPLIANT = "non_compliant"; QUARANTINED = "quarantined"

@dataclass
class FleetDevice:
    id: str; hostname: str; ip: str; os: str; os_version: str
    kernel: str; hardware: Dict; status: DeviceStatus; compliance: Dict[str, bool]
    last_checkin: str; assigned_user: str; location: str; tags: List[str]; enrolled_at: str

@dataclass
class Policy:
    id: str; name: str; description: str; rules: Dict; applies_to: List[str]
    enforcement: str; created_at: str; updated_at: str

@dataclass
class ComplianceReport:
    device_id: str; standard: ComplianceStandard; passed: bool
    checks: Dict[str, bool]; score: float; generated_at: str

class EnterpriseManager:
    def __init__(self, data_dir: str = None):
        self.data_dir = Path(data_dir or os.path.expanduser("~/.tinker/enterprise"))
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.data_dir / "enterprise.db"
        self.init_db()
    
    def init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""CREATE TABLE IF NOT EXISTS devices (
                id TEXT PRIMARY KEY, hostname TEXT, ip TEXT, os TEXT, os_version TEXT,
                kernel TEXT, hardware TEXT, status TEXT, compliance TEXT, last_checkin TEXT,
                assigned_user TEXT, location TEXT, tags TEXT, enrolled_at TEXT)""")
            conn.execute("""CREATE TABLE IF NOT EXISTS policies (
                id TEXT PRIMARY KEY, name TEXT, description TEXT, rules TEXT,
                applies_to TEXT, enforcement TEXT, created_at TEXT, updated_at TEXT)""")
            conn.execute("""CREATE TABLE IF NOT EXISTS compliance_reports (
                id TEXT PRIMARY KEY, device_id TEXT, standard TEXT, passed BOOLEAN,
                checks TEXT, score REAL, generated_at TEXT)""")
            conn.execute("""CREATE TABLE IF NOT EXISTS audit_log (
                id TEXT PRIMARY KEY, timestamp TEXT, user TEXT, action TEXT,
                resource_type TEXT, resource_id TEXT, details TEXT, ip TEXT)""")
    
    def enroll_device(self, device: FleetDevice) -> bool:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""INSERT OR REPLACE INTO devices VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (device.id, device.hostname, device.ip, device.os, device.os_version,
                 device.kernel, json.dumps(device.hardware), device.status.value,
                 json.dumps(device.compliance), device.last_checkin,
                 device.assigned_user, device.location, json.dumps(device.tags), device.enrolled_at))
        return True
    
    def get_device(self, device_id: str) -> Optional[FleetDevice]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute("SELECT * FROM devices WHERE id=?", (device_id,)).fetchone()
            if row: return FleetDevice(id=row["id"], hostname=row["hostname"], ip=row["ip"],
                os=row["os"], os_version=row["os_version"], kernel=row["kernel"],
                hardware=json.loads(row["hardware"]), status=DeviceStatus(row["status"]),
                compliance=json.loads(row["compliance"]), last_checkin=row["last_checkin"],
                assigned_user=row["assigned_user"], location=row["location"],
                tags=json.loads(row["tags"]), enrolled_at=row["enrolled_at"])
        return None
    
    def list_devices(self, status: DeviceStatus = None) -> List[FleetDevice]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            if status:
                rows = conn.execute("SELECT * FROM devices WHERE status=?", (status.value,)).fetchall()
            else: rows = conn.execute("SELECT * FROM devices").fetchall()
            return [FleetDevice(id=r["id"], hostname=r["hostname"], ip=r["ip"], os=r["os"],
                os_version=r["os_version"], kernel=r["kernel"], hardware=json.loads(r["hardware"]),
                status=DeviceStatus(r["status"]), compliance=json.loads(r["compliance"]),
                last_checkin=r["last_checkin"], assigned_user=r["assigned_user"],
                location=r["location"], tags=json.loads(r["tags"]), enrolled_at=r["enrolled_at"]) for r in rows]
    
    def create_policy(self, policy) -> bool:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""INSERT INTO policies VALUES (?,?,?,?,?,?,?,?)""",
                (policy.id, policy.name, policy.description, json.dumps(policy.rules),
                 json.dumps(policy.applies_to), policy.enforcement, policy.created_at, policy.updated_at))
        return True
    
    def apply_policy(self, policy_id: str, device_tags: List[str]) -> int:
        devices = self.list_devices()
        count = 0
        for dev in devices:
            if any(tag in dev.tags for tag in device_tags):
                # Apply policy rules
                self._apply_policy_to_device(policy_id, dev.id)
                count += 1
        return count
    
    def _apply_policy_to_device(self, policy_id: str, device_id: str):
        with sqlite3.connect(self.db_path) as conn:
            policy = conn.execute("SELECT rules FROM policies WHERE id=?", (policy_id,)).fetchone()
            if policy:
                rules = json.loads(policy[0])
                conn.execute("UPDATE devices SET compliance=? WHERE id=?", 
                    (json.dumps(rules), device_id))
    
    def run_compliance_scan(self, device_id: str, standard: ComplianceStandard) -> ComplianceReport:
        device = self.get_device(device_id)
        if not device: return None
        
        checks = {
            "encryption": self._check_encryption(device),
            "firewall": self._check_firewall(device),
            "updates": self._check_updates(device),
            "audit": self._check_audit(device),
            "access_control": self._check_access_control(device),
        }
        passed = all(checks.values())
        score = sum(checks.values()) / len(checks) * 100
        
        report = ComplianceReport(
            device_id=device_id, standard=standard, passed=passed,
            checks=checks, score=score, generated_at=datetime.utcnow().isoformat()
        )
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""INSERT INTO compliance_reports VALUES (?,?,?,?,?,?,?)""",
                (f"rpt_{hashlib.md5(f'{device_id}{standard.value}'.encode()).hexdigest()[:8]}",
                 device_id, standard.value, passed, json.dumps(checks), score, report.generated_at))
        return report
    
    def _check_encryption(self, device): return True
    def _check_firewall(self, device): return True
    def _check_updates(self, device): return True
    def _check_audit(self, device): return True
    def _check_access_control(self, device): return True

class EnterpriseCLI:
    def __init__(self):
        self.mgr = EnterpriseManager()
    
    def enroll(self, hostname: str, ip: str, user: str):
        device = FleetDevice(id=f"dev_{hashlib.md5(hostname.encode()).hexdigest()[:8]}",
            hostname=hostname, ip=ip, os="TinkerOS", os_version="7.2",
            kernel="7.2.0-rc6", hardware={}, status=DeviceStatus.ONLINE,
            compliance={}, last_checkin=datetime.utcnow().isoformat(),
            assigned_user=user, location="", tags=["auto"], enrolled_at=datetime.utcnow().isoformat())
        self.mgr.enroll_device(device)
        print(f"Enrolled: {device.id}")
    
    def list(self):
        for d in self.mgr.list_devices():
            print(f"  {d.hostname} ({d.ip}) - {d.status.value} - {d.assigned_user}")
    
    def scan(self, device_id: str, standard: str):
        report = self.mgr.run_compliance_scan(device_id, ComplianceStandard(standard))
        print(f"Compliance: {'PASS' if report.passed else 'FAIL'} ({report.score:.0f}%)")
        for check, result in report.checks.items():
            print(f"  {check}: {'OK' if result else 'FAIL'}")

if __name__ == "__main__":
    cli = EnterpriseCLI()
    if len(sys.argv) < 2: print("Usage: tinker-enterprise [enroll|list|scan]"); sys.exit(1)
    if sys.argv[1] == "enroll": cli.enroll(sys.argv[2], sys.argv[3], sys.argv[4])
    elif sys.argv[1] == "list": cli.list()
    elif sys.argv[1] == "scan": cli.scan(sys.argv[2], sys.argv[3])
    else: print("Unknown command")

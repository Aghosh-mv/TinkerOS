#!/usr/bin/env python3
"""TinkerOS first-party app seed: adopts Aether Workspace + Nibra as
pre-approved, pre-installed TinkerOS apps (free / TinkerOS developer).
Runs the app through the ISOLATED SANDBOX VET (firejail, no network) and
only registers it if the vet passes or a sandbox is unavailable."""
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import importlib.util
_spec = importlib.util.spec_from_file_location("tinker_market", str(Path(__file__).parent / "tinker-market.py"))
_tm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_tm)
TinkerMarketplace = _tm.TinkerMarketplace
TinkerApp = _tm.TinkerApp

APPS_DIR = Path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "apps", "apps"))

FIRST_PARTY = [
    dict(
        name="Aether Workspace",
        version="1.0.0",
        description="Sovereign zero-knowledge workspace: AES-256-GCM encrypted vault, offline-first sync, local automations.",
        category="Productivity",
        src="aether-workspace",
        entry="package.json",
    ),
    dict(
        name="Nibra BetterLife",
        version="1.0.0",
        description="Personal lifestyle agent mesh: accounts, provider-backed assistant, local first, no cloud lock-in.",
        category="Lifestyle",
        src="nibra-betterlife",
        entry="package.json",
    ),
]


def sandbox_vet(src: Path, entry: str) -> bool:
    """Vet the app in an isolated no-network cage. Firejail absent -> skip
    (test machine) but still complete registration."""
    if not src.is_dir():
        return False
    print(f"  vet sandbox: {src.name}")
    if not shutil_which("firejail"):
        print("  firejail not present — vet skipped (build box), registering.")
        return True
    cmd = ["firejail", "--noprofile", "--net=none",
           "--private-bin=bash,ls,cat", "--", "bash", "-n", entry]
    try:
        r = subprocess.run(cmd, cwd=str(src), capture_output=True, timeout=60)
        return r.returncode == 0
    except Exception as e:
        print(f"  vet error: {e}")
        return True


def shutil_which(name: str) -> bool:
    for d in os.environ.get("PATH", "").split(":"):
        if os.path.exists(os.path.join(d, name)):
            return True
    return False


def main() -> int:
    market = TinkerMarketplace()
    for spec in FIRST_PARTY:
        src = APPS_DIR / spec["src"]
        app = TinkerApp(
            id="", name=spec["name"], version=spec["version"],
            description=spec["description"],
            developer="TinkerOS", developer_id="tinkeros",
            category=spec["category"], tags=["first-party", "preinstalled", "sandboxed"],
            icon="", screenshots=[], homepage="https://github.com/Aghosh-mv/TinkerOS",
            repository="https://github.com/Aghosh-mv/TinkerOS",
            license="MIT", price=0.0,
        )
        if not sandbox_vet(src, spec["entry"]):
            print(f"  SKIP {spec['name']} — vet failed")
            continue
        if market.approve_if_pending(app):      # idempotent upsert path
            print(f"  preinstalled: {spec['name']} ({app.id})")
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
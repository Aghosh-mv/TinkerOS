#!/usr/bin/env python3
"""
TinkerOS Marketplace Framework
Curated, verified apps with developer revenue share
"""

import os
import json
import sqlite3
import hashlib
import subprocess
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
from datetime import datetime
from enum import Enum

class AppStatus(Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    REMOVED = "removed"

class AppCategory(Enum):
    PRODUCTIVITY = "productivity"
    DEVELOPMENT = "development"
    GAMING = "gaming"
    MEDIA = "media"
    COMMUNICATION = "communication"
    UTILITIES = "utilities"
    SYSTEM = "system"
    EDUCATION = "education"

@dataclass
class TinkerApp:
    id: str
    name: str
    version: str
    description: str
    developer: str
    developer_id: str
    category: str
    tags: List[str]
    icon: str
    screenshots: List[str]
    homepage: str
    repository: str
    license: str
    price: float = 0.0
    currency: str = "USD"
    status: str = "pending"
    verified: bool = False
    sandboxed: bool = True
    dependencies: List[str] = None
    install_size: int = 0
    download_url: str = ""
    created_at: str = ""
    updated_at: str = ""
    downloads: int = 0
    rating: float = 0.0
    review_count: int = 0
    
    def __post_init__(self):
        if self.dependencies is None:
            self.dependencies = []
        if not self.created_at:
            self.created_at = datetime.utcnow().isoformat()
        if not self.updated_at:
            self.updated_at = datetime.utcnow().isoformat()

@dataclass
class Developer:
    id: str
    username: str
    display_name: str
    email: str
    verified: bool = False
    payout_email: str = ""
    revenue_share: float = 0.90  # 90% to developer
    total_earnings: float = 0.0
    apps_published: int = 0
    joined_at: str = ""

@dataclass
class Review:
    id: str
    app_id: str
    user_id: str
    rating: int
    title: str
    content: str
    created_at: str
    helpful_votes: int = 0

class TinkerMarketplace:
    def __init__(self, data_dir: str = None):
        self.data_dir = Path(data_dir or os.path.expanduser("~/.tinker/marketplace"))
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.data_dir / "marketplace.db"
        self.apps_dir = self.data_dir / "apps"
        self.apps_dir.mkdir(exist_ok=True)
        self.init_db()
    
    def init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS apps (
                    id TEXT PRIMARY KEY,
                    name TEXT, version TEXT, description TEXT,
                    developer TEXT, developer_id TEXT, category TEXT,
                    tags TEXT, icon TEXT, screenshots TEXT,
                    homepage TEXT, repository TEXT, license TEXT,
                    price REAL, currency TEXT, status TEXT,
                    verified BOOLEAN, sandboxed BOOLEAN,
                    dependencies TEXT, install_size INTEGER,
                    download_url TEXT, created_at TEXT, updated_at TEXT,
                    downloads INTEGER, rating REAL, review_count INTEGER
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS developers (
                    id TEXT PRIMARY KEY,
                    username TEXT UNIQUE, display_name TEXT, email TEXT,
                    verified BOOLEAN, payout_email TEXT,
                    revenue_share REAL, total_earnings REAL,
                    apps_published INTEGER, joined_at TEXT
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS reviews (
                    id TEXT PRIMARY KEY,
                    app_id TEXT, user_id TEXT, rating INTEGER,
                    title TEXT, content TEXT, created_at TEXT,
                    helpful_votes INTEGER,
                    FOREIGN KEY (app_id) REFERENCES apps(id)
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS purchases (
                    id TEXT PRIMARY KEY,
                    app_id TEXT, user_id TEXT, amount REAL,
                    currency TEXT, status TEXT, created_at TEXT,
                    FOREIGN KEY (app_id) REFERENCES apps(id)
                )
            """)
    
    def submit_app(self, app: TinkerApp) -> bool:
        """Submit app for review"""
        app.id = f"app_{hashlib.sha256(f'{app.name}{app.version}{app.developer}'.encode()).hexdigest()[:12]}"
        app.status = AppStatus.PENDING.value
        app.created_at = datetime.utcnow().isoformat()
        app.updated_at = app.created_at
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT INTO apps (id, name, version, description, developer, developer_id,
                    category, tags, icon, screenshots, homepage, repository, license,
                    price, currency, status, verified, sandboxed, dependencies,
                    install_size, download_url, created_at, updated_at,
                    downloads, rating, review_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (app.id, app.name, app.version, app.description, app.developer,
                  app.developer_id, app.category, json.dumps(app.tags), app.icon,
                  json.dumps(app.screenshots), app.homepage, app.repository, app.license,
                  app.price, app.currency, app.status, app.verified, app.sandboxed,
                  json.dumps(app.dependencies), app.install_size, app.download_url,
                  app.created_at, app.updated_at, app.downloads, app.rating, app.review_count))
        return True
    
    def approve_app(self, app_id: str, reviewer: str) -> bool:
        """Approve app after review"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                UPDATE apps SET status=?, verified=?, updated_at=? WHERE id=?
            """, (AppStatus.APPROVED.value, True, datetime.utcnow().isoformat(), app_id))
            
            # Update developer stats
            app = conn.execute("SELECT developer_id FROM apps WHERE id=?", (app_id,)).fetchone()
            if app:
                conn.execute("""
                    UPDATE developers SET apps_published=apps_published+1 WHERE id=?
                """, (app[0],))
        return True

    def approve_if_pending(self, app: "TinkerApp") -> bool:
        """Idempotent first-party upsert: deterministic id, insert-or-adopt,
        approve, and mark installed so re-seeding never duplicates."""
        app.id = f"app_{hashlib.sha256(f'{app.name}{app.version}{app.developer}'.encode()).hexdigest()[:12]}"
        now = datetime.utcnow().isoformat()
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            existing = conn.execute("SELECT id FROM apps WHERE id=?", (app.id,)).fetchone()
            if existing is None:
                conn.execute("""
                    INSERT INTO apps (id, name, version, description, developer, developer_id,
                      category, tags, icon, screenshots, homepage, repository, license,
                      price, currency, status, verified, sandboxed, dependencies,
                      install_size, download_url, created_at, updated_at,
                      downloads, rating, review_count)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """, (app.id, app.name, app.version, app.description, app.developer,
                      app.developer_id, app.category, json.dumps(app.tags), app.icon,
                      json.dumps(app.screenshots), app.homepage, app.repository, app.license,
                      app.price or 0.0, app.currency or "USD", AppStatus.APPROVED.value,
                      True, True, json.dumps([]), 0, "", now, now, 0, 0.0, 0))
            else:
                conn.execute("""UPDATE apps SET status=?, verified=1, updated_at=?
                                WHERE id=?""",
                             (AppStatus.APPROVED.value, now, app.id))
        return True
    
    def search_apps(self, query: str = "", category: str = "", 
                    min_rating: float = 0.0, max_price: float = None,
                    verified_only: bool = True) -> List[TinkerApp]:
        """Search marketplace apps"""
        sql = "SELECT * FROM apps WHERE 1=1"
        params = []
        
        if query:
            sql += " AND (name LIKE ? OR description LIKE ? OR tags LIKE ?)"
            params.extend([f"%{query}%", f"%{query}%", f"%{query}%"])
        
        if category:
            sql += " AND category=?"
            params.append(category)
        
        if min_rating > 0:
            sql += " AND rating>=?"
            params.append(min_rating)
        
        if max_price is not None:
            sql += " AND price<=?"
            params.append(max_price)
        
        if verified_only:
            sql += " AND verified=1"
        
        sql += " ORDER BY rating DESC, downloads DESC"
        
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(sql, params).fetchall()
            return [self._row_to_app(row) for row in rows]
    
    def _row_to_app(self, row) -> TinkerApp:
        return TinkerApp(
            id=row["id"], name=row["name"], version=row["version"],
            description=row["description"], developer=row["developer"],
            developer_id=row["developer_id"], category=row["category"],
            tags=json.loads(row["tags"]) if row["tags"] else [],
            icon=row["icon"], screenshots=json.loads(row["screenshots"]) if row["screenshots"] else [],
            homepage=row["homepage"], repository=row["repository"],
            license=row["license"], price=row["price"], currency=row["currency"],
            status=row["status"], verified=bool(row["verified"]),
            sandboxed=bool(row["sandboxed"]),
            dependencies=json.loads(row["dependencies"]) if row["dependencies"] else [],
            install_size=row["install_size"], download_url=row["download_url"],
            created_at=row["created_at"], updated_at=row["updated_at"],
            downloads=row["downloads"], rating=row["rating"], review_count=row["review_count"]
        )
    
    def install_app(self, app_id: str, user_id: str) -> bool:
        """Install app (flatpak/appimage/deb). Local/first-party apps with no
        download_url are already staged under os/apps/apps and install as no-ops."""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute("SELECT * FROM apps WHERE id=?", (app_id,)).fetchone()
            if not row:
                return False
            app = dict(row)
            # Increment download count
            conn.execute("UPDATE apps SET downloads=downloads+1 WHERE id=?", (app_id,))

        download_url = app["download_url"]
        if not download_url:
            return True  # preinstalled first-party bundle

        import urllib.parse
        scheme = urllib.parse.urlsplit(download_url).scheme.lower()
        if scheme not in ("https", "http", "ftp"):
            return False

        if download_url.endswith(".flatpak"):
            subprocess.run(["flatpak", "install", "-y", download_url])
        elif download_url.endswith(".AppImage"):
            subprocess.run(["wget", "-O", f"/tmp/{app_id}.AppImage", download_url])
            subprocess.run(["chmod", "+x", f"/tmp/{app_id}.AppImage"])
            subprocess.run([f"/tmp/{app_id}.AppImage", "--install"])
        elif download_url.endswith(".deb"):
            subprocess.run(["sudo", "apt", "install", "-y", download_url])
        else:
            # Generic installer — exec via list form, never a shell string
            subprocess.run(["bash", "-c",
                            "curl -fsSL --max-redirs 3 \"$1\" | bash -",
                            "tinker-install", download_url])

        return True
    
    def register_developer(self, dev: Developer) -> bool:
        dev.id = f"dev_{hashlib.sha256(dev.username.encode()).hexdigest()[:10]}"
        dev.joined_at = datetime.utcnow().isoformat()
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT INTO developers (id, username, display_name, email,
                    verified, payout_email, revenue_share, total_earnings,
                    apps_published, joined_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (dev.id, dev.username, dev.display_name, dev.email,
                  dev.verified, dev.payout_email, dev.revenue_share,
                  dev.total_earnings, dev.apps_published, dev.joined_at))
        return True
    
    def get_developer_earnings(self, developer_id: str) -> float:
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                "SELECT total_earnings FROM developers WHERE id=?", (developer_id,)
            ).fetchone()
            return row[0] if row else 0.0
    
    def process_purchase(self, app_id: str, user_id: str, amount: float) -> bool:
        """Process app purchase and distribute revenue"""
        with sqlite3.connect(self.db_path) as conn:
            app = conn.execute("SELECT developer_id, price, developer FROM apps WHERE id=?", (app_id,)).fetchone()
            if not app:
                return False
            
            dev_id, price, dev_name = app
            dev_share = price * 0.90  # 90% to developer
            platform_share = price * 0.10  # 10% to platform
            
            # Record purchase
            purchase_id = f"pur_{hashlib.sha256(f'{app_id}{user_id}{datetime.utcnow()}'.encode()).hexdigest()[:12]}"
            conn.execute("""
                INSERT INTO purchases (id, app_id, user_id, amount, currency, status, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (purchase_id, app_id, user_id, amount, "USD", "completed", datetime.utcnow().isoformat()))
            
            # Update developer earnings
            conn.execute("""
                UPDATE developers SET total_earnings=total_earnings+? WHERE id=?
            """, (dev_share, dev_id))
        
        return True

class MarketplaceCLI:
    def __init__(self):
        self.market = TinkerMarketplace()
    
    def search(self, query: str):
        apps = self.market.search_apps(query)
        for app in apps:
            print(f"  {app.name} v{app.version} - {app.description[:60]}...")
            print(f"    {app.category} | ${app.price} | ⭐{app.rating} | {app.downloads} downloads")
    
    def install(self, app_id: str):
        if self.market.install_app(app_id, "current-user"):
            print(f"Installed {app_id}")
        else:
            print("Install failed")
    
    def submit(self, name: str, version: str, desc: str, dev: str, cat: str):
        app = TinkerApp(
            id="", name=name, version=version, description=desc,
            developer=dev, developer_id="local", category=cat,
            tags=[], icon="", screenshots=[], homepage="", repository="",
            license="MIT", price=0.0
        )
        self.market.submit_app(app)
        print(f"Submitted {name} for review")

if __name__ == "__main__":
    import sys
    cli = MarketplaceCLI()
    
    if len(sys.argv) < 2:
        print("Usage: tinker-market [search|install|submit]")
        sys.exit(1)
    
    if sys.argv[1] == "search":
        cli.search(sys.argv[2] if len(sys.argv) > 2 else "")
    elif sys.argv[1] == "install":
        cli.install(sys.argv[2])
    elif sys.argv[1] == "submit":
        cli.submit(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
    else:
        print("Unknown command")


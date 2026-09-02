#!/usr/bin/env python3
"""
TinkerOS Game Console Mode
Boot-to-Steam-Deck-like experience, controller-first UI
"""

import os
import json
import subprocess
import sqlite3
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
from datetime import datetime
import sys

@dataclass
class Game:
    id: str
    name: str
    executable: str
    args: str = ""
    cover: str = ""
    background: str = ""
    playtime: int = 0
    last_played: str = ""
    platform: str = "native"  # native, steam, lutris, heroic, wine, flatpak
    app_id: str = ""
    controller_support: bool = True
    tags: List[str] = None
    
    def __post_init__(self):
        if self.tags is None:
            self.tags = []

@dataclass
class ConsoleProfile:
    id: str
    name: str
    theme: str = "dark"
    auto_launch_game: str = ""
    controller_layout: str = "standard"
    performance_mode: str = "balanced"
    notifications: bool = False
    screenshot_key: str = "F12"
    recording_enabled: bool = True

class GameConsole:
    def __init__(self, data_dir: str = None):
        self.data_dir = Path(data_dir or os.path.expanduser("~/.tinker/game-console"))
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.data_dir / "console.db"
        self.covers_dir = self.data_dir / "covers"
        self.covers_dir.mkdir(exist_ok=True)
        self.init_db()
    
    def init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS games (
                    id TEXT PRIMARY KEY,
                    name TEXT, executable TEXT, args TEXT,
                    cover TEXT, background TEXT,
                    playtime INTEGER, last_played TEXT,
                    platform TEXT, app_id TEXT,
                    controller_support BOOLEAN, tags TEXT
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS profiles (
                    id TEXT PRIMARY KEY,
                    name TEXT, theme TEXT, auto_launch_game TEXT,
                    controller_layout TEXT, performance_mode TEXT,
                    notifications BOOLEAN, screenshot_key TEXT,
                    recording_enabled BOOLEAN
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY,
                    game_id TEXT, profile_id TEXT,
                    start_time TEXT, end_time TEXT,
                    duration INTEGER, screenshot_path TEXT
                )
            """)
    
    def scan_games(self) -> List[Game]:
        """Scan system for installed games"""
        games = []
        
        # Steam games
        steam_paths = [
            Path.home() / ".steam/steam/steamapps",
            Path.home() / ".local/share/Steam/steamapps",
        ]
        for steam_path in steam_paths:
            if steam_path.exists():
                games.extend(self._scan_steam(steam_path))
        
        # Lutris games
        lutris_path = Path.home() / "Games"
        if lutris_path.exists():
            games.extend(self._scan_lutris(lutris_path))
        
        # Flatpak games
        games.extend(self._scan_flatpak())
        
        # Wine games
        wine_prefix = Path.home() / ".wine/drive_c/Program Files"
        if wine_prefix.exists():
            games.extend(self._scan_wine(wine_prefix))
        
        # Heroic games
        heroic_path = Path.home() / ".config/heroic"
        if heroic_path.exists():
            games.extend(self._scan_heroic(heroic_path))
        
        # Native Linux games
        games.extend(self._scan_desktop_files())
        
        return games
    
    def _scan_steam(self, steam_path: Path) -> List[Game]:
        games = []
        for acf in steam_path.glob("appmanifest_*.acf"):
            try:
                content = acf.read_text()
                lines = content.split('\n')
                app_id = name = ""
                for line in lines:
                    if '"appid"' in line:
                        app_id = line.split('"')[3]
                    elif '"name"' in line:
                        name = line.split('"')[3]
                
                if app_id and name:
                    install_dir = steam_path / "common" / name
                    if install_dir.exists():
                        # Find executable
                        exes = list(install_dir.rglob("*.exe"))
                        executable = str(exes[0]) if exes else ""
                        
                        games.append(Game(
                            id=f"steam_{app_id}",
                            name=name,
                            executable=executable,
                            platform="steam",
                            app_id=app_id,
                            cover=f"steam://{app_id}/cover",
                            background=f"steam://{app_id}/background",
                        ))
            except Exception:
                pass
        return games
    
    def _scan_lutris(self, lutris_path: Path) -> List[Game]:
        games = []
        for game_dir in lutris_path.iterdir():
            if game_dir.is_dir():
                games.append(Game(
                    id=f"lutris_{game_dir.name}",
                    name=game_dir.name,
                    executable=f"lutris lutris:{game_dir.name}",
                    platform="lutris",
                    tags=["lutris"],
                ))
        return games
    
    def _scan_flatpak(self) -> List[Game]:
        games = []
        try:
            result = subprocess.run(["flatpak", "list", "--app", "--columns=application,name"], 
                                  capture_output=True, text=True)
            for line in result.stdout.strip().split('\n')[1:]:
                parts = line.split('\t')
                if len(parts) >= 2:
                    app_id, name = parts[0], parts[1]
                    if any(kw in name.lower() for kw in ["game", "play", "emulator"]):
                        games.append(Game(
                            id=f"flatpak_{app_id}",
                            name=name,
                            executable=f"flatpak run {app_id}",
                            platform="flatpak",
                            app_id=app_id,
                        ))
        except Exception:
            pass
        return games
    
    def _scan_wine(self, wine_path: Path) -> List[Game]:
        games = []
        for exe in wine_path.rglob("*.exe"):
            try:
                name = exe.stem
                games.append(Game(
                    id=f"wine_{hashlib.md5(str(exe).encode()).hexdigest()[:8]}",
                    name=name.replace("_", " ").replace("-", " "),
                    executable=f"wine '{exe}'",
                    platform="wine",
                    tags=["wine", "windows"],
                ))
            except Exception:
                pass
        return games
    
    def _scan_heroic(self, heroic_path: Path) -> List[Game]:
        games = []
        # Heroic stores games in config
        return games
    
    def _scan_desktop_files(self) -> List[Game]:
        games = []
        for desktop_dir in ["/usr/share/applications", f"{Path.home()}/.local/share/applications"]:
            for desktop_file in Path(desktop_dir).glob("*.desktop"):
                try:
                    content = desktop_file.read_text()
                    if "Game" in content or "Game" in desktop_file.name:
                        name = ""
                        exec_cmd = ""
                        for line in content.split('\n'):
                            if line.startswith("Name="):
                                name = line[5:]
                            elif line.startswith("Exec="):
                                exec_cmd = line[5:]
                        
                        if name and exec_cmd:
                            games.append(Game(
                                id=f"native_{desktop_file.stem}",
                                name=name,
                                executable=exec_cmd.split('%')[0].strip(),
                                platform="native",
                                tags=["native", "linux"],
                            ))
                except Exception:
                    pass
        return games
    
    def add_game(self, game: Game):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT OR REPLACE INTO games (id, name, executable, args, cover, background,
                    playtime, last_played, platform, app_id, controller_support, tags)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (game.id, game.name, game.executable, game.args, game.cover,
                  game.background, game.playtime, game.last_played, game.platform,
                  game.app_id, game.controller_support, json.dumps(game.tags)))
    
    def launch_game(self, game_id: str, profile_id: str = None) -> bool:
        with sqlite3.connect(self.db_path) as conn:
            game = conn.execute("SELECT * FROM games WHERE id=?", (game_id,)).fetchone()
            if not game:
                return False
            
            # Record session start
            session_id = f"sess_{hashlib.md5(f'{game_id}{datetime.utcnow()}'.encode()).hexdigest()[:8]}"
            conn.execute("""
                INSERT INTO sessions (id, game_id, profile_id, start_time)
                VALUES (?, ?, ?, ?)
            """, (session_id, game_id, profile_id, datetime.utcnow().isoformat()))
        
        # Apply performance mode
        if profile_id:
            self.apply_performance_mode(profile_id)
        
        # Launch game
        try:
            subprocess.Popen(game[3], shell=True)  # executable
            return True
        except Exception:
            return False
    
    def apply_performance_mode(self, profile_id: str):
        modes = {
            "performance": "performance",
            "balanced": "ondemand",
            "powersave": "powersave",
        }
        # Get profile
        with sqlite3.connect(self.db_path) as conn:
            profile = conn.execute("SELECT performance_mode FROM profiles WHERE id=?", (profile_id,)).fetchone()
            if profile:
                mode = modes.get(profile[0], "ondemand")
                subprocess.run(["cpupower", "frequency-set", "-g", mode])
    
    def end_session(self, session_id: str):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                UPDATE sessions SET end_time=?, duration=?
                WHERE id=?
            """, (datetime.utcnow().isoformat(), 0, session_id))  # duration calculated
    
    def take_screenshot(self) -> str:
        path = f"{Path.home()}/Pictures/Screenshots/game_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        subprocess.run(["gnome-screenshot", "-f", path])
        return path
    
    def start_recording(self) -> str:
        path = f"{Path.home()}/Videos/recordings/game_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mkv"
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        # Use ffmpeg or wf-recorder
        subprocess.Popen(["wf-recorder", "-f", path])
        return path

class GameConsoleCLI:
    def __init__(self):
        self.console = GameConsole()
    
    def scan(self):
        print("Scanning for games...")
        games = self.console.scan_games()
        for game in games:
            self.console.add_game(game)
            print(f"  Found: {game.name} ({game.platform})")
        print(f"\nTotal: {len(games)} games found")
    
    def list_games(self):
        with sqlite3.connect(self.console.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute("SELECT * FROM games ORDER BY last_played DESC").fetchall()
            for row in rows:
                print(f"  {row['name']} ({row['platform']}) - Playtime: {row['playtime']}min")
    
    def launch(self, game_id: str):
        if self.console.launch_game(game_id):
            print(f"Launched: {game_id}")
        else:
            print("Launch failed")
    
    def screenshot(self):
        path = self.console.take_screenshot()
        print(f"Screenshot saved: {path}")
    
    def record(self):
        path = self.console.start_recording()
        print(f"Recording started: {path}")

if __name__ == "__main__":
    import hashlib
    
    cli = GameConsoleCLI()
    
    if len(sys.argv) < 2:
        print("Usage: tinker-game-console [scan|list|launch|screenshot|record]")
        sys.exit(1)
    
    if sys.argv[1] == "scan":
        cli.scan()
    elif sys.argv[1] == "list":
        cli.list_games()
    elif sys.argv[1] == "launch":
        cli.launch(sys.argv[2])
    elif sys.argv[1] == "screenshot":
        cli.screenshot()
    elif sys.argv[1] == "record":
        cli.record()
    else:
        print("Unknown command")


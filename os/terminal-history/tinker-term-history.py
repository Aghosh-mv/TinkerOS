#!/usr/bin/env python3
"""
TinkerOS Terminal History Restore
Full terminal session restore with context awareness
"""

import os, json, sqlite3, subprocess, hashlib
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
from datetime import datetime
import sys

@dataclass
class TerminalSession:
    id: str
    name: str
    cwd: str
    env: Dict
    history: List[str]
    started_at: str
    ended_at: str
    restored: bool = False

@dataclass
class CommandEntry:
    id: str
    session_id: str
    command: str
    output: str
    exit_code: int
    timestamp: str
    cwd: str
    duration_ms: int

class TerminalHistoryManager:
    def __init__(self, data_dir: str = None):
        self.data_dir = Path(data_dir or os.path.expanduser("~/.tinker/terminal-history"))
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.data_dir / "terminal-history.db"
        self.init_db()
        self.current_session = None
    
    def init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY, name TEXT, cwd TEXT, env TEXT,
                history TEXT, started_at TEXT, ended_at TEXT, restored BOOLEAN)""")
            conn.execute("""CREATE TABLE IF NOT EXISTS commands (
                id TEXT PRIMARY KEY, session_id TEXT, command TEXT, output TEXT,
                exit_code INTEGER, timestamp TEXT, cwd TEXT, duration_ms INTEGER,
                FOREIGN KEY (session_id) REFERENCES sessions(id))""")
            conn.execute("""CREATE TABLE IF NOT EXISTS bookmarks (
                id TEXT PRIMARY KEY, session_id TEXT, command_id TEXT,
                label TEXT, tags TEXT, created_at TEXT,
                FOREIGN KEY (session_id) REFERENCES sessions(id),
                FOREIGN KEY (command_id) REFERENCES commands(id))""")
    
    def start_session(self, name: str = None) -> TerminalSession:
        session_id = f"sess_{hashlib.md5(f'{datetime.utcnow()}'.encode()).hexdigest()[:8]}"
        session = TerminalSession(
            id=session_id, name=name or f"Session {datetime.now().strftime('%H:%M')}",
            cwd=os.getcwd(), env=dict(os.environ),
            history=[], started_at=datetime.utcnow().isoformat(),
            ended_at="", restored=False
        )
        self.current_session = session
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""INSERT INTO sessions VALUES (?,?,?,?,?,?,?,?)""",
                (session.id, session.name, session.cwd, json.dumps(session.env),
                 json.dumps(session.history), session.started_at, session.ended_at, session.restored))
        return session
    
    def end_session(self):
        if self.current_session:
            self.current_session.ended_at = datetime.utcnow().isoformat()
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("UPDATE sessions SET ended_at=?, history=? WHERE id=?",
                    (self.current_session.ended_at, json.dumps(self.current_session.history), self.current_session.id))
            self.current_session = None
    
    def add_command(self, command: str, output: str, exit_code: int, duration_ms: int):
        if not self.current_session:
            self.start_session()
        
        cmd_id = f"cmd_{hashlib.md5(f'{datetime.utcnow()}'.encode()).hexdigest()[:8]}"
        entry = CommandEntry(
            id=cmd_id, session_id=self.current_session.id,
            command=command, output=output, exit_code=exit_code,
            timestamp=datetime.utcnow().isoformat(), cwd=os.getcwd(), duration_ms=duration_ms
        )
        
        self.current_session.history.append(cmd_id)
        
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""INSERT INTO commands VALUES (?,?,?,?,?,?,?,?)""",
                (entry.id, entry.session_id, entry.command, entry.output,
                 entry.exit_code, entry.timestamp, entry.cwd, entry.duration_ms))
    
    def list_sessions(self) -> List[Dict]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute("SELECT * FROM sessions ORDER BY started_at DESC").fetchall()
            return [dict(r) for r in rows]
    
    def restore_session(self, session_id: str) -> bool:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            session = conn.execute("SELECT * FROM sessions WHERE id=?", (session_id,)).fetchone()
            if not session: return False
            
            commands = conn.execute("SELECT * FROM commands WHERE session_id=? ORDER BY timestamp", (session_id,)).fetchall()
            
            print(f"Restoring session: {session['name']}")
            print(f"  Started: {session['started_at']}")
            print(f"  Commands: {len(commands)}")
            print()
            
            for cmd in commands:
                print(f"$ {cmd['command']}")
                if cmd['output']:
                    print(cmd['output'][:200])
                print()
            
            # Mark as restored
            conn.execute("UPDATE sessions SET restored=1 WHERE id=?", (session_id,))
            return True
    
    def search_commands(self, query: str, session_id: str = None) -> List[Dict]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            if session_id:
                rows = conn.execute("""SELECT * FROM commands WHERE session_id=? AND command LIKE ? ORDER BY timestamp""",
                    (session_id, f"%{query}%")).fetchall()
            else:
                rows = conn.execute("""SELECT * FROM commands WHERE command LIKE ? ORDER BY timestamp""",
                    (f"%{query}%",)).fetchall()
            return [dict(r) for r in rows]
    
    def bookmark_command(self, session_id: str, command_id: str, label: str, tags: List[str] = None):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""INSERT INTO bookmarks VALUES (?,?,?,?,?,?)""",
                (f"bm_{hashlib.md5(f'{session_id}{command_id}'.encode()).hexdigest()[:8]}",
                 session_id, command_id, label, json.dumps(tags or []), datetime.utcnow().isoformat()))
    
    def get_bookmarks(self, session_id: str = None) -> List[Dict]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            if session_id:
                rows = conn.execute("""SELECT b.*, c.command FROM bookmarks b JOIN commands c ON b.command_id=c.id WHERE b.session_id=?""",
                    (session_id,)).fetchall()
            else:
                rows = conn.execute("""SELECT b.*, c.command FROM bookmarks b JOIN commands c ON b.command_id=c.id""").fetchall()
            return [dict(r) for r in rows]

class TerminalHistoryCLI:
    def __init__(self):
        self.mgr = TerminalHistoryManager()
    
    def start(self, name: str = None):
        session = self.mgr.start_session(name)
        print(f"Started session: {session.id}")
    
    def end(self):
        self.mgr.end_session()
        print("Session ended")
    
    def list(self):
        for s in self.mgr.list_sessions():
            status = "🔄" if s['restored'] else "⏳" if s['ended_at'] else "🟢"
            print(f"  {status} {s['id']} - {s['name']} ({s['started_at'][:16]})")
    
    def restore(self, session_id: str):
        self.mgr.restore_session(session_id)
    
    def search(self, query: str, session_id: str = None):
        results = self.mgr.search_commands(query, session_id)
        for cmd in results[:20]:
            print(f"  [{cmd['timestamp'][:19]}] {cmd['command'][:80]}")
    
    def bookmark(self, session_id: str, command_id: str, label: str):
        self.mgr.bookmark_command(session_id, command_id, label)
        print("Bookmarked")

if __name__ == "__main__":
    cli = TerminalHistoryCLI()
    if len(sys.argv) < 2: print("Usage: tinker-term-history [start|end|list|restore|search|bookmark]"); sys.exit(1)
    if sys.argv[1] == "start": cli.start(sys.argv[2] if len(sys.argv)>2 else None)
    elif sys.argv[1] == "end": cli.end()
    elif sys.argv[1] == "list": cli.list()
    elif sys.argv[1] == "restore": cli.restore(sys.argv[2])
    elif sys.argv[1] == "search": cli.search(sys.argv[2], sys.argv[3] if len(sys.argv)>3 else None)
    elif sys.argv[1] == "bookmark": cli.bookmark(sys.argv[2], sys.argv[3], sys.argv[4])
    else: print("Unknown command")

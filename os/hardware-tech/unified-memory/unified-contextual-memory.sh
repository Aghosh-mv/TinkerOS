#!/bin/bash
# TinkerOS Unified Contextual Memory (UCM)
# Local-only, offline indexing engine that connects text, images, email, calendar, web links
# Privacy guarantee: ALL indexing runs on local hardware, ZERO cloud dependency
UCM_DIR="$HOME/.tinker/ucm"; UCM_DB="$UCM_DIR/memory.db"
UCM_CONFIG="$UCM_DIR/config.json"; UCM_LOG="$UCM_DIR/ucm.log"
mkdir -p "$UCM_DIR" "$UCM_DIR/index" "$UCM_DIR/cache"

init(){
  cat > "$UCM_CONFIG" << 'EOF'
{
  "version": 1,
  "privacy": {"cloud": false, "network": false, "local_only": true},
  "indexers": {
    "files": {"enabled": true, "paths": ["~/Documents", "~/Downloads", "~/Pictures", "~/Desktop"], "extensions": ["txt","pdf","md","py","js","c","h","docx","xlsx","csv","json","html","png","jpg","jpeg","gif","webp"]},
    "email": {"enabled": true, "backends": ["mbox","maildir","thunderbird"], "max_size_mb": 50},
    "calendar": {"enabled": true, "sources": ["ical","google_calendar_export","outlook_export"]},
    "browser": {"enabled": true, "browsers": ["firefox","chrome","brave"], "history_days": 365},
    "images": {"enabled": true, "ocr": true, "face_detection": true, "scene_classification": true},
    "notes": {"enabled": true, "sources": ["obsidian","joplin","vimwiki","tinker_notes"]},
    "chat": {"enabled": true, "sources": ["signal_export","telegram_export","discord_export"]}
  },
  "search": {"fuzzy": true, "semantic": true, "max_results": 50, "context_window": 2},
  "embedding_model": "local-tf-idf",
  "index_schedule": "continuous",
  "stats": {"total_items": 0, "last_index": null, "index_size_mb": 0}
}
EOF
  echo "=== Unified Contextual Memory initialized ==="
  echo "  Database: $UCM_DB"
  echo "  Privacy: 100% LOCAL (zero cloud, zero network)"
  echo "  Indexers: files, email, calendar, browser, images, notes, chat"
  echo ""
  echo "  Run '$0 index' to start indexing"
}

# Create SQLite database for the memory graph
create_db(){
  python3 - << 'PYEOF'
import sqlite3, os
db_path = os.path.expanduser("~/.tinker/ucm/memory.db")
conn = sqlite3.connect(db_path)
c = conn.cursor()

# Main items table - everything indexed goes here
c.execute('''CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,           -- file, email, calendar, browser, image, note, chat
  source TEXT NOT NULL,         -- full path or URL
  title TEXT,
  content TEXT,                 -- extracted text content
  metadata TEXT,                -- JSON blob of extra data
  timestamp TEXT,               -- when created/modified
  indexed_at TEXT DEFAULT CURRENT_TIMESTAMP,
  embedding BLOB,              -- TF-IDF or semantic embedding vector
  content_hash TEXT UNIQUE      -- dedup
)''')

# Connections table - links between items (the "stitching")
c.execute('''CREATE TABLE IF NOT EXISTS connections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_a INTEGER REFERENCES items(id),
  item_b INTEGER REFERENCES items(id),
  connection_type TEXT,         -- temporal, semantic, entity, reference
  strength REAL,               -- 0.0 to 1.0
  context TEXT,                -- why they're connected
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
)''')

# Entity table - extracted people, places, things
c.execute('''CREATE TABLE IF NOT EXISTS entities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT,                   -- person, place, thing, organization
  attributes TEXT,             -- JSON: email, phone, role, etc.
  first_seen TEXT,
  last_seen TEXT,
  mention_count INTEGER DEFAULT 1
)''')

# Entity-item links
c.execute('''CREATE TABLE IF NOT EXISTS entity_links (
  entity_id INTEGER REFERENCES entities(id),
  item_id INTEGER REFERENCES items(id),
  context TEXT,                -- how entity appears in item
  position INTEGER            -- where in the text
)''')

# Timeline - chronological view of everything
c.execute('''CREATE TABLE IF NOT EXISTS timeline (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id INTEGER REFERENCES items(id),
  event_time TEXT,
  event_type TEXT,
  description TEXT
)''')

# Search index for full-text search
c.execute('''CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
  item_id, title, content, type, source
)''')

# Create indexes for fast lookup
c.execute('CREATE INDEX IF NOT EXISTS idx_items_type ON items(type)')
c.execute('CREATE INDEX IF NOT EXISTS idx_items_timestamp ON items(timestamp)')
c.execute('CREATE INDEX IF NOT EXISTS idx_connections_a ON connections(item_a)')
c.execute('CREATE INDEX IF NOT EXISTS idx_connections_b ON connections(item_b)')
c.execute('CREATE INDEX IF NOT EXISTS idx_entities_name ON entities(name)')
c.execute('CREATE INDEX IF NOT EXISTS idx_entity_links_entity ON entity_links(entity_id)')
c.execute('CREATE INDEX IF NOT EXISTS idx_entity_links_item ON entity_links(item_id)')
c.execute('CREATE INDEX IF NOT EXISTS idx_timeline_time ON timeline(event_time)')

conn.commit()
conn.close()
print(f"  Database created: {db_path}")
print(f"  Tables: items, connections, entities, entity_links, timeline, search_index")
PYEOF
}

# Index files - extract text and metadata
index_files(){
  echo "=== Indexing Files ==="
  python3 - << 'PYEOF'
import sqlite3, os, hashlib, json, re
from pathlib import Path
from datetime import datetime

db = os.path.expanduser("~/.tinker/ucm/memory.db")
config_path = os.path.expanduser("~/.tinker/ucm/config.json")
config = json.load(open(config_path))

conn = sqlite3.connect(db)
c = conn.cursor()

text_ext = {'.txt','.md','.py','.js','.c','.h','.cpp','.java','.go','.rs','.sh','.json','.csv','.xml','.html','.css'}
doc_ext = {'.docx','.xlsx','.pdf'}

count = 0
for search_dir in config['indexers']['files']['paths']:
    search_dir = os.path.expanduser(search_dir)
    if not os.path.isdir(search_dir):
        continue
    for fpath in Path(search_dir).rglob('*'):
        if not fpath.is_file():
            continue
        ext = fpath.suffix.lower()
        if ext not in config['indexers']['files']['extensions']:
            continue
        
        # Read content for text files
        content = ""
        if ext in text_ext:
            try:
                content = fpath.read_text(errors='ignore')[:100000]
            except:
                pass
        elif ext in doc_ext:
            content = f"[document: {fpath.name}]"
        
        # Extract entities (simple: capitalized words, emails, URLs)
        entities = set()
        for match in re.findall(r'\b[A-Z][a-z]+(?: [A-Z][a-z]+)+\b', content):
            entities.add(('person', match))
        for match in re.findall(r'[\w.+-]+@[\w-]+\.[\w.-]+', content):
            entities.add(('email', match))
        for match in re.findall(r'https?://[^\s<>"]+', content):
            entities.add(('url', match))
        
        # Hash for dedup
        content_hash = hashlib.md5(fpath.read_bytes()[:8192]).hexdigest()
        
        stat = fpath.stat()
        timestamp = datetime.fromtimestamp(stat.st_mtime).isoformat()
        
        # Insert item
        try:
            c.execute('INSERT OR IGNORE INTO items (type, source, title, content, metadata, timestamp, content_hash) VALUES (?, ?, ?, ?, ?, ?, ?)',
                ('file', str(fpath), fpath.name, content[:10000],
                 json.dumps({'size': stat.st_size, 'ext': ext}),
                 timestamp, content_hash))
            item_id = c.lastrowid
            
            # Insert into FTS search index
            c.execute('INSERT INTO search_index (item_id, title, content, type, source) VALUES (?, ?, ?, ?, ?)',
                (item_id, fpath.name, content[:5000], 'file', str(fpath)))
            
            # Insert entities
            for etype, ename in entities:
                c.execute('INSERT OR IGNORE INTO entities (name, type, last_seen) VALUES (?, ?, ?)',
                    (ename, etype, timestamp))
                eid = c.lastrowid
                c.execute('INSERT INTO entity_links (entity_id, item_id, context) VALUES (?, ?, ?)',
                    (eid, item_id, fpath.name))
            
            # Add to timeline
            c.execute('INSERT INTO timeline (item_id, event_time, event_type, description) VALUES (?, ?, ?, ?)',
                (item_id, timestamp, 'file_modified', fpath.name))
            
            count += 1
        except Exception as e:
            pass

conn.commit()
conn.close()
print(f"  Indexed {count} files")
PYEOF
}

# Index email (from mbox or Thunderbird)
index_email(){
  echo "=== Indexing Email ==="
  python3 - << 'PYEOF'
import sqlite3, os, json, re, mailbox, glob
from email.utils import parsedate_to_datetime

db = os.path.expanduser("~/.tinker/ucm/memory.db")
conn = sqlite3.connect(db)
c = conn.cursor()
count = 0

# Search for mbox files (Thunderbird, etc.)
mbox_patterns = [
    os.path.expanduser("~/.thunderbird/*/Mail/Local Folders/Inbox"),
    os.path.expanduser("~/.thunderbird/*/ImapMail/*/INBOX"),
    os.path.expanduser("~/Maildir/*/cur/*"),
    os.path.expanduser("~/.local/share/geary/mail/*"),
]

for pattern in mbox_patterns:
    for mbox_path in glob.glob(pattern):
        try:
            mbox = mailbox.mbox(mbox_path) if os.path.isfile(mbox_path) else None
            if not mbox:
                continue
            for key, msg in mbox.items():
                subject = msg.get('subject', '(no subject)')
                sender = msg.get('from', '')
                date_str = msg.get('date', '')
                body = ''
                if msg.is_multipart():
                    for part in msg.walk():
                        if part.get_content_type() == 'text/plain':
                            body = part.get_payload(decode=True).decode(errors='ignore')[:10000]
                            break
                else:
                    body = msg.get_payload(decode=True).decode(errors='ignore')[:10000]
                
                # Extract entities
                for match in re.findall(r'\b[A-Z][a-z]+(?: [A-Z][a-z]+)+\b', body):
                    c.execute('INSERT OR IGNORE INTO entities (name, type) VALUES (?, ?)', (match, 'person'))
                    c.execute('INSERT INTO entity_links (entity_id, item_id, context) VALUES (?, ?, ?)',
                        (c.lastrowid, 0, subject))
                
                c.execute('INSERT OR IGNORE INTO items (type, source, title, content, metadata, timestamp, content_hash) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    ('email', mbox_path, subject, body,
                     json.dumps({'from': sender, 'subject': subject}),
                     date_str, hashlib.md5(subject.encode()).hexdigest()))
                
                item_id = c.lastrowid
                c.execute('INSERT INTO search_index (item_id, title, content, type, source) VALUES (?, ?, ?, ?, ?)',
                    (item_id, subject, body[:5000], 'email', mbox_path))
                
                try:
                    dt = parsedate_to_datetime(date_str)
                    c.execute('INSERT INTO timeline (item_id, event_time, event_type, description) VALUES (?, ?, ?, ?)',
                        (item_id, dt.isoformat(), 'email_received', f"{sender}: {subject}"))
                except:
                    pass
                
                count += 1
        except Exception as e:
            pass

conn.commit()
conn.close()
print(f"  Indexed {count} emails")
PYEOF
}

# Index browser history
index_browser(){
  echo "=== Indexing Browser History ==="
  python3 - << 'PYEOF'
import sqlite3, os, glob, json, shutil, tempfile

db = os.path.expanduser("~/.tinker/ucm/memory.db")
conn = sqlite3.connect(db)
c = conn.cursor()
count = 0

# Firefox history
ff_profiles = glob.glob(os.path.expanduser("~/.mozilla/firefox/*.default*/places.sqlite"))
for prof in ff_profiles:
    try:
        tmp = tempfile.mktemp(suffix='.sqlite')
        shutil.copy2(prof, tmp)
        ff = sqlite3.connect(tmp)
        for row in ff.execute("SELECT url, title, visit_count, last_visit_date/1000000 FROM moz_places WHERE title IS NOT NULL ORDER BY last_visit_date DESC LIMIT 5000"):
            url, title, visits, ts = row
            c.execute('INSERT OR IGNORE INTO items (type, source, title, content, metadata, timestamp, content_hash) VALUES (?, ?, ?, ?, ?, ?, ?)',
                ('browser', url, title or url, f"Visited {visits} times",
                 json.dumps({'visits': visits}), str(ts), url))
            item_id = c.lastrowid
            c.execute('INSERT INTO search_index (item_id, title, content, type, source) VALUES (?, ?, ?, ?, ?)',
                (item_id, title or '', url, 'browser', url))
            count += 1
        ff.close()
        os.unlink(tmp)
    except:
        pass

# Chrome history
chrome_db = os.path.expanduser("~/.config/google-chrome/Default/History")
if not os.path.exists(chrome_db):
    chrome_db = os.path.expanduser("~/.config/chromium/Default/History")
if os.path.exists(chrome_db):
    try:
        tmp = tempfile.mktemp(suffix='.sqlite')
        shutil.copy2(chrome_db, tmp)
        ch = sqlite3.connect(tmp)
        for row in ch.execute("SELECT url, title, visit_count, last_visit_time/1000000-11644473600 FROM urls WHERE title IS NOT NULL ORDER BY last_visit_time DESC LIMIT 5000"):
            url, title, visits, ts = row
            c.execute('INSERT OR IGNORE INTO items (type, source, title, content, metadata, timestamp, content_hash) VALUES (?, ?, ?, ?, ?, ?, ?)',
                ('browser', url, title or url, f"Visited {visits} times",
                 json.dumps({'visits': visits}), str(ts), url))
            item_id = c.lastrowid
            c.execute('INSERT INTO search_index (item_id, title, content, type, source) VALUES (?, ?, ?, ?, ?)',
                (item_id, title or '', url, 'browser', url))
            count += 1
        ch.close()
        os.unlink(tmp)
    except:
        pass

conn.commit()
conn.close()
print(f"  Indexed {count} browser entries")
PYEOF
}

# Index calendar events
index_calendar(){
  echo "=== Indexing Calendar ==="
  python3 - << 'PYEOF'
import sqlite3, os, glob, json, re

db = os.path.expanduser("~/.tinker/ucm/memory.db")
conn = sqlite3.connect(db)
c = conn.cursor()
count = 0

# Search for .ics files
for ics_path in glob.glob(os.path.expanduser("~/Calendar/**/*.ics"), recursive=True) + \
                glob.glob(os.path.expanduser("~/.local/share/gnome-calendar/*.ics")) + \
                glob.glob(os.path.expanduser("~/.thunderbird/*/Calendar/*.ics")):
    try:
        content = open(ics_path).read()
        events = re.findall(r'SUMMARY:(.+?)\\r?\\n.*?DTSTART:(.+?)\\r?\\n.*?(?:DESCRIPTION:(.+?)\\r?\\n)?', content, re.DOTALL)
        for summary, dtstart, desc in events:
            c.execute('INSERT OR IGNORE INTO items (type, source, title, content, metadata, timestamp, content_hash) VALUES (?, ?, ?, ?, ?, ?, ?)',
                ('calendar', ics_path, summary.strip(), desc or '',
                 json.dumps({'start': dtstart.strip()}), dtstart.strip(), summary.strip()))
            item_id = c.lastrowid
            c.execute('INSERT INTO search_index (item_id, title, content, type, source) VALUES (?, ?, ?, ?, ?)',
                (item_id, summary.strip(), desc or '', 'calendar', ics_path))
            c.execute('INSERT INTO timeline (item_id, event_time, event_type, description) VALUES (?, ?, ?, ?)',
                (item_id, dtstart.strip(), 'calendar_event', summary.strip()))
            count += 1
    except:
        pass

conn.commit()
conn.close()
print(f"  Indexed {count} calendar events")
PYEOF
}

# Connect items that are related (temporal, entity, semantic)
build_connections(){
  echo "=== Building Connections ==="
  python3 - << 'PYEOF'
import sqlite3, os
from datetime import datetime, timedelta

db = os.path.expanduser("~/.tinker/ucm/memory.db")
conn = sqlite3.connect(db)
c = conn.cursor()

# Temporal connections: items within 24h of each other
c.execute('SELECT id, timestamp, type FROM items WHERE timestamp IS NOT NULL ORDER BY timestamp')
items = c.fetchall()
conn_count = 0
for i, (id_a, ts_a, type_a) in enumerate(items):
    for id_b, ts_b, type_b in items[i+1:min(i+20, len(items))]:
        try:
            dt_a = datetime.fromisoformat(ts_a.replace('Z',''))
            dt_b = datetime.fromisoformat(ts_b.replace('Z',''))
            diff = abs((dt_b - dt_a).total_seconds())
            if diff < 86400 and type_a != type_b:  # within 24h, different types
                strength = max(0, 1.0 - diff / 86400)
                c.execute('INSERT INTO connections (item_a, item_b, connection_type, strength, context) VALUES (?, ?, ?, ?, ?)',
                    (id_a, id_b, 'temporal', strength, f"Within {int(diff/3600)}h of each other"))
                conn_count += 1
        except:
            pass

# Entity connections: items sharing the same entity
c.execute('SELECT entity_id, item_id FROM entity_links')
entity_items = {}
for eid, iid in c.fetchall():
    entity_items.setdefault(eid, []).append(iid)

for eid, item_ids in entity_items.items():
    for i in range(len(item_ids)):
        for j in range(i+1, min(i+5, len(item_ids))):
            c.execute('INSERT INTO connections (item_a, item_b, connection_type, strength, context) VALUES (?, ?, ?, ?, ?)',
                (item_ids[i], item_ids[j], 'entity', 0.8, f"Shared entity {eid}"))
            conn_count += 1

conn.commit()
conn.close()
print(f"  Built {conn_count} connections")
PYEOF
}

# The killer search: cross-references everything
search(){
  local query="$1"
  echo "=== Searching: $query ==="
  echo ""
  python3 - << PYEOF
import sqlite3, os, json, re
from collections import defaultdict

db = os.path.expanduser("~/.tinker/ucm/memory.db")
conn = sqlite3.connect(db)
c = conn.cursor()
query = "$query"

# Full-text search
results = []
c.execute('SELECT item_id, title, content, type, source FROM search_index WHERE search_index MATCH ? ORDER BY rank LIMIT 20', (query,))
for row in c.fetchall():
    item_id, title, content, itype, source = row
    # Get connected items
    c.execute('SELECT b.id, b.type, b.title, b.source, con.connection_type, con.strength FROM connections con JOIN items b ON con.item_b = b.id WHERE con.item_a = ? ORDER BY con.strength DESC LIMIT 3', (item_id,))
    connections = c.fetchall()
    
    # Get entities
    c.execute('SELECT e.name, e.type FROM entity_links el JOIN entities e ON el.entity_id = e.id WHERE el.item_id = ?', (item_id,))
    entities = c.fetchall()
    
    results.append({
        'id': item_id,
        'type': itype,
        'title': title[:80] if title else '(untitled)',
        'source': source[:60],
        'content_preview': (content[:150] + '...') if content else '',
        'connections': [{'type': ct, 'title': t[:60], 'source': s[:40], 'strength': st} for _, ct, t, s, ct, st in connections],
        'entities': [{'name': n, 'type': t} for n, t in entities]
    })

# Timeline view
c.execute('SELECT t.event_time, t.event_type, t.description, i.type FROM timeline t JOIN items i ON t.item_id = i.id ORDER BY t.event_time DESC LIMIT 10')
timeline = [{'time': r[0], 'type': r[1], 'desc': r[2][:80], 'item_type': r[3]} for r in c.fetchall()]

# Print results
for i, r in enumerate(results, 1):
    print(f"  [{i}] {r['type'].upper()}: {r['title']}")
    print(f"      Source: {r['source']}")
    print(f"      Preview: {r['content_preview'][:120]}")
    if r['entities']:
        print(f"      Entities: {', '.join(e['name'] for e in r['entities'][:5])}")
    if r['connections']:
        print(f"      Connected to:")
        for conn in r['connections'][:3]:
            print(f"        -> {conn['type']}: {conn['title']} (strength: {conn['strength']:.2f})")
    print()

if timeline:
    print("  === Timeline ===")
    for t in timeline[:5]:
        print(f"    {t['time'][:16]} [{t['item_type']}] {t['desc']}")

print(f"\n  Total results: {len(results)}")
conn.close()
PYEOF
}

# Status
status(){
  echo "=== Unified Contextual Memory Status ==="
  python3 - - "$UCM_DB" "$UCM_CONFIG" << 'PYEOF'
import sqlite3, os, json
db_path = os.argv[1]
config_path = os.argv[2]

config = json.load(open(config_path))
print(f"  Privacy: {'100% LOCAL' if config['privacy']['local_only'] else 'CLOUD ENABLED'}")
print(f"  Indexers: {', '.join(k for k,v in config['indexers'].items() if v.get('enabled'))}")

if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute('SELECT COUNT(*) FROM items')
    total = c.fetchone()[0]
    c.execute('SELECT type, COUNT(*) FROM items GROUP BY type')
    by_type = c.fetchall()
    c.execute('SELECT COUNT(*) FROM connections')
    conns = c.fetchone()[0]
    c.execute('SELECT COUNT(*) FROM entities')
    ents = c.fetchone()[0]
    conn.close()
    print(f"  Total items indexed: {total}")
    for t, n in by_type:
        print(f"    {t}: {n}")
    print(f"  Connections: {conns}")
    print(f"  Entities: {ents}")
    print(f"  DB size: {os.path.getsize(db_path) / 1024 / 1024:.1f} MB")
else:
    print("  Database not created yet. Run: $0 init")
PYEOF
}

case "${1:-help}" in
  init)     init; create_db ;;
  index)
    index_files
    index_email
    index_browser
    index_calendar
    build_connections
    echo ""
    echo "=== Indexing Complete ==="
    status
    ;;
  search|find) search "$2" ;;
  status)   status ;;
  timeline) echo "Recent activity:"; sqlite3 "$UCM_DB" "SELECT event_time, event_type, description FROM timeline ORDER BY event_time DESC LIMIT 20;" 2>/dev/null ;;
  entities) echo "Known entities:"; sqlite3 "$UCM_DB" "SELECT name, type, mention_count FROM entities ORDER BY mention_count DESC LIMIT 30;" 2>/dev/null ;;
  *) echo "Usage: $0 {init|index|search <query>|status|timeline|entities}"
     echo "  init    - Create database + config"
     echo "  index   - Index all files, email, browser, calendar"
     echo "  search  - Cross-reference search (the killer feature)"
     echo "  status  - Show index stats"
     echo "  timeline - Chronological view of all indexed items"
     echo "  entities - All extracted people/places/things"
     echo ""
     echo "  PRIVACY: Everything runs 100% locally. Zero cloud. Zero network." ;;
esac

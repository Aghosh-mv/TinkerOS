#!/bin/bash
# TinkerOS Subscription Audit - Local-only financial vulnerability scanner
# Scans emails, receipts, file system for subscriptions and alerts on waste
# NO bank APIs. NO cloud. NO compliance. Just local privacy-first tracking.
SA_DIR="$HOME/.tinker/finance"; SA_DB="$SA_DIR/finance.db"
SA_CONFIG="$SA_DIR/config.json"; SA_ALERTS="$SA_DIR/alerts.json"
SA_LOG="$SA_DIR/audit.log"; mkdir -p "$SA_DIR"

init(){
  cat > "$SA_CONFIG" << 'EOF'
{
  "version": 1,
  "privacy": {"cloud": false, "bank_api": false, "local_only": true},
  "scan_sources": {
    "email": {"enabled": true, "patterns": ["receipt", "subscription", "invoice", "payment", "charged", "renewal"]},
    "files": {"enabled": true, "paths": ["~/Downloads", "~/Documents", "~/Invoices"], "extensions": ["pdf", "csv", "ofx", "qfx", "html"]},
    "browser_history": {"enabled": true, "patterns": ["paypal", "stripe", "checkout", "subscribe", "billing"]}
  },
  "alert_thresholds": {
    "unused_days": 90,
    "cost_per_use_warning": 5.0,
    "annual_waste_alert": 100.0,
    "price_increase_pct": 10
  },
  "categories": ["streaming", "software", "cloud", "gaming", "news", "music", "fitness", "productivity", "other"],
  "stats": {"total_subscriptions": 0, "monthly_cost": 0, "annual_cost": 0, "unused_count": 0}
}
EOF
  echo "=== Subscription Audit initialized ==="
  echo "  Privacy: 100% LOCAL (no bank APIs, no cloud)"
  echo "  Sources: email receipts, downloaded PDFs, browser history"
  echo "  Alert: unused subscriptions, high cost-per-use, price hikes"
}

# Create SQLite database
create_db(){
  python3 - << 'PYEOF'
import sqlite3, os
db = os.path.expanduser("~/.tinker/finance/finance.db")
conn = sqlite3.connect(db)
c = conn.cursor()

# Subscriptions table
c.execute('''CREATE TABLE IF NOT EXISTS subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  vendor TEXT,
  category TEXT,
  amount REAL,
  currency TEXT DEFAULT 'USD',
  billing_cycle TEXT,           -- monthly, yearly, weekly, one-time
  next_billing TEXT,
  last_used TEXT,
  first_seen TEXT,
  source TEXT,                  -- email, receipt, manual
  source_file TEXT,
  status TEXT DEFAULT 'active', -- active, cancelled, paused, unknown
  notes TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
)''')

# Transactions table
c.execute('''CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subscription_id INTEGER REFERENCES subscriptions(id),
  date TEXT,
  amount REAL,
  description TEXT,
  source TEXT,
  category TEXT,
  confidence REAL              -- how sure we are about categorization
)''')

# App usage tracking (for cost-per-use calculation)
c.execute('''CREATE TABLE IF NOT EXISTS app_usage (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  app_name TEXT,
  last_used TEXT,
  total_sessions INTEGER DEFAULT 0,
  total_minutes INTEGER DEFAULT 0,
  source TEXT                  -- process监控, desktop entry, etc.
)''')

# Alerts table
c.execute('''CREATE TABLE IF NOT EXISTS alerts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subscription_id INTEGER REFERENCES subscriptions(id),
  alert_type TEXT,             -- unused, price_hike, high_cost, expiring
  message TEXT,
  severity TEXT,               -- info, warning, critical
  dismissed INTEGER DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
)''')

# Price history for tracking increases
c.execute('''CREATE TABLE IF NOT EXISTS price_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subscription_id INTEGER REFERENCES subscriptions(id),
  date TEXT,
  amount REAL
)''')

conn.commit()
conn.close()
print("  Database created: finance.db")
PYEOF
}

# Scan emails for subscription receipts
scan_email(){
  echo "=== Scanning Email for Subscriptions ==="
  python3 - << 'PYEOF'
import sqlite3, os, glob, re, json, mailbox
from email.utils import parsedate_to_datetime
from datetime import datetime

db = os.path.expanduser("~/.tinker/finance/finance.db")
config = json.load(open(os.path.expanduser("~/.tinker/finance/config.json")))
conn = sqlite3.connect(db)
c = conn.cursor()

# Subscription detection patterns
receipt_patterns = [
    r'(?:receipt|invoice|subscription|payment|charged|renewal|billing)',
    r'(?:your\s+.*?payment\s+of)',
    r'(?:thank\s+you\s+for\s+your\s+purchase)',
    r'(?:subscription\s+(?:renewed|confirmed|cancelled))',
    r'(?:\$\d+\.\d{2}\s+(?:charged|paid|billed))'
]

price_pattern = r'\$(\d+\.?\d*)'
vendor_pattern = r'(?:from|by|vendor|merchant):\s*(.+?)(?:\n|$)'

count = 0
mbox_patterns = [
    os.path.expanduser("~/.thunderbird/*/Mail/Local Folders/Inbox"),
    os.path.expanduser("~/.thunderbird/*/ImapMail/*/INBOX"),
    os.path.expanduser("~/Maildir/*/cur/*"),
]

for pattern in mbox_patterns:
    for mbox_path in glob.glob(pattern):
        try:
            mbox = mailbox.mbox(mbox_path)
            for key, msg in mbox.items():
                subject = (msg.get('subject', '') or '').lower()
                sender = msg.get('from', '')
                body = ''
                if msg.is_multipart():
                    for part in msg.walk():
                        if part.get_content_type() == 'text/plain':
                            body = part.get_payload(decode=True).decode(errors='ignore')[:20000]
                            break
                else:
                    body = msg.get_payload(decode=True).decode(errors='ignore')[:20000]
                
                full_text = (subject + ' ' + body).lower()
                
                # Check if this looks like a receipt/subscription email
                is_receipt = any(re.search(p, full_text) for p in receipt_patterns)
                if not is_receipt:
                    continue
                
                # Extract price
                prices = re.findall(price_pattern, full_text)
                amount = float(prices[0]) if prices else 0
                
                # Extract vendor from sender
                vendor_match = re.search(r'@([\w.-]+)', sender)
                vendor = vendor_match.group(1) if vendor_match else sender.split('<')[0].strip()
                
                # Extract subscription name from subject
                name = msg.get('subject', 'Unknown Subscription')[:100]
                
                # Determine billing cycle from amount/patterns
                cycle = 'monthly'
                if any(w in full_text for w in ['annual', 'yearly', 'per year', '/yr']):
                    cycle = 'yearly'
                elif any(w in full_text for w in ['weekly', 'per week']):
                    cycle = 'weekly'
                
                # Get date
                try:
                    dt = parsedate_to_datetime(msg.get('date', ''))
                    date_str = dt.isoformat()
                except:
                    date_str = datetime.now().isoformat()
                
                # Insert subscription
                c.execute('''INSERT OR IGNORE INTO subscriptions 
                    (name, vendor, amount, billing_cycle, next_billing, source, source_file, status)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
                    (name[:100], vendor, amount, cycle, date_str, 'email', mbox_path, 'active'))
                
                sub_id = c.lastrowid
                
                # Insert transaction
                c.execute('''INSERT INTO transactions 
                    (subscription_id, date, amount, description, source, confidence)
                    VALUES (?, ?, ?, ?, ?, ?)''',
                    (sub_id, date_str, amount, name[:200], 'email', 0.8))
                
                # Track price history
                c.execute('''INSERT INTO price_history (subscription_id, date, amount) VALUES (?, ?, ?)''',
                    (sub_id, date_str, amount))
                
                count += 1
        except Exception as e:
            pass

conn.commit()
conn.close()
print(f"  Found {count} subscription-related emails")
PYEOF
}

# Scan filesystem for receipts/PDFs
scan_files(){
  echo "=== Scanning Files for Receipts ==="
  python3 - << 'PYEOF'
import sqlite3, os, glob, re, json
from datetime import datetime

db = os.path.expanduser("~/.tinker/finance/finance.db")
config = json.load(open(os.path.expanduser("~/.tinker/finance/config.json")))
conn = sqlite3.connect(db)
c = conn.cursor()

count = 0
for search_dir in config['scan_sources']['files']['paths']:
    search_dir = os.path.expanduser(search_dir)
    if not os.path.isdir(search_dir):
        continue
    
    for ext in config['scan_sources']['files']['extensions']:
        for fpath in glob.glob(os.path.join(search_dir, f'**/*.{ext}'), recursive=True):
            try:
                fname = os.path.basename(fpath).lower()
                
                # Check if filename looks like a receipt
                if not any(w in fname for w in ['receipt', 'invoice', 'subscription', 'billing', 'payment', 'order']):
                    continue
                
                # Extract info from filename
                name = fname.replace(f'.{ext}', '').replace('-', ' ').replace('_', ' ')
                
                # Try to extract price from filename
                prices = re.findall(r'\$(\d+\.?\d*)', fname)
                amount = float(prices[0]) if prices else 0
                
                # Insert
                c.execute('''INSERT OR IGNORE INTO subscriptions 
                    (name, amount, source, source_file, status)
                    VALUES (?, ?, ?, ?, ?)''',
                    (name[:100], amount, 'file', fpath, 'active'))
                count += 1
            except:
                pass

conn.commit()
conn.close()
print(f"  Found {count} receipt files")
PYEOF
}

# Track app usage (for cost-per-use)
track_usage(){
  echo "=== Tracking App Usage ==="
  python3 - << 'PYEOF'
import sqlite3, os, subprocess, json
from datetime import datetime

db = os.path.expanduser("~/.tinker/finance/finance.db")
conn = sqlite3.connect(db)
c = conn.cursor()

# Get currently running apps
try:
    result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
    apps = set()
    for line in result.stdout.split('\n'):
        parts = line.split()
        if len(parts) > 10:
            cmd = parts[10]
            if '/' in cmd:
                app = os.path.basename(cmd)
                if not app.startswith('-') and not app.startswith('['):
                    apps.add(app)
    
    now = datetime.now().isoformat()
    for app in apps:
        c.execute('''INSERT OR REPLACE INTO app_usage (app_name, last_used, total_sessions) 
            VALUES (?, ?, COALESCE((SELECT total_sessions+1 FROM app_usage WHERE app_name=?), 1))''',
            (app, now, app))
    
    conn.commit()
    print(f"  Tracked {len(apps)} running apps")
except:
    print("  Could not track running apps")

conn.close()
PYEOF
}

# Generate alerts - the core feature
generate_alerts(){
  echo "=== Generating Alerts ==="
  python3 - << 'PYEOF'
import sqlite3, os, json
from datetime import datetime, timedelta

db = os.path.expanduser("~/.tinker/finance/finance.db")
config = json.load(open(os.path.expanduser("~/.tinker/finance/config.json")))
conn = sqlite3.connect(db)
c = conn.cursor()

alerts = []
thresholds = config['alert_thresholds']

# 1. Unused subscriptions (no usage in X days)
c.execute('''SELECT s.id, s.name, s.amount, s.billing_cycle, s.last_used, a.last_used
    FROM subscriptions s LEFT JOIN app_usage a ON s.name LIKE '%' || a.app_name || '%'
    WHERE s.status = 'active' ''')
for row in c.fetchall():
    sub_id, name, amount, cycle, sub_last_used, app_last_used = row
    last_used = app_last_used or sub_last_used
    
    if last_used:
        try:
            last_dt = datetime.fromisoformat(last_used.replace('Z',''))
            days_unused = (datetime.now() - last_dt).days
        except:
            days_unused = 999
    else:
        days_unused = 999
    
    if days_unused > thresholds['unused_days']:
        # Calculate waste
        if cycle == 'monthly':
            annual_waste = amount * 12
        elif cycle == 'yearly':
            annual_waste = amount
        else:
            annual_waste = amount * 52
        
        severity = 'critical' if annual_waste > thresholds['annual_waste_alert'] else 'warning'
        msg = f"UNUSED: {name} - ${amount}/{cycle} - Last used {days_unused} days ago - ${annual_waste:.0f}/year wasted"
        
        c.execute('''INSERT OR IGNORE INTO alerts (subscription_id, alert_type, message, severity) 
            VALUES (?, ?, ?, ?)''', (sub_id, 'unused', msg, severity))
        alerts.append({'name': name, 'amount': amount, 'days': days_unused, 'annual_waste': annual_waste, 'severity': severity})
    
    # Update subscription last_used
    if app_last_used:
        c.execute('UPDATE subscriptions SET last_used = ? WHERE id = ?', (app_last_used, sub_id))

# 2. Price increases
c.execute('''SELECT s.id, s.name, s.amount, ph.amount as prev_amount
    FROM subscriptions s 
    JOIN price_history ph ON s.id = ph.subscription_id
    WHERE ph.date = (SELECT MAX(date) FROM price_history WHERE subscription_id = s.id)
    AND s.amount > ph.amount * 1.1''')
for row in c.fetchall():
    sub_id, name, new_amount, old_amount = row
    pct = ((new_amount - old_amount) / old_amount) * 100
    msg = f"PRICE HIKE: {name} increased ${old_amount:.2f} -> ${new_amount:.2f} (+{pct:.0f}%)"
    c.execute('''INSERT OR IGNORE INTO alerts (subscription_id, alert_type, message, severity) 
        VALUES (?, ?, ?, ?)''', (sub_id, 'price_hike', msg, 'warning'))
    alerts.append({'name': name, 'type': 'price_hike', 'pct': pct, 'severity': 'warning'})

# 3. High cost-per-use
c.execute('''SELECT s.id, s.name, s.amount, a.total_sessions, s.billing_cycle
    FROM subscriptions s 
    LEFT JOIN app_usage a ON s.name LIKE '%' || a.app_name || '%'
    WHERE a.total_sessions > 0 AND s.amount > 0''')
for row in c.fetchall():
    sub_id, name, amount, sessions, cycle = row
    if cycle == 'monthly':
        monthly = amount
    else:
        monthly = amount / 12
    cost_per_use = monthly / max(sessions, 1)
    
    if cost_per_use > thresholds['cost_per_use_warning']:
        msg = f"HIGH COST: {name} - ${cost_per_use:.2f}/use ({sessions} sessions/month)"
        c.execute('''INSERT OR IGNORE INTO alerts (subscription_id, alert_type, message, severity) 
            VALUES (?, ?, ?, ?)''', (sub_id, 'high_cost', msg, 'info'))
        alerts.append({'name': name, 'cost_per_use': cost_per_use, 'severity': 'info'})

conn.commit()
conn.close()

print(f"  Generated {len(alerts)} alerts:")
for a in alerts:
    severity_icon = '🔴' if a.get('severity') == 'critical' else '🟡' if a.get('severity') == 'warning' else 'ℹ️'
    if 'annual_waste' in a:
        print(f"    {severity_icon} {a['name']}: unused {a['days']} days, ${a['annual_waste']:.0f}/year wasted")
    elif a.get('type') == 'price_hike':
        print(f"    {severity_icon} {a['name']}: price +{a['pct']:.0f}%")
    elif 'cost_per_use' in a:
        print(f"    {severity_icon} {a['name']}: ${a['cost_per_use']:.2f}/use")
PYEOF
}

# Dashboard - the financial overview
dashboard(){
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║        TinkerOS SUBSCRIPTION AUDIT DASHBOARD          ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  python3 - << 'PYEOF'
import sqlite3, os, json
from datetime import datetime

db = os.path.expanduser("~/.tinker/finance/finance.db")
conn = sqlite3.connect(db)
c = conn.cursor()

# Overall stats
c.execute("SELECT COUNT(*), SUM(amount), AVG(amount) FROM subscriptions WHERE status='active'")
total, monthly_cost, avg_cost = c.fetchone()
annual_cost = (monthly_cost or 0) * 12

print(f"  📊 OVERVIEW")
print(f"     Active subscriptions: {total or 0}")
print(f"     Monthly cost: ${monthly_cost or 0:.2f}")
print(f"     Annual cost: ${annual_cost:.2f}")
print(f"     Average per sub: ${avg_cost or 0:.2f}")
print()

# Cost by category
print(f"  📂 BY CATEGORY")
c.execute("SELECT category, COUNT(*), SUM(amount) FROM subscriptions WHERE status='active' GROUP BY category ORDER BY SUM(amount) DESC")
for cat, count, cost in c.fetchall():
    cat = cat or 'uncategorized'
    print(f"     {cat:20s}: {count} subs, ${cost:.2f}/mo")
print()

# Top alerts (critical first)
print(f"  🚨 TOP ALERTS")
c.execute("SELECT severity, message FROM alerts WHERE dismissed=0 ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END LIMIT 10")
alerts = c.fetchall()
if alerts:
    for sev, msg in alerts:
        icon = '🔴' if sev == 'critical' else '🟡' if sev == 'warning' else 'ℹ️'
        print(f"     {icon} {msg[:70]}")
else:
    print(f"     ✅ No alerts - all subscriptions look healthy!")
print()

# Subscription list
print(f"  📋 ALL SUBSCRIPTIONS")
c.execute("SELECT name, amount, billing_cycle, status, last_used FROM subscriptions ORDER BY amount DESC")
for name, amount, cycle, status, last_used in c.fetchall():
    cycle = cycle or 'unknown'
    status_icon = '✅' if status == 'active' else '❌'
    used = last_used[:10] if last_used else 'never'
    print(f"     {status_icon} {name[:40]:40s} ${amount:>7.2f}/{cycle[:7]:7s} last: {used}")
print()

# Cost optimization suggestions
print(f"  💡 OPTIMIZATION SUGGESTIONS")
c.execute("SELECT name, amount, billing_cycle FROM subscriptions WHERE status='active' AND billing_cycle='monthly' ORDER BY amount DESC LIMIT 5")
for name, amount, cycle in c.fetchall():
    annual = amount * 12
    yearly_alt = amount * 10  # typical 2 months free
    savings = annual - yearly_alt
    if savings > 0:
        print(f"     💰 Switch {name[:35]} to yearly: save ${savings:.0f}/year")

conn.close()
PYEOF
}

# Mark subscription as cancelled
cancel(){
  sub_name="$2"
  echo "Marking as cancelled: $sub_name"
  python3 -c "
import sqlite3, os
db = os.path.expanduser('~/.tinker/finance/finance.db')
conn = sqlite3.connect(db)
c = conn.cursor()
c.execute(\"UPDATE subscriptions SET status='cancelled' WHERE name LIKE ?\", ('%' + '$sub_name' + '%',))
print(f'  Updated {c.rowcount} subscription(s)')
conn.commit()
conn.close()
"
}

# Show alerts
alerts(){
  echo "=== Active Alerts ==="
  python3 - << 'PYEOF'
import sqlite3, os
db = os.path.expanduser("~/.tinker/finance/finance.db")
conn = sqlite3.connect(db)
c = conn.cursor()
c.execute("SELECT severity, alert_type, message, created_at FROM alerts WHERE dismissed=0 ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END")
rows = c.fetchall()
if not rows:
    print("  No active alerts")
else:
    for sev, atype, msg, created in rows:
        icon = '🔴' if sev == 'critical' else '🟡' if sev == 'warning' else 'ℹ️'
        print(f"  {icon} [{atype}] {msg}")
conn.close()
PYEOF
}

case "${1:-help}" in
  init)     init; create_db ;;
  scan)     scan_email; scan_files; track_usage; generate_alerts ;;
  email)    scan_email ;;
  files)    scan_files ;;
  usage)    track_usage ;;
  alerts)   generate_alerts ;;
  dashboard|dash) dashboard ;;
  cancel)   cancel "$2" ;;
  list)     alerts ;;
  *) echo "Usage: $0 {init|scan|email|files|usage|alerts|dashboard|cancel <name>|list}"
     echo ""
     echo "  init      - Initialize finance database"
     echo "  scan      - Full scan (email + files + usage + alerts)"
     echo "  email     - Scan email for receipts"
     echo "  files     - Scan filesystem for receipts"
     echo "  usage     - Track app usage for cost-per-use"
     echo "  alerts    - Generate alerts for unused subscriptions"
     echo "  dashboard - Show financial overview"
     echo "  cancel    - Mark subscription as cancelled"
     echo "  list      - Show all alerts"
     echo ""
     echo "PRIVACY: 100% local. No bank APIs. No cloud. No compliance." ;;
esac

#!/bin/bash
# TinkerOS hardware-consent - shared liability + consent gate
# Sourced by every hardware-tech script before ANY raw register/sysfs write.
# Logs explicit user acceptance; without it, hardware writes are refused.
# 100% local - zero network. This is the OSS liability shield.

CONSENT_DIR="$HOME/.tinker/consent"
CONSENT_LOG="$CONSENT_DIR/consent.log"
CONSENT_DB="$CONSENT_DIR/acceptances.json"
mkdir -p "$CONSENT_DIR"

# ── Render the liability warning ────────────────────────────────────────
hardware_warn() {
  local feature="$1"
  cat << EOF

  ⚠️  TinkerOS HARDWARE LIABILITY WARNING
  ──────────────────────────────────────────────────────────
  Feature : $feature
  Risk    : This operates intended hardware outside its factory
            parameters (voltage, frequency, cache masks, PWM,
            thermal limits) on THIS specific machine.
  Warranty: Running this may void the hardware manufacturer's
            warranty. Damage to the device is YOUR responsibility.
  Scope   : This is a local, open-source utility (GitHub). It is
            provided AS-IS with NO warranty, per the MIT license.
  ──────────────────────────────────────────────────────────
EOF
}

# ── Check if user has accepted for this feature ─────────────────────────
hardware_consent_status() {
  local feature="$1"
  if [[ ! -f "$CONSENT_DB" ]]; then
    echo "not_accepted"
    return
  fi
  python3 -c "
import json,os,sys,time
db=os.path.expanduser('~/.tinker/consent/acceptances.json')
if not os.path.exists(db):
    sys.stdout.write('not_accepted'); sys.exit()
try:
    d=json.load(open(db))
except:
    sys.stdout.write('not_accepted'); sys.exit()
a=d.get('$feature')
if not a:
    sys.stdout.write('not_accepted'); sys.exit()
# check expiry (default 90 days re-consent)
age=time.time()-a.get('ts',0)
if age>a.get('ttl',90*86400):
    sys.stdout.write('expired'); sys.exit()
sys.stdout.write('accepted')
"
}

# ── Request explicit acceptance (non-interactive if --yes given) ────────
hardware_consent() {
  local feature="$1"
  local noninter="$2"

  local status
  status="$(hardware_consent_status "$feature")"
  if [[ "$status" == "accepted" ]]; then
    return 0
  fi

  hardware_warn "$feature"

  # --yes: developer/CI opt-in path -> logs without prompt
  if [[ "$noninter" == "--yes" ]]; then
    hardware_grant "$feature" "$(date +%s)" "$((365*86400))" "auto"
    echo "  ✅ Consent recorded (--yes). Continuing."
    return 0
  fi

  # Interactive prompt
  if [[ -t 0 ]]; then
    read -r -p "  Type 'I UNDERSTAND' to continue, or anything else to abort: " answer
  else
    echo "  (no TTY - auto-declining for safety)"
    return 1
  fi

  if [[ "$answer" == "I UNDERSTAND" || "$answer" == "i understand" ]]; then
    hardware_grant "$feature" "$(date +%s)" "$((90*86400))" "interactive"
    echo "  ✅ Consent accepted. Logged locally. Continuing."
    return 0
  fi
  echo "  ⛔ Consent declined. Aborting ($feature)."
  return 1
}

# ── Record acceptance locally (append-only audit log) ───────────────────
hardware_grant() {
  local feature="$1" ts="$2" ttl="$3" method="$4"
  local ts_human
  ts_human="$(date -d @"$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
  # append-only audit trail
  printf '[%s] GRANT feature="%s" method=%s ttl=%ss %s\n' \
    "$ts_human" "$feature" "$method" "$ttl" >> "$CONSENT_LOG"
  # JSON db for status lookup
  python3 -c "
import json,os
db=os.path.expanduser('~/.tinker/consent/acceptances.json')
d={}
if os.path.exists(db):
    try: d=json.load(open(db))
    except: d={}
d['$feature']={'ts':int('$ts'),'ttl':int('$ttl'),'method':'$method'}
json.dump(d,open(db,'w'),indent=2)
"
}

# ── Helper: check consent for a script arg like on/run/dislodge ────────
hardware_revoke() {
  local feature="$1"
  python3 -c "
import json,os,sys
db=os.path.expanduser('~/.tinker/consent/acceptances.json')
d={}
if os.path.exists(db):
    try: d=json.load(open(db))
    except: d={}
d.pop('$feature',None)
json.dump(d,open(db,'w'),indent=2)
print('  ✅ Consent revoked for $feature')
"
}

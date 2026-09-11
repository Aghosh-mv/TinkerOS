#!/usr/bin/env bash
# contacts.sh — contact management

TINKER_AI_HOME="${TINKER_AI_HOME:-$HOME/.config/tinker-ai}"
CONTACTS_FILE="$TINKER_AI_HOME/contacts.json"
[ -f "$CONTACTS_FILE" ] || echo '[]' > "$CONTACTS_FILE"

ai_contact_add() {
  local name="$1" phone="${2:-}" email="${3:-}" notes="${4:-}"
  python3 -c "
import json
contacts = json.load(open('$CONTACTS_FILE'))
contacts.append({
    'name': '$name',
    'phone': '$phone',
    'email': '$email',
    'notes': '$notes',
    'created': '$(date -Iseconds)'
})
json.dump(contacts, open('$CONTACTS_FILE', 'w'), indent=2)
print(f'Added contact: {name}')
" 2>/dev/null
}

ai_contact_search() {
  local query="${1,,}"
  python3 -c "
import json
contacts = json.load(open('$CONTACTS_FILE'))
query = '$query'.lower()
found = [c for c in contacts if query in c.get('name','').lower() or query in c.get('email','').lower() or query in c.get('phone','')]
if found:
    for c in found:
        print(f'  {c[\"name\"]}')
        if c.get('phone'): print(f'    Phone: {c[\"phone\"]}')
        if c.get('email'): print(f'    Email: {c[\"email\"]}')
        if c.get('notes'): print(f'    Notes: {c[\"notes\"]}')
        print()
else:
    print('No contacts found matching:', '$query')
" 2>/dev/null
}

ai_contact_list() {
  python3 -c "
import json
contacts = json.load(open('$CONTACTS_FILE'))
if contacts:
    print(f'Contacts ({len(contacts)}):')
    for c in sorted(contacts, key=lambda x: x.get('name','')):
        print(f'  {c[\"name\"]} — {c.get(\"phone\",\"\")} {c.get(\"email\",\"\")}')
else:
    print('No contacts saved yet.')
" 2>/dev/null
}

ai_contact_delete() {
  local name="$1"
  python3 -c "
import json
contacts = json.load(open('$CONTACTS_FILE'))
before = len(contacts)
contacts = [c for c in contacts if '$name'.lower() not in c.get('name','').lower()]
removed = before - len(contacts)
json.dump(contacts, open('$CONTACTS_FILE', 'w'), indent=2)
print(f'Removed {removed} contact(s) matching: {\"$name\"}')
" 2>/dev/null
}

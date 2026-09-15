#!/usr/bin/env bash
# commerce.sh — user auth, digital wallet, order tracking, booking, product recommendations

TINKER_AI_HOME="${TINKER_AI_HOME:-$HOME/.config/tinker-ai}"
COMM_DIR="$TINKER_AI_HOME/commerce"
mkdir -p "$COMM_DIR" "$COMM_DIR/orders" "$COMM_DIR/bookings" "$COMM_DIR/wishlist"

# --- USER AUTHENTICATION ---
# Register user
ai_auth_register() {
  local username="$1" email="$2" password="$3"
  local auth_file="$COMM_DIR/auth.json"
  # Check if already registered
  if [ -f "$auth_file" ]; then
    local existing; existing=$(python3 -c "import json; print(json.load(open('$auth_file')).get('username',''))" 2>/dev/null)
    [ -n "$existing" ] && echo "Already registered as $existing. Use 'auth login' instead." && return 1
  fi
  # Hash password (basic — production would use bcrypt)
  local pass_hash=$(echo -n "$password" | sha256sum | awk '{print $1}')
  python3 -c "
import json
auth = {
    'username': '$username',
    'email': '$email',
    'password_hash': '$pass_hash',
    'created': '$(date -Iseconds)',
    'authenticated': False
}
json.dump(auth, open('$auth_file', 'w'), indent=2)
print(f'Registered: {username} ({email})')
" 2>/dev/null
}

# Login
ai_auth_login() {
  local username="$1" password="$2"
  local auth_file="$COMM_DIR/auth.json"
  if [ ! -f "$auth_file" ]; then echo "No account found. Register first."; return 1; fi
  local pass_hash=$(echo -n "$password" | sha256sum | awk '{print $1}')
  python3 -c "
import json
auth = json.load(open('$auth_file'))
if auth['username'] == '$username' and auth['password_hash'] == '$pass_hash':
    auth['authenticated'] = True
    auth['last_login'] = '$(date -Iseconds)'
    json.dump(auth, open('$auth_file', 'w'), indent=2)
    print(f'Welcome back, {auth[\"username\"]}!')
else:
    print('Invalid credentials.')
" 2>/dev/null
}

# Check auth status
ai_auth_status() {
  local auth_file="$COMM_DIR/auth.json"
  if [ ! -f "$auth_file" ]; then echo "Not registered"; return 1; fi
  python3 -c "
import json
auth = json.load(open('$auth_file'))
status = 'authenticated' if auth.get('authenticated') else 'not authenticated'
print(f'User: {auth[\"username\"]} | Email: {auth[\"email\"]} | Status: {status}')
print(f'Last login: {auth.get(\"last_login\", \"never\")}')
" 2>/dev/null
}

# Logout
ai_auth_logout() {
  local auth_file="$COMM_DIR/auth.json"
  if [ ! -f "$auth_file" ]; then echo "Not logged in"; return 1; fi
  python3 -c "
import json
auth = json.load(open('$auth_file'))
auth['authenticated'] = False
json.dump(auth, open('$auth_file', 'w'), indent=2)
print(f'Goodbye, {auth[\"username\"]}!')
" 2>/dev/null
}

# --- DIGITAL WALLET ---
# Check balance
ai_wallet_balance() {
  local auth_file="$COMM_DIR/auth.json"
  local wallet_file="$COMM_DIR/wallet.json"
  [ -f "$auth_file" ] || { echo "Login first"; return 1; }
  local authed; authed=$(python3 -c "import json; print(json.load(open('$auth_file')).get('authenticated',False))" 2>/dev/null)
  [ "$authed" = "True" ] || { echo "Not authenticated"; return 1; }
  if [ ! -f "$wallet_file" ]; then
    echo '{"balance": 0.00, "currency": "USD", "transactions": []}' > "$wallet_file"
  fi
  python3 -c "
import json
w = json.load(open('$wallet_file'))
print(f'Balance: \${w[\"balance\"]:.2f} {w[\"currency\"]}')
if w['transactions']:
    print('Recent transactions:')
    for t in w['transactions'][-5:]:
        print(f'  {t[\"date\"]} | {t[\"description\"]} | \${t[\"amount\"]:.2f}')
" 2>/dev/null
}

# Add funds
ai_wallet_add() {
  local amount="$1" desc="${2:-Deposit}"
  local wallet_file="$COMM_DIR/wallet.json"
  [ -f "$wallet_file" ] || echo '{"balance": 0.00, "currency": "USD", "transactions": []}' > "$wallet_file"
  python3 -c "
import json
w = json.load(open('$wallet_file'))
w['balance'] += float('$amount')
w['transactions'].append({'date': '$(date -Iseconds)', 'amount': float('$amount'), 'description': '$desc', 'type': 'credit'})
json.dump(w, open('$wallet_file', 'w'), indent=2)
print(f'Added \${float(\"$amount\"):.2f}. New balance: \${w[\"balance\"]:.2f}')
" 2>/dev/null
}

# Spend from wallet
ai_wallet_spend() {
  local amount="$1" desc="${2:-Purchase}"
  local wallet_file="$COMM_DIR/wallet.json"
  [ -f "$wallet_file" ] || { echo "No wallet. Add funds first."; return 1; }
  python3 -c "
import json
w = json.load(open('$wallet_file'))
amt = float('$amount')
if w['balance'] >= amt:
    w['balance'] -= amt
    w['transactions'].append({'date': '$(date -Iseconds)', 'amount': -amt, 'description': '$desc', 'type': 'debit'})
    json.dump(w, open('$wallet_file', 'w'), indent=2)
    print(f'Spent \${amt:.2f} on {\"$desc\"}. Remaining: \${w[\"balance\"]:.2f}')
else:
    print(f'Insufficient funds. Balance: \${w[\"balance\"]:.2f}, needed: \${amt:.2f}')
" 2>/dev/null
}

# --- ORDER TRACKING ---
ai_order_track() {
  local order_id="$1"
  local order_file="$COMM_DIR/orders/${order_id}.json"
  if [ -f "$order_file" ]; then
    python3 -c "
import json
o = json.load(open('$order_file'))
print(f'Order: {o[\"id\"]}')
print(f'Status: {o[\"status\"]}')
print(f'Item: {o[\"item\"]}')
print(f'Price: \${o[\"price\"]:.2f}')
print(f'Ordered: {o[\"date\"]}')
print(f'Expected: {o.get(\"delivery\", \"pending\")}')
" 2>/dev/null
  else
    echo "Order not found: $order_id"
    echo "Your orders:"
    ls "$COMM_DIR/orders"/*.json 2>/dev/null | while read f; do
      python3 -c "import json; o=json.load(open('$f')); print(f'  {o[\"id\"]} — {o[\"status\"]} — {o[\"item\"]}')" 2>/dev/null
    done
  fi
}

ai_order_place() {
  local item="$1" price="$2" qty="${3:-1}"
  local id="ORD-$(date +%s)"
  cat > "$COMM_DIR/orders/$id.json" <<EOJSON
{"id":"$id","item":"$item","price":$price,"quantity":$qty,"status":"placed","date":"$(date -Iseconds)","delivery":"estimated 3-5 days"}
EOJSON
  echo "Order placed: $id — $item (qty: $qty, total: \$$price)"
}

# --- BOOKING ---
ai_book_reserve() {
  local type="$1" name="$2" date="$3" time="${4:-TBD}" notes="${5:-}"
  local id="BK-$(date +%s)"
  cat > "$COMM_DIR/bookings/$id.json" <<EOJSON
{"id":"$id","type":"$type","name":"$name","date":"$date","time":"$time","notes":"$notes","status":"confirmed","created":"$(date -Iseconds)"}
EOJSON
  echo "Booked: $type at $name on $date $time ($id)"
}

ai_book_list() {
  echo "=== My Bookings ==="
  for f in "$COMM_DIR/bookings"/*.json; do
    [ -f "$f" ] || continue
    python3 -c "
import json; b=json.load(open('$f'))
print(f'{b[\"id\"]} | {b[\"type\"]} at {b[\"name\"]} | {b[\"date\"]} {b[\"time\"]} | {b[\"status\"]}')
" 2>/dev/null
  done
}

# --- PRODUCT RECOMMENDATIONS ---
ai_recomm_add() {
  local item="$1" category="${2:-general}" rating="${3:-5}"
  local id="wish_$(date +%s)"
  cat > "$COMM_DIR/wishlist/$id.json" <<EOJSON
{"id":"$id","item":"$item","category":"$category","rating":$rating,"created":"$(date -Iseconds)"}
EOJSON
  echo "Added to wishlist: $item ($category, rating: $rating/5)"
}

ai_recomm_list() {
  echo "=== Wishlist ==="
  for f in "$COMM_DIR/wishlist"/*.json; do
    [ -f "$f" ] || continue
    python3 -c "
import json; w=json.load(open('$f'))
stars = '★' * w['rating'] + '☆' * (5 - w['rating'])
print(f'  {w[\"item\"]} | {w[\"category\"]} | {stars}')
" 2>/dev/null
  done
}

ai_recomm_suggest() {
  local interest="$1"
  echo "Recommendations based on '$interest':"
  echo "1. Browse related products online"
  echo "2. Check similar items in your wishlist"
  echo "3. Popular in this category:"
  case "${interest,,}" in
    *tech*|*gadget*|*computer*) echo "  - Latest processors, SSDs, peripherals" ;;
    *book*|*read*) echo "  - Bestsellers, new releases, classics" ;;
    *food*|*cook*) echo "  - Kitchen gadgets, ingredients, cookbooks" ;;
    *music*|*audio*) echo "  - Headphones, speakers, instruments" ;;
    *fitness*|*gym*) echo "  - Equipment, supplements, wearables" ;;
    *) echo "  - Search for '$interest' on your preferred store" ;;
  esac
}

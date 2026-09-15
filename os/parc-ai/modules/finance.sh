#!/usr/bin/env bash
# finance.sh — stock prices, currency, budget tracking

ai_finance_stock() {
  local symbol="$1"
  python3 -c "
import subprocess, json
symbol = '$symbol'.upper()
try:
    result = subprocess.run(['curl', '-s', f'https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=1d&range=1d'], capture_output=True, text=True, timeout=5)
    data = json.loads(result.stdout)
    meta = data['chart']['result'][0]['meta']
    price = meta.get('regularMarketPrice', 'N/A')
    prev = meta.get('previousClose', 'N/A')
    change = float(price) - float(prev) if price != 'N/A' and prev != 'N/A' else 0
    pct = (change / float(prev) * 100) if prev != 'N/A' and float(prev) > 0 else 0
    arrow = '📈' if change >= 0 else '📉'
    print(f'{arrow} {symbol}: \${price:.2f}')
    print(f'   Change: {\"+\" if change >= 0 else \"\"}\${change:.2f} ({\"+\" if pct >= 0 else \"\"}{pct:.2f}%)')
    print(f'   Previous close: \${prev}')
except:
    print(f'{symbol}: Data unavailable (install curl or check symbol)')
" 2>/dev/null || echo "Stock data unavailable"
}

ai_finance_currency() {
  local amount="$1" from="${2:-USD}" to="${3:-EUR}"
  python3 -c "
amount = float('$amount')
from_c = '$from'.upper()
to_c = '$to'.upper()
rates = {
    ('USD','EUR'): 0.92, ('EUR','USD'): 1.09,
    ('USD','GBP'): 0.79, ('GBP','USD'): 1.27,
    ('USD','JPY'): 149.5, ('JPY','USD'): 0.0067,
    ('USD','INR'): 83.1, ('INR','USD'): 0.012,
    ('EUR','GBP'): 0.86, ('GBP','EUR'): 1.16,
    ('USD','CAD'): 1.36, ('CAD','USD'): 0.74,
    ('USD','AUD'): 1.53, ('AUD','USD'): 0.65,
}
key = (from_c, to_c)
if key in rates:
    converted = amount * rates[key]
    print(f'{amount:.2f} {from_c} = {converted:.2f} {to_c}')
else:
    print(f'Rate not available for {from_c} → {to_c}')
    print(f'Available: USD, EUR, GBP, JPY, INR, CAD, AUD')
" 2>/dev/null || echo "Currency conversion unavailable"
}

ai_finance_budget() {
  local action="${1:-summary}"
  local budget_file="$TINKER_AI_HOME/budget.json"
  [ -f "$budget_file" ] || echo '{"income":0,"expenses":{},"savings":0}' > "$budget_file"

  case "$action" in
    add)
      local category="$2" amount="$3"
      python3 -c "
import json
b = json.load(open('$budget_file'))
cat = '$category'
amt = float('$amount')
if cat not in b['expenses']: b['expenses'][cat] = []
b['expenses'][cat].append({'amount': amt, 'date': '$(date +%Y-%m-%d)'})
json.dump(b, open('$budget_file', 'w'), indent=2)
print(f'Added \${amt:.2f} to {cat}')
" 2>/dev/null
      ;;
    income)
      local amount="$2"
      python3 -c "
import json
b = json.load(open('$budget_file'))
b['income'] = float('$amount')
json.dump(b, open('$budget_file', 'w'), indent=2)
print(f'Monthly income set to: \${float(\"$amount\"):.2f}')
" 2>/dev/null
      ;;
    summary|*)
      python3 -c "
import json
b = json.load(open('$budget_file'))
total_expenses = sum(sum(e['amount'] for e in exps) for exps in b['expenses'].values())
savings = b['income'] - total_expenses
print(f'=== Budget Summary ===')
print(f'Income: \${b[\"income\"]:.2f}')
print(f'Expenses:')
for cat, exps in b['expenses'].items():
    total = sum(e['amount'] for e in exps)
    print(f'  {cat}: \${total:.2f}')
print(f'Total expenses: \${total_expenses:.2f}')
print(f'Savings: \${savings:.2f} ({savings/max(b[\"income\"],1)*100:.1f}%)')
" 2>/dev/null
      ;;
  esac
}

ai_finance_budget_add() { ai_finance_budget "add" "$1" "$2"; }
ai_finance_budget_set_income() { ai_finance_budget "income" "$1"; }

#!/usr/bin/env bash
# math.sh — mathematical computation, unit conversion, data analysis

# Evaluate math expressions
ai_math_calc() {
  local expr="$1"
  python3 -c "
import math, sys
expr = '''$expr'''
# Add common math functions to namespace
ns = {k: v for k, v in math.__dict__.items() if not k.startswith('_')}
ns['abs'] = abs; ns['round'] = round; ns['min'] = min; ns['max'] = max
ns['sum'] = sum; ns['len'] = len; ns['pi'] = math.pi; ns['e'] = math.e
try:
    result = eval(expr, {'__builtins__': {}}, ns)
    print(f'{expr} = {result}')
except Exception as e:
    print(f'Error: {e}')
" 2>/dev/null || echo "Could not compute: $expr"
}

# Unit conversion
ai_math_convert() {
  local value="$1" from="$2" to="$3"
  python3 -c "
v = float('${value}')
conversions = {
    ('km','mi'): v * 0.621371, ('mi','km'): v * 1.60934,
    ('kg','lb'): v * 2.20462, ('lb','kg'): v * 0.453592,
    ('c','f'): v * 9/5 + 32, ('f','c'): (v - 32) * 5/9,
    ('m','ft'): v * 3.28084, ('ft','m'): v * 0.3048,
    ('cm','in'): v * 0.393701, ('in','cm'): v * 2.54,
    ('l','gal'): v * 0.264172, ('gal','l'): v * 3.78541,
    ('gb','mb'): v * 1024, ('mb','gb'): v / 1024,
    ('kb','b'): v * 1024, ('b','kb'): v / 1024,
    ('s','ms'): v * 1000, ('ms','s'): v / 1000,
    ('min','s'): v * 60, ('h','min'): v * 60,
}
from_u = '${from}'.lower()
to_u = '${to}'.lower()
key = (from_u, to_u)
if key in conversions:
    print(str(v) + ' ' + from_u + ' = ' + str(round(conversions[key], 4)) + ' ' + to_u)
else:
    print('Unknown conversion: ' + from_u + ' -> ' + to_u)
    print('Supported: km/mi, kg/lb, c/f, m/ft, cm/in, l/gal, gb/mb, s/ms')
" 2>/dev/null || echo "Conversion failed"
}

# Analyze CSV data
ai_math_analyze() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "File not found: $file"; return 1
  fi
  python3 -c "
import csv, sys, statistics

with open('$file') as f:
    reader = csv.reader(f)
    headers = next(reader, None)
    data = list(reader)

if not headers:
    print('No headers found'); sys.exit()

print(f'File: $file')
print(f'Rows: {len(data)}')
print(f'Columns: {len(headers)}')
print()

for col_idx, header in enumerate(headers):
    vals = []
    for row in data:
        if col_idx < len(row):
            try: vals.append(float(row[col_idx]))
            except: pass
    if vals and len(vals) > 1:
        print(f'{header}:')
        print(f'  min={min(vals):.2f} max={max(vals):.2f} avg={statistics.mean(vals):.2f} median={statistics.median(vals):.2f} stdev={statistics.stdev(vals):.2f}')
    elif vals:
        print(f'{header}: {vals[0]}')
" 2>/dev/null || echo "Could not analyze CSV (install python3 for full support)"
}

# Financial calculations
ai_math_finance() {
  local calc_type="$1"; shift
  case "$calc_type" in
    compound)
      local p="$1" r="$2" n="$3" t="$4"
      ai_math_calc "$p * (1 + $r/$n)^($n * $t)"
      ;;
    loan)
      local p="$1" r="$2" n="$3"
      ai_math_calc "$p * ($r/$n) / (1 - (1 + $r/$n)^(-$n))"
      ;;
    roi)
      local gain="$1" cost="$2"
      ai_math_calc "(($gain - $cost) / $cost) * 100"
      ;;
    *)
      echo "Usage: ai_math_finance compound|loan|roi [args]"
      echo "  compound principal rate periods years"
      echo "  loan principal rate months"
      echo "  roi gain cost"
      ;;
  esac
}

# Solve basic equations (x = ?)
ai_math_solve() {
  local equation="$1"
  python3 -c "
import re
eq = '''$equation'''
# Simple linear: ax + b = c
m = re.match(r'(\-?\d*\.?\d*)\s*x\s*([+\-])\s*(\d+\.?\d*)\s*=\s*(\-?\d+\.?\d*)', eq)
if m:
    a = float(m.group(1)) if m.group(1) and m.group(1) != '-' else (-1 if m.group(1) == '-' else 1)
    sign = 1 if m.group(2) == '+' else -1
    b = sign * float(m.group(3))
    c = float(m.group(4))
    x = (c - b) / a
    print(f'x = {x}')
else:
    print(f'Could not solve: {eq}')
    print('Format: ax + b = c')
" 2>/dev/null || echo "Could not solve equation"
}

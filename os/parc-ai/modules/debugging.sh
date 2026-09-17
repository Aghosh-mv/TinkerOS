#!/usr/bin/env bash
# debugging.sh — rubber duck debugging, boilerplate generation, reverse-engineering

# Rubber duck debugging: ask clarifying questions to help find the bug
ai_debug_duck() {
  local problem="$1"
  python3 -c "
problem = '''$problem'''

questions = [
    '1. What is the EXPECTED behavior? What should happen?',
    '2. What is the ACTUAL behavior? What is happening instead?',
    '3. When did this start happening? What changed recently?',
    '4. Can you reproduce it consistently, or is it intermittent?',
    '5. What have you already tried?',
    '6. What is the exact error message (if any)?',
    '7. What are the inputs that trigger this?',
    '8. Does it work in a different environment/context?',
    '9. What is the simplest case where this fails?',
    '10. If you add print/log statements before the failing line, what do you see?',
]

print(' Rubber Duck Debugging Session')
print('=' * 40)
print()
print(f'Problem: {problem[:200]}')
print()
print('Let us talk through this step by step:')
print()
for q in questions:
    print(f'  {q}')
print()
print('Common root causes to check:')
print('  • Off-by-one errors (loop boundaries)')
print('  • Null/None/undefined values')
print('  • Race conditions (async timing)')
print('  • Incorrect variable scope')
print('  • Stale state / caching issues')
print('  • Wrong data type (string vs int)')
print('  • Missing imports / dependencies')
print('  • Hardcoded values that should be dynamic')
" 2>/dev/null || echo "Rubber duck: describe your problem and I will help debug it."
}

# Generate boilerplate for various project types
ai_debug_boilerplate() {
  local type="$1" name="${2:-project}"
  case "$type" in
    python-api|fastapi)
      cat <<EOF
# $name — FastAPI project
# pip install fastapi uvicorn

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import uvicorn

app = FastAPI(title="$name")

class Item(BaseModel):
    name: str
    description: Optional[str] = None
    price: float

@app.get("/")
def root():
    return {"message": "$name API"}

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/items/")
def create_item(item: Item):
    return {"item": item, "status": "created"}

@app.get("/items/{item_id}")
def read_item(item_id: int):
    return {"item_id": item_id}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
      ;;
    react-app)
      cat <<EOF
// $name — React App
import React, { useState, useEffect } from 'react';

function App() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/data')
      .then(res => res.json())
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div>Loading...</div>;

  return (
    <div className="App">
      <h1>$name</h1>
      {data && <pre>{JSON.stringify(data, null, 2)}</pre>}
    </div>
  );
}

export default App;
EOF
      ;;
    docker)
      cat <<EOF
# $name — Docker Compose
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    environment:
      - NODE_ENV=production
    volumes:
      - .:/app
      - /app/node_modules
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      POSTGRES_DB: $name
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secret
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
EOF
      ;;
    bash-script)
      cat <<'EOF'
#!/usr/bin/env bash
# Script: NAME
# Description: DESCRIPTION
# Usage: ./script.sh [OPTIONS]

set -euo pipefail
IFS=$'\n\t'

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<USAGE
Usage: $SCRIPT_NAME [OPTIONS] <args>

Options:
  -h, --help      Show this help
  -v, --version   Show version
  -q, --quiet     Suppress output

Version: $VERSION
USAGE
}

# --- Main ---
main() {
    local quiet=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -v|--version) echo "$VERSION"; exit 0 ;;
            -q|--quiet) quiet=true; shift ;;
            *) shift ;;
        esac
    done
    log "Starting $SCRIPT_NAME"
    # TODO: implement
}

main "$@"
EOF
      ;;
    *)
      echo "Boilerplate types: python-api, react-app, docker, bash-script"
      ;;
  esac
}

# Reverse-engineer: explain code step by step
ai_debug_explain() {
  local code="$1"
  python3 -c "
import re
code = '''$code'''
lines = [l.strip() for l in code.strip().split('\n') if l.strip()]

print('=== Code Explanation (Step by Step) ===')
print()

step = 0
for i, line in enumerate(lines):
    explanation = ''

    # Python
    if line.startswith('def '):
        fname = re.search(r'def\s+(\w+)', line)
        args = re.search(r'\((.*?)\)', line)
        explanation = f'Defines a function named {fname.group(1) if fname else \"?\"} that takes {args.group(1) if args else \"no\"} arguments'
    elif line.startswith('class '):
        cname = re.search(r'class\s+(\w+)', line)
        explanation = f'Defines a class named {cname.group(1) if cname else \"?\"}'
    elif line.startswith('import ') or line.startswith('from '):
        explanation = f'Imports a module: {line}'
    elif line.startswith('if ') or line.startswith('elif '):
        explanation = f'Conditional check: {line[:60]}'
    elif line.startswith('for ') or line.startswith('while '):
        explanation = f'Loop: {line[:60]}'
    elif line.startswith('return '):
        explanation = f'Returns: {line[7:60]}'
    elif line.startswith('print('):
        explanation = f'Outputs to console: {line[7:-2][:50]}'
    elif '=' in line and not line.startswith('#'):
        var = line.split('=')[0].strip()
        explanation = f'Sets variable: {var}'
    elif line.startswith('#'):
        explanation = f'Comment: {line[:60]}'

    # JavaScript
    elif 'function' in line or '=>' in line:
        explanation = f'Function definition: {line[:60]}'
    elif 'const ' in line or 'let ' in line or 'var ' in line:
        explanation = f'Variable declaration: {line[:60]}'
    elif line.startswith('//'):
        explanation = f'Comment: {line[:60]}'

    if explanation:
        step += 1
        print(f'Step {step} (line {i+1}):')
        print(f'  Code:   {line[:70]}')
        print(f'  Explain: {explanation}')
        print()

if step == 0:
    print('Could not parse code. Make sure it is valid Python, JavaScript, or bash.')
else:
    print(f'Total: {step} steps explained.')
" 2>/dev/null || echo "Explain: paste code and I will walk through it step by step."
}

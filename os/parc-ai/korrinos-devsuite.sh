#!/usr/bin/env bash
# korrinos-devsuite.sh — Developer Productivity Suite
# Git shortcuts, project templates, code analysis, container tools

set -euo pipefail

DEV_DIR="${HOME}/.config/korrinos/devsuite"
DEV_CONFIG="$DEV_DIR/config.json"
mkdir -p "$DEV_DIR"

# Git shortcuts
cmd_git_status() {
  echo "=== Git Status ==="
  echo ""
  
  if [ -d .git ]; then
    echo "  Repository: $(basename $(git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null || echo '?')"
    echo "  Branch: $(git branch --show-current 2>/dev/null || echo 'detached')"
    echo ""
    git status --short 2>/dev/null | head -20 | sed 's/^/  /'
    echo ""
    echo "  Recent commits:"
    git log --oneline -5 2>/dev/null | sed 's/^/    /'
  else
    echo "  Not a git repository"
  fi
}

# Git quick commit
cmd_git_commit() {
  local msg="$1"
  if [ -d .git ]; then
    git add -A 2>/dev/null
    git commit -m "$msg" 2>/dev/null
    echo "Committed: ${msg}"
  else
    echo "Not a git repository"
    return 1
  fi
}

# Git smart commit (auto-message)
cmd_git_smart() {
  if [ -d .git ]; then
    local changes
    changes=$(git diff --stat 2>/dev/null | tail -1)
    local files_changed
    files_changed=$(git diff --name-only 2>/dev/null | wc -l)
    local additions
    additions=$(git diff --numstat 2>/dev/null | awk '{s+=$1}END{print s+0}')
    local deletions
    deletions=$(git diff --numstat 2>/dev/null | awk '{s+=$2}END{print s+0}')
    
    # Auto-generate message
    local msg="chore: update ${files_changed} files (+${additions}/-${deletions})"
    
    # Detect type of change
    if git diff --name-only 2>/dev/null | grep -q "\.md$"; then
      msg="docs: update documentation"
    elif git diff --name-only 2>/dev/null | grep -qE "\.(sh|bash)$"; then
      msg="feat: update shell scripts"
    elif git diff --name-only 2>/dev/null | grep -qE "\.(c|h)$"; then
      msg="feat: update kernel code"
    elif git diff --name-only 2>/dev/null | grep -qE "\.(py)$"; then
      msg="feat: update Python code"
    fi
    
    git add -A 2>/dev/null
    git commit -m "$msg" 2>/dev/null
    echo "Auto-committed: ${msg}"
  else
    echo "Not a git repository"
    return 1
  fi
}

# Project templates
cmd_template() {
  local template="$1"
  local name="${2:-myproject}"
  
  echo "Creating project: ${name}"
  echo "Template: ${template}"
  echo ""
  
  case "$template" in
    python|py)
      mkdir -p "$name"/{src,tests,docs}
      cat > "$name/README.md" << EOF
# ${name}

## Installation
\`\`\`bash
pip install -r requirements.txt
\`\`\`

## Usage
\`\`\`python
from src import main
\`\`\`
EOF
      cat > "$name/requirements.txt" << 'EOF'
# Add dependencies here
EOF
      cat > "$name/setup.py" << EOF
from setuptools import setup, find_packages

setup(
    name="${name}",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[],
)
EOF
      cat > "$name/.gitignore" << 'EOF'
__pycache__/
*.pyc
.env
venv/
*.egg-info/
dist/
build/
EOF
      echo "✓ Python project created"
      ;;
      
    node|js)
      mkdir -p "$name"/{src,public,tests}
      cat > "$name/package.json" << EOF
{
  "name": "${name}",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/index.js",
    "test": "jest"
  }
}
EOF
      cat > "$name/src/index.js" << 'EOF'
// Entry point
console.log('Hello from ${name}');
EOF
      cat > "$name/.gitignore" << 'EOF'
node_modules/
.env
dist/
EOF
      echo "✓ Node.js project created"
      ;;
      
    go|golang)
      mkdir -p "$name"/{cmd,pkg,internal}
      cat > "$name/go.mod" << EOF
module ${name}

go 1.21
EOF
      cat > "$name/main.go" << EOF
package main

import "fmt"

func main() {
    fmt.Println("Hello from ${name}")
}
EOF
      cat > "$name/.gitignore" << 'EOF'
${name}
*.exe
vendor/
EOF
      echo "✓ Go project created"
      ;;
      
    rust|rs)
      mkdir -p "$name"/src
      cat > "$name/Cargo.toml" << EOF
[package]
name = "${name}"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF
      cat > "$name/src/main.rs" << EOF
fn main() {
    println!("Hello from ${name}");
}
EOF
      cat > "$name/.gitignore" << 'EOF'
target/
Cargo.lock
EOF
      echo "✓ Rust project created"
      ;;
      
    c|kernel)
      mkdir -p "$name"/{src,include}
      cat > "$name/Makefile" << EOF
obj-m += ${name}.o

all:
\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) modules

clean:
\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) clean
EOF
      cat > "$name/src/${name}.c" << EOF
#include <linux/module.h>
#include <linux/kernel.h>

static int __init ${name}_init(void) {
    printk(KERN_INFO "${name} loaded\\n");
    return 0;
}

static void __exit ${name}_exit(void) {
    printk(KERN_INFO "${name} unloaded\\n");
}

module_init(${name}_init);
module_exit(${name}_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("${name} kernel module");
EOF
      echo "✓ Kernel module project created"
      ;;
      
    *)
      echo "Available templates: python, node, go, rust, c"
      return 1
      ;;
  esac
  
  echo "  Location: $(pwd)/${name}"
}

# Code analysis
cmd_analyze() {
  echo "=== Code Analysis ==="
  echo ""
  
  local dir="${1:-.}"
  
  # Language breakdown
  echo "  Language breakdown:"
  find "$dir" -type f -name "*.py" 2>/dev/null | wc -l | xargs -I{} echo "    Python: {} files"
  find "$dir" -type f -name "*.sh" 2>/dev/null | wc -l | xargs -I{} echo "    Shell: {} files"
  find "$dir" -type f -name "*.c" 2>/dev/null | wc -l | xargs -I{} echo "    C: {} files"
  find "$dir" -type f -name "*.h" 2>/dev/null | wc -l | xargs -I{} echo "    Headers: {} files"
  find "$dir" -type f -name "*.js" 2>/dev/null | wc -l | xargs -I{} echo "    JavaScript: {} files"
  find "$dir" -type f -name "*.ts" 2>/dev/null | wc -l | xargs -I{} echo "    TypeScript: {} files"
  find "$dir" -type f -name "*.rs" 2>/dev/null | wc -l | xargs -I{} echo "    Rust: {} files"
  find "$dir" -type f -name "*.go" 2>/dev/null | wc -l | xargs -I{} echo "    Go: {} files"
  echo ""
  
  # Line counts
  echo "  Line counts:"
  local total=0
  for ext in py sh c h js ts rs go; do
    local count
    count=$(find "$dir" -type f -name "*.${ext}" -exec cat {} + 2>/dev/null | wc -l)
    [ "$count" -gt 0 ] && echo "    .${ext}: ${count} lines" && total=$((total + count))
  done
  echo "    Total: ${total} lines"
  echo ""
  
  # TODOs
  echo "  TODOs found:"
  grep -rn "TODO\|FIXME\|HACK\|XXX" "$dir" 2>/dev/null | head -10 | sed 's/^/    /'
}

# Docker helpers
cmd_docker() {
  echo "=== Docker Status ==="
  echo ""
  
  if command -v docker &>/dev/null; then
    echo "  Containers:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -10 | sed 's/^/    /'
    echo ""
    echo "  Images:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null | head -10 | sed 's/^/    /'
  else
    echo "  Docker not installed"
  fi
}

# Container helpers
cmd_container() {
  local action="$1"
  shift
  
  case "$action" in
    run)
      local image="$1"
      shift
      docker run -it --rm "$image" "$@" 2>/dev/null
      ;;
    shell)
      local container="$1"
      docker exec -it "$container" /bin/bash 2>/dev/null || docker exec -it "$container" /bin/sh 2>/dev/null
      ;;
    logs)
      local container="$1"
      docker logs -f "$container" 2>/dev/null
      ;;
    *)
      echo "Usage: devsuite container (run|shell|logs)"
      ;;
  esac
}

# Runtime management
cmd_runtime() {
  echo "=== Development Runtimes ==="
  echo ""
  
  command -v python3 &>/dev/null && echo "  Python: $(python3 --version 2>&1 | awk '{print $2}')"
  command -v node &>/dev/null && echo "  Node.js: $(node --version 2>&1)"
  command -v npm &>/dev/null && echo "  npm: $(npm --version 2>&1)"
  command -v go &>/dev/null && echo "  Go: $(go version 2>&1 | awk '{print $3}')"
  command -v rustc &>/dev/null && echo "  Rust: $(rustc --version 2>&1 | awk '{print $2}')"
  command -v gcc &>/dev/null && echo "  GCC: $(gcc --version 2>&1 | head -1 | awk '{print $3}')"
  command -v docker &>/dev/null && echo "  Docker: $(docker --version 2>&1 | awk '{print $3}' | tr -d ',')"
  command -v git &>/dev/null && echo "  Git: $(git --version 2>&1 | awk '{print $3}')"
}

case "${1:-help}" in
  git)
    shift
    case "${1:-status}" in
      status)      cmd_git_status ;;
      commit)      shift; cmd_git_commit "$@" ;;
      smart)       cmd_git_smart ;;
      *)           echo "Usage: devsuite git (status|commit|smart)" ;;
    esac
    ;;
  template|tpl)
    shift; cmd_template "$@"
    ;;
  analyze)
    shift; cmd_analyze "$@"
    ;;
  docker)
    shift; cmd_docker "$@"
    ;;
  container)
    shift; cmd_container "$@"
    ;;
  runtime)
    cmd_runtime
    ;;
  *)
    echo "KorrinOS Developer Suite"
    echo "Usage: korrinos-devsuite.sh <command>"
    echo ""
    echo "Commands:"
    echo "  git status          Git repository status"
    echo "  git commit <msg>    Quick git commit"
    echo "  git smart           Auto-commit with smart message"
    echo "  template <type> <name>  Create project from template"
    echo "                         (python|node|go|rust|c)"
    echo "  analyze [dir]       Code analysis & stats"
    echo "  docker              Docker status"
    echo "  container <action>  Container management (run|shell|logs)"
    echo "  runtime             Show development runtimes"
    ;;
esac

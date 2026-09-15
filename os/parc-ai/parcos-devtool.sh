#!/usr/bin/env bash
# korrinos-devtool.sh — Developer Toolkit for KorrinOS
# VS Code Server, Docker, Git GUI, runtime manager

set -euo pipefail

DEV_DIR="${HOME}/.config/korrinos/devtool"
DEV_CONFIG="$DEV_DIR/config.json"

mkdir -p "$DEV_DIR"

# Git operations
dev_git_status() {
  echo "=== Git Status ==="
  if [ -d .git ]; then
    git status
    echo ""
    echo "=== Recent Commits ==="
    git log --oneline -10
  else
    echo "Not a git repository"
  fi
}

dev_git_diff() {
  echo "=== Git Diff ==="
  if [ -d .git ]; then
    git diff
  fi
}

dev_git_commit() {
  local msg="$1"
  if [ -d .git ]; then
    git add -A
    git commit -m "$msg"
    echo "Committed: $msg"
  fi
}

dev_git_push() {
  if [ -d .git ]; then
    git push
    echo "Pushed to remote"
  fi
}

dev_git_pull() {
  if [ -d .git ]; then
    git pull
    echo "Pulled from remote"
  fi
}

dev_git_log() {
  local count="${1:-20}"
  if [ -d .git ]; then
    git log --oneline --graph -"$count"
  fi
}

dev_git_branches() {
  if [ -d .git ]; then
    echo "=== Local Branches ==="
    git branch
    echo ""
    echo "=== Remote Branches ==="
    git branch -r
  fi
}

# Docker operations
dev_docker_status() {
  echo "=== Docker Status ==="
  if command -v docker &>/dev/null; then
    docker info 2>/dev/null | head -20
    echo ""
    echo "=== Running Containers ==="
    docker ps
    echo ""
    echo "=== Images ==="
    docker images | head -10
  else
    echo "Docker not installed"
  fi
}

dev_docker_run() {
  local image="$1"
  shift
  docker run -it "$image" "$@"
}

dev_docker_stop() {
  local container="$1"
  docker stop "$container"
  echo "Stopped: $container"
}

dev_docker_logs() {
  local container="$1"
  docker logs -f "$container"
}

dev_docker_clean() {
  echo "Cleaning Docker..."
  docker system prune -af
  docker volume prune -f
  echo "Cleaned"
}

# Runtime manager
dev_runtime_list() {
  echo "=== Development Runtimes ==="
  echo ""
  
  echo "Python:"
  python3 --version 2>/dev/null || echo "  Not installed"
  python3.10 --version 2>/dev/null || echo "  python3.10 not installed"
  
  echo ""
  echo "Node.js:"
  node --version 2>/dev/null || echo "  Not installed"
  npm --version 2>/dev/null || echo "  npm not installed"
  
  echo ""
  echo "Rust:"
  rustc --version 2>/dev/null || echo "  Not installed"
  cargo --version 2>/dev/null || echo "  cargo not installed"
  
  echo ""
  echo "Go:"
  go version 2>/dev/null || echo "  Not installed"
  
  echo ""
  echo "Java:"
  java -version 2>&1 | head -1 || echo "  Not installed"
  
  echo ""
  echo "Ruby:"
  ruby --version 2>/dev/null || echo "  Not installed"
  
  echo ""
  echo "PHP:"
  php --version 2>&1 | head -1 || echo "  Not installed"
  
  echo ""
  echo "Docker:"
  docker --version 2>/dev/null || echo "  Not installed"
}

dev_runtime_install() {
  local runtime="$1"
  
  case "$runtime" in
    python)
      sudo apt install -y python3 python3-pip python3-venv
      ;;
    node)
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt install -y nodejs
      ;;
    rust)
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      ;;
    go)
      sudo apt install -y golang-go
      ;;
    java)
      sudo apt install -y default-jdk
      ;;
    ruby)
      sudo apt install -y ruby-full
      ;;
    php)
      sudo apt install -y php-cli
      ;;
    *)
      echo "Unknown runtime: $runtime"
      ;;
  esac
}

# Project templates
dev_project_template() {
  local type="$1"
  local name="${2:-myproject}"
  
  mkdir -p "$name"
  
  case "$type" in
    python)
      cat > "$name/README.md" << EOF
# $name

Python project

## Setup

\`\`\`bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
\`\`\`

## Usage

\`\`\`bash
python main.py
\`\`\`
EOF
      touch "$name/requirements.txt"
      touch "$name/main.py"
      touch "$name/.gitignore"
      echo "Python project created: $name"
      ;;
    node)
      cat > "$name/package.json" << EOF
{
  "name": "$name",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  }
}
EOF
      touch "$name/index.js"
      touch "$name/.gitignore"
      echo "Node.js project created: $name"
      ;;
    rust)
      cargo init "$name"
      echo "Rust project created: $name"
      ;;
    go)
      mkdir -p "$name/cmd"
      cat > "$name/main.go" << EOF
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
EOF
      echo "Go project created: $name"
      ;;
    *)
      echo "Unknown template: $type"
      ;;
  esac
}

# Code analysis
dev_analyze() {
  local file="$1"
  
  echo "=== Code Analysis: $file ==="
  
  # Line count
  echo ""
  echo "Lines of code:"
  wc -l "$file"
  
  # Language detection
  local ext="${file##*.}"
  case "$ext" in
    py)     echo "Language: Python" ;;
    js)     echo "Language: JavaScript" ;;
    ts)     echo "Language: TypeScript" ;;
    c)      echo "Language: C" ;;
    h)      echo "Language: C Header" ;;
    cpp)    echo "Language: C++" ;;
    rs)     echo "Language: Rust" ;;
    go)     echo "Language: Go" ;;
    java)   echo "Language: Java" ;;
    sh)     echo "Language: Shell" ;;
    *)      echo "Language: Unknown" ;;
  esac
  
  # Check for TODOs
  echo ""
  echo "TODOs found:"
  grep -n "TODO\|FIXME\|HACK\|XXX" "$file" 2>/dev/null || echo "  None"
}

case "${1:-help}" in
  git)
    shift
    case "${1:-status}" in
      status)    dev_git_status ;;
      diff)      dev_git_diff ;;
      commit)    shift; dev_git_commit "$@" ;;
      push)      dev_git_push ;;
      pull)      dev_git_pull ;;
      log)       shift; dev_git_log "$@" ;;
      branches)  dev_git_branches ;;
    esac
    ;;
  docker)
    shift
    case "${1:-status}" in
      status) dev_docker_status ;;
      run)    shift; dev_docker_run "$@" ;;
      stop)   shift; dev_docker_stop "$@" ;;
      logs)   shift; dev_docker_logs "$@" ;;
      clean)  dev_docker_clean ;;
    esac
    ;;
  runtime)
    shift
    case "${1:-list}" in
      list)     dev_runtime_list ;;
      install)  shift; dev_runtime_install "$@" ;;
    esac
    ;;
  template)   shift; dev_project_template "$@" ;;
  analyze)    shift; dev_analyze "$@" ;;
  *)
    echo "KorrinOS Developer Toolkit"
    echo "Usage: korrinos-devtool.sh <command>"
    echo ""
    echo "Commands:"
    echo "  git (status|diff|commit|push|pull|log|branches)"
    echo "  docker (status|run|stop|logs|clean)"
    echo "  runtime (list|install <runtime>)"
    echo "  template <type> [name]  Create project template"
    echo "  analyze <file>          Analyze code file"
    ;;
esac

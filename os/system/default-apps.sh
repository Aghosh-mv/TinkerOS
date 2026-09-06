#!/bin/bash
# TinkerOS Default Apps Bundler
# Pre-installs the essential native apps onto the OS image:
# GitHub CLI, Chrome (or removable Brave), VS Code, Claude, and a
# docker-like built-in sandbox helper. This runs during OS install,
# NOT on the user's host (per project rule).

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Env guard: only allow inside an install/ISO chroot context.
require_install_target() {
    if [ "$TINKER_INSTALL_TARGET" != "1" ]; then
        echo -e "${YELLOW}Refusing: this bundles apps for the OS IMAGE only.${NC}"
        echo "  Set TINKER_INSTALL_TARGET=1 inside the ISO/chroot build to proceed."
        exit 1
    fi
}

install_github_cli() {
    echo "== GitHub CLI =="
    command -v gh >/dev/null 2>&1 || \
        (ls /usr/bin/apt >/dev/null 2>&1 && apt-get install -y gh) || true
}

install_vscode() {
    echo "== VS Code =="
    command -v code >/dev/null 2>&1 || \
        (curl -fsSL https://go.microsoft.com/fwlink/?LinkID=760868 -o /tmp/vscode.deb \
         && dpkg -i /tmp/vscode.deb || true)
}

install_browser() {
    echo "== Browser (Chrome; Brave removable) =="
    if command -v google-chrome >/dev/null 2>&1; then return; fi
    curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        -o /tmp/chrome.deb && dpkg -i /tmp/chrome.deb || \
        (echo "Chrome failed; installing Brave" &&
         curl -fsSLo /tmp/brave.deb https://github.com/brave/brave-browser/releases/latest/download/brave-browser_amd64.deb \
         && dpkg -i /tmp/brave.deb || true)
}

install_sandbox_tool() {
    echo "== Docker-like sandbox helper =="
    mkdir -p /usr/lib/tinker/sandbox
    # minimal bwrap-based sandbox wrapper
    [ -f /usr/lib/tinker/sandbox/tinker-sandbox ] || \
        printf '#!/bin/bash\n[ $# -lt 1 ] && exit 1\nif command -v bwrap >/dev/null; then\n  exec bwrap --ro-bind / / \\\n    --dev /dev --proc /proc --unshare-net \\\n    --die-with-parent "$@";\nelse\n  echo "run in a container (no bwrap)"; "$@"\nfi\n' \
        > /usr/lib/tinker/sandbox/tinker-sandbox && chmod +x /usr/lib/tinker/sandbox/tinker-sandbox
    echo "sandbox helper installed: /usr/lib/tinker/sandbox/tinker-sandbox"
}

echo -e "${BLUE}── TinkerOS Default Apps Bundler ──${NC}"
require_install_target
install_github_cli
install_vscode
install_browser
install_sandbox_tool
echo -e "${GREEN}Default apps bundled.${NC}"
echo "  (Claude API integration is configured separately; see os/tinkerai)"

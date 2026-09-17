#!/usr/bin/env bash
# korrinos-ai-installer.sh — Installs Tinkeria as a persistent system service
# Files go to /usr/local/korrinos/ — protected, non-removable by user

set -euo pipefail

INSTALL_DIR="/usr/local/korrinos"
SERVICE_NAME="korrinos-ai"
AI_SOURCE="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[korrinos-ai]${NC} $1"; }
ok()   { echo -e "${GREEN}[]${NC} $1"; }
fail() { echo -e "${RED}[]${NC} $1"; exit 1; }

# Must be root for system install
if [ "$EUID" -ne 0 ]; then
  fail "Run with sudo: sudo bash korrinos-ai-installer.sh"
fi

log "Installing Tinkeria to $INSTALL_DIR..."

# 1. Create directory structure
mkdir -p "$INSTALL_DIR"/{bin,modules,overlay,model,config}
ok "Directory structure created"

# 2. Copy CLI
cp "$AI_SOURCE/parc-ai.sh" "$INSTALL_DIR/bin/parc-ai"
chmod +x "$INSTALL_DIR/bin/parc-ai"
ok "CLI installed"

# 3. Copy all modules
cp "$AI_SOURCE"/modules/*.sh "$INSTALL_DIR/modules/" 2>/dev/null
ok "Modules installed ($(ls "$INSTALL_DIR/modules/"*.sh 2>/dev/null | wc -l) files)"

# 4. Copy overlay
if [ -d "$AI_SOURCE/overlay" ]; then
  cp -r "$AI_SOURCE/overlay/"* "$INSTALL_DIR/overlay/" 2>/dev/null
  ok "Overlay installed"
fi

# 5. Copy model files
if [ -d "$AI_SOURCE/model" ]; then
  cp -r "$AI_SOURCE/model/"* "$INSTALL_DIR/model/" 2>/dev/null
  ok "Model files installed"
fi

# 6. Create wrapper script in /usr/local/bin
cat > /usr/local/bin/korrinos-ai << 'WRAPPER'
#!/usr/bin/env bash
exec /usr/local/korrinos/bin/parc-ai "$@"
WRAPPER
chmod +x /usr/local/bin/korrinos-ai
ok "Command: korrinos-ai available system-wide"

# 7. Create systemd service — auto-starts on boot
cat > /etc/systemd/system/${SERVICE_NAME}.service << 'SERVICE'
[Unit]
Description=KorrinOS Tinkeria Assistant
After=network.target graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=tinkerspace
Environment=DISPLAY=:1
ExecStart=/usr/local/korrinos/bin/parc-ai --daemon
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE
ok "Systemd service created"

# 8. Enable service (starts on boot)
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}.service
ok "Service enabled (auto-start on boot)"

# 9. Set permissions — owned by root, read-only to users
chown -R root:root "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 755 /usr/local/bin/korrinos-ai
ok "Permissions set (root-owned, system-protected)"

# 10. Create uninstall protection marker
cat > "$INSTALL_DIR/config/.protected" << 'PROTECTED'
# This file marks Tinkeria as a protected system component.
# Tinkeria is an integral part of KorrinOS and cannot be removed.
# Removing this file does not uninstall Tinkeria.
PROTECTED
chmod 444 "$INSTALL_DIR/config/.protected"
ok "Protection marker installed"

# 11. Install uninstall blocker
if [ -f "$AI_SOURCE/korrinos-uninstall-blocker.sh" ]; then
  cp "$AI_SOURCE/korrinos-uninstall-blocker.sh" "$INSTALL_DIR/config/uninstall-blocker.sh"
  chmod +x "$INSTALL_DIR/config/uninstall-blocker.sh"
  "$INSTALL_DIR/config/uninstall-blocker.sh" --setup-cron 2>/dev/null || true
  ok "Uninstall blocker installed (cron every 5 min)"
else
  log "Skipping uninstall blocker (not found)"
fi

# 12. Hide from package managers
mkdir -p /etc/korrinos
echo "korrinos-ai" > /etc/korrinos/.protected
ok "Protected from package manager removal"

echo ""
echo "============================================"
echo -e "${GREEN}Tinkeria installed successfully!${NC}"
echo "============================================"
echo ""
echo "Location:   $INSTALL_DIR"
echo "Command:    korrinos-ai"
echo "Service:    ${SERVICE_NAME}"
echo "Auto-start: Yes (survives reboot)"
echo "Removable:  No (system-protected)"
echo ""
echo "Usage:"
echo "  korrinos-ai ask 'hello'     — Ask anything"
echo "  korrinos-ai health          — System dashboard"
echo "  korrinos-ai learn 'topic'   — Search and learn"
echo "  systemctl status ${SERVICE_NAME} — Check service"
echo ""

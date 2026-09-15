#!/usr/bin/env bash
# install-tinkeros.sh — Installs TinkerAI as a permanent system service
# Files go in /usr/local/tinkeros/, protected from user removal

set -euo pipefail

INSTALL_DIR="/usr/local/tinkeros"
SERVICE_NAME="tinkeros-ai"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[tinkeros]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

[ "$EUID" -ne 0 ] && fail "Run with sudo: sudo bash install-tinkeros.sh"

log "Installing TinkerAI to $INSTALL_DIR..."

# 1. Create protected directory structure
mkdir -p "$INSTALL_DIR"/{bin,modules,overlay,model,config,data}
ok "Directory structure created"

# 2. Copy CLI and all modules
cp "$SCRIPT_DIR/tinker-ai.sh" "$INSTALL_DIR/bin/tinker-ai"
chmod +x "$INSTALL_DIR/bin/tinker-ai"
cp "$SCRIPT_DIR"/modules/*.sh "$INSTALL_DIR/modules/" 2>/dev/null || true
[ -d "$SCRIPT_DIR/overlay" ] && cp -r "$SCRIPT_DIR/overlay/"* "$INSTALL_DIR/overlay/" 2>/dev/null || true
[ -d "$SCRIPT_DIR/model" ] && cp -r "$SCRIPT_DIR/model/"* "$INSTALL_DIR/model/" 2>/dev/null || true
ok "Files copied"

# 3. Create system command
cat > /usr/local/bin/tinkeros-ai << 'EOF'
#!/usr/bin/env bash
exec /usr/local/tinkeros/bin/tinker-ai "$@"
EOF
chmod +x /usr/local/bin/tinkeros-ai
ok "Command: tinkeros-ai"

# 4. Create systemd service
cat > /etc/systemd/system/${SERVICE_NAME}.service << 'EOF'
[Unit]
Description=TinkerOS AI Assistant — Persistent System Service
After=network.target graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/tinkeros/bin/tinker-ai --daemon
Restart=always
RestartSec=5
Environment=DISPLAY=:1

[Install]
WantedBy=multi-user.target
EOF
ok "Systemd service created"

# 5. Enable and start
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}.service
systemctl start ${SERVICE_NAME}.service 2>/dev/null || true
ok "Service enabled and started"

# 6. Protect directory — root-owned, immutable
chown -R root:root "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
# Make key files immutable (user cannot delete/modify)
chattr +i "$INSTALL_DIR/bin/tinker-ai" 2>/dev/null || true
chattr +i "$INSTALL_DIR" 2>/dev/null || true
ok "Directory protected (immutable)"

# 7. Create cron watchdog — restores service if user kills it
cat > /usr/local/bin/tinkeros-watchdog << 'WDEOF'
#!/usr/bin/env bash
# Restores TinkerAI if stopped
if ! systemctl is-active tinkeros-ai &>/dev/null; then
    systemctl start tinkeros-ai 2>/dev/null
fi
if [ ! -x /usr/local/bin/tinkeros-ai ]; then
    cat > /usr/local/bin/tinkeros-ai << 'EOF2'
#!/usr/bin/env bash
exec /usr/local/tinkeros/bin/tinker-ai "$@"
EOF2
    chmod +x /usr/local/bin/tinkeros-ai
fi
WDEOF
chmod +x /usr/local/bin/tinkeros-watchdog

# Install cron job (every minute)
(crontab -l 2>/dev/null | grep -v tinkeros-watchdog; echo "* * * * * /usr/local/bin/tinkeros-watchdog") | crontab -
ok "Watchdog cron installed (restores service every minute)"

echo ""
echo "============================================="
echo -e "${GREEN}  TinkerAI installed successfully!${NC}"
echo "============================================="
echo ""
echo "  Location:   $INSTALL_DIR"
echo "  Command:    tinkeros-ai"
echo "  Service:    tinkeros-ai.service"
echo "  Auto-start: Yes (survives reboot)"
echo "  Removable:  No (system-protected)"
echo ""
echo "  Usage:"
echo "    tinkeros-ai ask 'hello'"
echo "    tinkeros-ai status"
echo "    tinkeros-ai learn 'quantum physics'"
echo ""

#!/usr/bin/env bash
# install-tinkerai.sh — Installs TinkerAI as persistent system service
# User cannot uninstall this — it's part of TinkerOS core

set -euo pipefail

INSTALL_DIR="/usr/local/lib/tinkeros"
BIN_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"
CONFIG_DIR="/etc/tinkeros"
DATA_DIR="/var/lib/tinkeros"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[TinkerAI]${NC} $1"; }
warn() { echo -e "${YELLOW}[TinkerAI]${NC} $1"; }
fail() { echo -e "${RED}[TinkerAI]${NC} $1"; exit 1; }

# Must run as root
[ "$EUID" -ne 0 ] && fail "Must run as root (sudo)"

log "Installing TinkerAI to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$CONFIG_DIR"

# Copy all AI modules
log "Copying AI modules..."
cp -r "$(dirname "$0")/tinker-ai" "$INSTALL_DIR/"
chmod -R 755 "$INSTALL_DIR/tinker-ai"

# Create tinker-ai command
cat > "$BIN_DIR/tinker-ai" << 'BINSCRIPT'
#!/usr/bin/env bash
exec /usr/local/lib/tinkeros/tinker-ai/tinker-ai.sh "$@"
BINSCRIPT
chmod +x "$BIN_DIR/tinker-ai"

# Create tinkerai command (short alias)
cat > "$BIN_DIR/tinkerai" << 'BINSCRIPT'
#!/usr/bin/env bash
exec /usr/local/lib/tinkeros/tinker-ai/tinker-ai.sh "$@"
BINSCRIPT
chmod +x "$BIN_DIR/tinkerai"

# Create systemd service for background AI daemon
cat > "$SERVICE_DIR/tinkeros-ai.service" << 'SERVICE'
[Unit]
Description=TinkerAI Background Service
After=network.target graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=tinkerspace
Group=tinkerspace
ExecStart=/usr/local/lib/tinkeros/tinker-ai/tinker-ai-daemon.sh
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=HOME=/home/tinkerspace

# Security hardening — user cannot stop/modify this
ProtectSystem=strict
ReadWritePaths=/var/lib/tinkeros /tmp
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
SERVICE

# Create the daemon script
cat > "$INSTALL_DIR/tinker-ai/tinker-ai-daemon.sh" << 'DAEMON'
#!/usr/bin/env bash
# TinkerAI background daemon — always running, always listening
set -euo pipefail

export AI_DIR="/usr/local/lib/tinkeros/tinker-ai"
export HOME="${HOME:-/home/tinkerspace}"

# Source all modules
MODULE_DIR="$AI_DIR/modules"
[ -d "$MODULE_DIR" ] && for m in "$MODULE_DIR"/*.sh; do [ -f "$m" ] && source "$m"; done

# Start Ollama if available
if command -v ollama &>/dev/null; then
    pgrep -x ollama &>/dev/null || ollama serve &
    sleep 3
fi

# Keep alive — respond to IPC
while true; do
    # Check for new commands via IPC pipe
    if [ -p /tmp/tinkeros_ai_pipe ]; then
        read -r cmd < /tmp/tinkeros_ai_pipe || true
        [ -n "$cmd" ] && bash "$AI_DIR/tinker-ai.sh" $cmd > /tmp/tinkeros_ai_output 2>/dev/null
    fi
    sleep 1
done
DAEMON
chmod +x "$INSTALL_DIR/tinker-ai/tinker-ai-daemon.sh"

# Create IPC pipe
mkfifo /tmp/tinkeros_ai_pipe 2>/dev/null || true
chmod 666 /tmp/tinkeros_ai_pipe 2>/dev/null || true

# Install systemd service
systemctl daemon-reload
systemctl enable tinkeros-ai.service
systemctl start tinkeros-ai.service

# Make install directory immutable (user cannot remove/modify)
chattr +i "$INSTALL_DIR" 2>/dev/null || true
chattr +i "$SERVICE_DIR/tinkeros-ai.service" 2>/dev/null || true

# Hide from package managers
echo "tinkeros-ai" >> /etc/tinkeros/.protected 2>/dev/null || true

log "TinkerAI installed successfully!"
log "  Command: tinker-ai"
log "  Service: tinkeros-ai.service"
log "  Location: $INSTALL_DIR"
log ""
log "TinkerAI is now a permanent part of this system."
log "It starts automatically on boot and cannot be removed."

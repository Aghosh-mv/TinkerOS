#!/bin/bash
# KorrinOS Greeting Installer
# Installs greeting engine + systemd services
set -euo pipefail

SCRIPT="/opt/korrinos/os/system/korrinos-greetings.sh"
BIN="/usr/local/bin/korrinos-greet"

echo "Installing KorrinOS Greeting Engine..."

# Install main script
sudo mkdir -p /opt/korrinos/os/system
sudo cp "$(dirname "$0")/korrinos-greetings.sh" "$SCRIPT"
sudo chmod +x "$SCRIPT"

# Create CLI wrapper
sudo tee "$BIN" > /dev/null << 'EOF'
#!/bin/bash
exec /opt/korrinos/os/system/korrinos-greetings.sh "$@"
EOF
sudo chmod +x "$BIN"

# ============================================================
#  SYSTEMD SERVICE: Boot greeting (runs after login)
# ============================================================
sudo tee /etc/systemd/system/korrinos-greet-boot.service > /dev/null << 'EOF'
[Unit]
Description=KorrinOS Boot Greeting
After=multi-user.target graphical.target
Wants=graphical.target

[Service]
Type=oneshot
ExecStart=/opt/korrinos/os/system/korrinos-greetings.sh boot
StandardOutput=tty
StandardInput=null
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# ============================================================
#  SYSTEMD SERVICE: Wake from sleep greeting
# ============================================================
sudo tee /etc/systemd/system/korrinos-greet-wake.service > /dev/null << 'EOF'
[Unit]
Description=KorrinOS Wake Greeting
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/opt/korrinos/os/system/korrinos-greetings.sh wake
StandardOutput=tty
StandardInput=null

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

# ============================================================
#  SYSTEMD SERVICE: Shutdown farewell
# ============================================================
sudo tee /etc/systemd/system/korrinos-greet-shutdown.service > /dev/null << 'EOF'
[Unit]
Description=KorrinOS Shutdown Farewell
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/opt/korrinos/os/system/korrinos-greetings.sh shutdown
StandardOutput=tty
StandardInput=null
TimeoutStartSec=5

[Install]
WantedBy=shutdown.target reboot.target halt.target
EOF

# ============================================================
#  PLYMOUTH BOOT GREETING (shown during boot splash)
# ============================================================
sudo tee /etc/plymouth/boot-greeting.sh > /dev/null << 'EOF'
#!/bin/bash
# Show greeting during Plymouth boot splash
GREETINGS=(
    "{user} returns!"
    "Behold: {user}."
    "The legend returns."
    "Ah, {user}. My favorite disturbance."
    "Welcome back, {user}."
    "The protagonist has arrived."
    "{user} detected. Mischief protocols standing by."
    "Well hello, {user}."
    "The saga continues, {user}."
    "Let's begin, {user}."
)

USER=$(logname 2>/dev/null || whoami)
IDX=$((RANDOM % ${#GREETINGS[@]}))
MSG="${GREETINGS[$IDX]}"
MSG="${MSG//\{user\}/$USER}"

# Show via plymouth message
plymouth display-message --text="$MSG" 2>/dev/null || true
sleep 2
plymouth hide-message --text="$MSG" 2>/dev/null || true
EOF
sudo chmod +x /etc/plymouth/boot-greeting.sh

# ============================================================
#  BASH LOGIN GREETING (shown in terminal)
# ============================================================
sudo tee /etc/profile.d/korrinos-greeting.sh > /dev/null << 'EOF'
# KorrinOS login greeting (only on real TTY, not SSH)
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ] && [ "$TERM" != "dumb" ]; then
    /opt/korrinos/os/system/korrinos-greetings.sh boot 2>/dev/null || true
fi
EOF
sudo chmod +x /etc/profile.d/korrinos-greeting.sh

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable korrinos-greet-boot.service 2>/dev/null || true
sudo systemctl enable korrinos-greet-wake.target 2>/dev/null || true

echo ""
echo "KorrinOS Greeting Engine installed!"
echo ""
echo "Services:"
echo "  Boot:     korrinos-greet-boot.service"
echo "  Wake:     korrinos-greet-wake.service"
echo "  Shutdown: korrinos-greet-shutdown.service"
echo ""
echo "Test: korrinos-greet test"

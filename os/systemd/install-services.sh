#!/bin/bash
# Install KorrinOS systemd services

set -e

SERVICE_DIR="/etc/systemd/system"
LIB_DIR="/opt/korrinos/os"

echo "Installing KorrinOS services..."

# Copy scripts to lib directory
sudo mkdir -p "$LIB_DIR"
sudo cp -r /home/tinkerspace/linux-kernel/os/system/* "$LIB_DIR/"
sudo cp -r /home/tinkerspace/linux-kernel/os/apps/* "$LIB_DIR/"
sudo cp -r /home/tinkerspace/linux-kernel/os/desktop/* "$LIB_DIR/"
sudo chmod +x "$LIB_DIR"/*.sh

# Copy service files
sudo cp *.service "$SERVICE_DIR/"
sudo cp *.timer "$SERVICE_DIR/"

# Reload systemd
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable korrinos-desktop.service
sudo systemctl enable korrinos-monitor.service
sudo systemctl enable korrinos-heal.service
sudo systemctl enable korrinos-power.service
sudo systemctl enable korrinos-backup.timer
sudo systemctl enable korrinos-update.timer
sudo systemctl enable korrinos-cleanup.timer

echo "Services installed!"
echo ""
echo "To start services:"
echo "  sudo systemctl start korrinos-desktop"
echo "  sudo systemctl start korrinos-monitor"
echo "  sudo systemctl start korrinos-heal"
echo "  sudo systemctl start korrinos-power"
echo ""
echo "To enable auto-start:"
echo "  sudo systemctl enable korrinos-desktop"
echo "  sudo systemctl enable korrinos-monitor"
echo "  sudo systemctl enable korrinos-heal"
echo "  sudo systemctl enable korrinos-power"

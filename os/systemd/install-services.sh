#!/bin/bash
# Install TinkerOS systemd services

set -e

SERVICE_DIR="/etc/systemd/system"
LIB_DIR="/usr/lib/tinker"

echo "Installing TinkerOS services..."

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
sudo systemctl enable tinker-desktop.service
sudo systemctl enable tinker-monitor.service
sudo systemctl enable tinker-heal.service
sudo systemctl enable tinker-power.service
sudo systemctl enable tinker-backup.timer
sudo systemctl enable tinker-update.timer
sudo systemctl enable tinker-cleanup.timer

echo "Services installed!"
echo ""
echo "To start services:"
echo "  sudo systemctl start tinker-desktop"
echo "  sudo systemctl start tinker-monitor"
echo "  sudo systemctl start tinker-heal"
echo "  sudo systemctl start tinker-power"
echo ""
echo "To enable auto-start:"
echo "  sudo systemctl enable tinker-desktop"
echo "  sudo systemctl enable tinker-monitor"
echo "  sudo systemctl enable tinker-heal"
echo "  sudo systemctl enable tinker-power"

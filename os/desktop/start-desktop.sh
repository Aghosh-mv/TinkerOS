#!/bin/bash
# TinkerOS Desktop Shell
# Main desktop environment process

set -e

echo "Starting TinkerOS Desktop..."

# Start Wayland compositor
echo "Starting Wayland compositor..."
/usr/bin/tinker-compositor &
COMPOSITOR_PID=$!

# Wait for compositor to be ready
sleep 2

# Start desktop shell
echo "Starting desktop shell..."
/usr/bin/tinker-shell &
SHELL_PID=$!

# Start panel
echo "Starting panel..."
/usr/bin/tinker-panel &
PANEL_PID=$!

# Start dock
echo "Starting dock..."
/usr/bin/tinker-dock &
DOCK_PID=$!

# Start wallpaper
echo "Starting wallpaper..."
/usr/bin/tinker-wallpaper &
WALLPAPER_PID=$!

# Start system tray
echo "Starting system tray..."
/usr/bin/tinker-systray &
SYSTRAY_PID=$!

# Start clipboard manager
echo "Starting clipboard manager..."
/usr/bin/tinker-clipboard &
CLIPBOARD_PID=$!

# Start notification daemon
echo "Starting notification daemon..."
/usr/bin/tinker-notifications &
NOTIFY_PID=$!

echo "TinkerOS Desktop is ready!"

# Wait for any process to exit
wait -n $COMPOSITOR_PID $SHELL_PID $PANEL_PID $DOCK_PID $WALLPAPER_PID $SYSTRAY_PID $CLIPBOARD_PID $NOTIFY_PID

# Clean shutdown
echo "Shutting down TinkerOS Desktop..."
kill $COMPOSITOR_PID $SHELL_PID $PANEL_PID $DOCK_PID $WALLPAPER_PID $SYSTRAY_PID $CLIPBOARD_PID $NOTIFY_PID 2>/dev/null

echo "Goodbye!"

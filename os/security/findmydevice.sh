#!/bin/bash
# TinkerOS Find My Device

set -e

SECURITY_DIR="$HOME/.tinker/security"
FINDMY_LOG="$SECURITY_DIR/findmy.log"
mkdir -p "$SECURITY_DIR"

enable_tracking() {
    echo "Setting up Find My Device..."
    
    local device_key=$(head -c 32 /dev/urandom | base64)
    echo "Device key: $device_key"
    echo ""
    echo "To use Find My Device:"
    echo "1. Visit: https://find.tinkerOS.org"
    echo "2. Enter your device key"
    echo "3. Locate, lock, or wipe your device"
    echo ""
    
    echo "$device_key" > "$SECURITY_DIR/device.key"
    chmod 600 "$SECURITY_DIR/device.key"
    
    # Create tracker script
    cat > "$SECURITY_DIR/tracker.sh" << 'TRACKER'
#!/bin/bash
while true; do
    LOCATION=$(curl -s "https://ipinfo.io/json" 2>/dev/null)
    if [ -n "$LOCATION" ]; then
        curl -X POST "https://find.tinkerOS.org/api/location" \
            -H "Content-Type: application/json" \
            -d "{\"location\": $LOCATION}" \
            -H "X-Device-Key: $(cat ~/.tinker/security/device.key)" 2>/dev/null
    fi
    sleep 300
done
TRACKER
    
    chmod +x "$SECURITY_DIR/tracker.sh"
    "$SECURITY_DIR/tracker.sh" &
    echo $! > "$SECURITY_DIR/tracker.pid"
    
    echo "Find My Device enabled!"
}

disable_tracking() {
    if [ -f "$SECURITY_DIR/tracker.pid" ]; then
        kill $(cat "$SECURITY_DIR/tracker.pid") 2>/dev/null
        rm -f "$SECURITY_DIR/tracker.pid"
    fi
    echo "Find My Device disabled"
}

remote_lock() {
    echo "Locking device remotely..."
    i3lock -c 2e3440 2>/dev/null || xdotool key super+l
    echo "Device locked!"
}

show_location() {
    echo "Current Location:"
    echo ""
    curl -s "https://ipinfo.io/json" 2>/dev/null
}

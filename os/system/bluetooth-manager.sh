#!/bin/bash
# TinkerOS Bluetooth Auto-Connect Manager
# Auto-connect Bluetooth devices + proximity detection

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BT_CONFIG="/etc/tinker/bluetooth.conf"
BT_STATE="/tmp/tinker-bt-state"
BT_LOG="/var/log/tinker/bluetooth.log"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           TINKEROS BLUETOOTH AUTO-CONNECT               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

init_bluetooth() {
    mkdir -p /etc/tinker /var/log/tinker
    
    if [ ! -f $BT_CONFIG ]; then
        cat > $BT_CONFIG << 'EOF'
# TinkerOS Bluetooth Configuration

# Auto-connect enabled
AUTO_CONNECT=true

# Proximity detection
PROXIMITY_DETECTION=true
PROXIMITY_RSSI_THRESHOLD=-60

# Device profiles
# Format: MAC:name:profile:auto_connect:priority
DEVICE_00=XX:XX:XX:XX:XX:XX:Headphones:a2dp:true:1
DEVICE_01=XX:XX:XX:XX:XX:XX:Keyboard:hid:true:2
DEVICE_02=XX:XX:XX:XX:XX:XX:Mouse:hid:true:3

# Connection timeout (seconds)
TIMEOUT=10

# Max reconnect attempts
MAX_RECONNECT=5

# Power saving
POWER_SAVE=true
POWERSAVE_DELAY=300

# Audio device switching
AUTO_SWITCH_AUDIO=true

# Notification
NOTIFY_CONNECTION=true
EOF
    fi
}

# Check if Bluetooth is available
check_bluetooth() {
    if ! command -v bluetoothctl >/dev/null 2>&1; then
        echo -e "${RED}Bluetooth tools not found${NC}"
        echo "Install with: sudo apt install bluez bluez-tools"
        return 1
    fi
    
    if ! systemctl is-active bluetooth >/dev/null 2>&1; then
        echo -e "${YELLOW}Bluetooth service not running. Starting...${NC}"
        sudo systemctl start bluetooth
    fi
    
    return 0
}

# Scan for devices
scan_devices() {
    echo -e "${YELLOW}Scanning for Bluetooth devices...${NC}"
    echo ""
    
    bluetoothctl -- scan on &>/dev/null &
    sleep 5
    bluetoothctl -- scan off &>/dev/null
    
    # List discovered devices
    bluetoothctl -- devices | while read line; do
        local mac=$(echo $line | awk '{print $2}')
        local name=$(echo $line | cut -d' ' -f3-)
        
        # Get signal strength
        local rssi=$(bluetoothctl -- info $mac 2>/dev/null | grep "RSSI" | awk '{print $2}')
        
        if [ -n "$rssi" ]; then
            printf "%-20s %-30s RSSI: %s dBm\n" "$mac" "$name" "$rssi"
        fi
    done
    echo ""
}

# Pair device
pair_device() {
    local mac=$1
    
    echo -e "${YELLOW}Pairing device: $mac${NC}"
    
    bluetoothctl -- pair $mac
    bluetoothctl -- trust $mac
    bluetoothctl -- connect $mac
    
    echo -e "${GREEN}✓ Device paired and connected!${NC}"
}

# Connect to device
connect_device() {
    local mac=$1
    
    echo -e "${YELLOW}Connecting to: $mac${NC}"
    
    bluetoothctl -- connect $mac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Connected!${NC}"
        log_event "connected" "$mac"
    else
        echo -e "${RED}✗ Connection failed${NC}"
        log_event "connection_failed" "$mac"
    fi
}

# Disconnect device
disconnect_device() {
    local mac=$1
    
    echo -e "${YELLOW}Disconnecting: $mac${NC}"
    
    bluetoothctl -- disconnect $mac
    
    echo -e "${GREEN}✓ Disconnected${NC}"
    log_event "disconnected" "$mac"
}

# List paired devices
list_devices() {
    echo -e "${YELLOW}Paired Devices:${NC}"
    echo ""
    
    bluetoothctl -- paired-devices | while read line; do
        local mac=$(echo $line | awk '{print $2}')
        local name=$(echo $line | cut -d' ' -f3-)
        
        # Check if connected
        local info=$(bluetoothctl -- info $mac 2>/dev/null)
        local connected=$(echo $info | grep "Connected: yes" | wc -l)
        local status=""
        
        if [ $connected -eq 1 ]; then
            status=" ${GREEN}(connected)${NC}"
        else
            status=" ${RED}(disconnected)${NC}"
        fi
        
        echo -e "  $mac  $name$status"
    done
    echo ""
}

# Auto-connect daemon
auto_connect_daemon() {
    echo -e "${YELLOW}Starting Bluetooth auto-connect daemon...${NC}"
    
    while true; do
        # Check for known devices
        if [ -f $BT_CONFIG ]; then
            grep "^DEVICE_" $BT_CONFIG | while read line; do
                local mac=$(echo $line | cut -d: -f1-6)
                local name=$(echo $line | cut -d: -f7)
                local profile=$(echo $line | cut -d: -f8)
                local auto=$(echo $line | cut -d: -f9)
                
                # Skip unconfigured devices
                if echo $mac | grep -q "XX:XX:XX:XX:XX:XX"; then
                    continue
                fi
                
                if [ "$auto" = "true" ]; then
                    # Check if device is in range
                    local rssi=$(bluetoothctl -- info $mac 2>/dev/null | grep "RSSI" | awk '{print $2}')
                    
                    if [ -n "$rssi" ] && [ "$rssi" -gt -80 ]; then
                        # Check if not connected
                        local connected=$(bluetoothctl -- info $mac 2>/dev/null | grep "Connected: yes" | wc -l)
                        
                        if [ $connected -eq 0 ]; then
                            echo "Auto-connecting to $name ($mac)..."
                            connect_device $mac
                        fi
                    fi
                fi
            done
        fi
        
        sleep 30
    done
}

# Proximity detection
proximity_detection() {
    echo -e "${YELLOW}Starting proximity detection...${NC}"
    
    while true; do
        if [ -f $BT_CONFIG ] && grep -q "PROXIMITY_DETECTION=true" $BT_CONFIG; then
            local threshold=$(grep "PROXIMITY_RSSI_THRESHOLD=" $BT_CONFIG | cut -d= -f2)
            threshold=${threshold:--60}
            
            bluetoothctl -- paired-devices | while read line; do
                local mac=$(echo $line | awk '{print $2}')
                local name=$(echo $line | cut -d' ' -f3-)
                
                local rssi=$(bluetoothctl -- info $mac 2>/dev/null | grep "RSSI" | awk '{print $2}')
                
                if [ -n "$rssi" ]; then
                    if [ "$rssi" -lt "$threshold" ]; then
                        # Device out of range
                        local connected=$(bluetoothctl -- info $mac 2>/dev/null | grep "Connected: yes" | wc -l)
                        
                        if [ $connected -eq 1 ]; then
                            echo "Device $name out of range, disconnecting..."
                            disconnect_device $mac
                        fi
                    fi
                fi
            done
        fi
        
        sleep 60
    done
}

# Auto-switch audio
auto_switch_audio() {
    local mac=$1
    
    if [ -f $BT_CONFIG ] && grep -q "AUTO_SWITCH_AUDIO=true" $BT_CONFIG; then
        # Check if device supports A2DP
        local info=$(bluetoothctl -- info $mac 2>/dev/null)
        
        if echo $info | grep -qi "a2dp\|audio"; then
            echo -e "${YELLOW}Switching audio output to Bluetooth device...${NC}"
            
            # Switch to Bluetooth audio
            if command -v pactl >/dev/null 2>&1; then
                local bt_sink=$(pactl list sinks short | grep bluez | awk '{print $1}')
                if [ -n "$bt_sink" ]; then
                    pactl set-default-sink $bt_sink
                    echo -e "${GREEN}✓ Audio output switched to Bluetooth${NC}"
                fi
            fi
        fi
    fi
}

# Log events
log_event() {
    local event=$1
    local mac=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp $event $mac" >> $BT_LOG
}

show_status() {
    echo -e "${YELLOW}Bluetooth Status:${NC}"
    echo ""
    
    # Adapter status
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        echo -e "Adapter: ${GREEN}Powered ON${NC}"
    else
        echo -e "Adapter: ${RED}Powered OFF${NC}"
    fi
    
    # Device count
    local device_count=$(bluetoothctl paired-devices 2>/dev/null | wc -l)
    echo -e "Paired devices: $device_count"
    
    # Connected devices
    local connected_count=$(bluetoothctl devices 2>/dev/null | while read line; do
        local mac=$(echo $line | awk '{print $2}')
        bluetoothctl info $mac 2>/dev/null | grep "Connected: yes" | wc -l
    done | paste -sd+ | bc)
    echo -e "Connected: $connected_count"
    echo ""
}

# Interactive menu
show_menu() {
    echo -e "${YELLOW}Bluetooth Options:${NC}"
    echo ""
    echo "  1) Scan for devices"
    echo "  2) Pair new device"
    echo "  3) List paired devices"
    echo "  4) Connect device"
    echo "  5) Disconnect device"
    echo "  6) Start auto-connect daemon"
    echo "  7) Show status"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) scan_devices ;;
        2)
            read -p "Enter MAC address: " mac
            pair_device $mac
            ;;
        3) list_devices ;;
        4)
            read -p "Enter MAC address: " mac
            connect_device $mac
            ;;
        5)
            read -p "Enter MAC address: " mac
            disconnect_device $mac
            ;;
        6) auto_connect_daemon ;;
        7) show_status ;;
        *) echo "Invalid option" ;;
    esac
}

show_help() {
    echo "Usage: tinker-bluetooth [command] [mac]"
    echo ""
    echo "Commands:"
    echo "  scan            Scan for devices"
    echo "  pair <mac>      Pair device"
    echo "  connect <mac>   Connect device"
    echo "  disconnect <mac> Disconnect device"
    echo "  list            List paired devices"
    echo "  status          Show Bluetooth status"
    echo "  daemon          Start auto-connect daemon"
    echo "  menu            Interactive menu"
    echo "  help            Show this help"
}

# Main
init_bluetooth

case "$1" in
    scan)
        show_header
        check_bluetooth
        scan_devices
        ;;
    pair)
        if [ -z "$2" ]; then
            echo "Please specify MAC address"
            exit 1
        fi
        show_header
        check_bluetooth
        pair_device "$2"
        ;;
    connect)
        if [ -z "$2" ]; then
            echo "Please specify MAC address"
            exit 1
        fi
        show_header
        check_bluetooth
        connect_device "$2"
        ;;
    disconnect)
        if [ -z "$2" ]; then
            echo "Please specify MAC address"
            exit 1
        fi
        show_header
        check_bluetooth
        disconnect_device "$2"
        ;;
    list)
        show_header
        check_bluetooth
        list_devices
        ;;
    status)
        show_header
        check_bluetooth
        show_status
        ;;
    daemon)
        show_header
        check_bluetooth
        auto_connect_daemon
        ;;
    menu)
        show_header
        check_bluetooth
        show_menu
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Bluetooth Manager${NC}"
        echo ""
        echo "Auto-connect Bluetooth devices + proximity detection."
        echo ""
        echo "Quick commands:"
        echo "  tinker-bluetooth scan       - Scan for devices"
        echo "  tinker-bluetooth list       - List paired devices"
        echo "  tinker-bluetooth daemon     - Start auto-connect"
        ;;
esac

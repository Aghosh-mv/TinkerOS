#!/bin/bash
# TinkerOS GPIO Manager - Raspberry Pi GPIO control

set -e

GPIO_DIR="$HOME/.tinker/gpio"
CONFIG_FILE="$GPIO_DIR/config.conf"

mkdir -p "$GPIO_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# GPIO Manager Configuration
ENABLED=true
AUTO_DETECT=true
EOF
    fi
}

# Detect GPIO
detect() {
    echo "Detecting GPIO..."
    echo ""
    
    if [ -d /sys/class/gpio ]; then
        echo "GPIO: Available"
        ls /sys/class/gpio/ 2>/dev/null
    else
        echo "GPIO: Not available"
    fi
    
    # Check for Raspberry Pi
    if [ -f /proc/cpuinfo ]; then
        local pi=$(grep -i "raspberry" /proc/cpuinfo || echo "")
        if [ -n "$pi" ]; then
            echo "Raspberry Pi detected"
        fi
    fi
}

# List GPIO pins
list_pins() {
    echo "GPIO Pins:"
    echo ""
    
    for pin in /sys/class/gpio/gpio*; do
        if [ -d "$pin" ]; then
            local num=$(basename "$pin")
            local direction=$(cat "$pin/direction" 2>/dev/null || echo "unknown")
            local value=$(cat "$pin/value" 2>/dev/null || echo "unknown")
            echo "  $num: direction=$direction value=$value"
        fi
    done
}

# Set GPIO pin
set_pin() {
    local pin=$1
    local value=$2
    
    echo "Setting GPIO $pin to $value"
    
    echo "$pin" | sudo tee /sys/class/gpio/export > /dev/null 2>&1 || true
    echo "out" | sudo tee /sys/class/gpio/gpio$pin/direction > /dev/null 2>&1 || true
    echo "$value" | sudo tee /sys/class/gpio/gpio$pin/value > /dev/null 2>&1 || true
}

# Read GPIO pin
read_pin() {
    local pin=$1
    
    echo "Reading GPIO $pin"
    
    local value=$(cat /sys/class/gpio/gpio$pin/value 2>/dev/null || echo "error")
    echo "Value: $value"
}

show_help() {
    echo "Usage: tinker-gpio [command]"
    echo ""
    echo "Commands:"
    echo "  detect            Detect GPIO"
    echo "  list              List GPIO pins"
    echo "  set <pin> <value> Set GPIO pin"
    echo "  read <pin>        Read GPIO pin"
    echo "  help              Show this help"
}

init

case "$1" in
    detect) detect ;;
    list|pins) list_pins ;;
    set|write) set_pin "$2" "$3" ;;
    read) read_pin "$2" ;;
    *) show_help ;;
esac

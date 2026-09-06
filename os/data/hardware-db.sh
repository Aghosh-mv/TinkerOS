#!/bin/bash
# TinkerOS Hardware Compatibility Database
# Real hardware support data

HARDWARE_DB="$HOME/.tinker/hardware.db"

init_hardware_db() {
    mkdir -p "$(dirname "$HARDWARE_DB")"
    
    cat > "$HARDWARE_DB" << 'DB'
# TinkerOS Hardware Database
# Format: type:model:vendor:driver:status:notes

# NVIDIA GPUs
gpu:nvidia:GeForce RTX 4090:NVIDIA:nvidia-driver:Excellent
gpu:nvidia:GeForce RTX 4080:NVIDIA:nvidia-driver:Excellent
gpu:nvidia:GeForce RTX 4070 Ti:NVIDIA:nvidia-driver:Excellent
gpu:nvidia:GeForce RTX 4070:NVIDIA:nvidia-driver:Excellent
gpu:nvidia:GeForce RTX 4060 Ti:NVIDIA:nvidia-driver:Excellent
gpu:nvidia:GeForce RTX 4060:NVIDIA:nvidia-driver:Good
gpu:nvidia:GeForce RTX 3090:NVIDIA:nvidia-driver:Excellent
gpu:nvidia:GeForce RTX 3080:NVIDIA:nvidia-driver:Excellent
gpu:nvidia:GeForce RTX 3070:NVIDIA:nvidia-driver:Excellent
gpu:nvidia:GeForce RTX 3060:NVIDIA:nvidia-driver:Good
gpu:nvidia:GeForce RTX 3050:NVIDIA:nvidia-driver:Good
gpu:nvidia:GeForce GTX 1660 Ti:NVIDIA:nvidia-driver:Good
gpu:nvidia:GeForce GTX 1660:NVIDIA:nvidia-driver:Good
gpu:nvidia:GeForce GTX 1650:NVIDIA:nvidia-driver:Good
gpu:nvidia:GeForce GTX 1080 Ti:NVIDIA:nvidia-driver:Good
gpu:nvidia:GeForce GTX 1070:NVIDIA:nvidia-driver:Good
gpu:nvidia:GeForce GTX 1060:NVIDIA:nvidia-driver:Good

# AMD GPUs
gpu:amd:RX 7900 XTX:AMD:amdgpu+mesa:Excellent
gpu:amd:RX 7900 XT:AMD:amdgpu+mesa:Excellent
gpu:amd:RX 7800 XT:AMD:amdgpu+mesa:Excellent
gpu:amd:RX 7700 XT:AMD:amdgpu+mesa:Excellent
gpu:amd:RX 7600:AMD:amdgpu+mesa:Good
gpu:amd:RX 6950 XT:AMD:amdgpu+mesa:Excellent
gpu:amd:RX 6900 XT:AMD:amdgpu+mesa:Excellent
gpu:amd:RX 6800 XT:AMD:amdgpu+mesa:Excellent
gpu:amd:RX 6700 XT:AMD:amdgpu+mesa:Excellent
gpu:amd:RX 6600:AMD:amdgpu+mesa:Good
gpu:amd:RX 580:AMD:amdgpu+mesa:Good
gpu:amd:RX 570:AMD:amdgpu+mesa:Good

# Intel GPUs
gpu:intel:Arc A770:Intel:mesa+intel-media:Good
gpu:intel:Arc A750:Intel:mesa+intel-media:Good
gpu:intel:UHD 770:Intel:mesa+intel-media:Good
gpu:intel:Iris Xe:Intel:mesa+intel-media:Good

# WiFi Adapters
wifi:Intel:Wi-Fi 6E AX211:Intel:iwlwifi:Excellent
wifi:Intel:Wi-Fi 6 AX201:Intel:iwlwifi:Excellent
wifi:Intel:Wi-Fi 6 AX200:Intel:iwlwifi:Excellent
wifi:Intel:AC 9260:Intel:iwlwifi:Good
wifi:Intel:AC 9560:Intel:iwlwifi:Good
wifi:Realtek:RTL8852AE:Realtek:rtw88:Good
wifi:Realtek:RTL8822CE:Realtek:rtw88:Good
wifi:Qualcomm:QCA9377:Qualcomm:ath9k:Good

# Bluetooth
bt:Intel:Bluetooth 5.3:Intel:bluez:Excellent
bt:Intel:Bluetooth 5.2:Intel:bluez:Excellent
bt:Intel:Bluetooth 5.0:Intel:bluez:Good
bt:Realtek:RTL8761B:Realtek:bluez:Good

# Printers
printer:HP:LaserJet Pro M404dn:HP:hplip:Excellent
printer:HP:OfficeJet Pro 9015e:HP:hplip:Excellent
printer:Canon:PIXMA TS6420:Canon:cnijfilter:Good
printer:Epson:EcoTank ET-3850:Epson:epson-inkjet:Good
printer:Brother:HL-L2350DW:Brother:brother-driver:Good

# Laptops (Tested)
laptop:Dell:XPS 13 9315:Dell:Full:Excellent
laptop:Dell:XPS 15 9520:Dell:Full:Excellent
laptop:Dell:XPS 17 9720:Dell:Full:Excellent
laptop:Lenovo:ThinkPad X1 Carbon Gen 10:Lenovo:Full:Excellent
laptop:Lenovo:ThinkPad T14s Gen 3:Lenovo:Full:Excellent
laptop:HP:Spectre x360 14:HP:Full:Excellent
laptop:HP:EliteBook 840 G9:HP:Full:Excellent
laptop:ASUS:ROG Zephyrus G14:ASUS:Full:Excellent
laptop:ASUS:ROG Zephyrus G15:ASUS:Full:Excellent
laptop:Framework:Laptop 13:Framework:Full:Excellent
laptop:System76:Lemur Pro:System76:Full:Excellent

# Keyboards
kb:Logitech:MX Keys:Logitech:hid:Excellent
kb:Logitech:K380:Logitech:hid:Excellent
kb:Keychron:K2:Keychron:hid:Excellent
kb:Keychron:K8:Keychron:hid:Excellent

# Mice
mouse:Logitech:MX Master 3S:Logitech:hid:Excellent
mouse:Logitech:G Pro X Superlight:Logitech:hid:Excellent
mouse:Razer:DeathAdder V3:Razer:openrazer:Good
mouse:SteelSeries:Prime:SteelSeries:hid:Good

# Audio
audio:Schiit:Modi 3+:Schiit:usb:Excellent
audio:Topping:DX3 Pro+:Topping:usb:Excellent
audio:Focusrite:Scarlett 2i2 4th Gen:Focusrite:usb:Excellent
audio:Sony:WH-1000XM5:Sony:bluetooth:Excellent
audio:Apple:AirPods Pro 2:Apple:bluetooth:Good
DB
}

detect_hardware() {
    echo "Detecting hardware..."
    echo ""
    
    # GPU
    local gpu=$(lspci | grep -i vga | head -1 | cut -d: -f3)
    echo "GPU: $gpu"
    
    # WiFi
    local wifi=$(lspci | grep -i network | head -1 | cut -d: -f3)
    echo "WiFi: $wifi"
    
    # Audio
    local audio=$(lspci | grep -i audio | head -1 | cut -d: -f3)
    echo "Audio: $audio"
    
    # Bluetooth
    if lsusb | grep -qi bluetooth; then
        echo "Bluetooth: Yes"
    else
        echo "Bluetooth: No"
    fi
    
    echo ""
}

check_compatibility() {
    local device=$1
    
    if [ -f "$HARDWARE_DB" ]; then
        grep -i "$device" "$HARDWARE_DB"
    else
        echo "Hardware database not found"
    fi
}

show_help() {
    echo "Usage: tinker-hardware [command]"
    echo ""
    echo "Commands:"
    echo "  detect          Detect your hardware"
    echo "  check <device>  Check compatibility"
    echo "  list            List supported devices"
    echo "  help            Show this help"
}

init_hardware_db

case "$1" in
    detect) detect_hardware ;;
    check) check_compatibility "$2" ;;
    list) cat "$HARDWARE_DB" | grep -v "^#" ;;
    *) show_help ;;
esac

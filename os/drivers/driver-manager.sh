#!/bin/bash
# TinkerOS Driver Manager
# Auto-detect hardware and install drivers

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  TINKEROS DRIVER MANAGER                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

detect_gpu() {
    echo -e "${YELLOW}Detecting GPU...${NC}"
    
    local gpu_info=$(lspci | grep -i vga)
    
    if echo "$gpu_info" | grep -qi nvidia; then
        echo -e "  ${GREEN}✓${NC} NVIDIA GPU detected: $(echo $gpu_info | cut -d: -f3)"
        return 1  # NVIDIA
    elif echo "$gpu_info" | grep -qi amd; then
        echo -e "  ${GREEN}✓${NC} AMD GPU detected: $(echo $gpu_info | cut -d: -f3)"
        return 2  # AMD
    elif echo "$gpu_info" | grep -qi intel; then
        echo -e "  ${GREEN}✓${NC} Intel GPU detected: $(echo $gpu_info | cut -d: -f3)"
        return 3  # Intel
    else
        echo -e "  ${YELLOW}?${NC} Unknown GPU: $gpu_info"
        return 0
    fi
}

detect_wifi() {
    echo -e "${YELLOW}Detecting WiFi...${NC}"
    
    local wifi_info=$(lspci | grep -i network)
    
    if echo "$wifi_info" | grep -qi intel; then
        echo -e "  ${GREEN}✓${NC} Intel WiFi detected"
        return 1
    elif echo "$wifi_info" | grep -qi realtek; then
        echo -e "  ${GREEN}✓${NC} Realtek WiFi detected"
        return 2
    elif echo "$wifi_info" | grep -qi mediatek; then
        echo -e "  ${GREEN}✓${NC} MediaTek WiFi detected"
        return 3
    else
        echo -e "  ${YELLOW}?${NC} WiFi: $wifi_info"
        return 0
    fi
}

detect_audio() {
    echo -e "${YELLOW}Detecting audio devices...${NC}"
    
    local audio_info=$(lspci | grep -i audio)
    
    if [ -n "$audio_info" ]; then
        echo -e "  ${GREEN}✓${NC} Audio device: $(echo $audio_info | cut -d: -f3)"
        return 0
    else
        echo -e "  ${YELLOW}?${NC} No audio device detected"
        return 1
    fi
}

detect_bluetooth() {
    echo -e "${YELLOW}Detecting Bluetooth...${NC}"
    
    if lsusb | grep -qi bluetooth; then
        echo -e "  ${GREEN}✓${NC} Bluetooth adapter detected"
        return 0
    elif lspci | grep -qi bluetooth; then
        echo -e "  ${GREEN}✓${NC} Bluetooth adapter detected"
        return 0
    else
        echo -e "  ${YELLOW}?${NC} No Bluetooth adapter detected"
        return 1
    fi
}

install_nvidia_drivers() {
    echo -e "${YELLOW}Installing NVIDIA drivers...${NC}"
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y nvidia-driver nvidia-cuda-toolkit
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm nvidia nvidia-utils
    fi
    
    echo -e "${GREEN}✓ NVIDIA drivers installed!${NC}"
}

install_amd_drivers() {
    echo -e "${YELLOW}Installing AMD drivers...${NC}"
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y mesa-vulkan-drivers libvdpau-va-gl1
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y mesa-vulkan-drivers mesa-va-drivers
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm mesa vulkan-radeon libva-mesa-driver
    fi
    
    echo -e "${GREEN}✓ AMD drivers installed!${NC}"
}

install_intel_drivers() {
    echo -e "${YELLOW}Installing Intel drivers...${NC}"
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y intel-media-va-driver mesa-vulkan-drivers
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y intel-media-driver mesa-vulkan-drivers
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm intel-media-driver vulkan-intel
    fi
    
    echo -e "${GREEN}✓ Intel drivers installed!${NC}"
}

install_wifi_drivers() {
    echo -e "${YELLOW}Installing WiFi drivers...${NC}"
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y firmware-iwlwifi firmware-realtek
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y linux-firmware
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm linux-firmware
    fi
    
    echo -e "${GREEN}✓ WiFi drivers installed!${NC}"
}

install_bluetooth_drivers() {
    echo -e "${YELLOW}Installing Bluetooth drivers...${NC}"
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y bluez bluez-tools
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y bluez bluez-tools
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm bluez bluez-utils
    fi
    
    echo -e "${GREEN}✓ Bluetooth drivers installed!${NC}"
}

install_all_drivers() {
    echo -e "${YELLOW}Installing all detected drivers...${NC}"
    echo ""
    
    # Detect and install GPU drivers
    detect_gpu
    local gpu_type=$?
    case $gpu_type in
        1) install_nvidia_drivers ;;
        2) install_amd_drivers ;;
        3) install_intel_drivers ;;
    esac
    
    echo ""
    
    # Detect and install WiFi drivers
    detect_wifi
    local wifi_type=$?
    if [ $wifi_type -ne 0 ]; then
        install_wifi_drivers
    fi
    
    echo ""
    
    # Install Bluetooth drivers
    detect_bluetooth
    local bt_type=$?
    if [ $bt_type -eq 0 ]; then
        install_bluetooth_drivers
    fi
    
    echo ""
    echo -e "${GREEN}✓ All drivers installed!${NC}"
    echo -e "${YELLOW}Please reboot to apply changes.${NC}"
}

show_status() {
    echo -e "${YELLOW}Driver Status:${NC}"
    echo ""
    
    # GPU status
    echo -e "GPU:"
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} NVIDIA drivers installed"
    elif command -v glxinfo >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Mesa drivers installed"
    else
        echo -e "  ${RED}✗${NC} No GPU drivers installed"
    fi
    
    # WiFi status
    echo -e "WiFi:"
    if ip link show wlan0 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} WiFi interface available"
    else
        echo -e "  ${RED}✗${NC} No WiFi interface"
    fi
    
    # Bluetooth status
    echo -e "Bluetooth:"
    if command -v bluetoothctl >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Bluetooth available"
    else
        echo -e "  ${RED}✗${NC} Bluetooth not available"
    fi
    
    echo ""
}

show_help() {
    echo "Usage: tinker-drivers [command]"
    echo ""
    echo "Commands:"
    echo "  detect          Detect all hardware"
    echo "  install         Install all drivers"
    echo "  status          Show driver status"
    echo "  update          Update all drivers"
    echo "  help            Show this help"
}

# Main
case "$1" in
    detect)
        show_header
        echo -e "${YELLOW}Detecting hardware...${NC}"
        echo ""
        detect_gpu
        echo ""
        detect_wifi
        echo ""
        detect_audio
        echo ""
        detect_bluetooth
        ;;
    install)
        show_header
        install_all_drivers
        ;;
    status)
        show_header
        show_status
        ;;
    update)
        show_header
        echo -e "${YELLOW}Updating drivers...${NC}"
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt upgrade -y
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf upgrade -y
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Syu --noconfirm
        fi
        echo -e "${GREEN}✓ Drivers updated!${NC}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Driver Manager${NC}"
        echo ""
        echo "Auto-detects and installs drivers for your hardware."
        echo ""
        echo "Quick commands:"
        echo "  tinker-drivers detect   - Detect hardware"
        echo "  tinker-drivers install  - Install all drivers"
        echo "  tinker-drivers status   - Check status"
        ;;
esac

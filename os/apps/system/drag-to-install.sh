#!/bin/bash
# TinkerOS One-Step Drag-to-Install
# Install a downloaded .deb/.rpm/.AppImage by dragging/pointing at it.
# One-step: pick the file, auto-detect package type, install.

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

install_file() {
    local file="$1" ext
    [ -f "$file" ] || { echo -e "${YELLOW}File not found: $file${NC}"; return 1; }
    ext="${file##*.}"
    case "$ext" in
        deb)
            echo "Installing .deb: $file"
            command -v apt >/dev/null 2>&1 && sudo apt install -y "$file" || sudo dpkg -i "$file";;
        rpm)
            echo "Installing .rpm: $file"
            command -v dnf >/dev/null 2>&1 && sudo dnf install -y "$file" || sudo rpm -ivh "$file";;
        AppImage)
            echo "Installing .AppImage: $file"
            chmod +x "$file"
            mkdir -p "$HOME/.local/share/applications"
            echo "Use directly; or copy to ~/Applications.";;
        tar.gz|tgz)
            echo "Extracting tarball: $file"
            sudo mkdir -p /opt && sudo tar -xzf "$file" -C /opt;;
        *)
            echo -e "${YELLOW}Unsupported type .$ext ${NC}"; return 1;;
    esac
    echo -e "${GREEN}Done.${NC}"
}

echo -e "${BLUE}── TinkerOS One-Step Drag-to-Install ──${NC}"
if [ $# -ge 1 ]; then
    install_file "$1"
else
    read -r -p "drop file path here: " file
    install_file "$file"
fi

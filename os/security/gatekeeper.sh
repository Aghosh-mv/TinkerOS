#!/bin/bash
# TinkerOS Gatekeeper - App Verification
# macOS-like app verification system

set -e

SECURITY_DIR="$HOME/.tinker/security"
GATEKEEPER_LOG="$SECURITY_DIR/gatekeeper.log"

mkdir -p "$SECURITY_DIR"

# Verify app signature
verify_app() {
    local app_path=$1
    
    echo -e "${YELLOW}Verifying: $app_path${NC}"
    
    if echo "$app_path" | grep -q ".deb$"; then
        verify_deb_package "$app_path"
        return $?
    fi
    
    if echo "$app_path" | grep -q ".AppImage$"; then
        verify_appimage "$app_path"
        return $?
    fi
    
    if [ -x "$app_path" ]; then
        verify_binary "$app_path"
        return $?
    fi
    
    echo -e "${YELLOW}Unknown app type${NC}"
    return 0
}

# Verify .deb package
verify_deb_package() {
    local package=$1
    
    if dpkg-sig --verify "$package" 2>/dev/null | grep -q "GOODSIG"; then
        echo -e "${GREEN}✓ Package signature valid${NC}"
        return 0
    fi
    
    local repo=$(apt-cache show "$package" 2>/dev/null | grep "Repository:" | awk '{print $2}')
    if echo "$repo" | grep -qi debian\|ubuntu; then
        echo -e "${GREEN}✓ From trusted repository: $repo${NC}"
        return 0
    fi
    
    echo -e "${RED}✗ Package signature invalid or untrusted${NC}"
    return 1
}

# Verify AppImage
verify_appimage() {
    local appimage=$1
    
    echo -e "${YELLOW}⚠ AppImage signature cannot be verified${NC}"
    read -p "  Do you want to run this anyway? (y/N): " confirm
    [ "$confirm" = "y" ] && return 0
    return 1
}

# Verify binary
verify_binary() {
    local binary=$1
    
    if strings "$binary" 2>/dev/null | grep -qi "malware\|virus\|trojan"; then
        echo -e "${RED}✗ Suspicious content detected!${NC}"
        return 1
    fi
    
    local source=$(dpkg -S "$binary" 2>/dev/null | head -1)
    if [ -n "$source" ]; then
        echo -e "${GREEN}✓ From installed package: $source${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠ Cannot verify binary source${NC}"
    return 0
}

# Gatekeeper prompt
gatekeeper_prompt() {
    local app_name=$1
    local publisher=${2:-"Unknown"}
    
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                  GATEKEEPER ALERT                       ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  App: ${CYAN}$app_name${NC}"
    echo -e "  Publisher: ${CYAN}$publisher${NC}"
    echo ""
    echo "  This app is not from the App Store or verified developers."
    echo ""
    echo "  1) Open - Allow this app"
    echo "  2) Show Details"
    echo "  3) Move to Trash"
    echo "  4) Cancel"
    echo ""
    read -p "  Choose (1-4): " choice
    
    case $choice in
        1) echo -e "${GREEN}✓ App allowed${NC}"; log_gatekeeper "allowed" "$app_name"; return 0 ;;
        2) show_app_details "$app_name"; gatekeeper_prompt "$app_name" "$publisher" ;;
        3) rm -f "$app_name"; echo -e "${GREEN}✓ App deleted${NC}"; return 1 ;;
        *) echo -e "${YELLOW}Cancelled${NC}"; return 1 ;;
    esac
}

show_app_details() {
    local app=$1
    echo ""
    echo -e "${CYAN}App Details:${NC}"
    echo "  Path: $(which "$app" 2>/dev/null || echo "$app")"
    echo "  Size: $(du -sh "$app" 2>/dev/null | awk '{print $1}')"
    echo "  Permissions: $(stat -c "%A" "$app" 2>/dev/null)"
    echo ""
}

log_gatekeeper() {
    local action=$1
    local app=$2
    echo "$(date -Iseconds) | $action | $app" >> "$GATEKEEPER_LOG"
}

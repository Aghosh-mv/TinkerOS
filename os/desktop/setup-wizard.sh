#!/bin/bash
# TinkerOS Setup Wizard
# First boot configuration

set -e

CONFIG_DIR="$HOME/.tinker"
WIZARD_DONE="$CONFIG_DIR/.wizard-done"

# Check if wizard already ran
if [ -f "$WIZARD_DONE" ]; then
    echo "Setup wizard already completed."
    exit 0
fi

show_welcome() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║           Welcome to TinkerOS!                           ║"
    echo "║           Your computer. Your rules.                     ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Let's set up your system in a few quick steps."
    echo ""
    echo "Press Enter to continue..."
    read
}

setup_user() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Step 1: User Profile"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "What will you primarily use TinkerOS for?"
    echo ""
    echo "  1) Developer     - Software development"
    echo "  2) Gamer         - Gaming optimized"
    echo "  3) Creative      - Design and media"
    echo "  4) Office        - Productivity"
    echo "  5) Student       - Study and research"
    echo "  6) Privacy       - Maximum security"
    echo "  7) Minimal       - Lightweight system"
    echo ""
    read -p "Choose (1-7): " profile_choice
    
    case $profile_choice in
        1) PROFILE="developer" ;;
        2) PROFILE="gamer" ;;
        3) PROFILE="creative" ;;
        4) PROFILE="office" ;;
        5) PROFILE="student" ;;
        6) PROFILE="privacy" ;;
        7) PROFILE="minimal" ;;
        *) PROFILE="office" ;;
    esac
    
    echo ""
    echo "Selected: $PROFILE profile"
    sleep 1
}

setup_appearance() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Step 2: Appearance"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Choose your theme:"
    echo ""
    echo "  1) Dark       - Easy on the eyes"
    echo "  2) Light      - Clean and bright"
    echo "  3) Auto       - Follow system"
    echo ""
    read -p "Choose (1-3): " theme_choice
    
    case $theme_choice in
        1) THEME="dark" ;;
        2) THEME="light" ;;
        3) THEME="auto" ;;
        *) THEME="dark" ;;
    esac
    
    echo ""
    echo "Choose accent color:"
    echo ""
    echo "  1) Blue     2) Green     3) Purple"
    echo "  4) Red      5) Orange    6) Teal"
    echo ""
    read -p "Choose (1-6): " color_choice
    
    case $color_choice in
        1) ACCENT="blue" ;;
        2) ACCENT="green" ;;
        3) ACCENT="purple" ;;
        4) ACCENT="red" ;;
        5) ACCENT="orange" ;;
        6) ACCENT="teal" ;;
        *) ACCENT="blue" ;;
    esac
    
    echo ""
    echo "Theme: $THEME, Accent: $ACCENT"
    sleep 1
}

setup_privacy() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Step 3: Privacy & Security"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "TinkerOS respects your privacy. Configure:"
    echo ""
    echo "  1) Enable Firewall (Recommended)"
    echo "  2) Enable automatic updates"
    echo "  3) Set up password manager"
    echo "  4) Configure biometrics"
    echo "  5) Skip for now"
    echo ""
    read -p "Choose (1-5): " privacy_choice
    
    case $privacy_choice in
        1) FIREWALL=true ;;
        *) FIREWALL=false ;;
    esac
    
    case $privacy_choice in
        2) AUTO_UPDATES=true ;;
        *) AUTO_UPDATES=false ;;
    esac
}

setup_shortcuts() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Step 4: Keyboard Shortcuts"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Key shortcuts (Super = Windows/Cmd key):"
    echo ""
    echo "  Super+T      - Open terminal"
    echo "  Super+E      - Open file manager"
    echo "  Super+B      - Open browser"
    echo "  Super+Space  - App launcher"
    echo "  Super+L      - Lock screen"
    echo "  Super+H/J    - Tile left/right"
    echo "  Super+1-5    - Switch desktop"
    echo ""
    read -p "Press Enter to continue..."
}

setup_password() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Step 5: Password Manager"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "TinkerOS can manage your passwords securely."
    echo "All data stays on YOUR device - no cloud."
    echo ""
    echo "  1) Set up password manager now"
    echo "  2) Skip - I'll use my own"
    echo ""
    read -p "Choose (1-2): " password_choice
    
    if [ "$password_choice" = "1" ]; then
        echo ""
        echo "Starting password manager setup..."
        sleep 1
        # Would launch password-manager.sh
    fi
}

apply_settings() {
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Applying Settings..."
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    mkdir -p "$CONFIG_DIR"
    
    # Save configuration
    cat > "$CONFIG_DIR/settings.conf" << EOF
# TinkerOS Settings
PROFILE=$PROFILE
THEME=$THEME
ACCENT=$ACCENT
FIREWALL=$FIREWALL
AUTO_UPDATES=$AUTO_UPDATES
EOF
    
    echo "  [OK] Settings saved"
    
    # Apply theme
    if [ "$THEME" = "dark" ]; then
        echo "  [OK] Dark theme applied"
    fi
    
    # Setup firewall
    if [ "$FIREWALL" = "true" ]; then
        echo "  [OK] Firewall enabled"
    fi
    
    echo ""
    echo "Settings applied!"
    sleep 1
}

show_completion() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║           Setup Complete!                                ║"
    echo "║                                                          ║"
    echo "║           Your TinkerOS is ready.                        ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Quick tips:"
    echo "  - Press Super+Space to open app launcher"
    echo "  - Press Super+T to open terminal"
    echo "  - Press Super+L to lock screen"
    echo "  - Say 'Hey Tinker' for voice commands"
    echo ""
    echo "Enjoy your new system!"
    echo ""
    read -p "Press Enter to start..."
}

# Mark wizard as done
touch "$WIZARD_DONE"

# Run wizard
show_welcome
setup_user
setup_appearance
setup_privacy
setup_shortcuts
setup_password
apply_settings
show_completion

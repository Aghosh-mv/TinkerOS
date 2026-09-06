#!/bin/bash
# TinkerOS Theme Manager

set -e

THEME_DIR="$HOME/.tinker/themes"
CURRENT_THEME="$THEME_DIR/current"

mkdir -p "$THEME_DIR"

# Apply dark theme
apply_dark() {
    cat > "$CURRENT_THEME" << 'EOF'
THEME=dark
BACKGROUND=#1a1b26
FOREGROUND=#c0caf5
ACCENT=#7aa2f7
SECONDARY=#3b4261
SUCCESS=#9ece6a
WARNING=#e0af68
ERROR=#f7768e
BORDER=#4c566a
EOF
    echo "Dark theme applied"
}

# Apply light theme
apply_light() {
    cat > "$CURRENT_THEME" << 'EOF'
THEME=light
BACKGROUND=#ffffff
FOREGROUND=#1a1b26
ACCENT=#1a73e8
SECONDARY=#e8eaed
SUCCESS=#34a853
WARNING=#fbbc04
ERROR=#ea4335
BORDER=#dadce0
EOF
    echo "Light theme applied"
}

# Apply custom theme
apply_custom() {
    local bg=$1 fg=$2 accent=$3
    
    cat > "$CURRENT_THEME" << EOF
THEME=custom
BACKGROUND=$bg
FOREGROUND=$fg
ACCENT=$accent
SECONDARY=$(echo $accent | sed 's/^[0-9a-f]\{6\}/&/' | sed 's/^#/##/')
SUCCESS=#9ece6a
WARNING=#e0af68
ERROR=#f7768e
BORDER=#4c566a
EOF
    echo "Custom theme applied"
}

# Get current theme
get_theme() {
    if [ -f "$CURRENT_THEME" ]; then
        source "$CURRENT_THEME"
        echo "$THEME"
    else
        echo "dark"
    fi
}

# List available themes
list_themes() {
    echo "Available Themes:"
    echo ""
    echo "  dark      - Dark theme (default)"
    echo "  light     - Light theme"
    echo "  custom    - Custom colors"
    echo ""
}

# Create theme
create_theme() {
    local name=$1
    
    echo "Creating theme: $name"
    echo ""
    read -p "Background color (#hex): " bg
    read -p "Foreground color (#hex): " fg
    read -p "Accent color (#hex): " accent
    
    cat > "$THEME_DIR/$name.conf" << EOF
THEME=$name
BACKGROUND=$bg
FOREGROUND=$fg
ACCENT=$accent
SECONDARY=$(echo $accent)
SUCCESS=#9ece6a
WARNING=#e0af68
ERROR=#f7768e
BORDER=#4c566a
EOF
    
    echo "Theme created: $name"
}

# Apply GTK theme
apply_gtk() {
    local theme=$(get_theme)
    
    if [ "$theme" = "dark" ]; then
        # Apply dark GTK theme
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    else
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
    fi
}

show_help() {
    echo "Usage: tinker-theme [command]"
    echo ""
    echo "Commands:"
    echo "  dark              Apply dark theme"
    echo "  light             Apply light theme"
    echo "  custom <bg> <fg> <accent> Custom theme"
    echo "  current           Show current theme"
    echo "  list              List themes"
    echo "  create <name>     Create new theme"
    echo "  apply-gtk         Apply GTK theme"
    echo "  help              Show this help"
}

case "$1" in
    dark) apply_dark ;;
    light) apply_light ;;
    custom) apply_custom "$2" "$3" "$4" ;;
    current) get_theme ;;
    list) list_themes ;;
    create) create_theme "$2" ;;
    apply-gtk) apply_gtk ;;
    *) show_help ;;
esac

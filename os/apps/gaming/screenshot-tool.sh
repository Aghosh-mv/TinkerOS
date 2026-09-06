#!/bin/bash
# TinkerOS Screenshot Tool - Capture, annotate, and share screenshots

set -e

SS_DIR="$HOME/tinker-screenshots"
mkdir -p "$SS_DIR"

# Detect screenshot tool
detect_tool() {
    if command -v grim &>/dev/null; then echo "grim"
    elif command -v scrot &>/dev/null; then echo "scrot"
    elif command -v import &>/dev/null; then echo "import"
    elif command -v spectacle &>/dev/null; then echo "spectacle"
    elif command -v gnome-screenshot &>/dev/null; then echo "gnome-screenshot"
    else echo "none"
    fi
}

# Full screen
full() {
    local name="full-$(date +%Y%m%d-%H%M%S).png"
    local path="$SS_DIR/$name"
    local tool=$(detect_tool)
    
    echo "=== Full Screen Capture ==="
    echo ""
    echo "  Tool: $tool"
    
    case $tool in
        grim) grim "$path" ;;
        scrot) scrot "$path" ;;
        import) import -window root "$path" ;;
        spectacle) spectacle -b -f -o "$path" ;;
        gnome-screenshot) gnome-screenshot -f "$path" ;;
        none)
            echo "  No screenshot tool found."
            echo "  Install one: sudo apt install grim scrot imagemagick"
            return 1
            ;;
    esac
    
    [ -f "$path" ] && echo "  Saved: $path" || echo "  Capture failed"
}

# Region/selection
region() {
    local tool=$(detect_tool)
    local path="$SS_DIR/region-$(date +%Y%m%d-%H%M%S).png"
    
    echo "=== Region Capture ==="
    echo "  Click and drag to select region..."
    
    case $tool in
        grim) grim -g "$(slurp 2>/dev/null)" "$path" || grim "$path" ;;
        scrot) scrot -s "$path" ;;
        import) import "$path" ;;
        spectacle) spectacle -r -o "$path" ;;
        gnome-screenshot) gnome-screenshot -a -f "$path" ;;
        none) echo "  No screenshot tool"; return 1 ;;
    esac
    
    [ -f "$path" ] && echo "  Saved: $path" || echo "  Capture cancelled/failed"
}

# Window capture
window() {
    local tool=$(detect_tool)
    local path="$SS_DIR/window-$(date +%Y%m%d-%H%M%S).png"
    
    echo "=== Active Window Capture ==="
    
    case $tool in
        grim) grim -g "$(swayprops 2>/dev/null || echo)" "$path" 2>/dev/null || grim "$path" ;;
        scrot) scrot -u "$path" ;;
        import) import -window "$(xdotool getactivewindow 2>/dev/null)" "$path" 2>/dev/null || import -window root "$path" ;;
        spectacle) spectacle -a -o "$path" ;;
        gnome-screenshot) gnome-screenshot -w -f "$path" ;;
        none) echo "  No screenshot tool"; return 1 ;;
    esac
    
    [ -f "$path" ] && echo "  Saved: $path" || echo "  Capture failed"
}

# Delayed capture
delayed() {
    local seconds=${1:-5}
    echo "=== Delayed Capture (${seconds}s) ==="
    echo "  Countdown..."
    
    for ((i=$seconds; i>=1; i--)); do
        echo "  $i"
        sleep 1
    done
    
    full
}

# Annotate with annotations tool
annotate() {
    local file=$1
    [ -z "$file" ] && file=$(ls -t "$SS_DIR"/*.png 2>/dev/null | head -1)
    [ -z "$file" ] && { echo "No screenshot to annotate"; return 1; }
    
    if command -v krita &>/dev/null; then
        krita "$file"
    elif command -v gimp &>/dev/null; then
        gimp "$file"
    elif command -v flameshot &>/dev/null; then
        flameshot full -p "$file"
    else
        echo "No annotation tool. Install: sudo apt install flameshot"
        echo "Opening image: $file"
        xdg-open "$file" 2>/dev/null || echo "  (no image viewer)"
    fi
}

# List captures
list() {
    echo "=== Captured Screenshots ==="
    echo ""
    ls -lht "$SS_DIR"/*.{png,jpg,jpeg} 2>/dev/null | sed 's/^/  /' || echo "  No screenshots yet"
}

show_help() {
    echo "Usage: tinker-screenshot [command]"
    echo ""
    echo "Commands:"
    echo "  full                Capture full screen"
    echo "  region              Capture selection region"
    echo "  window              Capture active window"
    echo "  delayed [sec]       Capture after delay (default 5s)"
    echo "  annotate [file]     Annotate a screenshot"
    echo "  list                List captured screenshots"
    echo "  help                Show this help"
}

case "$1" in
    full) full ;;
    region|area) region ;;
    window|win) window ;;
    delayed) delayed "$2" ;;
    annotate) annotate "$2" ;;
    list) list ;;
    *) show_help ;;
esac
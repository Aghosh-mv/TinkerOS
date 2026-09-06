#!/bin/bash
# TinkerOS Markdown Editor - Live preview markdown

set -e

MD_DIR="$HOME/.tinker/markdown"
CONFIG_FILE="$MD_DIR/config.conf"

mkdir -p "$MD_DIR"

init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Markdown Editor Configuration
ENABLED=true
AUTO_PREVIEW=true
THEME=dark
EOF
    fi
}

# Open markdown file
open() {
    local file=$1
    
    if [ -f "$file" ]; then
        echo "Opening: $file"
        
        # Try different editors
        if command -v code >/dev/null 2>&1; then
            code "$file"
        elif command -v atom >/dev/null 2>&1; then
            atom "$file"
        elif command -v gedit >/dev/null 2>&1; then
            gedit "$file"
        else
            less "$file"
        fi
    else
        echo "File not found: $file"
    fi
}

# Preview markdown
preview() {
    local file=$1
    
    if [ -f "$file" ]; then
        if command -v grip >/dev/null 2>&1; then
            grip "$file" --browser
        elif command -v pandoc >/dev/null 2>&1; then
            pandoc "$file" -o /tmp/preview.html && xdg-open /tmp/preview.html
        else
            echo "Install grip or pandoc for preview"
            echo "  sudo apt install grip"
        fi
    fi
}

# Convert markdown
convert() {
    local file=$1
    local format=${2:-html}
    
    if [ -f "$file" ]; then
        case $format in
            html)
                pandoc "$file" -o "${file%.md}.html" 2>/dev/null || echo "Install pandoc"
                ;;
            pdf)
                pandoc "$file" -o "${file%.md}.pdf" 2>/dev/null || echo "Install pandoc"
                ;;
            *)
                echo "Format: html, pdf"
                ;;
        esac
    fi
}

# Create new markdown
new() {
    local file=${1:-"note_$(date +%Y%m%d).md"}
    
    cat > "$file" << 'EOF'
# Title

## Subtitle

### Section

- Item 1
- Item 2

**Bold** and *italic*

```
code block
```

> blockquote

| Header | Header |
|--------|--------|
| Cell   | Cell   |
EOF
    
    echo "Created: $file"
}

show_help() {
    echo "Usage: tinker-markdown [command]"
    echo ""
    echo "Commands:"
    echo "  open <file>       Open markdown file"
    echo "  preview <file>    Preview markdown"
    echo "  convert <file> [format] Convert markdown"
    echo "  new [file]        Create new markdown"
    echo "  help              Show this help"
}

init

case "$1" in
    open|edit) open "$2" ;;
    preview|view) preview "$2" ;;
    convert) convert "$2" "$3" ;;
    new|create) new "$2" ;;
    *) show_help ;;
esac

#!/bin/bash
# TinkerOS OCR Everywhere
# Extract text from screen, images, PDFs, videos

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OCR_CONFIG="/etc/tinker/ocr.conf"
OCR_HISTORY="/var/log/tinker/ocr-history.log"
OCR_LANG="eng"

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                TINKEROS OCR EVERYWHERE                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check dependencies
check_deps() {
    local missing=()
    
    if ! command -v tesseract >/dev/null 2>&1; then
        missing+=("tesseract-ocr")
    fi
    
    if ! command -v import >/dev/null 2>&1; then
        missing+=("imagemagick")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing OCR dependencies...${NC}"
        if command -v apt >/dev/null 2>&1; then
            sudo apt install -y tesseract-ocr imagemagick ${missing[@]/#/tesseract-ocr-}
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y tesseract imagemagick ${missing[@]/#/tesseract-}
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm tesseract imagemagick ${missing[@]/#/tesseract-}
        fi
    fi
}

# OCR from screen region
ocr_screen_region() {
    echo -e "${YELLOW}Select region to OCR (click and drag)...${NC}"
    
    local screenshot="/tmp/ocr-region-$(date +%s).png"
    
    # Take screenshot of selected region
    import -window root $screenshot
    
    # Run OCR
    local text=$(tesseract $screenshot stdout -l $OCR_LANG 2>/dev/null)
    
    if [ -n "$text" ]; then
        echo -e "${GREEN}Extracted text:${NC}"
        echo ""
        echo "$text"
        echo ""
        
        # Copy to clipboard
        echo "$text" | xclip -selection clipboard 2>/dev/null
        echo -e "${GREEN}✓ Copied to clipboard${NC}"
        
        # Save to history
        log_ocr "screen_region" "$text"
    else
        echo -e "${RED}No text found${NC}"
    fi
    
    # Cleanup
    rm -f $screenshot
}

# OCR full screen
ocr_full_screen() {
    echo -e "${YELLOW}Capturing full screen...${NC}"
    
    local screenshot="/tmp/ocr-full-$(date +%s).png"
    
    # Take full screenshot
    import -window root $screenshot
    
    # Run OCR
    local text=$(tesseract $screenshot stdout -l $OCR_LANG 2>/dev/null)
    
    if [ -n "$text" ]; then
        echo -e "${GREEN}Extracted text:${NC}"
        echo ""
        echo "$text"
        echo ""
        
        # Copy to clipboard
        echo "$text" | xclip -selection clipboard 2>/dev/null
        echo -e "${GREEN}✓ Copied to clipboard${NC}"
        
        # Save to history
        log_ocr "full_screen" "$text"
    else
        echo -e "${RED}No text found${NC}"
    fi
    
    # Cleanup
    rm -f $screenshot
}

# OCR from file
ocr_file() {
    local file=$1
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}File not found: $file${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Processing: $file${NC}"
    
    local text=""
    
    case $file in
        *.png|*.jpg|*.jpeg|*.gif|*.bmp|*.tiff)
            text=$(tesseract $file stdout -l $OCR_LANG 2>/dev/null)
            ;;
        *.pdf)
            # Convert PDF to images first
            local tmpdir=$(mktemp -d)
            pdftoppm -png $file $tmpdir/page 2>/dev/null
            
            for img in $tmpdir/page-*.png; do
                text+="$(tesseract $img stdout -l $OCR_LANG 2>/dev/null)"
                text+=$'\n'
            done
            
            rm -rf $tmpdir
            ;;
        *)
            echo -e "${RED}Unsupported file type${NC}"
            return 1
            ;;
    esac
    
    if [ -n "$text" ]; then
        echo -e "${GREEN}Extracted text:${NC}"
        echo ""
        echo "$text"
        echo ""
        
        # Copy to clipboard
        echo "$text" | xclip -selection clipboard 2>/dev/null
        echo -e "${GREEN}✓ Copied to clipboard${NC}"
        
        # Save to history
        log_ocr "file:$file" "$text"
    else
        echo -e "${RED}No text found${NC}"
    fi
}

# OCR from clipboard image
ocr_clipboard() {
    echo -e "${YELLOW}Processing image from clipboard...${NC}"
    
    local clipboard_img="/tmp/ocr-clipboard-$(date +%s).png"
    
    # Get image from clipboard
    xclip -selection clipboard -t image/png -o > $clipboard_img 2>/dev/null
    
    if [ -s $clipboard_img ]; then
        # Run OCR
        local text=$(tesseract $clipboard_img stdout -l $OCR_LANG 2>/dev/null)
        
        if [ -n "$text" ]; then
            echo -e "${GREEN}Extracted text:${NC}"
            echo ""
            echo "$text"
            echo ""
            
            # Copy to clipboard
            echo "$text" | xclip -selection clipboard 2>/dev/null
            echo -e "${GREEN}✓ Copied to clipboard${NC}"
            
            # Save to history
            log_ocr "clipboard" "$text"
        else
            echo -e "${RED}No text found${NC}"
        fi
    else
        echo -e "${RED}No image in clipboard${NC}"
    fi
    
    # Cleanup
    rm -f $clipboard_img
}

# OCR from video frame
ocr_video() {
    local video=$1
    local timestamp=${2:-"00:00:05"}
    
    if [ ! -f "$video" ]; then
        echo -e "${RED}Video not found: $video${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Extracting frame from video...${NC}"
    
    local frame="/tmp/ocr-frame-$(date +%s).png"
    
    # Extract frame
    ffmpeg -ss $timestamp -i $video -vframes 1 -q:v 2 $frame 2>/dev/null
    
    if [ -f $frame ]; then
        # Run OCR
        local text=$(tesseract $frame stdout -l $OCR_LANG 2>/dev/null)
        
        if [ -n "$text" ]; then
            echo -e "${GREEN}Extracted text:${NC}"
            echo ""
            echo "$text"
            echo ""
            
            # Copy to clipboard
            echo "$text" | xclip -selection clipboard 2>/dev/null
            echo -e "${GREEN}✓ Copied to clipboard${NC}"
            
            # Save to history
            log_ocr "video:$video" "$text"
        else
            echo -e "${RED}No text found${NC}"
        fi
    fi
    
    # Cleanup
    rm -f $frame
}

# Live OCR mode
live_ocr() {
    echo -e "${YELLOW}Live OCR Mode (Press Ctrl+C to exit)${NC}"
    echo "Select regions to extract text in real-time..."
    echo ""
    
    while true; do
        read -p "Press Enter to capture region..."
        
        ocr_screen_region
        
        echo ""
        echo "---"
        echo ""
    done
}

# OCR history
show_history() {
    echo -e "${YELLOW}OCR History:${NC}"
    echo ""
    
    if [ -f $OCR_HISTORY ]; then
        tail -20 $OCR_HISTORY
    else
        echo "No OCR history found."
    fi
    echo ""
}

# Log OCR result
log_ocr() {
    local source=$1
    local text=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp | $source | ${text:0:100}..." >> $OCR_HISTORY
}

# Change language
set_language() {
    local lang=$1
    
    echo -e "${YELLOW}Setting OCR language: $lang${NC}"
    
    # Check if language is installed
    if ! tesseract --list-langs 2>/dev/null | grep -q $lang; then
        echo -e "${YELLOW}Installing language pack...${NC}"
        if command -v apt >/dev/null 2>&1; then
            sudo apt install -y tesseract-ocr-$lang
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y tesseract-langpack-$lang
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm tesseract-data-$lang
        fi
    fi
    
    OCR_LANG=$lang
    echo -e "${GREEN}✓ Language set to: $lang${NC}"
}

# List available languages
list_languages() {
    echo -e "${YELLOW}Available OCR Languages:${NC}"
    echo ""
    tesseract --list-langs 2>/dev/null
    echo ""
}

show_help() {
    echo "Usage: tinker-ocr [command] [options]"
    echo ""
    echo "Commands:"
    echo "  screen          OCR screen region"
    echo "  full            OCR full screen"
    echo "  file <path>     OCR file (image/PDF)"
    echo "  clipboard       OCR image from clipboard"
    echo "  video <file>    OCR video frame"
    echo "  live            Live OCR mode"
    echo "  history         Show OCR history"
    echo "  lang <code>     Set language"
    echo "  langs           List available languages"
    echo "  help            Show this help"
    echo ""
    echo "Examples:"
    echo "  tinker-ocr screen"
    echo "  tinker-ocr file ~/document.png"
    echo "  tinker-ocr lang deu"
}

# Main
check_deps

case "$1" in
    screen|region)
        show_header
        ocr_screen_region
        ;;
    full|fullscreen)
        show_header
        ocr_full_screen
        ;;
    file)
        if [ -z "$2" ]; then
            echo "Please specify file path"
            exit 1
        fi
        show_header
        ocr_file "$2"
        ;;
    clipboard|clip)
        show_header
        ocr_clipboard
        ;;
    video)
        if [ -z "$2" ]; then
            echo "Please specify video file"
            exit 1
        fi
        show_header
        ocr_video "$2" "$3"
        ;;
    live)
        show_header
        live_ocr
        ;;
    history)
        show_header
        show_history
        ;;
    lang|language)
        if [ -z "$2" ]; then
            show_header
            list_languages
        else
            set_language "$2"
        fi
        ;;
    langs|languages)
        show_header
        list_languages
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS OCR Everywhere${NC}"
        echo ""
        echo "Extract text from anything on your screen."
        echo ""
        echo "Quick commands:"
        echo "  tinker-ocr screen     - OCR screen region"
        echo "  tinker-ocr file doc.png - OCR image file"
        echo "  tinker-ocr clipboard  - OCR clipboard image"
        ;;
esac

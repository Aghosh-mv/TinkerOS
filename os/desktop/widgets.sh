#!/bin/bash
# TinkerOS Desktop Widgets

set -e

WIDGET_DIR="$HOME/.tinker/widgets"
mkdir -p "$WIDGET_DIR"

# Clock Widget
show_clock() {
    while true; do
        clear
        echo "╔══════════════════════════════════════╗"
        echo "║                                      ║"
        echo "║        $(date '+%I:%M:%S %p')             ║"
        echo "║        $(date '+%A, %B %d')           ║"
        echo "║                                      ║"
        echo "╚══════════════════════════════════════╝"
        sleep 1
    done
}

# Date/Time Widget
show_datetime() {
    echo "╔══════════════════════════════════════╗"
    echo "║           $(date '+%I:%M %p')                ║"
    echo "║                                      ║"
    echo "║     $(date '+%A, %B %d, %Y')        ║"
    echo "║     Week $(date '+%V')                     ║"
    echo "╚══════════════════════════════════════╝"
}

# Calendar Widget
show_calendar() {
    echo "╔══════════════════════════════════════╗"
    echo "║           $(date '+%B %Y')               ║"
    echo "║                                      ║"
    cal -3 2>/dev/null || cal
    echo "╚══════════════════════════════════════╝"
}

# Weather Widget
show_weather() {
    local weather=$(curl -s "wttr.in?format=%C+%t+%h+%w" 2>/dev/null)
    local location=$(curl -s "wttr.in?format=%l" 2>/dev/null)
    
    echo "╔══════════════════════════════════════╗"
    echo "║           Weather                    ║"
    echo "║                                      ║"
    if [ -n "$weather" ]; then
        echo "║     $weather                         ║"
        echo "║     $location                        ║"
    else
        echo "║     Weather data unavailable         ║"
    fi
    echo "╚══════════════════════════════════════╝"
}

# System Monitor Widget
show_sysmon() {
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    local mem=$(free | grep Mem | awk '{printf "%d", $3/$2 * 100}')
    local disk=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
    local uptime=$(uptime -p 2>/dev/null || uptime)
    
    echo "╔══════════════════════════════════════╗"
    echo "║           System Monitor             ║"
    echo "║                                      ║"
    echo "║     CPU:    ${cpu}%                      ║"
    echo "║     RAM:    ${mem}%                      ║"
    echo "║     Disk:   ${disk}%                      ║"
    echo "║                                      ║"
    echo "║     $uptime                           ║"
    echo "╚══════════════════════════════════════╝"
}

# Quick Notes Widget
show_notes() {
    local notes_file="$WIDGET_DIR/notes.txt"
    
    echo "╔══════════════════════════════════════╗"
    echo "║           Quick Notes                ║"
    echo "║                                      ║"
    
    if [ -f "$notes_file" ]; then
        head -10 "$notes_file" | while read -r line; do
            echo "║  $line"
        done
    else
        echo "║  No notes yet                        ║"
    fi
    
    echo "║                                      ║"
    echo "╚══════════════════════════════════════╝"
}

# Add note
add_note() {
    local note=$1
    echo "$note" >> "$WIDGET_DIR/notes.txt"
    echo "Note added"
}

# Clear notes
clear_notes() {
    rm -f "$WIDGET_DIR/notes.txt"
    echo "Notes cleared"
}

# Today Widget (combined)
show_today() {
    clear
    show_datetime
    echo ""
    show_weather
    echo ""
    show_sysmon
    echo ""
    show_notes
}

# Widgets help
show_help() {
    echo "Usage: tinker-widgets [command]"
    echo ""
    echo "Commands:"
    echo "  clock             Show clock widget"
    echo "  datetime          Show date/time"
    echo "  calendar          Show calendar"
    echo "  weather           Show weather"
    echo "  sysmon            System monitor"
    echo "  notes             Quick notes"
    echo "  note <text>       Add note"
    echo "  today             All widgets"
    echo "  help              Show this help"
}

case "$1" in
    clock) show_clock ;;
    datetime|time) show_datetime ;;
    calendar|cal) show_calendar ;;
    weather) show_weather ;;
    sysmon|monitor) show_sysmon ;;
    notes) show_notes ;;
    note) add_note "$2" ;;
    clear-notes) clear_notes ;;
    today|all) show_today ;;
    *) show_help ;;
esac

#!/bin/bash
# TinkerOS Temporal Resource Mapping (TRM) - Time-based resource scheduling

set -e

TRM_DIR="$HOME/.tinker/trm"
CONFIG_FILE="$TRM_DIR/config.conf"
SCHEDULE_FILE="$TRM_DIR/schedule.conf"
LOG_FILE="$TRM_DIR/trm.log"

mkdir -p "$TRM_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Temporal Resource Mapping Configuration
ENABLED=true
TIMEZONE=local
DEFAULT_PROFILE=balanced
LOG_ACTIONS=true
NOTIFICATIONS=true
EOF

    [ ! -f "$SCHEDULE_FILE" ] && cat > "$SCHEDULE_FILE" << 'EOF'
# Temporal Schedule
# Format: day|start_time|end_time|profile|command
# Days: 0=Sun, 1=Mon, ..., 6=Sat, *=every day
# Time: HH:MM (24h)
# Profile: performance, balanced, powersave, ultra
# Command: optional script to run

# Weekday work hours - performance
1|08:00|18:00|performance|
2|08:00|18:00|performance|
3|08:00|18:00|performance|
4|08:00|18:00|performance|
5|08:00|18:00|performance|

# Weekday evening - balanced
1|18:00|22:00|balanced|
2|18:00|22:00|balanced|
3|18:00|22:00|balanced|
4|18:00|22:00|balanced|
5|18:00|22:00|balanced|

# Night - powersave
*|22:00|07:00|powersave|

# Weekend - balanced
0|08:00|22:00|balanced|
6|08:00|22:00|balanced|
EOF

    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Get current profile for time
get_current_profile() {
    local now=$(date +%s)
    local dow=$(date +%u)  # 1-7
    local tod=$(date +%H:%M)
    
    while IFS='|' read -r day start end profile cmd; do
        [ -z "$day" ] && continue
        [[ "$day" =~ ^#.* ]] && continue
        
        local match=0
        if [ "$day" = "*" ] || [ "$day" = "$dow" ] || [ "$day" = "0" ] && [ $dow -eq 7 ]; then
            match=1
        fi
        
        if [ $match -eq 1 ]; then
            # Convert times to seconds for comparison
            local start_sec=$(date -d "$start" +%s 2>/dev/null)
            local end_sec=$(date -d "$end" +%s 2>/dev/null)
            local tod_sec=$(date -d "$tod" +%s 2>/dev/null)
            
            # Handle overnight schedules
            if [ $start_sec -lt $end_sec ]; then
                [ $tod_sec -ge $start_sec ] && [ $tod_sec -lt $end_sec ] && echo "$profile" && return
            else
                [ $tod_sec -ge $start_sec ] || [ $tod_sec -lt $end_sec ] && echo "$profile" && return
            fi
        fi
    done < "$SCHEDULE_FILE"
    
    # Default
    grep DEFAULT_PROFILE "$CONFIG_FILE" | cut -d= -f2
}

# Apply temporal profile
apply_temporal() {
    local profile=$(get_current_profile)
    echo "Current temporal profile: $profile"
    
    # Apply via power manager
    if [ -f /home/tinkerspace/linux-kernel/os/apps/system/power-manager.sh ]; then
        bash /home/tinkerspace/linux-kernel/os/apps/system/power-manager.sh apply "$profile"
    fi
    
    echo "$(date +%s)|apply|$profile" >> "$LOG_FILE"
}

# Show schedule
show_schedule() {
    echo "=== Temporal Schedule ==="
    echo ""
    printf "  %-4s  %-8s  %-8s  %-12s  %s\n" "DAY" "START" "END" "PROFILE" "COMMAND"
    echo "  ----  --------  --------  ------------  -------"
    
    local days=("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")
    
    while IFS='|' read -r day start end profile cmd; do
        [ -z "$day" ] && continue
        [[ "$day" =~ ^#.* ]] && continue
        
        local day_name=""
        if [ "$day" = "*" ]; then
            day_name="All"
        elif [ "$day" = "0" ]; then
            day_name="Sun"
        else
            day_name="${days[$day]}"
        fi
        
        printf "  %-4s  %-8s  %-8s  %-12s  %s\n" "$day_name" "$start" "$end" "$profile" "$cmd"
    done < "$SCHEDULE_FILE"
}

# Add schedule entry
add_schedule() {
    local day=$1
    local start=$2
    local end=$3
    local profile=$4
    local cmd=${5:-}
    
    [ -z "$day" ] || [ -z "$start" ] || [ -z "$end" ] || [ -z "$profile" ] && \
        echo "Usage: $0 add <day> <start> <end> <profile> [command]" && return 1
    
    echo "$day|$start|$end|$profile|$cmd" >> "$SCHEDULE_FILE"
    echo "Added: $day $start-$end $profile $cmd"
}

# Remove schedule entry
remove_schedule() {
    local line=$1
    [ -z "$line" ] && echo "Usage: $0 remove <line-number>" && return 1
    
    sed -i "${line}d" "$SCHEDULE_FILE"
    echo "Removed line $line"
}

# Run daemon
daemon() {
    echo "Starting TRM daemon..."
    echo "Checking schedule every minute..."
    
    local last_profile=""
    
    while true; do
        local current=$(get_current_profile)
        
        if [ "$current" != "$last_profile" ]; then
            echo "Profile change: $last_profile -> $current"
            apply_temporal
            last_profile=$current
        fi
        
        sleep 60
    done
}

# Show next change
next_change() {
    local now=$(date +%s)
    local dow=$(date +%u)
    local tod=$(date +%H:%M)
    local tod_sec=$(date -d "$tod" +%s)
    
    local next_profile=""
    local next_time=""
    local next_day=""
    
    while IFS='|' read -r day start end profile cmd; do
        [ -z "$day" ] && continue
        [[ "$day" =~ ^#.* ]] && continue
        
        local match=0
        if [ "$day" = "*" ] || [ "$day" = "$dow" ] || [ "$day" = "0" ] && [ $dow -eq 7 ]; then
            match=1
        fi
        
        if [ $match -eq 1 ]; then
            local start_sec=$(date -d "$start" +%s)
            
            if [ $start_sec -gt $tod_sec ]; then
                if [ -z "$next_time" ] || [ $start_sec -lt $next_time ]; then
                    next_time=$start_sec
                    next_profile=$profile
                    next_day=$day
                fi
            fi
        fi
    done < "$SCHEDULE_FILE"
    
    if [ -n "$next_time" ]; then
        local days=("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")
        local day_name=""
        if [ "$next_day" = "*" ]; then day_name="Today"; 
        elif [ "$next_day" = "0" ]; then day_name="Sun";
        else day_name="${days[$next_day]}"; fi
        
        echo "Next change: $day_name at $(date -d @$next_time +%H:%M) -> $next_profile"
    else
        echo "No scheduled changes"
    fi
}

show_help() {
    echo "Usage: tinker-trm [command]"
    echo ""
    echo "Commands:"
    echo "  current             Show current temporal profile"
    echo "  apply               Apply current profile"
    echo "  schedule            Show full schedule"
    echo "  add <day> <start> <end> <profile> [cmd]  Add schedule entry"
    echo "  remove <line>       Remove schedule entry"
    echo "  next                Show next scheduled change"
    echo "  daemon              Run temporal daemon"
    echo "  help                Show this help"
    echo ""
    echo "Days: 0=Sun, 1=Mon, ..., 6=Sat, *=every day"
    echo "Times: HH:MM (24h)"
    echo "Profiles: performance, balanced, powersave, ultra"
}

init

case "$1" in
    current) get_current_profile ;;
    apply) apply_temporal ;;
    schedule) show_schedule ;;
    add) add_schedule "$2" "$3" "$4" "$5" "$6" ;;
    remove) remove_schedule "$2" ;;
    next) next_change ;;
    daemon) daemon ;;
    *) show_help ;;
esac
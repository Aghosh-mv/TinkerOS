#!/bin/bash
# TinkerOS Rollback Recovery - BTRFS/LVM/Timeshift snapshot management

set -e

ROLLBACK_DIR="$HOME/.tinker/rollback"
CONFIG_FILE="$ROLLBACK_DIR/config.conf"
LOG_FILE="$ROLLBACK_DIR/rollback.log"

mkdir -p "$ROLLBACK_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# Rollback Recovery Configuration
DEFAULT_TOOL=auto
BTRFS_SUBVOL=@
LVM_VG=
SNAPSHOT_PREFIX=tinker
MAX_SNAPSHOTS=50
AUTO_SNAPSHOT_BEFORE_UPDATE=true
AUTO_SNAPSHOT_ON_BOOT=false
NOTIFICATIONS=true
EOF
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# Detect available tools
detect_tool() {
    local tool=$(grep DEFAULT_TOOL "$CONFIG_FILE" | cut -d= -f2)
    [ "$tool" = "auto" ] && tool=""
    
    if [ -z "$tool" ]; then
        if command -v timeshift &>/dev/null; then tool="timeshift"
        elif command -v snapper &>/dev/null; then tool="snapper"
        elif command -v btrfs &>/dev/null && mount | grep -q "btrfs"; then tool="btrfs"
        elif command -v lvm &>/dev/null && lvs | grep -q "vg"; then tool="lvm"
        else tool="none"
        fi
    fi
    echo "$tool"
}

# List snapshots
list_snapshots() {
    local tool=$(detect_tool)
    echo "Snapshots ($tool):"
    echo ""
    
    case $tool in
        timeshift)
            timeshift --list 2>/dev/null | grep -E "^[0-9]|^Name" | sed 's/^/  /'
            ;;
        snapper)
            snapper list 2>/dev/null | sed 's/^/  /'
            ;;
        btrfs)
            local subvol=$(grep BTRFS_SUBVOL "$CONFIG_FILE" | cut -d= -f2)
            btrfs subvolume list / 2>/dev/null | grep "$subvol" | sed 's/^/  /'
            ;;
        lvm)
            lvs 2>/dev/null | grep snap | sed 's/^/  /'
            ;;
        *)
            echo "  No snapshot tool available"
            ;;
    esac
}

# Create snapshot
create_snapshot() {
    local name=${1:-"${SNAPSHOT_PREFIX}-$(date +%Y%m%d-%H%M%S)"}
    local tool=$(detect_tool)
    local comment=${2:-"Manual snapshot"}
    
    echo "Creating snapshot: $name ($tool)"
    
    case $tool in
        timeshift)
            timeshift --create --comments "$comment" --tags D 2>&1 | tail -5
            ;;
        snapper)
            snapper create --description "$comment" --cleanup-algorithm number 2>&1
            ;;
        btrfs)
            local subvol=$(grep BTRFS_SUBVOL "$CONFIG_FILE" | cut -d= -f2)
            btrfs subvolume snapshot / /.snapshots/$name 2>&1
            ;;
        lvm)
            local vg=$(grep LVM_VG "$CONFIG_FILE" | cut -d= -f2)
            [ -z "$vg" ] && echo "LVM VG not configured" && return 1
            lvcreate -s -n $name -L 10G $vg/root 2>&1
            ;;
        *)
            echo "No snapshot tool available"
            return 1
            ;;
    esac
    
    local result=${PIPESTATUS[0]}
    if [ $result -eq 0 ]; then
        echo "Snapshot created: $name"
        echo "$(date +%s)|create|$name|$tool|success" >> "$LOG_FILE"
        grep -q "NOTIFICATIONS=true" "$CONFIG_FILE" && notify-send "Snapshot Created" "$name" 2>/dev/null || true
    else
        echo "Snapshot failed"
        echo "$(date +%s)|create|$name|$tool|failed" >> "$LOG_FILE"
    fi
    return $result
}

# Rollback to snapshot
rollback() {
    local name=$1
    local tool=$(detect_tool)
    
    [ -z "$name" ] && echo "Usage: $0 rollback <snapshot-name>" && return 1
    
    echo "Rolling back to: $name"
    echo ""
    echo "WARNING: This will revert system state!"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Yy]$ ]] && echo "Aborted" && return 1
    
    case $tool in
        timeshift)
            timeshift --restore --snapshot "$name" 2>&1 | tail -10
            ;;
        snapper)
            snapper undochange "$name" 2>&1
            ;;
        btrfs)
            echo "BTRFS rollback requires booting from snapshot"
            echo "Add to kernel cmdline: rootflags=subvol=.snapshots/$name"
            ;;
        lvm)
            local vg=$(grep LVM_VG "$CONFIG_FILE" | cut -d= -f2)
            lvconvert --merge $vg/$name 2>&1
            echo "Reboot required for merge to complete"
            ;;
        *)
            echo "No snapshot tool available"
            return 1
            ;;
    esac
    
    local result=${PIPESTATUS[0]}
    if [ $result -eq 0 ]; then
        echo "Rollback initiated: $name"
        echo "$(date +%s)|rollback|$name|$tool|success" >> "$LOG_FILE"
        grep -q "NOTIFICATIONS=true" "$CONFIG_FILE" && notify-send "Rollback Started" "Reboot may be required" 2>/dev/null || true
    else
        echo "Rollback failed"
        echo "$(date +%s)|rollback|$name|$tool|failed" >> "$LOG_FILE"
    fi
    return $result
}

# Delete snapshot
delete_snapshot() {
    local name=$1
    local tool=$(detect_tool)
    
    [ -z "$name" ] && echo "Usage: $0 delete <snapshot-name>" && return 1
    
    case $tool in
        timeshift)
            timeshift --delete --snapshot "$name" 2>&1
            ;;
        snapper)
            snapper delete "$name" 2>&1
            ;;
        btrfs)
            btrfs subvolume delete /.snapshots/$name 2>&1
            ;;
        lvm)
            local vg=$(grep LVM_VG "$CONFIG_FILE" | cut -d= -f2)
            lvremove -f $vg/$name 2>&1
            ;;
        *)
            echo "No snapshot tool available"
            return 1
            ;;
    esac
}

# Cleanup old snapshots
cleanup() {
    local max=$(grep MAX_SNAPSHOTS "$CONFIG_FILE" | cut -d= -f2)
    max=${max:-50}
    local tool=$(detect_tool)
    
    echo "Cleaning up old snapshots (keeping $max)..."
    
    case $tool in
        timeshift)
            timeshift --list 2>/dev/null | grep "^[0-9]" | tail -n +$((max+1)) | while read line; do
                local id=$(echo "$line" | awk '{print $1}')
                timeshift --delete --snapshot "$id" 2>/dev/null
            done
            ;;
        snapper)
            snapper list 2>/dev/null | grep -E "^[0-9]+" | awk '{print $1}' | tail -n +$((max+1)) | while read num; do
                snapper delete "$num" 2>/dev/null
            done
            ;;
        btrfs)
            btrfs subvolume list / 2>/dev/null | grep tinker | sort | head -n -$max | while read line; do
                local path=$(echo "$line" | awk '{print $9}')
                btrfs subvolume delete "$path" 2>/dev/null
            done
            ;;
        lvm)
            lvs --noheadings -o lv_name 2>/dev/null | grep snap | sort | head -n -$max | while read lv; do
                lvremove -f $(grep LVM_VG "$CONFIG_FILE" | cut -d= -f2)/$lv 2>/dev/null
            done
            ;;
    esac
    
    echo "Cleanup complete"
}

# Show snapshot details
details() {
    local name=$1
    local tool=$(detect_tool)
    
    [ -z "$name" ] && echo "Usage: $0 details <snapshot-name>" && return 1
    
    case $tool in
        timeshift)
            timeshift --list 2>/dev/null | grep -A 10 "$name"
            ;;
        snapper)
            snapper list 2>/dev/null | grep -A 5 "$name"
            ;;
        btrfs)
            btrfs subvolume show /.snapshots/$name 2>/dev/null
            ;;
        lvm)
            lvs -o +lv_snapshot_status 2>/dev/null | grep "$name"
            ;;
    esac
}

show_help() {
    echo "Usage: tinker-rollback [command]"
    echo ""
    echo "Commands:"
    echo "  list                List all snapshots"
    echo "  create [name]       Create new snapshot"
    echo "  rollback <name>     Rollback to snapshot"
    echo "  delete <name>       Delete snapshot"
    echo "  cleanup             Remove old snapshots"
    echo "  details <name>      Show snapshot details"
    echo "  tool                Show detected snapshot tool"
    echo "  help                Show this help"
}

init

case "$1" in
    list) list_snapshots ;;
    create) create_snapshot "$2" "$3" ;;
    rollback) rollback "$2" ;;
    delete) delete_snapshot "$2" ;;
    cleanup) cleanup ;;
    details) details "$2" ;;
    tool) detect_tool ;;
    *) show_help ;;
esac
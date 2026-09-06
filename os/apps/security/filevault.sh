#!/bin/bash
# TinkerOS File Vault - Encrypted container management (cryptsetup/LUKS)

set -e

VAULT_DIR="$HOME/.tinker/vaults"
CONFIG_FILE="$VAULT_DIR/config.conf"
mkdir -p "$VAULT_DIR"

init() {
    [ ! -f "$CONFIG_FILE" ] && cat > "$CONFIG_FILE" << 'EOF'
# File Vault Configuration
DEFAULT_SIZE_MB=512
DEFAULT_FS=ext4
MOUNT_POINT="$HOME/vault-mount"
EOF
}

# Check dependencies
check_deps() {
    for tool in cryptsetup; do
        command -v $tool &>/dev/null || { echo "Missing: $tool (sudo apt install cryptsetup)"; return 1; }
    done
    command -v losetup &>/dev/null || { echo "Missing: losetup (util-linux)"; return 1; }
}

# Create vault
create() {
    local name=${1:-secure}
    local size=${2:-$(grep DEFAULT_SIZE_MB "$CONFIG_FILE" | cut -d= -f2)}
    size=${size:-512}
    
    check_deps || return 1
    [ -f "$VAULT_DIR/$name.img" ] && { echo "Vault '$name' already exists"; return 1; }
    
    echo "=== Creating Encrypted Vault: $name (${size}MB) ==="
    echo ""
    echo "Creating sparse image file..."
    truncate -s "${size}M" "$VAULT_DIR/$name.img"
    echo "  ✓ Created $VAULT_DIR/$name.img"
    echo ""
    echo "Setting up loop device (requires sudo)..."
    echo "  (You must complete LUKS format + mount manually:)"
    echo ""
    echo "  sudo losetup /dev/loop0 $VAULT_DIR/$name.img"
    echo "  sudo cryptsetup luksFormat /dev/loop0"
    echo "  sudo cryptsetup open /dev/loop0 $name"
    echo "  sudo mkfs.${FS:-ext4} /dev/mapper/$name"
    echo "  sudo mount /dev/mapper/$name $MOUNT_POINT"
    echo ""
    echo "  Vault created. Complete the steps above to encrypt and mount."
}

# Try to open/mount (requires user to complete system setup)
open() {
    local name=${1:-secure}
    echo "=== Opening Vault: $name ==="
    echo ""
    echo "This requires the loop device and LUKS passphrase:"
    echo ""
    echo "  sudo cryptsetup open $VAULT_DIR/$name.img $name"
    echo "  sudo mount /dev/mapper/$name $MOUNT_POINT"
    echo ""
    echo "  (Interactive. Run the sudo command above to complete.)"
}

# Close/unmount
close() {
    local name=${1:-secure}
    echo "Closing vault: $name..."
    sudo umount "$MOUNT_POINT" 2>/dev/null || echo "  (mount point not mounted)"
    sudo cryptsetup close "$name" 2>/dev/null || echo "  (already closed)"
    echo "  Vault closed"
}

# List vaults
list() {
    echo "=== File Vaults ==="
    echo ""
    local count=0
    for img in "$VAULT_DIR"/*.img; do
        [ -e "$img" ] || continue
        local size=$(du -h "$img" 2>/dev/null | awk '{print $1}')
        local logical=$(ls -lh "$img" | awk '{print $5}')
        echo "  $(basename "$img" .img): $size used ($logical logical)"
        count=$((count+1))
    done
    [ $count -eq 0 ] && echo "  No vaults created"
}

# Delete vault
delete() {
    local name=${1:-secure}
    echo "Deleting vault: $name..."
    close "$name"
    rm -f "$VAULT_DIR/$name.img"
    echo "  Deleted (irrecoverable!)"
}

show_help() {
    echo "Usage: tinker-filevault [command]"
    echo ""
    echo "Commands:"
    echo "  create [name] [mb]  Create encrypted vault container"
    echo "  open [name]         Open/mount vault"
    echo "  close [name]        Close/unmount vault"
    echo "  list                List vaults"
    echo "  delete [name]       Delete vault"
    echo "  help                Show this help"
}

init

case "$1" in
    create) create "$2" "$3" ;;
    open|mount) open "$2" ;;
    close|unmount) close "$2" ;;
    list) list ;;
    delete) delete "$2" ;;
    *) show_help ;;
esac
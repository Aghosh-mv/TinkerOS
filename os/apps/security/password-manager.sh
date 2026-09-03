#!/bin/bash
# TinkerOS Password Manager - Local, encrypted credential storage
# Local-only. No cloud. Your data stays on your machine.

set -e

# Delegate to the full implementation when available
SYSTEM_IMPL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/system/password-manager.sh"
if [ -f "$SYSTEM_IMPL" ] && [ -s "$SYSTEM_IMPL" ]; then
    exec bash "$SYSTEM_IMPL" "$@"
fi

PM_DIR="$HOME/.tinker/passwords"
VAULT_FILE="$PM_DIR/vault"
MASTER_HASH="$PM_DIR/.master"
mkdir -p "$PM_DIR"

# Derive encryption key from master password
derive_key() {
    echo -n "$1" | sha256sum | awk '{print $1}'
}

# Initialize vault
init() {
    echo "=== Initialize Password Vault ==="
    echo ""
    [ -f "$MASTER_HASH" ] && { echo "Vault already initialized"; return 0; }
    
    echo -n "Set master password: "
    read -rs master
    echo ""
    echo -n "Confirm master password: "
    read -rs confirm
    echo ""
    
    [ "$master" != "$confirm" ] && { echo "Passwords don't match"; return 1; }
    
    local hash=$(echo -n "$master" | sha256sum | awk '{print $1}')
    echo "$hash" > "$MASTER_HASH"
    echo "[]" > "$VAULT_FILE" 2>/dev/null || true
    chmod 600 "$MASTER_HASH" "$VAULT_FILE"
    echo "Vault initialized. Never forget your master password!"
}

# Unlock and verify
unlock() {
    [ ! -f "$MASTER_HASH" ] && { echo "Vault not initialized. Run: $0 init"; return 1; }
    
    echo -n "Master password: "
    read -rs master
    echo ""
    
    local stored=$(cat "$MASTER_HASH")
    local given=$(echo -n "$master" | sha256sum | awk '{print $1}')
    
    if [ "$stored" != "$given" ]; then
        echo "Incorrect master password"
        return 1
    fi
    echo "$master"
}

# Add a credential
add() {
    local service=${1:-}
    local username=${2:-}
    
    echo -n "Service name: "
    [ -n "$service" ] && echo "$service" || read -r service
    echo -n "Username: "
    [ -n "$username" ] && echo "$username" || read -r username
    echo -n "Password (blank to generate): "
    read -rs password
    echo ""
    
    if [ -z "$password" ]; then
        password=$(head -c 16 /dev/urandom | base64 | head -c 20)
        echo "Generated password: $password"
    fi
    
    local master=$(unlock) || return 1
    local key=$(derive_key "$master")
    
    # Simple obfuscation using key
    local encoded=$(echo -n "$password" | openssl enc -aes-256-cbc -a -pbkdf2 -pass pass:"$key" 2>/dev/null || echo -n "$password")
    
    local file="$PM_DIR/$service.enc"
    printf '%s\n%s\n%s' "$username" "$encoded" "$(date +%s)" > "$file"
    chmod 600 "$file"
    echo "Stored: $service"
    echo "  File: $file"
}

# Retrieve a credential
get() {
    local service=${1:-}
    [ -z "$service" ] && { echo "Usage: $0 get <service>"; return 1; }
    
    local file="$PM_DIR/$service.enc"
    [ ! -f "$file" ] && { echo "Service not found: $service"; return 1; }
    
    local master=$(unlock) || return 1
    local key=$(derive_key "$master")
    
    local username=$(sed -n 1p "$file")
    local encoded=$(sed -n 2p "$file")
    local password=$(echo "$encoded" | openssl enc -d -aes-256-cbc -a -pbkdf2 -pass pass:"$key" 2>/dev/null || echo "$encoded")
    
    echo "Service: $service"
    echo "Username: $username"
    echo "Password: $password"
}

# List services
list() {
    echo "=== Saved Passwords ==="
    echo ""
    local count=0
    for f in "$PM_DIR"/*.enc; do
        [ -e "$f" ] || continue
        echo "  $(basename "$f" .enc)"
        count=$((count+1))
    done
    [ $count -eq 0 ] && echo "  No passwords saved yet"
}

# Delete a credential
delete() {
    local service=${1:-}
    [ -z "$service" ] && { echo "Usage: $0 delete <service>"; return 1; }
    rm -f "$PM_DIR/$service.enc"
    echo "Deleted: $service"
}

# Generate a strong password
generate() {
    local length=${1:-20}
    echo "=== Generated Password ==="
    head -c "$length" /dev/urandom | base64 | head -c "$length"
    echo ""
    echo ""
    echo "Length: $length chars (alphanumeric + symbols)"
}

show_help() {
    echo "Usage: tinker-password [command]"
    echo ""
    echo "Commands:"
    echo "  init                Initialize vault"
    echo "  add [svc] [user]    Add a credential"
    echo "  get <service>       Retrieve a credential"
    echo "  list                List saved services"
    echo "  delete <service>    Delete a credential"
    echo "  generate [len]      Generate a strong password"
    echo "  help                Show this help"
}

case "$1" in
    init) init ;;
    add) add "$2" "$3" ;;
    get|show) get "$2" ;;
    list) list ;;
    delete|rm) delete "$2" ;;
    generate|gen) generate "$2" ;;
    *) show_help ;;
esac
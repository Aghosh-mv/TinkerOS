#!/bin/bash
# TinkerOS Secure Password Manager
# Local-only password storage - YOUR data stays YOURS
# No cloud. No tracking. No one else uses it.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Secure storage paths
TINKER_HOME="$HOME/.tinker"
VAULT_DIR="$TINKER_HOME/vault"
VAULT_FILE="$VAULT_DIR/vault.enc"
KEYRING_SERVICE="tinker-passwords"
KEYRING_USER="tinker-vault"
PASSWORDS_DIR="$TINKER_HOME/passwords"
AUTO_LOCK_TIME=300  # 5 minutes

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         TINKEROS SECURE PASSWORD MANAGER                ║${NC}"
    echo -e "${BLUE}║         Your data. Your device. Your rules.             ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}✓ No cloud storage${NC}"
    echo -e "  ${CYAN}✓ No data collection${NC}"
    echo -e "  ${CYAN}✓ 100% local encryption${NC}"
    echo ""
}

# Initialize vault
init_vault() {
    mkdir -p "$VAULT_DIR" "$PASSWORDS_DIR" "$TINKER_HOME"
    
    if [ ! -f "$VAULT_FILE" ]; then
        echo -e "${YELLOW}Setting up your secure password vault...${NC}"
        echo ""
        echo "  Your vault is encrypted with a master password."
        echo "  This is the ONLY password you need to remember."
        echo "  All your other passwords will be generated and stored here."
        echo ""
        
        while true; do
            read -s -p "  Create master password: " master_pass
            echo ""
            read -s -p "  Confirm master password: " master_confirm
            echo ""
            
            if [ "$master_pass" = "$master_confirm" ]; then
                if [ ${#master_pass} -ge 8 ]; then
                    break
                else
                    echo -e "  ${RED}Password must be at least 8 characters${NC}"
                fi
            else
                echo -e "  ${RED}Passwords don't match${NC}"
            fi
        done
        
        # Create vault
        create_vault "$master_pass"
        
        echo ""
        echo -e "  ${GREEN}✓ Vault created successfully!${NC}"
        echo ""
        
        # Setup auto-lock
        setup_auto_lock
        
        echo -e "  ${GREEN}✓ Ready to use!${NC}"
        sleep 2
    fi
}

# Create encrypted vault
create_vault() {
    local master_pass=$1
    
    # Create vault structure
    cat > "$VAULT_DIR/vault.json" << EOF
{
    "version": "1.0",
    "created": "$(date -Iseconds)",
    "last_access": "$(date -Iseconds)",
    "settings": {
        "auto_generate": true,
        "auto_fill": true,
        "min_password_length": 16,
        "require_special_chars": true,
        "require_numbers": true,
        "require_uppercase": true
    },
    "entries": []
}
EOF
    
    # Encrypt vault
    encrypt_vault "$master_pass"
    
    # Store master password hash for verification
    echo "$master_pass" | sha256sum | awk '{print $1}' > "$VAULT_DIR/master.hash"
}

# Encrypt vault file
encrypt_vault() {
    local master_pass=$1
    
    if command -v openssl >/dev/null 2>&1; then
        openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
            -in "$VAULT_DIR/vault.json" \
            -out "$VAULT_FILE" \
            -pass pass:"$master_pass"
        
        # Remove unencrypted version
        shred -u "$VAULT_DIR/vault.json" 2>/dev/null || rm -f "$VAULT_DIR/vault.json"
    else
        # Fallback to gpg
        echo "$master_pass" | gpg --batch --yes --symmetric \
            --cipher-algo AES256 \
            --output "$VAULT_FILE" \
            "$VAULT_DIR/vault.json"
        
        shred -u "$VAULT_DIR/vault.json" 2>/dev/null || rm -f "$VAULT_DIR/vault.json"
    fi
}

# Decrypt vault
decrypt_vault() {
    local master_pass=$1
    
    # Verify master password
    local stored_hash=$(cat "$VAULT_DIR/master.hash" 2>/dev/null)
    local input_hash=$(echo "$master_pass" | sha256sum | awk '{print $1}')
    
    if [ "$stored_hash" != "$input_hash" ]; then
        echo -e "${RED}Invalid master password!${NC}"
        return 1
    fi
    
    # Decrypt
    if command -v openssl >/dev/null 2>&1; then
        openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
            -in "$VAULT_FILE" \
            -out "$VAULT_DIR/vault.json" \
            -pass pass:"$master_pass"
    else
        echo "$master_pass" | gpg --batch --yes --decrypt \
            --output "$VAULT_DIR/vault.json" \
            "$VAULT_FILE" 2>/dev/null
    fi
    
    echo "$VAULT_DIR/vault.json"
}

# Lock vault
lock_vault() {
    if [ -f "$VAULT_DIR/vault.json" ]; then
        shred -u "$VAULT_DIR/vault.json" 2>/dev/null || rm -f "$VAULT_DIR/vault.json"
        echo -e "${GREEN}✓ Vault locked${NC}"
    fi
    rm -f /tmp/tinker-vault-session
}

# Check if vault is unlocked
is_unlocked() {
    [ -f "$VAULT_DIR/vault.json" ]
}

# Get master password (from session or prompt)
get_master_password() {
    if [ -f /tmp/tinker-vault-session ]; then
        cat /tmp/tinker-vault-session
    else
        read -s -p "  Master password: " master_pass
        echo ""
        echo "$master_pass" > /tmp/tinker-vault-session
        chmod 600 /tmp/tinker-vault-session
        echo "$master_pass"
    fi
}

# ============================================
# PASSWORD GENERATOR
# ============================================

# Generate strong password
generate_password() {
    local length=${1:-20}
    local use_uppercase=${2:-true}
    local use_numbers=${3:-true}
    local use_special=${4:-true}
    
    local chars="abcdefghijklmnopqrstuvwxyz"
    local password=""
    
    if [ "$use_uppercase" = "true" ]; then
        chars+="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    fi
    
    if [ "$use_numbers" = "true" ]; then
        chars+="0123456789"
    fi
    
    if [ "$use_special" = "true" ]; then
        chars+="!@#$%^&*()_+-=[]{}|;:,.<>?"
    fi
    
    # Generate password
    password=$(cat /dev/urandom | tr -dc "$chars" | head -c $length)
    
    echo "$password"
}

# Generate passphrase
generate_passphrase() {
    local word_count=${1:-4}
    
    # Word list (common, memorable words)
    local words=(
        "apple" "beach" "candy" "dance" "eagle" "flame" "grape" "house"
        "image" "jungle" "kite" "lemon" "magic" "night" "ocean" "piano"
        "queen" "river" "stone" "tiger" "ultra" "vivid" "whale" "xenon"
        "yellow" "zebra" "anchor" "breeze" "castle" "dream" "ember" "frost"
        "ghost" "haven" "ivory" "jewel" "knack" "lunar" "maple" "noble"
        "orchid" "pearl" "quest" "robin" "solar" "terra" "unity" "vapor"
        "woven" "xenial" "youth" "zephyr"
    )
    
    local passphrase=""
    for i in $(seq 1 $word_count); do
        local word=${words[$RANDOM % ${#words[@]}]}
        # Capitalize first letter
        word=$(echo "$word" | sed 's/./\U&/')
        passphrase+="$word"
        if [ $i -lt $word_count ]; then
            passphrase+="-"
        fi
    done
    
    echo "$passphrase"
}

# ============================================
# PASSWORD STORAGE
# ============================================

# Add password to vault
add_password() {
    local site=$1
    local username=$2
    local password=$3
    local category=${4:-"general"}
    
    if ! is_unlocked; then
        echo -e "${YELLOW}Unlocking vault...${NC}"
        local master=$(get_master_password)
        decrypt_vault "$master"
    fi
    
    local vault=$(cat "$VAULT_DIR/vault.json")
    
    # Add new entry
    local new_entry=$(cat << EOF
{
    "id": "$(uuidgen 2>/dev/null || echo $RANDOM)",
    "site": "$site",
    "username": "$username",
    "password": "$password",
    "category": "$category",
    "created": "$(date -Iseconds)",
    "last_used": "$(date -Iseconds)",
    "use_count": 0,
    "notes": ""
}
EOF
)
    
    # Update vault
    echo "$vault" | jq --argjson entry "$new_entry" '.entries += [$entry]' > "$VAULT_DIR/vault.json"
    
    # Re-encrypt
    local master=$(cat /tmp/tinker-vault-session)
    encrypt_vault "$master"
    
    echo -e "${GREEN}✓ Password saved securely!${NC}"
}

# Get password from vault
get_password() {
    local site=$1
    
    if ! is_unlocked; then
        local master=$(get_master_password)
        decrypt_vault "$master"
    fi
    
    local vault=$(cat "$VAULT_DIR/vault.json")
    
    # Find entry
    local entry=$(echo "$vault" | jq -r --arg site "$site" '.entries[] | select(.site == $site)')
    
    if [ -n "$entry" ]; then
        local username=$(echo "$entry" | jq -r '.username')
        local password=$(echo "$entry" | jq -r '.password')
        
        # Update last used
        echo "$vault" | jq --arg site "$site" '(.entries[] | select(.site == $site)).last_used = "'$(date -Iseconds)'" | (.entries[] | select(.site == $site)).use_count += 1' > "$VAULT_DIR/vault.json"
        
        echo "$username:$password"
    else
        echo ""
    fi
}

# List all passwords
list_passwords() {
    if ! is_unlocked; then
        local master=$(get_master_password)
        decrypt_vault "$master"
    fi
    
    local vault=$(cat "$VAULT_DIR/vault.json")
    
    echo -e "${YELLOW}Stored Passwords:${NC}"
    echo ""
    printf "%-30s %-25s %-15s %s\n" "SITE" "USERNAME" "CATEGORY" "LAST USED"
    echo "─────────────────────────────────────────────────────────────────────────────"
    
    echo "$vault" | jq -r '.entries[] | "\(.site)\t\(.username)\t\(.category)\t\(.last_used)"' | \
    while IFS=$'\t' read -r site username category last_used; do
        printf "%-30s %-25s %-15s %s\n" "$site" "$username" "$category" "$(date -d "$last_used" '+%Y-%m-%d' 2>/dev/null || echo 'Never')"
    done
    echo ""
}

# ============================================
# BROWSER INTEGRATION
# ============================================

# Detect password field focus (requires browser extension or xdotool)
monitor_password_fields() {
    echo -e "${YELLOW}Monitoring for password fields...${NC}"
    echo "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        # Check active window
        local window=$(xdotool getactivewindow getwindowname 2>/dev/null)
        
        # Check if browser is active
        if echo "$window" | grep -qi firefox\|chromium\|chrome\|brave\|vivaldi\|opera; then
            # Check for password field (approximation)
            # In real implementation, this would use browser extension
            
            # Send notification
            notify_password_offer "$window"
        fi
        
        sleep 2
    done
}

# Notify user about password offer
notify_password_offer() {
    local window=$1
    
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal -i password \
            "TinkerOS Password Manager" \
            "Password field detected!\n\nWould you like to generate a secure password?\n\nClick here to open Password Manager" \
            --action="generate=Generate Password" \
            --action="skip=Skip"
    fi
}

# ============================================
# AUTO-FILL SYSTEM
# ============================================

# Auto-fill password for site
autofill_password() {
    local site=$1
    
    local credentials=$(get_password "$site")
    
    if [ -n "$credentials" ]; then
        local username=$(echo "$credentials" | cut -d: -f1)
        local password=$(echo "$credentials" | cut -d: -f2)
        
        echo -e "${GREEN}Filling credentials for: $site${NC}"
        echo -e "  Username: $username"
        
        # Type username
        xdotool type --delay 50 "$username"
        xdotool key Tab
        sleep 0.5
        
        # Type password
        xdotool type --delay 50 "$password"
        
        echo -e "${GREEN}✓ Credentials filled!${NC}"
    else
        echo -e "${YELLOW}No credentials found for: $site${NC}"
        echo "Would you like to generate and save a password?"
    fi
}

# ============================================
# PASSWORD HEALTH CHECK
# ============================================

check_password_health() {
    if ! is_unlocked; then
        local master=$(get_master_password)
        decrypt_vault "$master"
    fi
    
    local vault=$(cat "$VAULT_DIR/vault.json")
    
    echo -e "${YELLOW}Password Health Report:${NC}"
    echo ""
    
    local total=$(echo "$vault" | jq '.entries | length')
    local weak=0
    local reused=0
    local old=0
    
    # Check each password
    echo "$vault" | jq -r '.entries[] | "\(.site)\t\(.password)"' | \
    while IFS=$'\t' read -r site password; do
        local strength=$(check_password_strength "$password")
        
        if [ "$strength" = "weak" ]; then
            echo -e "  ${RED}✗${NC} $site - Weak password"
            weak=$((weak + 1))
        fi
        
        # Check if password is reused
        local count=$(echo "$vault" | jq --arg pass "$password" '[.entries[] | select(.password == $pass)] | length')
        if [ "$count" -gt 1 ]; then
            echo -e "  ${YELLOW}!${NC} $site - Password reused"
            reused=$((reused + 1))
        fi
    done
    
    echo ""
    echo -e "Summary:"
    echo -e "  Total passwords: $total"
    echo -e "  Weak: $weak"
    echo -e "  Reused: $reused"
    echo ""
}

# Check password strength
check_password_strength() {
    local password=$1
    local length=${#password}
    
    if [ $length -lt 8 ]; then
        echo "weak"
    elif [ $length -lt 12 ]; then
        echo "fair"
    elif [ $length -lt 16 ]; then
        echo "good"
    else
        echo "strong"
    fi
}

# ============================================
# SETUP AUTO-LOCK
# ============================================

setup_auto_lock() {
    # Create auto-lock script
    cat > "$TINKER_HOME/auto-lock.sh" << 'EOF'
#!/bin/bash
# Auto-lock vault after timeout

LOCK_FILE="/tmp/tinker-vault-session"
TIMEOUT=300  # 5 minutes

while true; do
    if [ -f "$LOCK_FILE" ]; then
        last_modified=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
        current_time=$(date +%s)
        elapsed=$((current_time - last_modified))
        
        if [ $elapsed -gt $TIMEOUT ]; then
            # Lock vault
            rm -f "$LOCK_FILE"
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -u warning "TinkerOS" "Password vault auto-locked"
            fi
        fi
    fi
    
    sleep 60
done
EOF
    
    chmod +x "$TINKER_HOME/auto-lock.sh"
    
    # Start auto-lock daemon
    "$TINKER_HOME/auto-lock.sh" &
    echo $! > "$TINKER_HOME/auto-lock.pid"
}

# ============================================
# MAIN
# ============================================

case "$1" in
    init|setup)
        show_header
        init_vault
        ;;
    add|save)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: tinker-vault add <site> <username> [password]"
            echo "If no password provided, one will be generated."
            exit 1
        fi
        
        show_header
        
        if [ -z "$4" ]; then
            echo -e "${YELLOW}Generating secure password...${NC}"
            password=$(generate_password 20)
            echo -e "Generated: ${CYAN}$password${NC}"
        else
            password=$4
        fi
        
        add_password "$2" "$3" "$password"
        ;;
    get|show)
        if [ -z "$2" ]; then
            echo "Usage: tinker-vault get <site>"
            exit 1
        fi
        
        show_header
        credentials=$(get_password "$2")
        
        if [ -n "$credentials" ]; then
            username=$(echo "$credentials" | cut -d: -f1)
            password=$(echo "$credentials" | cut -d: -f2)
            
            echo -e "${GREEN}Credentials for: $2${NC}"
            echo -e "  Username: ${CYAN}$username${NC}"
            echo -e "  Password: ${CYAN}$password${NC}"
            echo ""
            
            # Copy to clipboard
            echo "$password" | xclip -selection clipboard 2>/dev/null
            echo -e "${GREEN}✓ Password copied to clipboard${NC}"
        else
            echo -e "${YELLOW}No credentials found for: $2${NC}"
        fi
        ;;
    list|ls)
        show_header
        list_passwords
        ;;
    generate|gen)
        show_header
        echo -e "${YELLOW}Password Generator:${NC}"
        echo ""
        
        length=${2:-20}
        password=$(generate_password $length)
        
        echo -e "  Generated password: ${CYAN}$password${NC}"
        echo ""
        echo -e "  ${GREEN}✓ Copied to clipboard${NC}"
        echo "$password" | xclip -selection clipboard 2>/dev/null
        ;;
    passphrase)
        show_header
        echo -e "${YELLOW}Passphrase Generator:${NC}"
        echo ""
        
        words=${2:-4}
        passphrase=$(generate_passphrase $words)
        
        echo -e "  Generated passphrase: ${CYAN}$passphrase${NC}"
        echo ""
        echo -e "  ${GREEN}✓ Copied to clipboard${NC}"
        echo "$passphrase" | xclip -selection clipboard 2>/dev/null
        ;;
    lock)
        show_header
        lock_vault
        ;;
    unlock)
        show_header
        echo -e "${YELLOW}Unlocking vault...${NC}"
        master=$(get_master_password)
        decrypt_vault "$master" >/dev/null
        echo -e "${GREEN}✓ Vault unlocked!${NC}"
        ;;
    health)
        show_header
        check_password_health
        ;;
    monitor)
        show_header
        monitor_password_fields
        ;;
    autofill|fill)
        if [ -z "$2" ]; then
            echo "Usage: tinker-vault autofill <site>"
            exit 1
        fi
        autofill_password "$2"
        ;;
    help|--help|-h)
        show_header
        echo "Usage: tinker-vault [command] [options]"
        echo ""
        echo "Commands:"
        echo "  init              Initialize vault (first time setup)"
        echo "  add <site> <user> [pass]  Add password"
        echo "  get <site>        Get password"
        echo "  list              List all passwords"
        echo "  generate [len]    Generate password"
        echo "  passphrase [words] Generate passphrase"
        echo "  lock              Lock vault"
        echo "  unlock            Unlock vault"
        echo "  health            Check password health"
        echo "  monitor           Monitor password fields"
        echo "  autofill <site>   Auto-fill password"
        echo "  help              Show this help"
        echo ""
        echo "Examples:"
        echo "  tinker-vault init"
        echo "  tinker-vault add github.com john@email.com"
        echo "  tinker-vault get github.com"
        echo "  tinker-vault generate 32"
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Secure Password Manager${NC}"
        echo ""
        echo "  Your passwords stay on YOUR device."
        echo "  No cloud. No tracking. No exceptions."
        echo ""
        echo -e "  ${CYAN}Quick start:${NC}"
        echo "    tinker-vault init     - Set up your vault"
        echo "    tinker-vault add      - Save a password"
        echo "    tinker-vault get      - Retrieve a password"
        echo ""
        ;;
esac

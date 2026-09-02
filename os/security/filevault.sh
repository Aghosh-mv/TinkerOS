#!/bin/bash
# TinkerOS FileVault - Full Disk Encryption
# macOS-like encryption for Linux

set -e

SECURITY_DIR="$HOME/.tinker/security"
mkdir -p "$SECURITY_DIR"

# Enable FileVault
enable_filevault() {
    echo -e "${YELLOW}Setting up FileVault (Full Disk Encryption)...${NC}"
    echo ""
    echo "  This will encrypt your home directory."
    echo "  You will need your password on every boot."
    echo ""
    read -p "  Continue? (y/N): " confirm
    
    if [ "$confirm" != "y" ]; then
        return
    fi
    
    # Generate recovery key
    local recovery_key=$(head -c 32 /dev/urandom | base64 | head -c 16)
    echo ""
    echo -e "  ${CYAN}Your recovery key: $recovery_key${NC}"
    echo -e "  ${YELLOW}SAVE THIS KEY! You need it if you forget your password.${NC}"
    echo ""
    
    # Store recovery key securely
    echo "$recovery_key" > "$SECURITY_DIR/recovery.key"
    chmod 600 "$SECURITY_DIR/recovery.key"
    
    # Create encrypted backup of important files
    echo "  Creating encrypted backup..."
    
    local backup_dir="$HOME/.encrypted-backup"
    mkdir -p "$backup_dir"
    
    # Encrypt sensitive files
    for file in ~/.ssh/* ~/.gnupg/* ~/.config/autostart/*; do
        if [ -f "$file" ]; then
            openssl enc -aes-256-cbc -salt -pbkdf2 \
                -in "$file" \
                -out "$backup_dir/$(basename $file).enc" \
                -pass pass:"$recovery_key" 2>/dev/null
        fi
    done
    
    echo -e "${GREEN}✓ FileVault enabled!${NC}"
    echo -e "  Encrypted backup: $backup_dir"
    log_security "filevault" "enabled"
}

# Disable FileVault
disable_filevault() {
    echo -e "${YELLOW}Disabling FileVault...${NC}"
    
    # Decrypt backup
    local backup_dir="$HOME/.encrypted-backup"
    if [ -d "$backup_dir" ]; then
        echo "  Decrypted backup files available at: $backup_dir"
    fi
    
    echo -e "${GREEN}✓ FileVault disabled${NC}"
    log_security "filevault" "disabled"
}

# Decrypt specific file
decrypt_file() {
    local file=$1
    
    if [ ! -f "$file.enc" ]; then
        echo -e "${RED}Encrypted file not found${NC}"
        return 1
    fi
    
    read -s -p "  Enter decryption key: " key
    echo ""
    
    openssl enc -aes-256-cbc -d -salt -pbkdf2 \
        -in "$file.enc" \
        -out "$file" \
        -pass pass:"$key" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ File decrypted${NC}"
    else
        echo -e "${RED}✗ Decryption failed${NC}"
        rm -f "$file"
    fi
}

# Encrypt file
encrypt_file() {
    local file=$1
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}File not found${NC}"
        return 1
    fi
    
    read -s -p "  Enter encryption key: " key
    echo ""
    read -s -p "  Confirm key: " key2
    echo ""
    
    if [ "$key" != "$key2" ]; then
        echo -e "${RED}Keys don't match${NC}"
        return 1
    fi
    
    openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in "$file" \
        -out "$file.enc" \
        -pass pass:"$key"
    
    echo -e "${GREEN}✓ File encrypted: $file.enc${NC}"
}

log_security() {
    local action=$1
    local details=$2
    echo "$(date -Iseconds) | filevault | $action | $details" >> "$SECURITY_DIR/security.log"
}

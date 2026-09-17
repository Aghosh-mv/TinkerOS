#!/usr/bin/env bash
# korrinos-backup.sh — Quick backup tool for KorrinOS
# Backs up user config, dotfiles, and selected directories

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/share/korrinos/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

cmd_backup_dotfiles() {
    local dest="$BACKUP_DIR/dotfiles_$TIMESTAMP.tar.gz"
    echo "Backing up dotfiles..."
    
    tar czf "$dest" \
        -C "$HOME" \
        .bashrc .bash_profile .profile \
        .gitconfig .gitignore_global \
        .vimrc .tmux.conf \
        .config/vokk \
        .config/korrinos \
        2>/dev/null || true
    
    echo "Dotfiles backed up: $dest"
    du -sh "$dest"
}

cmd_backup_configs() {
    local dest="$BACKUP_DIR/configs_$TIMESTAMP.tar.gz"
    echo "Backing up system configs..."
    
    sudo tar czf "$dest" \
        /etc/fstab \
        /etc/hostname \
        /etc/hosts \
        /etc/resolv.conf \
        /etc/systemd/system/*.service \
        /etc/korrinos \
        2>/dev/null || true
    
    echo "Configs backed up: $dest"
    du -sh "$dest"
}

cmd_backup_kernel() {
    local dest="$BACKUP_DIR/kernel_$TIMESTAMP.tar.gz"
    echo "Backing up kernel modules..."
    
    tar czf "$dest" \
        -C "$(dirname "$(readlink -f "$0")")/../.." \
        kernel/tinker/ \
        os/parc-ai/modules/ \
        os/parc-ai/model/checkpoints/ \
        2>/dev/null || true
    
    echo "Kernel backed up: $dest"
    du -sh "$dest"
}

cmd_backup_full() {
    local dest="$BACKUP_DIR/full_$TIMESTAMP.tar.gz"
    local src="${2:-$HOME}"
    echo "Full backup of $src..."
    
    tar czf "$dest" \
        --exclude='*.o' \
        --exclude='*.pyc' \
        --exclude='.cache' \
        --exclude='node_modules' \
        -C "$(dirname "$src")" \
        "$(basename "$src")" \
        2>/dev/null || true
    
    echo "Full backup: $dest"
    du -sh "$dest"
}

cmd_list() {
    echo "=== Backups ==="
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No backups found"
    echo ""
    echo "Total: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)"
}

cmd_restore() {
    local backup="$1"
    local target="${2:-$HOME}"
    
    if [ ! -f "$backup" ]; then
        echo "Backup not found: $backup"
        return 1
    fi
    
    echo "Restoring $backup to $target..."
    tar xzf "$backup" -C "$target"
    echo "Restored!"
}

case "${1:-help}" in
    dotfiles)   cmd_backup_dotfiles ;;
    configs)    cmd_backup_configs ;;
    kernel)     cmd_backup_kernel ;;
    full)       cmd_backup_full "${2:-}" ;;
    list)       cmd_list ;;
    restore)    cmd_restore "${2:-}" "${3:-$HOME}" ;;
    *)
        echo "KorrinOS Backup Tool"
        echo "Usage: korrinos-backup.sh <command>"
        echo ""
        echo "Commands:"
        echo "  dotfiles       Backup user dotfiles and config"
        echo "  configs        Backup system configs"
        echo "  kernel         Backup kernel modules and AI"
        echo "  full [dir]     Full backup of directory"
        echo "  list           List all backups"
        echo "  restore <file> Restore from backup"
        echo ""
        echo "Backups stored: $BACKUP_DIR"
        ;;
esac

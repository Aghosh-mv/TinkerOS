#!/bin/bash
# TinkerOS Backup & Restore
BACKUP_DIR="$HOME/.tinker/backups"
mkdir -p "$BACKUP_DIR"
echo "=== TinkerOS Backup & Restore ==="
echo ""
case "${1:-help}" in
    create)
        TS=$(date +%Y%m%d-%H%M%S)
        echo "Creating backup: $TS"
        tar czf "$BACKUP_DIR/home-$TS.tar.gz" -C "$HOME" . 2>/dev/null && echo "  Saved to $BACKUP_DIR/home-$TS.tar.gz"
        ;;
    list)
        echo "Available backups:"
        ls -lh "$BACKUP_DIR" 2>/dev/null | sed 's/^/  /'
        ;;
    *)
        echo "Usage: $0 {create|list}"
        echo "  create - backup home directory"
        echo "  list   - show existing backups"
        ;;
esac

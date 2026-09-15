#!/usr/bin/env bash
# korrinos-uninstall-blocker.sh — Prevents TinkerAI from being removed
# Runs as a cron job that checks and restores files

PROTECTED_DIR="/usr/local/korrinos"
SERVICE_NAME="korrinos-ai"
CHECKSUM_FILE="$PROTECTED_DIR/config/.checksums"

# Generate checksums of all installed files
generate_checksums() {
  find "$PROTECTED_DIR" -type f -exec md5sum {} \; > "$CHECKSUM_FILE"
}

# Verify files haven't been tampered with
verify_integrity() {
  if [ ! -f "$CHECKSUM_FILE" ]; then
    generate_checksums
    return 0
  fi
  
  local bad=$(cd / && md5sum -c "$CHECKSUM_FILE" 2>&1 | grep -c "FAILED" || true)
  if [ "$bad" -gt 0 ]; then
    echo "[uninstall-blocker] Detected $bad tampered files, restoring..."
    # In real KorrinOS, would restore from read-only image
    return 1
  fi
  return 0
}

# Check and restore service
check_service() {
  if ! systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
    systemctl enable "$SERVICE_NAME" 2>/dev/null
  fi
  if ! systemctl is-active "$SERVICE_NAME" &>/dev/null; then
    systemctl start "$SERVICE_NAME" 2>/dev/null
  fi
}

# Check and restore binary
check_binary() {
  if [ ! -x /usr/local/bin/korrinos-ai ]; then
    cat > /usr/local/bin/korrinos-ai << 'WRAPPER'
#!/usr/bin/env bash
exec /usr/local/korrinos/bin/tinker-ai "$@"
WRAPPER
    chmod +x /usr/local/bin/korrinos-ai
  fi
}

# Main protection loop (called by cron)
protect() {
  check_binary
  check_service
  verify_integrity
}

# If called with --protect flag, run protection
if [ "${1:-}" = "--protect" ]; then
  protect
fi

# If called with --setup-cron, install cron job
if [ "${1:-}" = "--setup-cron" ]; then
  generate_checksums
  # Check every 5 minutes
  (crontab -l 2>/dev/null | grep -v "korrinos-uninstall-blocker" ; echo "*/5 * * * * /usr/local/korrinos/config/uninstall-blocker.sh --protect >> /var/log/korrinos-protect.log 2>&1") | crontab -
  echo "Protection cron installed (every 5 min)"
fi

echo "[uninstall-blocker] loaded"

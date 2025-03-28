#!/bin/bash
set -e

# Configuration
BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
DATA_DIR="/home/meowcoin/.meowcoin"
MAX_BACKUPS=7  # Keep a week of backups

# Create timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/meowcoin_backup_$TIMESTAMP.tar.gz"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Stop the wallet to ensure consistent backup (optional based on wallet configuration)
# meowcoin-cli -conf="$DATA_DIR/meowcoin.conf" stop

echo "Starting backup at $(date)"

# Create backup excluding large/unnecessary files
tar -czf "$BACKUP_FILE" \
    --exclude="$DATA_DIR/blocks" \
    --exclude="$DATA_DIR/chainstate" \
    --exclude="$DATA_DIR/database" \
    --exclude="$DATA_DIR/backups" \
    --exclude="$DATA_DIR/debug.log" \
    "$DATA_DIR"

echo "Backup completed: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

# Clean up old backups
echo "Cleaning up old backups..."
ls -t "$BACKUP_DIR"/meowcoin_backup_*.tar.gz | tail -n +$((MAX_BACKUPS+1)) | xargs rm -f 2>/dev/null || true

echo "Backup process completed at $(date)"

# Restart wallet if it was stopped (uncomment if wallet was stopped above)
# meowcoind -conf="$DATA_DIR/meowcoin.conf"
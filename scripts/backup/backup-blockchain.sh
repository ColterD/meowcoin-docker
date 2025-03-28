# scripts/backup/backup-blockchain.sh
#!/bin/bash
set -e

# Configuration
BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
DATA_DIR="/home/meowcoin/.meowcoin"
MAX_BACKUPS="${MAX_BACKUPS:-7}"  # Default: keep a week of backups
COMPRESSION_LEVEL="${BACKUP_COMPRESSION_LEVEL:-6}"  # Default: balanced compression
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/meowcoin_backup_$TIMESTAMP.tar.gz"
LOG_FILE="$BACKUP_DIR/backup.log"

# Helper function for logging
log() {
  echo "[$(date -Iseconds)] $1" | tee -a "$LOG_FILE"
}

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

log "Starting backup process"

# Check if we have enough disk space
REQUIRED_SPACE=$(($(du -sm $DATA_DIR/wallet.dat 2>/dev/null | cut -f1) * 2))
AVAILABLE_SPACE=$(df -m $BACKUP_DIR | tail -1 | awk '{print $4}')

if [ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]; then
  log "ERROR: Not enough disk space for backup. Required: ${REQUIRED_SPACE}MB, Available: ${AVAILABLE_SPACE}MB"
  exit 1
fi

# Try to use wallet lock API if available
if command -v meowcoin-cli >/dev/null 2>&1; then
  log "Attempting to lock wallet for consistent backup"
  if meowcoin-cli -conf="$DATA_DIR/meowcoin.conf" walletlock >/dev/null 2>&1; then
    log "Wallet locked successfully"
    WALLET_LOCKED=true
  else
    log "Could not lock wallet or wallet already locked"
  fi
fi

log "Creating backup archive with compression level $COMPRESSION_LEVEL"

# Create backup excluding large/unnecessary files
tar -C / -czf "$BACKUP_FILE" --exclude="$DATA_DIR/blocks" \
  --exclude="$DATA_DIR/chainstate" \
  --exclude="$DATA_DIR/database" \
  --exclude="$DATA_DIR/backups" \
  --exclude="$DATA_DIR/debug.log" \
  --exclude="$DATA_DIR/logs" \
  --exclude="$DATA_DIR/fee_estimates.dat" \
  --options="compression-level=$COMPRESSION_LEVEL" \
  "${DATA_DIR#/}"

# Create checksum file
sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"

# Attempt to encrypt backup if encryption key provided
if [ ! -z "$BACKUP_ENCRYPTION_KEY" ]; then
  log "Encrypting backup using provided key"
  
  # Encrypt the backup
  openssl enc -aes-256-cbc -salt -in "$BACKUP_FILE" \
    -out "$BACKUP_FILE.enc" -pass pass:"$BACKUP_ENCRYPTION_KEY"
  
  # Replace original with encrypted version
  mv "$BACKUP_FILE.enc" "$BACKUP_FILE"
  
  # Update checksum
  sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"
  
  log "Backup encrypted successfully"
fi

# Get file size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "Backup completed: $BACKUP_FILE ($BACKUP_SIZE)"

# Clean up old backups
log "Cleaning up old backups (keeping $MAX_BACKUPS most recent)"
ls -t "$BACKUP_DIR"/meowcoin_backup_*.tar.gz | tail -n +$((MAX_BACKUPS+1)) | xargs rm -f 2>/dev/null || true
ls -t "$BACKUP_DIR"/meowcoin_backup_*.tar.gz.sha256 | tail -n +$((MAX_BACKUPS+1)) | xargs rm -f 2>/dev/null || true

# If backup is configured to be sent to remote storage
if [ "${BACKUP_REMOTE_ENABLED:-false}" = "true" ]; then
  log "Remote backup enabled, attempting to transfer backup"
  
  case "${BACKUP_REMOTE_TYPE}" in
    "s3")
      log "Uploading to S3 bucket ${BACKUP_S3_BUCKET}"
      # Using AWS CLI if installed
      if command -v aws >/dev/null 2>&1; then
        aws s3 cp "$BACKUP_FILE" "s3://${BACKUP_S3_BUCKET}/meowcoin_backup_$TIMESTAMP.tar.gz"
        aws s3 cp "$BACKUP_FILE.sha256" "s3://${BACKUP_S3_BUCKET}/meowcoin_backup_$TIMESTAMP.tar.gz.sha256"
        log "Upload to S3 completed"
      else
        log "ERROR: AWS CLI not found, cannot upload to S3"
      fi
      ;;
    "sftp")
      log "Uploading to SFTP server ${BACKUP_SFTP_HOST}"
      # Using scp/sftp if installed
      if command -v sftp >/dev/null 2>&1; then
        scp -i "${BACKUP_SFTP_KEY}" "$BACKUP_FILE" "${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}/"
        scp -i "${BACKUP_SFTP_KEY}" "$BACKUP_FILE.sha256" "${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}/"
        log "Upload to SFTP completed"
      else
        log "ERROR: SFTP client not found, cannot upload to SFTP server"
      fi
      ;;
    *)
      log "Unknown or unspecified remote backup type: ${BACKUP_REMOTE_TYPE}"
      ;;
  esac
fi

# Unlock wallet if it was locked by this script
if [ "$WALLET_LOCKED" = true ]; then
  log "Unlocking wallet"
  meowcoin-cli -conf="$DATA_DIR/meowcoin.conf" walletpassphrase "$WALLET_PASSPHRASE" 0 true >/dev/null 2>&1 || true
fi

log "Backup process completed successfully"
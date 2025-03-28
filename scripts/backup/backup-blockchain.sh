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
TRACE_ID="${TRACE_ID:-$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)}"

# Helper function for logging
log() {
  echo "[$TRACE_ID][$(date -Iseconds)] $1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
  local EXIT_CODE=$1
  local ERROR_MESSAGE=$2
  local ERROR_SOURCE=${3:-"backup-blockchain.sh"}
  
  log "ERROR [$ERROR_SOURCE]: $ERROR_MESSAGE (exit code: $EXIT_CODE)"
  
  # Send alert if monitoring is configured
  if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
    /usr/local/bin/monitoring/send-alert.sh "Backup error: $ERROR_MESSAGE" "backup_error" "error"
  fi
  
  # Exit if this is a critical error
  if [ $EXIT_CODE -gt 100 ]; then
    execute_hook "backup_error" "$ERROR_MESSAGE" "$EXIT_CODE"
    exit $EXIT_CODE
  fi
  
  return $EXIT_CODE
}

# Function to execute hooks
execute_hook() {
  local HOOK_NAME="$1"
  shift
  
  if [ -x /usr/local/bin/entrypoint/plugins.sh ]; then
    TRACE_ID="$TRACE_ID" HOOK_ARGS="$@" /usr/local/bin/entrypoint/plugins.sh execute_hooks "$HOOK_NAME"
  fi
}

# Function to retry operations with exponential backoff
retry_operation() {
  local CMD="$1"
  local MAX_ATTEMPTS="${2:-3}"
  local ATTEMPT=1
  local DELAY="${3:-5}"
  local TIMEOUT="${4:-60}"
  
  while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log "Executing operation (attempt $ATTEMPT/$MAX_ATTEMPTS): $CMD"
    
    # Use timeout to prevent hanging commands
    timeout $TIMEOUT bash -c "$CMD" && return 0
    
    local EXIT_CODE=$?
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
      log "Operation failed after $MAX_ATTEMPTS attempts"
      return $EXIT_CODE
    fi
    
    log "Attempt $ATTEMPT failed (exit code: $EXIT_CODE), retrying in $DELAY seconds..."
    sleep $DELAY
    ATTEMPT=$((ATTEMPT + 1))
    DELAY=$((DELAY * 2))  # Exponential backoff
  done
  
  return 1
}

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR" || handle_error $? "Failed to create backup directory"
chmod 750 "$BACKUP_DIR"
chown meowcoin:meowcoin "$BACKUP_DIR"

log "Starting backup process"

# Execute pre-backup hook
execute_hook "backup_pre"

# Check if we have enough disk space
REQUIRED_SPACE=$(($(du -sm $DATA_DIR/wallet.dat 2>/dev/null | cut -f1) * 2))
AVAILABLE_SPACE=$(df -m $BACKUP_DIR | tail -1 | awk '{print $4}')

if [ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]; then
  handle_error 101 "Not enough disk space for backup. Required: ${REQUIRED_SPACE}MB, Available: ${AVAILABLE_SPACE}MB"
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
  "${DATA_DIR#/}" || handle_error $? "Backup creation failed"

# Create checksum file
sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256" || handle_error $? "Failed to create checksum file"

# Validate backup file integrity
if ! tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
  handle_error 102 "Backup file integrity check failed"
  rm -f "$BACKUP_FILE" "$BACKUP_FILE.sha256"
  exit 1
fi

# Attempt to encrypt backup if encryption key provided
if [ ! -z "$BACKUP_ENCRYPTION_KEY" ]; then
  log "Encrypting backup using provided key"
  
  # Validate encryption key format
  if [[ ! "$BACKUP_ENCRYPTION_KEY" =~ ^[a-zA-Z0-9_\-\.]+$ ]]; then
    handle_error 103 "Invalid encryption key format"
    exit 1
  fi
  
  # Create temporary keyfile with restricted permissions
  KEY_FILE=$(mktemp)
  chmod 600 "$KEY_FILE"
  echo -n "$BACKUP_ENCRYPTION_KEY" > "$KEY_FILE"
  
  # Encrypt the backup
  if openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "$BACKUP_FILE" \
       -out "$BACKUP_FILE.enc" -pass file:"$KEY_FILE"; then
    
    # Replace original with encrypted version
    mv "$BACKUP_FILE.enc" "$BACKUP_FILE"
    
    # Update checksum
    sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"
    
    log "Backup encrypted successfully"
  else
    handle_error 104 "Backup encryption failed"
    # Clean up failed encryption attempt
    rm -f "$BACKUP_FILE.enc"
  fi
  
  # Securely delete the key file
  shred -u "$KEY_FILE" || rm -f "$KEY_FILE"
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
      if [ -z "${BACKUP_S3_BUCKET}" ]; then
        handle_error 105 "S3 bucket not specified for remote backup"
      else
        log "Uploading to S3 bucket ${BACKUP_S3_BUCKET}"
        # Using AWS CLI if installed
        if command -v aws >/dev/null 2>&1; then
          # Set upload timeout and retry policy
          export AWS_MAX_ATTEMPTS=5
          export AWS_RETRY_MODE=adaptive
          
          # Upload main file with retry
          retry_operation "aws s3 cp \"$BACKUP_FILE\" \"s3://${BACKUP_S3_BUCKET}/meowcoin_backup_$TIMESTAMP.tar.gz\" --metadata \"trace_id=$TRACE_ID,timestamp=$(date -Iseconds)\"" 3 60 1800
          
          # Upload checksum file
          retry_operation "aws s3 cp \"$BACKUP_FILE.sha256\" \"s3://${BACKUP_S3_BUCKET}/meowcoin_backup_$TIMESTAMP.tar.gz.sha256\" --metadata \"trace_id=$TRACE_ID,timestamp=$(date -Iseconds)\"" 3 60 300
          
          # Verify upload
          if aws s3 ls "s3://${BACKUP_S3_BUCKET}/meowcoin_backup_$TIMESTAMP.tar.gz" >/dev/null 2>&1; then
            log "Upload to S3 verified"
          else
            handle_error 106 "Upload to S3 could not be verified"
          fi
        else
          handle_error 107 "AWS CLI not found, cannot upload to S3"
        fi
      fi
      ;;
    "sftp")
      if [ -z "${BACKUP_SFTP_HOST}" ] || [ -z "${BACKUP_SFTP_USER}" ]; then
        handle_error 108 "SFTP host or user not specified for remote backup"
      else
        log "Uploading to SFTP server ${BACKUP_SFTP_HOST}"
        # Using scp/sftp if installed
        if command -v sftp >/dev/null 2>&1; then
          # Setup SSH options for improved reliability
          SSH_OPTS="-o ConnectTimeout=30 -o ConnectionAttempts=3 -o ServerAliveInterval=30"
          
          # Ensure remote directory exists
          if ! retry_operation "ssh $SSH_OPTS -i \"${BACKUP_SFTP_KEY}\" \"${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}\" \"mkdir -p ${BACKUP_SFTP_PATH}\"" 3 10 120; then
            handle_error 109 "Failed to create remote directory on SFTP server"
          fi
          
          # Upload main file with retry
          retry_operation "scp $SSH_OPTS -i \"${BACKUP_SFTP_KEY}\" \"$BACKUP_FILE\" \"${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}/\"" 3 30 1800
          
          # Upload checksum file
          retry_operation "scp $SSH_OPTS -i \"${BACKUP_SFTP_KEY}\" \"$BACKUP_FILE.sha256\" \"${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}/\"" 3 10 300
          
          log "Upload to SFTP completed"
        else
          handle_error 110 "SFTP client not found, cannot upload to SFTP server"
        fi
      fi
      ;;
    *)
      handle_error 111 "Unknown or unspecified remote backup type: ${BACKUP_REMOTE_TYPE}"
      ;;
  esac
fi

# Unlock wallet if it was locked by this script
if [ "$WALLET_LOCKED" = true ]; then
  log "Unlocking wallet"
  meowcoin-cli -conf="$DATA_DIR/meowcoin.conf" walletpassphrase "$WALLET_PASSPHRASE" 0 true >/dev/null 2>&1 || handle_error $? "Failed to unlock wallet"
fi

# Execute post-backup hook
execute_hook "backup_post" "$BACKUP_FILE" "$BACKUP_SIZE"

log "Backup process completed successfully"

# Update backup status file for monitoring
STATUS_FILE="/var/lib/meowcoin/backup_status.json"
mkdir -p "$(dirname "$STATUS_FILE")"
cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_id": "$TRACE_ID",
  "backup_file": "$BACKUP_FILE",
  "backup_size": "$BACKUP_SIZE",
  "encrypted": $([ ! -z "$BACKUP_ENCRYPTION_KEY" ] && echo "true" || echo "false"),
  "remote_backup": $([ "${BACKUP_REMOTE_ENABLED:-false}" = "true" ] && echo "true" || echo "false"),
  "remote_type": "${BACKUP_REMOTE_TYPE:-none}",
  "status": "success"
}
EOF

exit 0
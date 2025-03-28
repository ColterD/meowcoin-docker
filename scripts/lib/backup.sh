#!/bin/bash
# Backup utilities for Meowcoin Docker
# Standardizes backup creation, verification, and recovery

# Source common utilities
source /usr/local/bin/lib/utils.sh

# Default paths
BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
DATA_DIR="/home/meowcoin/.meowcoin"
BACKUP_LOG="/var/log/meowcoin/backup.log"
BACKUP_STATUS_FILE="/home/meowcoin/.meowcoin/.backup_status"
BACKUP_MANIFEST_FILE="/home/meowcoin/.meowcoin/.backup_manifest"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
MAX_PARALLEL_UPLOADS="${MAX_PARALLEL_UPLOADS:-2}"

# Initialize backup system
function init_backup_system() {
  mkdir -p "$BACKUP_DIR"
  mkdir -p "$(dirname $BACKUP_LOG)"
  touch $BACKUP_LOG
  
  # Set correct permissions
  chmod 750 "$BACKUP_DIR"
  chown meowcoin:meowcoin "$BACKUP_DIR"
  chown meowcoin:meowcoin "$BACKUP_LOG"
  
  log "Backup system initialized" "INFO"
}

# Setup backup features with improved reliability
function setup_backup_features() {
  # Configure automatic backups if enabled
  if [ "${ENABLE_BACKUPS:-false}" = "true" ]; then
    setup_automated_backups
  fi
  
  return 0
}

# Setup automated blockchain backups with enhanced features
function setup_automated_backups() {
  log "Setting up automated blockchain backups" "INFO"
  
  # Create backup directory with secure permissions
  mkdir -p "$BACKUP_DIR"
  chmod 750 "$BACKUP_DIR"
  chown meowcoin:meowcoin "$BACKUP_DIR"
  
  # Create metadata directory for backup verification
  BACKUP_META_DIR="/home/meowcoin/.meowcoin/backup-metadata"
  mkdir -p "$BACKUP_META_DIR"
  chmod 750 "$BACKUP_META_DIR"
  chown meowcoin:meowcoin "$BACKUP_META_DIR"
  
  # Set up backup configuration with more robust scheduling
  BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 0 * * *}"  # Default: midnight daily
  BACKUP_SCRIPT="/usr/local/bin/lib/backup.sh create_backup"
  
  # Create proper cron job file with environment variables
  if [ -d "/etc/cron.d" ]; then
    cat > /etc/cron.d/meowcoin-backup <<EOF
# Meowcoin automated backup
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
HOME=/home/meowcoin

# Environment variables for backup
BACKUP_COMPRESSION_LEVEL=${BACKUP_COMPRESSION_LEVEL:-6}
MAX_BACKUPS=${MAX_BACKUPS:-7}
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS}
BACKUP_REMOTE_ENABLED=${BACKUP_REMOTE_ENABLED:-false}
BACKUP_REMOTE_TYPE=${BACKUP_REMOTE_TYPE}
BACKUP_S3_BUCKET=${BACKUP_S3_BUCKET}
BACKUP_S3_PREFIX=${BACKUP_S3_PREFIX:-meowcoin-backups}
BACKUP_S3_REGION=${BACKUP_S3_REGION:-us-east-1}
BACKUP_SFTP_HOST=${BACKUP_SFTP_HOST}
BACKUP_SFTP_USER=${BACKUP_SFTP_USER}
BACKUP_SFTP_PATH=${BACKUP_SFTP_PATH}
BACKUP_SFTP_PORT=${BACKUP_SFTP_PORT:-22}
BACKUP_ENCRYPTION_KEY=${BACKUP_ENCRYPTION_KEY}
BACKUP_VERIFY=${BACKUP_VERIFY:-true}

# Backup schedule
$BACKUP_SCHEDULE meowcoin $BACKUP_SCRIPT > $BACKUP_LOG 2>&1

# Add secondary backup schedule for redundancy (if enabled)
${BACKUP_SECONDARY_SCHEDULE:+$BACKUP_SECONDARY_SCHEDULE meowcoin $BACKUP_SCRIPT secondary > $BACKUP_LOG 2>&1}

# Backup verification and maintenance
0 1 * * * meowcoin /usr/local/bin/lib/backup.sh verify_backups > $BACKUP_LOG 2>&1
0 2 * * * meowcoin /usr/local/bin/lib/backup.sh cleanup_backups > $BACKUP_LOG 2>&1
EOF
    chmod 644 /etc/cron.d/meowcoin-backup
    log "Automatic backups scheduled: $BACKUP_SCHEDULE" "INFO"
    
    # Secondary backup schedule if configured
    if [ ! -z "${BACKUP_SECONDARY_SCHEDULE}" ]; then
      log "Secondary backups scheduled: $BACKUP_SECONDARY_SCHEDULE" "INFO"
    fi
    
    log "Backup retention set to ${MAX_BACKUPS:-7} backups and ${BACKUP_RETENTION_DAYS} days" "INFO"
    log "Backup compression level set to ${BACKUP_COMPRESSION_LEVEL:-6}" "INFO"
  else
    log "Cron not available, cannot schedule backups" "WARNING"
  fi
  
  # Setup remote backup if enabled
  if [ "${BACKUP_REMOTE_ENABLED:-false}" = "true" ]; then
    setup_remote_backup
  fi
  
  return 0
}

# Setup remote backup integration
function setup_remote_backup() {
  log "Remote backup enabled with type: ${BACKUP_REMOTE_TYPE}" "INFO"
  
  case "${BACKUP_REMOTE_TYPE}" in
    "s3")
      setup_s3_backup
      ;;
    "sftp")
      setup_sftp_backup
      ;;
    *)
      log "Unknown or unspecified remote backup type: ${BACKUP_REMOTE_TYPE}" "WARNING"
      ;;
  esac
}

# Setup S3 backup integration
function setup_s3_backup() {
  if [ -z "${BACKUP_S3_BUCKET}" ]; then
    log "S3 bucket not specified for remote backup" "ERROR"
    return 1
  fi
  
  log "Configured S3 remote backup to bucket: ${BACKUP_S3_BUCKET}" "INFO"
  
  # Install AWS CLI if needed and not already present
  if ! command -v aws >/dev/null 2>&1; then
    log "Installing AWS CLI for S3 backups" "INFO"
    apk add --no-cache aws-cli
  fi
  
  # Create S3 sync utility script
  cat > /usr/local/bin/utils/s3-sync.sh <<EOF
#!/bin/bash
# Script to sync backups to S3

BACKUP_DIR="$BACKUP_DIR"
S3_BUCKET="${BACKUP_S3_BUCKET}"
S3_PREFIX="${BACKUP_S3_PREFIX:-meowcoin-backups}"
S3_REGION="${BACKUP_S3_REGION:-us-east-1}"
LOG_FILE="$BACKUP_LOG"

echo "[\$(date -Iseconds)] Starting S3 backup sync" >> "\$LOG_FILE"

# Only sync files we haven't already synced
find "\$BACKUP_DIR" -name "*.tar.gz" | while read file; do
  filename=\$(basename "\$file")
  if [ ! -f "\$BACKUP_DIR/.\$filename.s3synced" ]; then
    echo "[\$(date -Iseconds)] Syncing \$filename to S3" >> "\$LOG_FILE"
    
    # Upload file with metadata
    if aws s3 cp "\$file" "s3://\$S3_BUCKET/\$S3_PREFIX/\$filename" \\
       --region "\$S3_REGION" \\
       --metadata "timestamp=\$(date -Iseconds),hostname=\$(hostname)" \\
       --expected-size \$(stat -c%s "\$file"); then
      
      # Also upload checksum file
      if [ -f "\$file.sha256" ]; then
        aws s3 cp "\$file.sha256" "s3://\$S3_BUCKET/\$S3_PREFIX/\$filename.sha256" --region "\$S3_REGION"
      fi

      # Mark as synced
      touch "\$BACKUP_DIR/.\$filename.s3synced"
      echo "[\$(date -Iseconds)] ✓ Successfully synced \$filename to S3" >> "\$LOG_FILE"
    else
      echo "[\$(date -Iseconds)] ✗ Failed to sync \$filename to S3" >> "\$LOG_FILE"
    fi
  fi
done

# Verify remote backups if enabled
if [ "${BACKUP_VERIFY_REMOTE:-true}" = "true" ]; then
  echo "[\$(date -Iseconds)] Verifying remote backups" >> "\$LOG_FILE"
  
  # List files in bucket to verify they exist
  aws s3 ls "s3://\$S3_BUCKET/\$S3_PREFIX/" --region "\$S3_REGION" > "/tmp/s3-files.txt"
  
  # Check for each local synced file
  find "\$BACKUP_DIR" -name ".*.s3synced" | while read syncfile; do
    filename=\$(basename "\$syncfile" | sed 's/^\\.//')
    if grep -q "\$filename" "/tmp/s3-files.txt"; then
      echo "[\$(date -Iseconds)] ✓ Verified \$filename exists in S3" >> "\$LOG_FILE"
    else
      echo "[\$(date -Iseconds)] ✗ File \$filename missing from S3" >> "\$LOG_FILE"
      # Remove sync marker to retry upload
      rm "\$syncfile"
    fi
  done
  
  rm -f "/tmp/s3-files.txt"
fi

# Check bucket lifecycle policy if configured
if [ "${BACKUP_S3_LIFECYCLE_CHECK:-true}" = "true" ]; then
  echo "[\$(date -Iseconds)] Checking S3 bucket lifecycle policy" >> "\$LOG_FILE"
  if ! aws s3api get-bucket-lifecycle-configuration --bucket "\$S3_BUCKET" --region "\$S3_REGION" >/dev/null 2>&1; then
    echo "[\$(date -Iseconds)] Warning: No lifecycle policy configured for S3 bucket" >> "\$LOG_FILE"
    echo "[\$(date -Iseconds)] Recommend setting up a lifecycle policy to manage remote backup retention" >> "\$LOG_FILE"
  fi
fi

echo "[\$(date -Iseconds)] S3 backup sync completed" >> "\$LOG_FILE"
EOF
  
  chmod +x /usr/local/bin/utils/s3-sync.sh
  
  # Schedule S3 sync after backups if cron available
  if [ -f "/etc/cron.d/meowcoin-backup" ]; then
    echo "30 0 * * * meowcoin /usr/local/bin/utils/s3-sync.sh > /var/log/meowcoin/s3-sync.log 2>&1" >> /etc/cron.d/meowcoin-backup
  fi
  
  return 0
}

# Setup SFTP backup integration
function setup_sftp_backup() {
  if [ -z "${BACKUP_SFTP_HOST}" ] || [ -z "${BACKUP_SFTP_USER}" ]; then
    log "SFTP host or user not specified for remote backup" "ERROR"
    return 1
  fi
  
  log "Configured SFTP remote backup to ${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}" "INFO"
  
  # Install SFTP client if needed
  if ! command -v sftp >/dev/null 2>&1; then
    log "Installing SFTP client for backups" "INFO"
    apk add --no-cache openssh-client
  fi
  
  # Set up SSH directory
  mkdir -p /home/meowcoin/.ssh
  chmod 700 /home/meowcoin/.ssh
  chown meowcoin:meowcoin /home/meowcoin/.ssh
  
  # Generate SSH key if it doesn't exist
  if [ ! -f "/home/meowcoin/.ssh/id_ed25519" ] && [ -z "${BACKUP_SFTP_KEY}" ]; then
    log "Generating SSH key for SFTP backups" "INFO"
    ssh-keygen -t ed25519 -f /home/meowcoin/.ssh/id_ed25519 -N "" -C "meowcoin-backup"
    chown meowcoin:meowcoin /home/meowcoin/.ssh/id_ed25519*
    log "SSH public key for SFTP setup:" "INFO"
    cat /home/meowcoin/.ssh/id_ed25519.pub | tee -a $LOG_FILE
  fi
  
  # Create SFTP sync utility script
  cat > /usr/local/bin/utils/sftp-sync.sh <<EOF
#!/bin/bash
# Script to sync backups to SFTP server

BACKUP_DIR="$BACKUP_DIR"
SFTP_HOST="${BACKUP_SFTP_HOST}"
SFTP_USER="${BACKUP_SFTP_USER}"
SFTP_PORT="${BACKUP_SFTP_PORT:-22}"
SFTP_PATH="${BACKUP_SFTP_PATH:-/backups}"
SSH_KEY="/home/meowcoin/.ssh/id_ed25519"
LOG_FILE="$BACKUP_LOG"
MAX_PARALLEL_UPLOADS=${MAX_PARALLEL_UPLOADS}

echo "[\$(date -Iseconds)] Starting SFTP backup sync" >> "\$LOG_FILE"

# Create list of files to sync
find "\$BACKUP_DIR" -name "*.tar.gz" | while read file; do
  filename=\$(basename "\$file")
  if [ ! -f "\$BACKUP_DIR/.\$filename.sftpsynced" ]; then
    echo "\$file" >> /tmp/sftp-files-to-sync.txt
  fi
done

if [ ! -f "/tmp/sftp-files-to-sync.txt" ] || [ ! -s "/tmp/sftp-files-to-sync.txt" ]; then
  echo "[\$(date -Iseconds)] No files to sync" >> "\$LOG_FILE"
  rm -f /tmp/sftp-files-to-sync.txt
  exit 0
fi

# Make sure remote directory exists
sftp -i "\$SSH_KEY" -P "\$SFTP_PORT" -o StrictHostKeyChecking=no -o BatchMode=yes "\$SFTP_USER@\$SFTP_HOST" << EOF >/dev/null 2>&1
  mkdir -p "\$SFTP_PATH"
  bye
EOF

# Use background processes to upload multiple files in parallel
cat /tmp/sftp-files-to-sync.txt | while read file; do
  # Limit parallel uploads
  while [ \$(jobs -p | wc -l) -ge "\$MAX_PARALLEL_UPLOADS" ]; do
    sleep 1
  done
  
  filename=\$(basename "\$file")
  echo "[\$(date -Iseconds)] Uploading \$filename to SFTP" >> "\$LOG_FILE"
  
  # Upload in background
  (
    if sftp -i "\$SSH_KEY" -P "\$SFTP_PORT" -o StrictHostKeyChecking=no -o BatchMode=yes "\$SFTP_USER@\$SFTP_HOST" << EOF >/dev/null 2>&1
      put "\$file" "\$SFTP_PATH/\$filename"
      put "\$file.sha256" "\$SFTP_PATH/\$filename.sha256"
      bye
EOF
    then
      touch "\$BACKUP_DIR/.\$filename.sftpsynced"
      echo "[\$(date -Iseconds)] ✓ Successfully uploaded \$filename to SFTP" >> "\$LOG_FILE"
    else
      echo "[\$(date -Iseconds)] ✗ Failed to upload \$filename to SFTP" >> "\$LOG_FILE"
    fi
  ) &
done

# Wait for all uploads to complete
wait

# Clean up
rm -f /tmp/sftp-files-to-sync.txt

echo "[\$(date -Iseconds)] SFTP backup sync completed" >> "\$LOG_FILE"
EOF
  
  chmod +x /usr/local/bin/utils/sftp-sync.sh
  
  # Schedule SFTP sync after backups if cron available
  if [ -f "/etc/cron.d/meowcoin-backup" ]; then
    echo "30 0 * * * meowcoin /usr/local/bin/utils/sftp-sync.sh > /var/log/meowcoin/sftp-sync.log 2>&1" >> /etc/cron.d/meowcoin-backup
  fi
  
  return 0
}

# Create a backup
function create_backup() {
  local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  local BACKUP_FILE="$BACKUP_DIR/meowcoin_backup_$TIMESTAMP.tar.gz"
  local SECONDARY="${1:-primary}"
  
  log "Starting backup process (type: $SECONDARY)" "INFO"
  
  # Execute pre-backup hook
  if type plugin_execute_hook >/dev/null 2>&1; then
    plugin_execute_hook "backup_pre"
  fi
  
  # Check available disk space
  local REQUIRED_SPACE=$(($(du -sm $DATA_DIR/wallet.dat 2>/dev/null | cut -f1) * 2))
  local AVAILABLE_SPACE=$(df -m $BACKUP_DIR | tail -1 | awk '{print $4}')
  
  if [ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]; then
    log "Not enough disk space for backup. Required: ${REQUIRED_SPACE}MB, Available: ${AVAILABLE_SPACE}MB" "ERROR"
    send_alert "backup_space" "Not enough disk space for backup" "critical"
    return 1
  fi
  
  # Try to use wallet lock API if available
  local WALLET_LOCKED=false
  if command -v meowcoin-cli >/dev/null 2>&1; then
    log "Attempting to lock wallet for consistent backup" "INFO"
    if meowcoin-cli -conf="$DATA_DIR/meowcoin.conf" walletlock >/dev/null 2>&1; then
      log "Wallet locked successfully" "INFO"
      WALLET_LOCKED=true
    else
      log "Could not lock wallet or wallet already locked" "INFO"
    fi
  fi
  
  log "Creating backup archive with compression level ${BACKUP_COMPRESSION_LEVEL:-6}" "INFO"
  
  # Create backup with detailed error handling
  if ! tar -C / -czf "$BACKUP_FILE" --exclude="$DATA_DIR/blocks" \
    --exclude="$DATA_DIR/chainstate" \
    --exclude="$DATA_DIR/database" \
    --exclude="$DATA_DIR/backups" \
    --exclude="$DATA_DIR/debug.log" \
    --exclude="$DATA_DIR/logs" \
    --exclude="$DATA_DIR/fee_estimates.dat" \
    --options="compression-level=${BACKUP_COMPRESSION_LEVEL:-6}" \
    "${DATA_DIR#/}"; then
    
    local ERROR_CODE=$?
    case $ERROR_CODE in
      1) log "Non-fatal error during backup creation - some files may have changed during backup" "WARNING" ;;
      2) log "Fatal error during backup creation - backup is likely incomplete or corrupted" "ERROR" ;;
      *) log "Backup creation failed with code $ERROR_CODE" "ERROR" ;;
    esac
    
    # For any error, attempt to clean up
    log "Removing failed backup file" "WARNING"
    rm -f "$BACKUP_FILE" 2>/dev/null || true
    
    # Send alert
    send_alert "backup_failed" "Backup creation failed with code $ERROR_CODE" "critical"
    
    # Execute error hook
    if type plugin_execute_hook >/dev/null 2>&1; then
      plugin_execute_hook "backup_error" "$ERROR_CODE"
    fi
    
    return 1
  fi
  
  # Create and verify checksum file
  if ! sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"; then
    log "Failed to create checksum file" "ERROR"
    send_alert "backup_checksum" "Failed to create backup checksum" "warning"
    return 1
  fi
  
  # Validate backup file integrity
  if ! tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
    log "Backup file integrity check failed" "ERROR"
    rm -f "$BACKUP_FILE" "$BACKUP_FILE.sha256"
    send_alert "backup_integrity" "Backup integrity check failed" "critical"
    return 1
  fi
  
  # Attempt to encrypt backup if encryption key provided
  if [ ! -z "$BACKUP_ENCRYPTION_KEY" ]; then
    encrypt_backup "$BACKUP_FILE" "$BACKUP_ENCRYPTION_KEY"
  fi
  
  # Get file size and record success
  local BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  log "Backup completed: $BACKUP_FILE ($BACKUP_SIZE)" "INFO"
  
  # Unlock wallet if it was locked by this script
  if [ "$WALLET_LOCKED" = true ]; then
    log "Unlocking wallet" "INFO"
    if ! meowcoin-cli -conf="$DATA_DIR/meowcoin.conf" walletpassphrase "$WALLET_PASSPHRASE" 0 true >/dev/null 2>&1; then
      log "Failed to unlock wallet" "WARNING"
    else
      log "Wallet unlocked successfully" "INFO"
    fi
  fi
  
  # Execute post-backup hook
  if type plugin_execute_hook >/dev/null 2>&1; then
    plugin_execute_hook "backup_post" "$BACKUP_FILE" "$BACKUP_SIZE"
  fi
  
  # Update backup status file for monitoring
  local STATUS_FILE="/var/lib/meowcoin/backup_status.json"
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
  
  return 0
}

# Encrypt a backup file
function encrypt_backup() {
  local BACKUP_FILE="$1"
  local ENCRYPTION_KEY="$2"
  
  log "Encrypting backup using provided key" "INFO"
  
  # Validate encryption key format
  if [[ ! "$ENCRYPTION_KEY" =~ ^[a-zA-Z0-9_\-\.]+$ ]]; then
    log "Invalid encryption key format" "WARNING"
    return 1
  fi
  
  # Create temporary keyfile with restricted permissions
  local KEY_FILE=$(mktemp)
  chmod 600 "$KEY_FILE"
  echo -n "$ENCRYPTION_KEY" > "$KEY_FILE"
  
  # Encrypt the backup with proper error handling
  if ! openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "$BACKUP_FILE" \
       -out "$BACKUP_FILE.enc" -pass file:"$KEY_FILE"; then
    local ERROR_CODE=$?
    log "Backup encryption failed with code $ERROR_CODE" "ERROR"
    # Clean up failed encryption attempt
    rm -f "$BACKUP_FILE.enc"
    shred -u "$KEY_FILE" || rm -f "$KEY_FILE"
    return 1
  fi
    
  # Replace original with encrypted version
  mv "$BACKUP_FILE.enc" "$BACKUP_FILE"
    
  # Update checksum
  sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"
    
  log "Backup encrypted successfully" "INFO"
  
  # Securely delete the key file
  shred -u "$KEY_FILE" || rm -f "$KEY_FILE"
  
  return 0
}

# Verify backup integrity
function verify_backups() {
  log "Starting backup verification" "INFO"
  
  local BACKUP_META_DIR="/home/meowcoin/.meowcoin/backup-metadata"
  mkdir -p "$BACKUP_META_DIR"
  
  # Verify all backups
  find "$BACKUP_DIR" -name "*.tar.gz" -type f | while read BACKUP_FILE; do
    local FILENAME=$(basename "$BACKUP_FILE")
    local CHECKSUM_FILE="$BACKUP_FILE.sha256"
    
    log "Verifying backup: $FILENAME" "INFO"
    
    # Check if checksum file exists
    if [ ! -f "$CHECKSUM_FILE" ]; then
      log "Checksum file missing for $FILENAME" "WARNING"
      # Generate checksum if missing
      sha256sum "$BACKUP_FILE" > "$CHECKSUM_FILE"
      log "Generated missing checksum file" "INFO"
      continue
    fi
    
    # Verify checksum
    if sha256sum -c "$CHECKSUM_FILE" >/dev/null 2>&1; then
      log "✓ Checksum verification passed for $FILENAME" "INFO"
      touch "$BACKUP_META_DIR/${FILENAME}.verified"
    else
      log "✗ CRITICAL: Checksum verification FAILED for $FILENAME" "ERROR"
      mv "$BACKUP_FILE" "$BACKUP_FILE.corrupted"
      mv "$CHECKSUM_FILE" "$CHECKSUM_FILE.corrupted"
      
      # Send alert
      send_alert "backup_corruption" "Backup corruption detected in $FILENAME" "critical"
    fi
  done
  
  # Report summary
  local TOTAL=$(find "$BACKUP_DIR" -name "*.tar.gz" -type f | wc -l)
  local VERIFIED=$(find "$BACKUP_META_DIR" -name "*.verified" -type f | wc -l)
  local CORRUPTED=$(find "$BACKUP_DIR" -name "*.corrupted" -type f | wc -l)
  
  log "Verification summary: $VERIFIED/$TOTAL backups verified, $CORRUPTED corrupted" "INFO"
  
  # Update status file
  echo "{\"timestamp\": \"$(date -Iseconds)\", \"total\": $TOTAL, \"verified\": $VERIFIED, \"corrupted\": $CORRUPTED}" > "/home/meowcoin/.meowcoin/.backup_verify_status"
  
  return 0
}

# Clean up old backups
function cleanup_backups() {
  log "Starting backup cleanup" "INFO"
  
  local MAX_BACKUPS="${MAX_BACKUPS:-7}"
  local RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
  
  # Keep at least MAX_BACKUPS latest backups
  if [ "$MAX_BACKUPS" -gt 0 ]; then
    local EXCESS_COUNT=$(find "$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" | wc -l)
    EXCESS_COUNT=$((EXCESS_COUNT - MAX_BACKUPS))
    
    if [ "$EXCESS_COUNT" -gt 0 ]; then
      log "Removing $EXCESS_COUNT excess backups based on count limit" "INFO"
      find "$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" -printf "%T@ %p\n" | sort -n | head -n $EXCESS_COUNT | cut -d' ' -f2- | while read file; do
        log "Removing old backup: $(basename "$file")" "INFO"
        rm -f "$file" "$file.sha256"
      done
    else
      log "No excess backups to remove based on count" "INFO"
    fi
  fi
  
  # Remove backups older than RETENTION_DAYS
  if [ "$RETENTION_DAYS" -gt 0 ]; then
    log "Removing backups older than $RETENTION_DAYS days" "INFO"
    find "$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" -mtime +$RETENTION_DAYS -print | while read file; do
      log "Removing aged backup: $(basename "$file")" "INFO"
      rm -f "$file" "$file.sha256"
    done
  fi
  
  # Clean up corrupted backups after 7 days
  log "Cleaning up corrupted backups older than 7 days" "INFO"
  find "$BACKUP_DIR" -name "*.corrupted" -mtime +7 -delete
  
  # Update backup manifest
  log "Updating backup manifest" "INFO"
  find "$BACKUP_DIR" -name "*.tar.gz" -printf "%T@ %p %s\n" | sort -nr > "$BACKUP_MANIFEST_FILE"
  
  local CURRENT_COUNT=$(find "$BACKUP_DIR" -name "*.tar.gz" | wc -l)
  log "Backup cleanup completed. Current backup count: $CURRENT_COUNT" "INFO"
  
  return 0
}

# Restore from backup
function restore_backup() {
  local BACKUP_FILE="$1"
  local TARGET_DIR="${2:-/home/meowcoin/.meowcoin}"
  
  log "Starting restore from backup: $BACKUP_FILE" "INFO"
  
  # Check if backup file exists
  if [ ! -f "$BACKUP_FILE" ]; then
    log "Backup file not found: $BACKUP_FILE" "ERROR"
    return 1
  fi
  
  # Check if wallet service is running
  if pgrep -x "meowcoind" > /dev/null || pgrep -x "meowcoin-qt" > /dev/null; then
    log "Meowcoin daemon is running. Please stop it before restore." "ERROR"
    return 1
  fi
  
  # Create temporary directory for extraction
  local TEMP_DIR=$(mktemp -d)
  log "Extracting backup to temporary directory: $TEMP_DIR" "INFO"
  
  # Check if backup is encrypted
  local IS_ENCRYPTED=false
  if file "$BACKUP_FILE" | grep -q "openssl"; then
    IS_ENCRYPTED=true
    log "Backup appears to be encrypted" "INFO"
    
    # Prompt for encryption key
    local ENCRYPTION_KEY=""
    if [ -z "$BACKUP_ENCRYPTION_KEY" ]; then
      read -s -p "Enter backup encryption key: " ENCRYPTION_KEY
      echo
    else
      ENCRYPTION_KEY="$BACKUP_ENCRYPTION_KEY"
    fi
    
    # Create temporary keyfile with restricted permissions
    local KEY_FILE=$(mktemp)
    chmod 600 "$KEY_FILE"
    echo -n "$ENCRYPTION_KEY" > "$KEY_FILE"
    
    # Create temporary decrypted file
    local DECRYPTED_FILE="$TEMP_DIR/backup.tar.gz"
    
    # Decrypt the backup with proper error handling
    if ! openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "$BACKUP_FILE" \
         -out "$DECRYPTED_FILE" -pass file:"$KEY_FILE"; then
      local ERROR_CODE=$?
      log "Backup decryption failed with code $ERROR_CODE" "ERROR"
      # Clean up
      rm -f "$DECRYPTED_FILE"
      shred -u "$KEY_FILE" || rm -f "$KEY_FILE"
      rm -rf "$TEMP_DIR"
      return 1
    fi
    
    # Securely delete the key file
    shred -u "$KEY_FILE" || rm -f "$KEY_FILE"
    
    # Use the decrypted file for extraction
    BACKUP_FILE="$DECRYPTED_FILE"
  fi
  
  # Extract backup
  if ! tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"; then
    log "Failed to extract backup" "ERROR"
    rm -rf "$TEMP_DIR"
    return 1
  fi
  
  # Backup the current wallet if it exists
  if [ -f "$TARGET_DIR/wallet.dat" ]; then
    local BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    log "Backing up existing wallet.dat to $TARGET_DIR/wallet.dat.backup-$BACKUP_TIMESTAMP" "INFO"
    cp "$TARGET_DIR/wallet.dat" "$TARGET_DIR/wallet.dat.backup-$BACKUP_TIMESTAMP"
  fi
  
  # Copy essential files to the target directory
  log "Copying essential files to $TARGET_DIR" "INFO"
  
  # Create target directories if they don't exist
  mkdir -p "$TARGET_DIR"
  
  # Find the extracted wallet directory path
  local EXTRACTED_DIR=$(find "$TEMP_DIR" -name ".meowcoin" -type d)
  if [ -z "$EXTRACTED_DIR" ]; then
    # Try alternative path
    EXTRACTED_DIR="$TEMP_DIR/home/meowcoin/.meowcoin"
    if [ ! -d "$EXTRACTED_DIR" ]; then
      log "Could not find extracted .meowcoin directory in backup" "ERROR"
      rm -rf "$TEMP_DIR"
      return 1
    fi
  fi
  
  # Copy wallet file
  if [ -f "$EXTRACTED_DIR/wallet.dat" ]; then
    cp "$EXTRACTED_DIR/wallet.dat" "$TARGET_DIR/"
    chmod 600 "$TARGET_DIR/wallet.dat"
    log "Restored wallet.dat" "INFO"
  else
    log "Warning: wallet.dat not found in backup" "WARNING"
  fi
  
  # Copy other important files
  for file in "meowcoin.conf" "peers.dat" "banlist.dat" "fee_estimates.dat"; do
    if [ -f "$EXTRACTED_DIR/$file" ]; then
      cp "$EXTRACTED_DIR/$file" "$TARGET_DIR/"
      log "Restored $file" "INFO"
    fi
  done
  
  # Copy keys directory if it exists
  if [ -d "$EXTRACTED_DIR/keys" ]; then
    mkdir -p "$TARGET_DIR/keys"
    cp -r "$EXTRACTED_DIR/keys"/* "$TARGET_DIR/keys/"
    chmod 700 "$TARGET_DIR/keys"
    log "Restored keys directory" "INFO"
  fi
  
  # Copy wallets directory if it exists (for descriptor wallets)
  if [ -d "$EXTRACTED_DIR/wallets" ]; then
    mkdir -p "$TARGET_DIR/wallets"
    cp -r "$EXTRACTED_DIR/wallets"/* "$TARGET_DIR/wallets/"
    log "Restored wallets directory" "INFO"
  fi
  
  # Set correct ownership
  chown -R meowcoin:meowcoin "$TARGET_DIR"
  
  # Clean up
  rm -rf "$TEMP_DIR"
  
  log "Restore completed successfully" "INFO"
  log "You may now start the Meowcoin daemon" "INFO"
  
  return 0
}

# Handle command-line arguments for direct execution
if [ "$1" = "create_backup" ]; then
  create_backup "${2:-primary}"
elif [ "$1" = "verify_backups" ]; then
  verify_backups
elif [ "$1" = "cleanup_backups" ]; then
  cleanup_backups
elif [ "$1" = "restore_backup" ]; then
  restore_backup "$2" "$3"
elif [ "$1" = "setup" ]; then
  init_backup_system
  setup_backup_features
fi

# Export functions for use in other scripts
export -f init_backup_system
export -f setup_backup_features
export -f setup_automated_backups
export -f setup_remote_backup
export -f setup_s3_backup
export -f setup_sftp_backup
export -f create_backup
export -f encrypt_backup
export -f verify_backups
export -f cleanup_backups
export -f restore_backup
#!/bin/bash
# Backup utilities for Meowcoin Docker
# Provides standardized backup creation, verification, and recovery functions

# Source common utilities if not already loaded
[[ -z "$UTILS_LOADED" ]] && source "$(dirname "$0")/utils.sh"

# Define backup system constants
BACKUP_DIR="${BACKUP_DIR:-/home/meowcoin/.meowcoin/backups}"
DATA_DIR="${DATA_DIR:-/home/meowcoin/.meowcoin}"
BACKUP_LOG="${LOG_DIR:-/var/log/meowcoin}/backup.log"
BACKUP_STATUS_FILE="$DATA_DIR/.backup_status"
BACKUP_MANIFEST_FILE="$DATA_DIR/.backup_manifest"
BACKUP_META_DIR="$DATA_DIR/backup-metadata"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
MAX_PARALLEL_UPLOADS="${MAX_PARALLEL_UPLOADS:-2}"

# Initialize backup system
function backup_init() {
    log_info "Initializing backup system"
    
    # Create necessary directories with proper permissions
    mkdir -p "$BACKUP_DIR" "$(dirname "$BACKUP_LOG")" "$BACKUP_META_DIR"
    
    # Set correct permissions
    chmod 750 "$BACKUP_DIR" "$BACKUP_META_DIR"
    chown -R meowcoin:meowcoin "$BACKUP_DIR" "$BACKUP_META_DIR"
    touch "$BACKUP_LOG"
    chown meowcoin:meowcoin "$BACKUP_LOG"
    
    log_info "Backup system initialized"
    return 0
}

# Setup backup features with improved reliability
function backup_setup() {
    log_info "Setting up backup features"
    
    # Configure automatic backups if enabled
    if [[ "${ENABLE_BACKUPS:-false}" == "true" ]]; then
        backup_setup_automated
    fi
    
    # Setup remote backup if enabled
    if [[ "${BACKUP_REMOTE_ENABLED:-false}" == "true" ]]; then
        backup_setup_remote
    fi
    
    # Check for encryption key
    if [[ -n "${BACKUP_ENCRYPTION_KEY}" ]]; then
        backup_setup_encryption
    fi
    
    log_info "Backup features setup completed"
    return 0
}

# Setup automated blockchain backups
function backup_setup_automated() {
    log_info "Setting up automated blockchain backups"
    
    # Set up backup configuration
    BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 0 * * *}"  # Default: midnight daily
    BACKUP_SCRIPT="/usr/local/bin/jobs/backup.sh"
    
    # Create proper cron job file with environment variables
    if [[ -d "/etc/cron.d" ]]; then
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
$BACKUP_SCHEDULE meowcoin $BACKUP_SCRIPT create > $BACKUP_LOG 2>&1

# Add secondary backup schedule for redundancy (if enabled)
${BACKUP_SECONDARY_SCHEDULE:+$BACKUP_SECONDARY_SCHEDULE meowcoin $BACKUP_SCRIPT create secondary > $BACKUP_LOG 2>&1}

# Backup verification and maintenance
0 1 * * * meowcoin $BACKUP_SCRIPT verify > $BACKUP_LOG 2>&1
0 2 * * * meowcoin $BACKUP_SCRIPT cleanup > $BACKUP_LOG 2>&1
EOF
        chmod 644 /etc/cron.d/meowcoin-backup
        log_info "Automatic backups scheduled: $BACKUP_SCHEDULE"
        
        # Secondary backup schedule if configured
        if [[ -n "${BACKUP_SECONDARY_SCHEDULE}" ]]; then
            log_info "Secondary backups scheduled: $BACKUP_SECONDARY_SCHEDULE"
        fi
        
        log_info "Backup retention set to ${MAX_BACKUPS:-7} backups and ${BACKUP_RETENTION_DAYS} days"
        log_info "Backup compression level set to ${BACKUP_COMPRESSION_LEVEL:-6}"
    else
        log_warning "Cron not available, cannot schedule backups"
    fi
    
    return 0
}

# Setup remote backup integration
function backup_setup_remote() {
    log_info "Setting up remote backup with type: ${BACKUP_REMOTE_TYPE}"
    
    case "${BACKUP_REMOTE_TYPE}" in
        "s3")
            backup_setup_s3
            ;;
        "sftp")
            backup_setup_sftp
            ;;
        *)
            log_warning "Unknown or unspecified remote backup type: ${BACKUP_REMOTE_TYPE}"
            ;;
    esac
}

# Setup S3 backup integration
function backup_setup_s3() {
    if [[ -z "${BACKUP_S3_BUCKET}" ]]; then
        log_error "S3 bucket not specified for remote backup"
        return 1
    fi
    
    log_info "Configuring S3 remote backup to bucket: ${BACKUP_S3_BUCKET}"
    
    # Install AWS CLI if needed and not already present
    if ! command -v aws >/dev/null 2>&1; then
        log_info "Installing AWS CLI for S3 backups"
        apk add --no-cache aws-cli
    fi
    
    # Create S3 sync utility script
    mkdir -p /usr/local/bin/utils
    cat > /usr/local/bin/utils/s3-sync.sh <<EOF
#!/bin/bash
# Script to sync backups to S3

source /usr/local/bin/core/utils.sh

BACKUP_DIR="$BACKUP_DIR"
S3_BUCKET="\${BACKUP_S3_BUCKET:-${BACKUP_S3_BUCKET}}"
S3_PREFIX="\${BACKUP_S3_PREFIX:-meowcoin-backups}"
S3_REGION="\${BACKUP_S3_REGION:-us-east-1}"
LOG_FILE="$BACKUP_LOG"

log_info "Starting S3 backup sync"

# Only sync files we haven't already synced
find "\$BACKUP_DIR" -name "*.tar.gz" | while read file; do
  filename=\$(basename "\$file")
  if [[ ! -f "\$BACKUP_DIR/.\$filename.s3synced" ]]; then
    log_info "Syncing \$filename to S3"
    
    # Upload file with metadata
    if aws s3 cp "\$file" "s3://\$S3_BUCKET/\$S3_PREFIX/\$filename" \\
       --region "\$S3_REGION" \\
       --metadata "timestamp=\$(date -Iseconds),hostname=\$(hostname)" \\
       --expected-size \$(stat -c%s "\$file"); then
      
      # Also upload checksum file
      if [[ -f "\$file.sha256" ]]; then
        aws s3 cp "\$file.sha256" "s3://\$S3_BUCKET/\$S3_PREFIX/\$filename.sha256" --region "\$S3_REGION"
      fi

      # Mark as synced
      touch "\$BACKUP_DIR/.\$filename.s3synced"
      log_info "Successfully synced \$filename to S3"
    else
      log_error "Failed to sync \$filename to S3"
    fi
  fi
done

# Verify remote backups if enabled
if [[ "\${BACKUP_VERIFY_REMOTE:-true}" == "true" ]]; then
  log_info "Verifying remote backups"
  
  # List files in bucket to verify they exist
  aws s3 ls "s3://\$S3_BUCKET/\$S3_PREFIX/" --region "\$S3_REGION" > "/tmp/s3-files.txt"
  
  # Check for each local synced file
  find "\$BACKUP_DIR" -name ".*.s3synced" | while read syncfile; do
    filename=\$(basename "\$syncfile" | sed 's/^\\.//')
    if grep -q "\$filename" "/tmp/s3-files.txt"; then
      log_info "Verified \$filename exists in S3"
    else
      log_warning "File \$filename missing from S3"
      # Remove sync marker to retry upload
      rm "\$syncfile"
    fi
  done
  
  rm -f "/tmp/s3-files.txt"
fi

# Check bucket lifecycle policy if configured
if [[ "\${BACKUP_S3_LIFECYCLE_CHECK:-true}" == "true" ]]; then
  log_info "Checking S3 bucket lifecycle policy"
  if ! aws s3api get-bucket-lifecycle-configuration --bucket "\$S3_BUCKET" --region "\$S3_REGION" >/dev/null 2>&1; then
    log_warning "No lifecycle policy configured for S3 bucket"
    log_warning "Recommend setting up a lifecycle policy to manage remote backup retention"
  fi
fi

log_info "S3 backup sync completed"
EOF
    
    chmod +x /usr/local/bin/utils/s3-sync.sh
    
    # Schedule S3 sync after backups if cron available
    if [[ -f "/etc/cron.d/meowcoin-backup" ]]; then
        echo "30 0 * * * meowcoin /usr/local/bin/utils/s3-sync.sh > /var/log/meowcoin/s3-sync.log 2>&1" >> /etc/cron.d/meowcoin-backup
    fi
    
    return 0
}

# Setup SFTP backup integration
function backup_setup_sftp() {
    if [[ -z "${BACKUP_SFTP_HOST}" || -z "${BACKUP_SFTP_USER}" ]]; then
        log_error "SFTP host or user not specified for remote backup"
        return 1
    fi
    
    log_info "Configuring SFTP remote backup to ${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}"
    
    # Install SFTP client if needed
    if ! command -v sftp >/dev/null 2>&1; then
        log_info "Installing SFTP client for backups"
        apk add --no-cache openssh-client
    fi
    
    # Set up SSH directory
    mkdir -p /home/meowcoin/.ssh
    chmod 700 /home/meowcoin/.ssh
    chown meowcoin:meowcoin /home/meowcoin/.ssh
    
    # Generate SSH key if it doesn't exist
    if [[ ! -f "/home/meowcoin/.ssh/id_ed25519" && -z "${BACKUP_SFTP_KEY}" ]]; then
        log_info "Generating SSH key for SFTP backups"
        ssh-keygen -t ed25519 -f /home/meowcoin/.ssh/id_ed25519 -N "" -C "meowcoin-backup"
        chown meowcoin:meowcoin /home/meowcoin/.ssh/id_ed25519*
        log_info "SSH public key for SFTP setup:"
        cat /home/meowcoin/.ssh/id_ed25519.pub
    fi
    
    # Create SFTP sync utility script
    mkdir -p /usr/local/bin/utils
    cat > /usr/local/bin/utils/sftp-sync.sh <<EOF
#!/bin/bash
# Script to sync backups to SFTP server

source /usr/local/bin/core/utils.sh

BACKUP_DIR="$BACKUP_DIR"
SFTP_HOST="\${BACKUP_SFTP_HOST:-${BACKUP_SFTP_HOST}}"
SFTP_USER="\${BACKUP_SFTP_USER:-${BACKUP_SFTP_USER}}"
SFTP_PORT="\${BACKUP_SFTP_PORT:-22}"
SFTP_PATH="\${BACKUP_SFTP_PATH:-/backups}"
SSH_KEY="/home/meowcoin/.ssh/id_ed25519"
LOG_FILE="$BACKUP_LOG"
MAX_PARALLEL_UPLOADS=\${MAX_PARALLEL_UPLOADS:-2}

log_info "Starting SFTP backup sync"

# Create list of files to sync
find "\$BACKUP_DIR" -name "*.tar.gz" | while read file; do
  filename=\$(basename "\$file")
  if [[ ! -f "\$BACKUP_DIR/.\$filename.sftpsynced" ]]; then
    echo "\$file" >> /tmp/sftp-files-to-sync.txt
  fi
done

if [[ ! -f "/tmp/sftp-files-to-sync.txt" || ! -s "/tmp/sftp-files-to-sync.txt" ]]; then
  log_info "No files to sync"
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
  while [[ \$(jobs -p | wc -l) -ge "\$MAX_PARALLEL_UPLOADS" ]]; do
    sleep 1
  done
  
  filename=\$(basename "\$file")
  log_info "Uploading \$filename to SFTP"
  
  # Upload in background
  (
    if sftp -i "\$SSH_KEY" -P "\$SFTP_PORT" -o StrictHostKeyChecking=no -o BatchMode=yes "\$SFTP_USER@\$SFTP_HOST" << EOF >/dev/null 2>&1
      put "\$file" "\$SFTP_PATH/\$filename"
      put "\$file.sha256" "\$SFTP_PATH/\$filename.sha256"
      bye
EOF
    then
      touch "\$BACKUP_DIR/.\$filename.sftpsynced"
      log_info "Successfully uploaded \$filename to SFTP"
    else
      log_error "Failed to upload \$filename to SFTP"
    fi
  ) &
done

# Wait for all uploads to complete
wait

# Clean up
rm -f /tmp/sftp-files-to-sync.txt

log_info "SFTP backup sync completed"
EOF
    
    chmod +x /usr/local/bin/utils/sftp-sync.sh
    
    # Schedule SFTP sync after backups if cron available
    if [[ -f "/etc/cron.d/meowcoin-backup" ]]; then
        echo "30 0 * * * meowcoin /usr/local/bin/utils/sftp-sync.sh > /var/log/meowcoin/sftp-sync.log 2>&1" >> /etc/cron.d/meowcoin-backup
    fi
    
    return 0
}

# Setup encryption for backups
function backup_setup_encryption() {
    log_info "Configuring backup encryption"
    
    # Verify encryption key format and strength
    KEY_LENGTH=${#BACKUP_ENCRYPTION_KEY}
    if [[ $KEY_LENGTH -lt 32 ]]; then
        log_warning "Encryption key is too short (<32 chars). Consider using a stronger key."
    fi
    
    # Create key verification file to test decryption
    echo "Encryption Test" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 \
        -out "$DATA_DIR/.enc_test" -pass pass:"$BACKUP_ENCRYPTION_KEY"
    
    # Test decryption
    if openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 10000 \
        -in "$DATA_DIR/.enc_test" -pass pass:"$BACKUP_ENCRYPTION_KEY" >/dev/null 2>&1; then
        log_info "Encryption key verified"
    else
        log_error "Encryption key verification failed"
    fi
    
    # Clean up test file
    rm -f "$DATA_DIR/.enc_test"
    
    return 0
}

# Create a backup with full error handling
function backup_create() {
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_FILE="$BACKUP_DIR/meowcoin_backup_$TIMESTAMP.tar.gz"
    local BACKUP_TYPE="${1:-primary}"
    
    log_info "Starting backup process (type: $BACKUP_TYPE)"
    
    # Execute pre-backup hook if plugins are available
    if type plugin_execute_hook >/dev/null 2>&1; then
        plugin_execute_hook "backup_pre"
    fi
    
    # Check available disk space
    local REQUIRED_SPACE=$(($(du -sm $DATA_DIR/wallet.dat 2>/dev/null | cut -f1) * 2))
    local AVAILABLE_SPACE=$(df -m $BACKUP_DIR | tail -1 | awk '{print $4}')
    
    if [[ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]]; then
        log_error "Not enough disk space for backup. Required: ${REQUIRED_SPACE}MB, Available: ${AVAILABLE_SPACE}MB"
        send_alert "backup_space" "Not enough disk space for backup" "critical"
        return 1
    fi
    
    # Try to use wallet lock API if available
    local WALLET_LOCKED=false
    if command -v meowcoin-cli >/dev/null 2>&1; then
        log_info "Attempting to lock wallet for consistent backup"
        if meowcoin-cli -conf="$DATA_DIR/meowcoin.conf" walletlock >/dev/null 2>&1; then
            log_info "Wallet locked successfully"
            WALLET_LOCKED=true
        else
            log_info "Could not lock wallet or wallet already locked"
        fi
    fi
    
    log_info "Creating backup archive with compression level ${BACKUP_COMPRESSION_LEVEL:-6}"
    
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
            1) log_warning "Non-fatal error during backup creation - some files may have changed during backup" ;;
            2) log_error "Fatal error during backup creation - backup is likely incomplete or corrupted" ;;
            *) log_error "Backup creation failed with code $ERROR_CODE" ;;
        esac
        
        # For any error, attempt to clean up
        log_warning "Removing failed backup file"
        rm -f "$BACKUP_FILE" 2>/dev/null || true
        
        # Send alert
        send_alert "backup_failed" "Backup creation failed with code $ERROR_CODE" "critical"
        
        # Execute error hook if plugins are available
        if type plugin_execute_hook >/dev/null 2>&1; then
            plugin_execute_hook "backup_error" "$ERROR_CODE"
        fi
        
        return 1
    fi
    
    # Create and verify checksum file
    if ! sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"; then
        log_error "Failed to create checksum file"
        send_alert "backup_checksum" "Failed to create backup checksum" "warning"
        return 1
    fi
    
    # Validate backup file integrity
    if ! tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
        log_error "Backup file integrity check failed"
        rm -f "$BACKUP_FILE" "$BACKUP_FILE.sha256"
        send_alert "backup_integrity" "Backup integrity check failed" "critical"
        return 1
    fi
    
    # Attempt to encrypt backup if encryption key provided
    if [[ -n "$BACKUP_ENCRYPTION_KEY" ]]; then
        backup_encrypt "$BACKUP_FILE" "$BACKUP_ENCRYPTION_KEY"
    fi
    
    # Get file size and record success
    local BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log_info "Backup completed: $BACKUP_FILE ($BACKUP_SIZE)"
    
    # Unlock wallet if it was locked by this script
    if [[ "$WALLET_LOCKED" = true ]]; then
        log_info "Unlocking wallet"
        if ! meowcoin-cli -conf="$DATA_DIR/meowcoin.conf" walletpassphrase "$WALLET_PASSPHRASE" 0 true >/dev/null 2>&1; then
            log_warning "Failed to unlock wallet"
        else
            log_info "Wallet unlocked successfully"
        fi
    fi
    
    # Execute post-backup hook if plugins are available
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
  "encrypted": $([ -n "$BACKUP_ENCRYPTION_KEY" ] && echo "true" || echo "false"),
  "remote_backup": $([ "${BACKUP_REMOTE_ENABLED:-false}" = "true" ] && echo "true" || echo "false"),
  "remote_type": "${BACKUP_REMOTE_TYPE:-none}",
  "status": "success"
}
EOF
    
    return 0
}

# Encrypt a backup file
function backup_encrypt() {
    local BACKUP_FILE="$1"
    local ENCRYPTION_KEY="$2"
    
    log_info "Encrypting backup using provided key"
    
    # Validate encryption key format
    if [[ ! "$ENCRYPTION_KEY" =~ ^[a-zA-Z0-9_\-\.]+$ ]]; then
        log_warning "Invalid encryption key format"
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
        log_error "Backup encryption failed with code $ERROR_CODE"
        # Clean up failed encryption attempt
        rm -f "$BACKUP_FILE.enc"
        shred -u "$KEY_FILE" || rm -f "$KEY_FILE"
        return 1
    fi
        
    # Replace original with encrypted version
    mv "$BACKUP_FILE.enc" "$BACKUP_FILE"
        
    # Update checksum
    sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"
        
    log_info "Backup encrypted successfully"
    
    # Securely delete the key file
    shred -u "$KEY_FILE" || rm -f "$KEY_FILE"
    
    return 0
}

# Verify backup integrity
function backup_verify() {
    log_info "Starting backup verification"
    
    # Verify all backups
    find "$BACKUP_DIR" -name "*.tar.gz" -type f | while read BACKUP_FILE; do
        local FILENAME=$(basename "$BACKUP_FILE")
        local CHECKSUM_FILE="$BACKUP_FILE.sha256"
        
        log_info "Verifying backup: $FILENAME"
        
        # Check if checksum file exists
        if [[ ! -f "$CHECKSUM_FILE" ]]; then
            log_warning "Checksum file missing for $FILENAME"
            # Generate checksum if missing
            sha256sum "$BACKUP_FILE" > "$CHECKSUM_FILE"
            log_info "Generated missing checksum file"
            continue
        fi
        
        # Verify checksum
        if sha256sum -c "$CHECKSUM_FILE" >/dev/null 2>&1; then
            log_info "✓ Checksum verification passed for $FILENAME"
            touch "$BACKUP_META_DIR/${FILENAME}.verified"
        else
            log_error "✗ CRITICAL: Checksum verification FAILED for $FILENAME"
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
    
    log_info "Verification summary: $VERIFIED/$TOTAL backups verified, $CORRUPTED corrupted"
    
    # Update status file
    echo "{\"timestamp\": \"$(date -Iseconds)\", \"total\": $TOTAL, \"verified\": $VERIFIED, \"corrupted\": $CORRUPTED}" > "$DATA_DIR/.backup_verify_status"
    
    return 0
}

# Clean up old backups
function backup_cleanup() {
    log_info "Starting backup cleanup"
    
    local MAX_BACKUPS="${MAX_BACKUPS:-7}"
    local RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
    
    # Keep at least MAX_BACKUPS latest backups
    if [[ "$MAX_BACKUPS" -gt 0 ]]; then
        local EXCESS_COUNT=$(find "$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" | wc -l)
        EXCESS_COUNT=$((EXCESS_COUNT - MAX_BACKUPS))
        
        if [[ "$EXCESS_COUNT" -gt 0 ]]; then
            log_info "Removing $EXCESS_COUNT excess backups based on count limit"
            find "$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" -printf "%T@ %p\n" | sort -n | head -n $EXCESS_COUNT | cut -d' ' -f2- | while read file; do
                log_info "Removing old backup: $(basename "$file")"
                rm -f "$file" "$file.sha256"
            done
        else
            log_info "No excess backups to remove based on count"
        fi
    fi
    
    # Remove backups older than RETENTION_DAYS
    if [[ "$RETENTION_DAYS" -gt 0 ]]; then
        log_info "Removing backups older than $RETENTION_DAYS days"
        find "$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" -mtime +$RETENTION_DAYS -print | while read file; do
            log_info "Removing aged backup: $(basename "$file")"
            rm -f "$file" "$file.sha256"
        done
    fi
    
    # Clean up corrupted backups after 7 days
    log_info "Cleaning up corrupted backups older than 7 days"
    find "$BACKUP_DIR" -name "*.corrupted" -mtime +7 -delete
    
    # Update backup manifest
    log_info "Updating backup manifest"
    find "$BACKUP_DIR" -name "*.tar.gz" -printf "%T@ %p %s\n" | sort -nr > "$BACKUP_MANIFEST_FILE"
    
    local CURRENT_COUNT=$(find "$BACKUP_DIR" -name "*.tar.gz" | wc -l)
    log_info "Backup cleanup completed. Current backup count: $CURRENT_COUNT"
    
    return 0
}

# Restore from backup
function backup_restore() {
    local BACKUP_FILE="$1"
    local TARGET_DIR="${2:-$DATA_DIR}"
    
    log_info "Starting restore from backup: $BACKUP_FILE"
    
    # Check if backup file exists
    if [[ ! -f "$BACKUP_FILE" ]]; then
        log_error "Backup file not found: $BACKUP_FILE"
        return 1
    fi
    
    # Check if wallet service is running
    if pgrep -x "meowcoind" > /dev/null || pgrep -x "meowcoin-qt" > /dev/null; then
        log_error "Meowcoin daemon is running. Please stop it before restore."
        return 1
    fi
    
    # Create temporary directory for extraction
    local TEMP_DIR=$(mktemp -d)
    log_info "Extracting backup to temporary directory: $TEMP_DIR"
    
    # Check if backup is encrypted
    local IS_ENCRYPTED=false
    if file "$BACKUP_FILE" | grep -q "openssl"; then
        IS_ENCRYPTED=true
        log_info "Backup appears to be encrypted"
        
        # Prompt for encryption key
        local ENCRYPTION_KEY=""
        if [[ -z "$BACKUP_ENCRYPTION_KEY" ]]; then
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
            log_error "Backup decryption failed with code $ERROR_CODE"
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
        log_error "Failed to extract backup"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Backup the current wallet if it exists
    if [[ -f "$TARGET_DIR/wallet.dat" ]]; then
        local BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        log_info "Backing up existing wallet.dat to $TARGET_DIR/wallet.dat.backup-$BACKUP_TIMESTAMP"
        cp "$TARGET_DIR/wallet.dat" "$TARGET_DIR/wallet.dat.backup-$BACKUP_TIMESTAMP"
    fi
    
    # Copy essential files to the target directory
    log_info "Copying essential files to $TARGET_DIR"
    
    # Create target directories if they don't exist
    mkdir -p "$TARGET_DIR"
    
    # Find the extracted wallet directory path
    local EXTRACTED_DIR=$(find "$TEMP_DIR" -name ".meowcoin" -type d)
    if [[ -z "$EXTRACTED_DIR" ]]; then
        # Try alternative path
        EXTRACTED_DIR="$TEMP_DIR/home/meowcoin/.meowcoin"
        if [[ ! -d "$EXTRACTED_DIR" ]]; then
            log_error "Could not find extracted .meowcoin directory in backup"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    fi
    
    # Copy wallet file
    if [[ -f "$EXTRACTED_DIR/wallet.dat" ]]; then
        cp "$EXTRACTED_DIR/wallet.dat" "$TARGET_DIR/"
        chmod 600 "$TARGET_DIR/wallet.dat"
        log_info "Restored wallet.dat"
    else
        log_warning "Warning: wallet.dat not found in backup"
    fi
    
    # Copy other important files
    for file in "meowcoin.conf" "peers.dat" "banlist.dat" "fee_estimates.dat"; do
        if [[ -f "$EXTRACTED_DIR/$file" ]]; then
            cp "$EXTRACTED_DIR/$file" "$TARGET_DIR/"
            log_info "Restored $file"
        fi
    done
    
    # Copy keys directory if it exists
    if [[ -d "$EXTRACTED_DIR/keys" ]]; then
        mkdir -p "$TARGET_DIR/keys"
        cp -r "$EXTRACTED_DIR/keys"/* "$TARGET_DIR/keys/"
        chmod 700 "$TARGET_DIR/keys"
        log_info "Restored keys directory"
    fi
    
    # Copy wallets directory if it exists (for descriptor wallets)
    if [[ -d "$EXTRACTED_DIR/wallets" ]]; then
        mkdir -p "$TARGET_DIR/wallets"
        cp -r "$EXTRACTED_DIR/wallets"/* "$TARGET_DIR/wallets/"
        log_info "Restored wallets directory"
    fi
    
    # Set correct ownership
    chown -R meowcoin:meowcoin "$TARGET_DIR"
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    log_info "Restore completed successfully"
    return 0
}

# Export functions for use in other scripts
export BACKUP_FUNCTIONS_LOADED=true
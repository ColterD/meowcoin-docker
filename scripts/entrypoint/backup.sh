#!/bin/bash
set -e

# Backup configuration
BACKUP_LOG="/var/log/meowcoin/backup.log"
BACKUP_STATUS_FILE="/home/meowcoin/.meowcoin/.backup_status"
BACKUP_MANIFEST_FILE="/home/meowcoin/.meowcoin/.backup_manifest"
BACKUP_RETENTION_DAYS=30
MAX_PARALLEL_UPLOADS=2

# Setup backup features with improved reliability
function setup_backup_features() {
  mkdir -p $(dirname $BACKUP_LOG)
  touch $BACKUP_LOG
  chown meowcoin:meowcoin $BACKUP_LOG
  
  # Configure automatic backups if enabled
  if [ "${ENABLE_BACKUPS:-false}" = "true" ]; then
    setup_automated_backups
  fi
}

# Setup automated blockchain backups with enhanced features
function setup_automated_backups() {
  echo "[$(date -Iseconds)] Setting up automated blockchain backups" | tee -a $BACKUP_LOG
  
  # Create backup directory with secure permissions
  BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
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
  BACKUP_SCRIPT="/usr/local/bin/backup/backup-blockchain.sh"
  
  if [ -f "$BACKUP_SCRIPT" ]; then
    # Create proper cron job file with environment variables
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
0 1 * * * meowcoin /usr/local/bin/backup/verify-backups.sh > $BACKUP_LOG 2>&1
0 2 * * * meowcoin /usr/local/bin/backup/cleanup-backups.sh > $BACKUP_LOG 2>&1
EOF

    chmod 644 /etc/cron.d/meowcoin-backup
    echo "[$(date -Iseconds)] Automatic backups scheduled: $BACKUP_SCHEDULE" | tee -a $BACKUP_LOG
    
    # Secondary backup schedule if configured
    if [ ! -z "${BACKUP_SECONDARY_SCHEDULE}" ]; then
      echo "[$(date -Iseconds)] Secondary backups scheduled: $BACKUP_SECONDARY_SCHEDULE" | tee -a $BACKUP_LOG
    fi
    
    # Configure backup retention policy
    echo "[$(date -Iseconds)] Backup retention set to ${MAX_BACKUPS:-7} backups and ${BACKUP_RETENTION_DAYS} days" | tee -a $BACKUP_LOG
    
    # Configure compression level
    echo "[$(date -Iseconds)] Backup compression level set to ${BACKUP_COMPRESSION_LEVEL:-6}" | tee -a $BACKUP_LOG
    
    # Create backup verification script for integrity checking
    cat > /usr/local/bin/backup/verify-backups.sh <<EOF
#!/bin/bash
# Script to verify backup integrity

BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
BACKUP_META_DIR="/home/meowcoin/.meowcoin/backup-metadata"
LOG_FILE="/var/log/meowcoin/backup-verify.log"

echo "[$(date -Iseconds)] Starting backup verification" > "\$LOG_FILE"

# Verify all backups
find "\$BACKUP_DIR" -name "*.tar.gz" -type f | while read BACKUP_FILE; do
  FILENAME=\$(basename "\$BACKUP_FILE")
  CHECKSUM_FILE="\$BACKUP_FILE.sha256"
  
  echo "[$(date -Iseconds)] Verifying backup: \$FILENAME" >> "\$LOG_FILE"
  
  # Check if checksum file exists
  if [ ! -f "\$CHECKSUM_FILE" ]; then
    echo "[$(date -Iseconds)] ERROR: Checksum file missing for \$FILENAME" >> "\$LOG_FILE"
    # Generate checksum if missing
    sha256sum "\$BACKUP_FILE" > "\$CHECKSUM_FILE"
    echo "[$(date -Iseconds)] Generated missing checksum file" >> "\$LOG_FILE"
    continue
  fi
  
  # Verify checksum
  if sha256sum -c "\$CHECKSUM_FILE" >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] ✓ Checksum verification passed for \$FILENAME" >> "\$LOG_FILE"
    touch "\$BACKUP_META_DIR/\${FILENAME}.verified"
  else
    echo "[$(date -Iseconds)] ✗ CRITICAL: Checksum verification FAILED for \$FILENAME" >> "\$LOG_FILE"
    mv "\$BACKUP_FILE" "\$BACKUP_FILE.corrupted"
    mv "\$CHECKSUM_FILE" "\$CHECKSUM_FILE.corrupted"
    
    # Alert mechanism
    if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
      /usr/local/bin/monitoring/send-alert.sh "CRITICAL: Backup corruption detected in \$FILENAME"
    fi
  fi
done

# Report summary
TOTAL=\$(find "\$BACKUP_DIR" -name "*.tar.gz" -type f | wc -l)
VERIFIED=\$(find "\$BACKUP_META_DIR" -name "*.verified" -type f | wc -l)
CORRUPTED=\$(find "\$BACKUP_DIR" -name "*.corrupted" -type f | wc -l)

echo "[$(date -Iseconds)] Verification summary: \$VERIFIED/\$TOTAL backups verified, \$CORRUPTED corrupted" >> "\$LOG_FILE"

# Update status file
echo "{\\"timestamp\\": \\"\$(date -Iseconds)\\", \\"total\\": \$TOTAL, \\"verified\\": \$VERIFIED, \\"corrupted\\": \$CORRUPTED}" > "/home/meowcoin/.meowcoin/.backup_verify_status"

echo "[$(date -Iseconds)] Backup verification completed" >> "\$LOG_FILE"
EOF

    chmod +x /usr/local/bin/backup/verify-backups.sh
    
    # Create backup cleanup script with retention policy
    cat > /usr/local/bin/backup/cleanup-backups.sh <<EOF
#!/bin/bash
# Script to clean up old backups based on retention policy

BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
MAX_BACKUPS=${MAX_BACKUPS:-7}
RETENTION_DAYS=${BACKUP_RETENTION_DAYS}
LOG_FILE="/var/log/meowcoin/backup-cleanup.log"

echo "[$(date -Iseconds)] Starting backup cleanup" > "\$LOG_FILE"

# Keep at least MAX_BACKUPS latest backups
if [ "\$MAX_BACKUPS" -gt 0 ]; then
  EXCESS_COUNT=\$(find "\$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" | wc -l)
  EXCESS_COUNT=\$((EXCESS_COUNT - MAX_BACKUPS))
  
  if [ "\$EXCESS_COUNT" -gt 0 ]; then
    echo "[$(date -Iseconds)] Removing \$EXCESS_COUNT excess backups based on count limit" >> "\$LOG_FILE"
    find "\$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" -printf "%T@ %p\n" | sort -n | head -n \$EXCESS_COUNT | cut -d' ' -f2- | while read file; do
      echo "[$(date -Iseconds)] Removing old backup: \$(basename "\$file")" >> "\$LOG_FILE"
      rm -f "\$file" "\$file.sha256"
    done
  else
    echo "[$(date -Iseconds)] No excess backups to remove based on count" >> "\$LOG_FILE"
  fi
fi

# Remove backups older than RETENTION_DAYS
if [ "\$RETENTION_DAYS" -gt 0 ]; then
  echo "[$(date -Iseconds)] Removing backups older than \$RETENTION_DAYS days" >> "\$LOG_FILE"
  find "\$BACKUP_DIR" -name "meowcoin_backup_*.tar.gz" -mtime +\$RETENTION_DAYS -print | while read file; do
    echo "[$(date -Iseconds)] Removing aged backup: \$(basename "\$file")" >> "\$LOG_FILE"
    rm -f "\$file" "\$file.sha256"
  done
fi

# Clean up corrupted backups after 7 days
echo "[$(date -Iseconds)] Cleaning up corrupted backups older than 7 days" >> "\$LOG_FILE"
find "\$BACKUP_DIR" -name "*.corrupted" -mtime +7 -delete

# Update backup manifest
echo "[$(date -Iseconds)] Updating backup manifest" >> "\$LOG_FILE"
find "\$BACKUP_DIR" -name "*.tar.gz" -printf "%T@ %p %s\n" | sort -nr > "/home/meowcoin/.meowcoin/.backup_manifest"

CURRENT_COUNT=\$(find "\$BACKUP_DIR" -name "*.tar.gz" | wc -l)
echo "[$(date -Iseconds)] Backup cleanup completed. Current backup count: \$CURRENT_COUNT" >> "\$LOG_FILE"
EOF

    chmod +x /usr/local/bin/backup/cleanup-backups.sh
    
    # Setup remote backup if enabled
    if [ "${BACKUP_REMOTE_ENABLED:-false}" = "true" ]; then
      echo "[$(date -Iseconds)] Remote backup enabled with type: ${BACKUP_REMOTE_TYPE}" | tee -a $BACKUP_LOG
      
      case "${BACKUP_REMOTE_TYPE}" in
        "s3")
          if [ -z "${BACKUP_S3_BUCKET}" ]; then
            echo "[$(date -Iseconds)] ERROR: S3 bucket not specified for remote backup" | tee -a $BACKUP_LOG
          else
            echo "[$(date -Iseconds)] Configured S3 remote backup to bucket: ${BACKUP_S3_BUCKET}" | tee -a $BACKUP_LOG
            
            # Install AWS CLI if needed and not already present
            if ! command -v aws >/dev/null 2>&1; then
              echo "[$(date -Iseconds)] Installing AWS CLI for S3 backups" | tee -a $BACKUP_LOG
              apk add --no-cache aws-cli
            fi
            
            # Create S3 sync utility script
            cat > /usr/local/bin/backup/s3-sync.sh <<EOF
#!/bin/bash
# Script to sync backups to S3

BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
S3_BUCKET="${BACKUP_S3_BUCKET}"
S3_PREFIX="${BACKUP_S3_PREFIX:-meowcoin-backups}"
S3_REGION="${BACKUP_S3_REGION:-us-east-1}"
LOG_FILE="/var/log/meowcoin/s3-sync.log"

echo "[$(date -Iseconds)] Starting S3 backup sync" > "\$LOG_FILE"

# Only sync files we haven't already synced
find "\$BACKUP_DIR" -name "*.tar.gz" | while read file; do
  filename=\$(basename "\$file")
  if [ ! -f "\$BACKUP_DIR/.\$filename.s3synced" ]; then
    echo "[$(date -Iseconds)] Syncing \$filename to S3" >> "\$LOG_FILE"
    
    # Upload file with metadata
    if aws s3 cp "\$file" "s3://\$S3_BUCKET/\$S3_PREFIX/\$filename" \
       --region "\$S3_REGION" \
       --metadata "timestamp=\$(date -Iseconds),hostname=\$(hostname)" \
       --expected-size \$(stat -c%s "\$file"); then
      
      # Also upload checksum file
      if [ -f "\$file.sha256" ]; then
        aws s3 cp "\$file.sha256" "s3://\$S3_BUCKET/\$S3_PREFIX/\$filename.sha256" --region "\$S3_REGION"
      fi

      # Mark as synced
      touch "\$BACKUP_DIR/.\$filename.s3synced"
      echo "[$(date -Iseconds)] ✓ Successfully synced \$filename to S3" >> "\$LOG_FILE"
    else
      echo "[$(date -Iseconds)] ✗ Failed to sync \$filename to S3" >> "\$LOG_FILE"
    fi
  fi
done

# Verify remote backups if enabled
if [ "${BACKUP_VERIFY_REMOTE:-true}" = "true" ]; then
  echo "[$(date -Iseconds)] Verifying remote backups" >> "\$LOG_FILE"
  
  # List files in bucket to verify they exist
  aws s3 ls "s3://\$S3_BUCKET/\$S3_PREFIX/" --region "\$S3_REGION" > "/tmp/s3-files.txt"
  
  # Check for each local synced file
  find "\$BACKUP_DIR" -name ".*.s3synced" | while read syncfile; do
    filename=\$(basename "\$syncfile" | sed 's/^\\.//')
    if grep -q "\$filename" "/tmp/s3-files.txt"; then
      echo "[$(date -Iseconds)] ✓ Verified \$filename exists in S3" >> "\$LOG_FILE"
    else
      echo "[$(date -Iseconds)] ✗ File \$filename missing from S3" >> "\$LOG_FILE"
      # Remove sync marker to retry upload
      rm "\$syncfile"
    fi
  done
  
  rm -f "/tmp/s3-files.txt"
fi

# Check bucket lifecycle policy if configured
if [ "${BACKUP_S3_LIFECYCLE_CHECK:-true}" = "true" ]; then
  echo "[$(date -Iseconds)] Checking S3 bucket lifecycle policy" >> "\$LOG_FILE"
  if ! aws s3api get-bucket-lifecycle-configuration --bucket "\$S3_BUCKET" --region "\$S3_REGION" >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] Warning: No lifecycle policy configured for S3 bucket" >> "\$LOG_FILE"
    echo "[$(date -Iseconds)] Recommend setting up a lifecycle policy to manage remote backup retention" >> "\$LOG_FILE"
  fi
fi

echo "[$(date -Iseconds)] S3 backup sync completed" >> "\$LOG_FILE"
EOF
            chmod +x /usr/local/bin/backup/s3-sync.sh
            
            # Schedule S3 sync after backups
            echo "30 0 * * * meowcoin /usr/local/bin/backup/s3-sync.sh > /var/log/meowcoin/s3-sync.log 2>&1" >> /etc/cron.d/meowcoin-backup
          fi
          ;;
        "sftp")
          if [ -z "${BACKUP_SFTP_HOST}" ] || [ -z "${BACKUP_SFTP_USER}" ]; then
            echo "[$(date -Iseconds)] ERROR: SFTP host or user not specified for remote backup" | tee -a $BACKUP_LOG
          else
            echo "[$(date -Iseconds)] Configured SFTP remote backup to ${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}" | tee -a $BACKUP_LOG
            
            # Install SFTP client if needed
            if ! command -v sftp >/dev/null 2>&1; then
              echo "[$(date -Iseconds)] Installing SFTP client for backups" | tee -a $BACKUP_LOG
              apk add --no-cache openssh-client
            fi
            
            # Set up SSH directory
            mkdir -p /home/meowcoin/.ssh
            chmod 700 /home/meowcoin/.ssh
            chown meowcoin:meowcoin /home/meowcoin/.ssh
            
            # Generate SSH key if it doesn't exist
            if [ ! -f "/home/meowcoin/.ssh/id_ed25519" ] && [ -z "${BACKUP_SFTP_KEY}" ]; then
              echo "[$(date -Iseconds)] Generating SSH key for SFTP backups" | tee -a $BACKUP_LOG
              ssh-keygen -t ed25519 -f /home/meowcoin/.ssh/id_ed25519 -N "" -C "meowcoin-backup"
              chown meowcoin:meowcoin /home/meowcoin/.ssh/id_ed25519*
              echo "[$(date -Iseconds)] SSH public key for SFTP setup:" | tee -a $BACKUP_LOG
              cat /home/meowcoin/.ssh/id_ed25519.pub | tee -a $BACKUP_LOG
            fi
            
            # Create SFTP sync utility script
            cat > /usr/local/bin/backup/sftp-sync.sh <<EOF
#!/bin/bash
# Script to sync backups to SFTP server

BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
SFTP_HOST="${BACKUP_SFTP_HOST}"
SFTP_USER="${BACKUP_SFTP_USER}"
SFTP_PORT="${BACKUP_SFTP_PORT:-22}"
SFTP_PATH="${BACKUP_SFTP_PATH:-/backups}"
SSH_KEY="/home/meowcoin/.ssh/id_ed25519"
LOG_FILE="/var/log/meowcoin/sftp-sync.log"
MAX_PARALLEL_UPLOADS=${MAX_PARALLEL_UPLOADS}

echo "[$(date -Iseconds)] Starting SFTP backup sync" > "\$LOG_FILE"

# Create list of files to sync
find "\$BACKUP_DIR" -name "*.tar.gz" | while read file; do
  filename=\$(basename "\$file")
  if [ ! -f "\$BACKUP_DIR/.\$filename.sftpsynced" ]; then
    echo "\$file" >> /tmp/sftp-files-to-sync.txt
  fi
done

if [ ! -f "/tmp/sftp-files-to-sync.txt" ] || [ ! -s "/tmp/sftp-files-to-sync.txt" ]; then
  echo "[$(date -Iseconds)] No files to sync" >> "\$LOG_FILE"
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
  echo "[$(date -Iseconds)] Uploading \$filename to SFTP" >> "\$LOG_FILE"
  
  # Upload in background
  (
    if sftp -i "\$SSH_KEY" -P "\$SFTP_PORT" -o StrictHostKeyChecking=no -o BatchMode=yes "\$SFTP_USER@\$SFTP_HOST" << EOF >/dev/null 2>&1
      put "\$file" "\$SFTP_PATH/\$filename"
      put "\$file.sha256" "\$SFTP_PATH/\$filename.sha256"
      bye
EOF
    then
      touch "\$BACKUP_DIR/.\$filename.sftpsynced"
      echo "[$(date -Iseconds)] ✓ Successfully uploaded \$filename to SFTP" >> "\$LOG_FILE"
    else
      echo "[$(date -Iseconds)] ✗ Failed to upload \$filename to SFTP" >> "\$LOG_FILE"
    fi
  ) &
done

# Wait for all uploads to complete
wait

# Clean up
rm -f /tmp/sftp-files-to-sync.txt

echo "[$(date -Iseconds)] SFTP backup sync completed" >> "\$LOG_FILE"
EOF
            
            chmod +x /usr/local/bin/backup/sftp-sync.sh
            
            # Schedule SFTP sync after backups
            echo "30 0 * * * meowcoin /usr/local/bin/backup/sftp-sync.sh > /var/log/meowcoin/sftp-sync.log 2>&1" >> /etc/cron.d/meowcoin-backup
          fi
          ;;
        *)
          echo "[$(date -Iseconds)] WARNING: Unknown remote backup type: ${BACKUP_REMOTE_TYPE}" | tee -a $BACKUP_LOG
          ;;
      esac
    fi
    
    # Check for encryption key
    if [ ! -z "${BACKUP_ENCRYPTION_KEY}" ]; then
      echo "[$(date -Iseconds)] Backup encryption enabled" | tee -a $BACKUP_LOG
      
      # Verify encryption key format and strength
      KEY_LENGTH=${#BACKUP_ENCRYPTION_KEY}
      if [ $KEY_LENGTH -lt 32 ]; then
        echo "[$(date -Iseconds)] WARNING: Encryption key is too short (<32 chars). Consider using a stronger key." | tee -a $BACKUP_LOG
      fi
      
      # Create key verification file to test decryption
      echo "Encryption Test" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 \
        -out "/home/meowcoin/.meowcoin/.enc_test" -pass pass:"$BACKUP_ENCRYPTION_KEY"
      
      # Test decryption
      if openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 10000 \
          -in "/home/meowcoin/.meowcoin/.enc_test" -pass pass:"$BACKUP_ENCRYPTION_KEY" >/dev/null 2>&1; then
        echo "[$(date -Iseconds)] Encryption key verified" | tee -a $BACKUP_LOG
      else
        echo "[$(date -Iseconds)] ERROR: Encryption key verification failed" | tee -a $BACKUP_LOG
      fi
      
      # Clean up test file
      rm -f "/home/meowcoin/.meowcoin/.enc_test"
    fi
    
  else
    echo "[$(date -Iseconds)] WARNING: Backup script not found at $BACKUP_SCRIPT, automatic backups will not be enabled" | tee -a $BACKUP_LOG
  fi
}
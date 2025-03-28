#!/bin/bash

# Setup backup features
function setup_backup_features() {
  # Configure automatic backups if enabled
  if [ "${ENABLE_BACKUPS:-false}" = "true" ]; then
    setup_automated_backups
  fi
}

# Setup automated blockchain backups
function setup_automated_backups() {
  echo "[$(date -Iseconds)] Setting up automated blockchain backups" | tee -a $LOG_FILE
  
  # Create backup directory
  BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
  mkdir -p "$BACKUP_DIR"
  chown meowcoin:meowcoin "$BACKUP_DIR"
  
  # Set up backup configuration
  BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 0 * * *}"  # Default: midnight daily
  BACKUP_SCRIPT="/usr/local/bin/backup/backup-blockchain.sh"
  
  if [ -f "$BACKUP_SCRIPT" ]; then
    # Create proper cron job file
    cat > /etc/cron.d/meowcoin-backup <<EOF
# Meowcoin automated backup
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
HOME=/home/meowcoin

# Environment variables for backup
BACKUP_COMPRESSION_LEVEL=${BACKUP_COMPRESSION_LEVEL:-6}
MAX_BACKUPS=${MAX_BACKUPS:-7}
BACKUP_REMOTE_ENABLED=${BACKUP_REMOTE_ENABLED:-false}
BACKUP_REMOTE_TYPE=${BACKUP_REMOTE_TYPE}
BACKUP_S3_BUCKET=${BACKUP_S3_BUCKET}
BACKUP_SFTP_HOST=${BACKUP_SFTP_HOST}
BACKUP_SFTP_USER=${BACKUP_SFTP_USER}
BACKUP_SFTP_PATH=${BACKUP_SFTP_PATH}
BACKUP_ENCRYPTION_KEY=${BACKUP_ENCRYPTION_KEY}

# Backup schedule
$BACKUP_SCHEDULE meowcoin $BACKUP_SCRIPT > $BACKUP_DIR/backup.log 2>&1
EOF

    chmod 644 /etc/cron.d/meowcoin-backup
    echo "[$(date -Iseconds)] Automatic backups scheduled: $BACKUP_SCHEDULE" | tee -a $LOG_FILE
    
    # Configure backup retention
    echo "[$(date -Iseconds)] Backup retention set to ${MAX_BACKUPS:-7} backups" | tee -a $LOG_FILE
    
    # Configure compression level
    echo "[$(date -Iseconds)] Backup compression level set to ${BACKUP_COMPRESSION_LEVEL:-6}" | tee -a $LOG_FILE
    
    # Setup remote backup if enabled
    if [ "${BACKUP_REMOTE_ENABLED:-false}" = "true" ]; then
      echo "[$(date -Iseconds)] Remote backup enabled with type: ${BACKUP_REMOTE_TYPE}" | tee -a $LOG_FILE
      
      case "${BACKUP_REMOTE_TYPE}" in
        "s3")
          if [ -z "${BACKUP_S3_BUCKET}" ]; then
            echo "[$(date -Iseconds)] ERROR: S3 bucket not specified for remote backup" | tee -a $LOG_FILE
          else
            echo "[$(date -Iseconds)] Configured S3 remote backup to bucket: ${BACKUP_S3_BUCKET}" | tee -a $LOG_FILE
            
            # Install AWS CLI if needed and not already present
            if ! command -v aws >/dev/null 2>&1; then
              echo "[$(date -Iseconds)] Installing AWS CLI for S3 backups" | tee -a $LOG_FILE
              apk add --no-cache aws-cli
            fi
          fi
          ;;
        "sftp")
          if [ -z "${BACKUP_SFTP_HOST}" ] || [ -z "${BACKUP_SFTP_USER}" ]; then
            echo "[$(date -Iseconds)] ERROR: SFTP host or user not specified for remote backup" | tee -a $LOG_FILE
          else
            echo "[$(date -Iseconds)] Configured SFTP remote backup to ${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}" | tee -a $LOG_FILE
            
            # Install SFTP client if needed
            if ! command -v sftp >/dev/null 2>&1; then
              echo "[$(date -Iseconds)] Installing SFTP client for backups" | tee -a $LOG_FILE
              apk add --no-cache openssh-client
            fi
            
            # Set up SSH directory
            mkdir -p /home/meowcoin/.ssh
            chmod 700 /home/meowcoin/.ssh
            chown meowcoin:meowcoin /home/meowcoin/.ssh
            
            # Generate SSH key if it doesn't exist
            if [ ! -f "/home/meowcoin/.ssh/id_rsa" ] && [ -z "${BACKUP_SFTP_KEY}" ]; then
              echo "[$(date -Iseconds)] Generating SSH key for SFTP backups" | tee -a $LOG_FILE
              ssh-keygen -t rsa -b 4096 -f /home/meowcoin/.ssh/id_rsa -N "" -C "meowcoin-backup"
              chown meowcoin:meowcoin /home/meowcoin/.ssh/id_rsa*
              echo "[$(date -Iseconds)] SSH public key for SFTP setup:" | tee -a $LOG_FILE
              cat /home/meowcoin/.ssh/id_rsa.pub | tee -a $LOG_FILE
            fi
          fi
          ;;
        *)
          echo "[$(date -Iseconds)] WARNING: Unknown remote backup type: ${BACKUP_REMOTE_TYPE}" | tee -a $LOG_FILE
          ;;
      esac
    fi
    
    # Check for encryption key
    if [ ! -z "${BACKUP_ENCRYPTION_KEY}" ]; then
      echo "[$(date -Iseconds)] Backup encryption enabled" | tee -a $LOG_FILE
    fi
    
  else
    echo "[$(date -Iseconds)] WARNING: Backup script not found at $BACKUP_SCRIPT, automatic backups will not be enabled" | tee -a $LOG_FILE
  fi
}
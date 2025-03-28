# scripts/entrypoint/backup.sh
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
    echo "$BACKUP_SCHEDULE $BACKUP_SCRIPT > $BACKUP_DIR/backup.log 2>&1" > /etc/cron.d/meowcoin-backup
    chmod 644 /etc/cron.d/meowcoin-backup
    echo "[$(date -Iseconds)] Automatic backups scheduled: $BACKUP_SCHEDULE" | tee -a $LOG_FILE
    
    # Configure backup retention
    export MAX_BACKUPS="${MAX_BACKUPS:-7}"
    echo "[$(date -Iseconds)] Backup retention set to $MAX_BACKUPS backups" | tee -a $LOG_FILE
    
    # Configure compression level
    export BACKUP_COMPRESSION_LEVEL="${BACKUP_COMPRESSION_LEVEL:-6}"
    echo "[$(date -Iseconds)] Backup compression level set to $BACKUP_COMPRESSION_LEVEL" | tee -a $LOG_FILE
  else
    echo "[$(date -Iseconds)] WARNING: Backup script not found, automatic backups will not be enabled" | tee -a $LOG_FILE
  fi
}
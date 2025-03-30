#!/bin/bash
set -e

# Source helper functions
source /scripts/functions.sh

log_info "Starting Meowcoin backup manager"

# Create backup directory if it doesn't exist
BACKUP_DIR="${MEOWCOIN_DATA}/backups"
mkdir -p "${BACKUP_DIR}"

# Set backup interval in seconds
case "${BACKUP_INTERVAL}" in
  hourly)
    INTERVAL=3600
    MAX_BACKUPS=24
    ;;
  daily)
    INTERVAL=86400
    MAX_BACKUPS=7
    ;;
  weekly)
    INTERVAL=604800
    MAX_BACKUPS=4
    ;;
  *)
    log_info "Unknown backup interval '${BACKUP_INTERVAL}', defaulting to daily"
    INTERVAL=86400
    MAX_BACKUPS=7
    ;;
esac

log_info "Backup interval set to ${BACKUP_INTERVAL} (${INTERVAL} seconds)"
log_info "Will keep last ${MAX_BACKUPS} backups"

while true; do
  # Check if daemon is running before attempting backup
  if pgrep -x "meowcoind" > /dev/null; then
    # Check if blockchain is syncing
    SYNC_STATUS=$(su-exec meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" getblockchaininfo 2>/dev/null | jq -r '.initialblockdownload // true')
    
    # Only backup if not syncing
    if [ "$SYNC_STATUS" != "true" ]; then
      log_info "Starting scheduled backup..."
      
      # Create timestamp for backup
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      BACKUP_FILE="${BACKUP_DIR}/meowcoin-backup-${TIMESTAMP}.dat"
      
<<<<<<< HEAD
      # Create backup with enhanced error logging
      if gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" backupwallet "${BACKUP_FILE}" 2> /tmp/backup_error.log; then
=======
      # Create backup
      if su-exec meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" backupwallet "${BACKUP_FILE}" 2>/dev/null; then
>>>>>>> parent of 0706e65 (refactor)
        log_info "Backup created successfully: ${BACKUP_FILE}"
        BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
        log_info "Backup size: ${BACKUP_SIZE}"
        
        # Verify backup integrity
        if [ -s "${BACKUP_FILE}" ]; then
          log_info "Backup verification: OK"
        else
          log_warning "Backup file exists but appears empty!"
        fi
        
        # Rotate old backups
        BACKUP_COUNT=$(find "${BACKUP_DIR}" -name "meowcoin-backup-*.dat" | wc -l)
        if [ $BACKUP_COUNT -gt $MAX_BACKUPS ]; then
          log_info "Rotating backups, removing oldest files..."
          find "${BACKUP_DIR}" -name "meowcoin-backup-*.dat" | sort | head -n $(($BACKUP_COUNT - $MAX_BACKUPS)) | xargs rm -f
        fi
      else
        log_error "Backup failed with error: $(cat /tmp/backup_error.log)"
      fi
    else
      log_info "Skipping backup while blockchain is syncing"
    fi
  else
    log_info "Meowcoin daemon not running, skipping backup"
  fi
  
  # Sleep until next backup
  log_info "Next backup in $(($INTERVAL / 3600)) hours"
  
  # Check every minute if we should exit
  for i in $(seq 1 $(($INTERVAL / 60))); do
    if [ -f "${MEOWCOIN_DATA}/.meowcoin/shutdown.flag" ]; then
      log_info "Shutdown flag detected, stopping backup manager"
      exit 0
    fi
    sleep 60
  done
done
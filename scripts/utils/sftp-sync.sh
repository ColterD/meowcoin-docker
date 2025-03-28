#!/bin/bash
# Script to sync backups to SFTP server

source /usr/local/bin/core/utils.sh

BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
SFTP_HOST="${BACKUP_SFTP_HOST:-sftp.example.com}"
SFTP_USER="${BACKUP_SFTP_USER:-meowcoin}"
SFTP_PORT="${BACKUP_SFTP_PORT:-22}"
SFTP_PATH="${BACKUP_SFTP_PATH:-/backups}"
SSH_KEY="/home/meowcoin/.ssh/id_ed25519"
LOG_FILE="/var/log/meowcoin/backup.log"
MAX_PARALLEL_UPLOADS=${MAX_PARALLEL_UPLOADS:-2}

log_info "Starting SFTP backup sync"

# Create list of files to sync
find "$BACKUP_DIR" -name "*.tar.gz" | while read file; do
  filename=$(basename "$file")
  if [[ ! -f "$BACKUP_DIR/.$filename.sftpsynced" ]]; then
    echo "$file" >> /tmp/sftp-files-to-sync.txt
  fi
done

if [[ ! -f "/tmp/sftp-files-to-sync.txt" || ! -s "/tmp/sftp-files-to-sync.txt" ]]; then
  log_info "No files to sync"
  rm -f /tmp/sftp-files-to-sync.txt
  exit 0
fi

# Make sure remote directory exists
sftp -i "$SSH_KEY" -P "$SFTP_PORT" -o StrictHostKeyChecking=no -o BatchMode=yes "$SFTP_USER@$SFTP_HOST" << EOF >/dev/null 2>&1
  mkdir -p "$SFTP_PATH"
  bye
EOF

# Use background processes to upload multiple files in parallel
cat /tmp/sftp-files-to-sync.txt | while read file; do
  # Limit parallel uploads
  while [[ $(jobs -p | wc -l) -ge "$MAX_PARALLEL_UPLOADS" ]]; do
    sleep 1
  done
  
  filename=$(basename "$file")
  log_info "Uploading $filename to SFTP"
  
  # Upload in background
  (
    if sftp -i "$SSH_KEY" -P "$SFTP_PORT" -o StrictHostKeyChecking=no -o BatchMode=yes "$SFTP_USER@$SFTP_HOST" << EOF >/dev/null 2>&1
      put "$file" "$SFTP_PATH/$filename"
      put "$file.sha256" "$SFTP_PATH/$filename.sha256"
      bye
EOF
    then
      touch "$BACKUP_DIR/.$filename.sftpsynced"
      log_info "Successfully uploaded $filename to SFTP"
    else
      log_error "Failed to upload $filename to SFTP"
    fi
  ) &
done

# Wait for all uploads to complete
wait

# Clean up
rm -f /tmp/sftp-files-to-sync.txt

log_info "SFTP backup sync completed"
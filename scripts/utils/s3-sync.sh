#!/bin/bash
# Script to sync backups to S3

source /usr/local/bin/core/utils.sh

BACKUP_DIR="/home/meowcoin/.meowcoin/backups"
S3_BUCKET="${BACKUP_S3_BUCKET:-meowcoin-backups}"
S3_PREFIX="${BACKUP_S3_PREFIX:-meowcoin-backups}"
S3_REGION="${BACKUP_S3_REGION:-us-east-1}"
LOG_FILE="/var/log/meowcoin/backup.log"

log_info "Starting S3 backup sync"

# Only sync files we haven't already synced
find "$BACKUP_DIR" -name "*.tar.gz" | while read file; do
  filename=$(basename "$file")
  if [[ ! -f "$BACKUP_DIR/.$filename.s3synced" ]]; then
    log_info "Syncing $filename to S3"
    
    # Upload file with metadata
    if aws s3 cp "$file" "s3://$S3_BUCKET/$S3_PREFIX/$filename" \
       --region "$S3_REGION" \
       --metadata "timestamp=$(date -Iseconds),hostname=$(hostname)" \
       --expected-size $(stat -c%s "$file"); then
      
      # Also upload checksum file
      if [[ -f "$file.sha256" ]]; then
        aws s3 cp "$file.sha256" "s3://$S3_BUCKET/$S3_PREFIX/$filename.sha256" --region "$S3_REGION"
      fi

      # Mark as synced
      touch "$BACKUP_DIR/.$filename.s3synced"
      log_info "Successfully synced $filename to S3"
    else
      log_error "Failed to sync $filename to S3"
    fi
  fi
done

# Verify remote backups if enabled
if [[ "${BACKUP_VERIFY_REMOTE:-true}" == "true" ]]; then
  log_info "Verifying remote backups"
  
  # List files in bucket to verify they exist
  aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX/" --region "$S3_REGION" > "/tmp/s3-files.txt"
  
  # Check for each local synced file
  find "$BACKUP_DIR" -name ".*.s3synced" | while read syncfile; do
    filename=$(basename "$syncfile" | sed 's/^\\.//')
    if grep -q "$filename" "/tmp/s3-files.txt"; then
      log_info "Verified $filename exists in S3"
    else
      log_warning "File $filename missing from S3"
      # Remove sync marker to retry upload
      rm "$syncfile"
    fi
  done
  
  rm -f "/tmp/s3-files.txt"
fi

# Check bucket lifecycle policy if configured
if [[ "${BACKUP_S3_LIFECYCLE_CHECK:-true}" == "true" ]]; then
  log_info "Checking S3 bucket lifecycle policy"
  if ! aws s3api get-bucket-lifecycle-configuration --bucket "$S3_BUCKET" --region "$S3_REGION" >/dev/null 2>&1; then
    log_warning "No lifecycle policy configured for S3 bucket"
    log_warning "Recommend setting up a lifecycle policy to manage remote backup retention"
  fi
fi

log_info "S3 backup sync completed"
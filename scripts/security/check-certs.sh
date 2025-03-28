#!/bin/bash
# Script to check for SSL certificate expiration

CERT_DIR="/home/meowcoin/.meowcoin/certs"
LOG_FILE="/var/log/meowcoin/security.log"
ALERT_DAYS=30

# Create directories if needed
mkdir -p $(dirname $LOG_FILE)
touch $LOG_FILE

echo "[$(date -Iseconds)] Checking SSL certificates" | tee -a $LOG_FILE

# Check if certs directory exists
if [ ! -d "$CERT_DIR" ]; then
  echo "[$(date -Iseconds)] Certificate directory not found: $CERT_DIR" | tee -a $LOG_FILE
  exit 0
fi

# Find all certificate files
find "$CERT_DIR" -name "*.crt" -o -name "*.pem" | while read cert_file; do
  echo "[$(date -Iseconds)] Checking certificate: $cert_file" | tee -a $LOG_FILE
  
  # Get expiration date
  EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
  EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
  CURRENT_EPOCH=$(date +%s)
  DAYS_REMAINING=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
  
  echo "[$(date -Iseconds)] Certificate $cert_file expires in $DAYS_REMAINING days" | tee -a $LOG_FILE
  
  # Check if certificate is expired or will expire soon
  if [ $EXPIRY_EPOCH -lt $CURRENT_EPOCH ]; then
    echo "[$(date -Iseconds)] ERROR: Certificate has expired: $cert_file" | tee -a $LOG_FILE
    
    # Send alert
    if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
      /usr/local/bin/monitoring/send-alert.sh "CRITICAL: SSL certificate has expired: $cert_file" "certificate_expired"
    fi
    
  elif [ $DAYS_REMAINING -lt $ALERT_DAYS ]; then
    echo "[$(date -Iseconds)] WARNING: Certificate will expire soon: $cert_file ($DAYS_REMAINING days)" | tee -a $LOG_FILE
    
    # Send alert
    if [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
      /usr/local/bin/monitoring/send-alert.sh "WARNING: SSL certificate will expire in $DAYS_REMAINING days: $cert_file" "certificate_expiring"
    fi
  fi
done

# Schedule self in cron if not already scheduled
if ! crontab -l | grep -q "check-certs.sh"; then
  (crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/security/check-certs.sh > /dev/null 2>&1") | crontab -
  echo "[$(date -Iseconds)] Scheduled certificate check to run daily" | tee -a $LOG_FILE
fi

echo "[$(date -Iseconds)] Certificate check completed" | tee -a $LOG_FILE
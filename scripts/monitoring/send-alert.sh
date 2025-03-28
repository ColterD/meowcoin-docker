#!/bin/bash
# Script to send alerts through configured channels

MESSAGE="$1"
ALERT_TYPE="${2:-unknown}"
SEVERITY="${3:-warning}"
LOG_FILE="/var/log/meowcoin/alerts.log"
CONFIG_FILE="/etc/meowcoin/alerts.conf"

# Create log directory if needed
mkdir -p $(dirname $LOG_FILE)
touch $LOG_FILE

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  # Default configuration
  ALERT_METHOD="log"
  WEBHOOK_URL=""
  EMAIL_TO=""
  ALERT_COOLDOWN=3600  # 1 hour
fi

# Function to log the alert
log_alert() {
  echo "[$(date -Iseconds)] [$SEVERITY] [$ALERT_TYPE] $MESSAGE" >> $LOG_FILE
}

# Function to check cooldown
check_cooldown() {
  local HISTORY_FILE="/var/log/meowcoin/alert_history.json"
  
  # Create history file if it doesn't exist
  if [ ! -f "$HISTORY_FILE" ]; then
    echo "{}" > "$HISTORY_FILE"
  fi
  
  # Check if we've sent this alert type recently
  if command -v jq >/dev/null 2>&1; then
    local LAST_ALERT_TIME=$(jq -r ".\"$ALERT_TYPE\".timestamp // 0" "$HISTORY_FILE")
    local CURRENT_TIME=$(date +%s)
    
    if [ $((CURRENT_TIME - LAST_ALERT_TIME)) -lt $ALERT_COOLDOWN ]; then
      echo "[$(date -Iseconds)] Alert suppressed (cooldown): $ALERT_TYPE" >> $LOG_FILE
      return 1
    fi
    
    # Update history
    local TEMP_FILE=$(mktemp)
    jq --arg type "$ALERT_TYPE" --arg time "$CURRENT_TIME" --arg msg "$MESSAGE" --arg sev "$SEVERITY" \
       '.[$type] = {"timestamp": $time|tonumber, "message": $msg, "severity": $sev}' \
       "$HISTORY_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$HISTORY_FILE"
  fi
  
  return 0
}

# Check cooldown before proceeding
if ! check_cooldown; then
  exit 0
fi

# Always log the alert
log_alert

# Send alert based on configured method
case "$ALERT_METHOD" in
  "webhook")
    if [ ! -z "$WEBHOOK_URL" ]; then
      # Prepare JSON payload
      PAYLOAD="{\"type\":\"$ALERT_TYPE\",\"message\":\"$MESSAGE\",\"severity\":\"$SEVERITY\",\"timestamp\":\"$(date -Iseconds)\"}"
      
      # Send webhook
      if command -v curl >/dev/null 2>&1; then
        curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK_URL" >> $LOG_FILE 2>&1
      elif command -v wget >/dev/null 2>&1; then
        wget -q --post-data="$PAYLOAD" --header="Content-Type: application/json" -O - "$WEBHOOK_URL" >> $LOG_FILE 2>&1
      else
        echo "[$(date -Iseconds)] Cannot send webhook: curl or wget not found" >> $LOG_FILE
      fi
    else
      echo "[$(date -Iseconds)] Cannot send webhook: URL not configured" >> $LOG_FILE
    fi
    ;;
    
  "email")
    if [ ! -z "$EMAIL_TO" ] && command -v mail >/dev/null 2>&1; then
      # Send email
      echo "$MESSAGE" | mail -s "Meowcoin Node Alert: $ALERT_TYPE [$SEVERITY]" "$EMAIL_TO"
    else
      echo "[$(date -Iseconds)] Cannot send email: missing configuration or mail command" >> $LOG_FILE
    fi
    ;;
    
  "log")
    # Already logged
    ;;
    
  *)
    echo "[$(date -Iseconds)] Unknown alert method: $ALERT_METHOD" >> $LOG_FILE
    ;;
esac

# Record alert in metrics if directory exists
METRICS_DIR="/var/lib/meowcoin/metrics"
if [ -d "$METRICS_DIR" ]; then
  echo "$(date +%s) 1" >> "$METRICS_DIR/alerts_${SEVERITY}.current"
  echo "$(date +%s) 1" >> "$METRICS_DIR/alerts_${ALERT_TYPE}.current"
fi
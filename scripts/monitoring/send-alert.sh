#!/bin/bash
# Script to send alerts through configured channels

MESSAGE="$1"
ALERT_TYPE="${2:-unknown}"
SEVERITY="${3:-warning}"
LOG_FILE="/var/log/meowcoin/alerts.log"
CONFIG_FILE="/etc/meowcoin/alerts.conf"
METRICS_DIR="/var/lib/meowcoin/metrics"
ALERT_HISTORY="/var/lib/meowcoin/alert_history.json"
TRACE_ID="${TRACE_ID:-$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)}"

# Create log directory if needed
mkdir -p $(dirname $LOG_FILE)
touch $LOG_FILE

# Helper function for logging
function log() {
  echo "[$TRACE_ID][$(date -Iseconds)] $1" | tee -a $LOG_FILE
}

# Function to handle errors
function handle_error() {
  local EXIT_CODE=$1
  local ERROR_MESSAGE=$2
  local ERROR_SOURCE=${3:-"send-alert.sh"}
  
  log "ERROR [$ERROR_SOURCE]: $ERROR_MESSAGE (exit code: $EXIT_CODE)"
  
  # Exit if this is a critical error
  if [ $EXIT_CODE -gt 100 ]; then
    exit $EXIT_CODE
  fi
  
  return $EXIT_CODE
}

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  # Default configuration
  ALERT_METHOD="log"
  WEBHOOK_URL=""
  WEBHOOK_AUTH_TOKEN=""
  EMAIL_TO=""
  EMAIL_FROM="meowcoin-node@localhost"
  SMTP_SERVER="localhost"
  SMTP_PORT="25"
  SMTP_USER=""
  SMTP_PASSWORD=""
  SMTP_USE_TLS="false"
  ALERT_COOLDOWN=3600  # 1 hour
  DAILY_SUMMARY="true"
  BATCH_ALERTS="true"
  ALERT_BATCH_INTERVAL=900  # 15 minutes
  ALERT_LEVEL_NODE_SYNC="warning"
  ALERT_LEVEL_CONNECTIONS="warning"
  ALERT_LEVEL_DISK_SPACE="warning"
  ALERT_LEVEL_MEMPOOL="info"
  ALERT_LEVEL_SYSTEM="warning"
  ALERT_LEVEL_SECURITY="critical"
}

# Validate alert category and check if this alert type should be sent based on configured levels
function validate_alert_category() {
  local ALERT_TYPE="$1"
  local SEVERITY="$2"
  
  # Map alert type to category
  local CATEGORY=""
  case "$ALERT_TYPE" in
    node_offline|node_behind|sync_stalled|sync_frozen)
      CATEGORY="NODE_SYNC"
      ;;
    no_inbound|no_outbound|low_peers|peer_anomaly)
      CATEGORY="CONNECTIONS"
      ;;
    low_disk_space|disk_anomaly|disk_trend|high_inode_usage)
      CATEGORY="DISK_SPACE"
      ;;
    high_mempool|high_mempool_mem|mempool_anomaly)
      CATEGORY="MEMPOOL"
      ;;
    high_cpu|high_memory|high_disk_io|cpu_anomaly|memory_anomaly|cpu_trend)
      CATEGORY="SYSTEM"
      ;;
    rpc_connection|rpc_auth|rpc_error|rpc_credentials|security_config)
      CATEGORY="SECURITY"
      ;;
    *)
      # For unknown categories, always allow the alert
      return 0
      ;;
  esac
  
  # Get configuration level for this category
  local CONFIG_VAR="ALERT_LEVEL_${CATEGORY}"
  local CONFIG_LEVEL="${!CONFIG_VAR:-warning}"
  
  # If level is "none", suppress this category of alerts
  if [ "$CONFIG_LEVEL" = "none" ]; then
    log "Alert suppressed (category $CATEGORY disabled): $ALERT_TYPE"
    return 1
  fi
  
  # Check severity levels (critical > warning > info)
  if [ "$SEVERITY" = "critical" ]; then
    # Critical alerts are always sent
    return 0
  elif [ "$SEVERITY" = "warning" ]; then
    # Warning alerts are sent if level is warning or info
    if [ "$CONFIG_LEVEL" = "critical" ]; then
      log "Alert downgraded (category $CATEGORY level is $CONFIG_LEVEL): $ALERT_TYPE"
      return 1
    fi
    return 0
  elif [ "$SEVERITY" = "info" ]; then
    # Info alerts are only sent if level is info
    if [ "$CONFIG_LEVEL" != "info" ]; then
      log "Alert suppressed (category $CATEGORY level is $CONFIG_LEVEL): $ALERT_TYPE"
      return 1
    fi
    return 0
  fi
  
  # Unknown severity, allow the alert
  return 0
}

# Function to check cooldown
function check_cooldown() {
  # Create history directory if needed
  mkdir -p "$(dirname $ALERT_HISTORY)"
  
  # Create history file if it doesn't exist
  if [ ! -f "$ALERT_HISTORY" ]; then
    echo "{}" > "$ALERT_HISTORY"
  fi
  
  # Check if we've sent this alert type recently
  if command -v jq >/dev/null 2>&1; then
    local LAST_ALERT_TIME=$(jq -r ".\"$ALERT_TYPE\".timestamp // 0" "$ALERT_HISTORY")
    local CURRENT_TIME=$(date +%s)
    
    if [ $((CURRENT_TIME - LAST_ALERT_TIME)) -lt $ALERT_COOLDOWN ]; then
      log "Alert suppressed (cooldown): $ALERT_TYPE"
      return 1
    fi
    
    # Update history
    local TEMP_FILE=$(mktemp)
    jq --arg type "$ALERT_TYPE" \
       --arg time "$CURRENT_TIME" \
       --arg msg "$MESSAGE" \
       --arg sev "$SEVERITY" \
       --arg trace "$TRACE_ID" \
       '.[$type] = {"timestamp": $time|tonumber, "message": $msg, "severity": $sev, "trace_id": $trace}' \
       "$ALERT_HISTORY" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$ALERT_HISTORY"
  else
    # Simple fallback without jq
    log "Alert history tracking requires jq, which is not installed"
  fi
  
  return 0
}

# Validate alert category
if ! validate_alert_category "$ALERT_TYPE" "$SEVERITY"; then
  exit 0
fi

# Check cooldown before proceeding
if ! check_cooldown; then
  exit 0
fi

# Always log the alert
log "[$SEVERITY] [$ALERT_TYPE] $MESSAGE"

# Add to batch queue if batching is enabled
if [ "$BATCH_ALERTS" = "true" ]; then
  # Store in batch file
  BATCH_FILE="/tmp/alert_batch.json"
  
  if [ ! -f "$BATCH_FILE" ]; then
    echo '{"alerts":[], "last_sent":0}' > "$BATCH_FILE"
  fi
  
  # Add to batch (with proper JSON handling)
  if command -v jq >/dev/null 2>&1; then
    TEMP_FILE=$(mktemp)
    jq --arg type "$ALERT_TYPE" \
       --arg msg "$MESSAGE" \
       --arg sev "$SEVERITY" \
       --arg time "$(date -Iseconds)" \
       --arg trace "$TRACE_ID" \
       '.alerts += [{"type": $type, "message": $msg, "severity": $sev, "timestamp": $time, "trace_id": $trace}]' \
       "$BATCH_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$BATCH_FILE"
    
    # Check if it's time to send batch
    CURRENT_TIME=$(date +%s)
    LAST_SENT=$(jq -r '.last_sent' "$BATCH_FILE")
    ALERT_COUNT=$(jq -r '.alerts | length' "$BATCH_FILE")
    
    # Send batch if enough time has passed or we have many alerts
    if [ $((CURRENT_TIME - LAST_SENT)) -gt $ALERT_BATCH_INTERVAL ] || [ $ALERT_COUNT -ge 5 ]; then
      # Only send if we have alerts
      if [ $ALERT_COUNT -gt 0 ]; then
        # Critical alerts are sent immediately and also added to batch
        if [ "$SEVERITY" != "critical" ]; then
          # Will send batch in next section
          :
        else
          # Send critical alert immediately, still keep in batch
          send_immediate=true
        fi
      fi
    else
      # Not time to send batch yet, but send critical alerts immediately
      if [ "$SEVERITY" = "critical" ]; then
        send_immediate=true
      else
        # Regular alert added to batch, will send later
        log "Alert added to batch queue (current count: $ALERT_COUNT)"
        exit 0
      fi
    fi
  else
    # No jq, can't manage batch
    log "Alert batching requires jq, which is not installed"
  fi
fi

# Logic for sending the alert based on configured method
function send_alert_via_method() {
  local ALERT_TYPE="$1"
  local ALERT_MESSAGE="$2"
  local ALERT_SEVERITY="$3"
  local IS_BATCH="${4:-false}"
  
  case "$ALERT_METHOD" in
    "webhook")
      if [ ! -z "$WEBHOOK_URL" ]; then
        # Prepare JSON payload with authentication if provided
        local AUTH_HEADER=""
        if [ ! -z "$WEBHOOK_AUTH_TOKEN" ]; then
          AUTH_HEADER="-H \"Authorization: Bearer $WEBHOOK_AUTH_TOKEN\""
        fi
        
        # Create payload
        local PAYLOAD=""
        if [ "$IS_BATCH" = "true" ]; then
          # Batch payload with all alerts
          PAYLOAD=$(jq -c '{"alerts": .alerts, "timestamp": now|tostring, "node": "'$(hostname)'", "trace_id": "'$TRACE_ID'"}' "$BATCH_FILE")
        else
          # Single alert payload
          PAYLOAD="{\"type\":\"$ALERT_TYPE\",\"message\":\"$ALERT_MESSAGE\",\"severity\":\"$ALERT_SEVERITY\",\"timestamp\":\"$(date -Iseconds)\",\"node\":\"$(hostname)\",\"trace_id\":\"$TRACE_ID\"}"
        fi
        
        # Send webhook
        if command -v curl >/dev/null 2>&1; then
          # Use eval to properly handle the AUTH_HEADER variable with quotes
          if ! eval "curl -s --retry 3 --max-time 10 -X POST -H \"Content-Type: application/json\" $AUTH_HEADER -d '$PAYLOAD' \"$WEBHOOK_URL\"" >> $LOG_FILE 2>&1; then
            log "WARNING: Failed to send webhook alert"
          else
            log "Webhook alert sent successfully"
          fi
        elif command -v wget >/dev/null 2>&1; then
          # Similar for wget
          if ! eval "wget -q --tries=3 --timeout=10 --post-data='$PAYLOAD' --header=\"Content-Type: application/json\" $AUTH_HEADER -O - \"$WEBHOOK_URL\"" >> $LOG_FILE 2>&1; then
            log "WARNING: Failed to send webhook alert"
          else
            log "Webhook alert sent successfully"
          fi
        else
          log "WARNING: Cannot send webhook: curl or wget not found"
        fi
      else
        log "WARNING: Cannot send webhook: URL not configured"
      fi
      ;;
      
    "email")
      if [ ! -z "$EMAIL_TO" ]; then
        # Check if mail command exists
        if command -v mail >/dev/null 2>&1; then
          # Format email content
          local EMAIL_SUBJECT=""
          local EMAIL_BODY=""
          
          if [ "$IS_BATCH" = "true" ]; then
            # Batch email
            EMAIL_SUBJECT="Meowcoin Node Alert Digest - $(date '+%Y-%m-%d %H:%M')"
            EMAIL_BODY="Meowcoin Node Alert Digest\n"
            EMAIL_BODY+="Node: $(hostname)\n"
            EMAIL_BODY+="Time: $(date -Iseconds)\n"
            EMAIL_BODY+="Trace ID: $TRACE_ID\n\n"
            EMAIL_BODY+="Alerts:\n"
            
            # Format each alert in the batch
            local ALERTS=$(jq -r '.alerts[] | "- [" + .severity + "] " + .type + ": " + .message' "$BATCH_FILE")
            EMAIL_BODY+="$ALERTS\n\n"
          else
            # Single alert email
            EMAIL_SUBJECT="Meowcoin Node Alert: $ALERT_TYPE [$ALERT_SEVERITY]"
            EMAIL_BODY="$ALERT_MESSAGE\n\n"
            EMAIL_BODY+="Alert Type: $ALERT_TYPE\n"
            EMAIL_BODY+="Severity: $ALERT_SEVERITY\n"
            EMAIL_BODY+="Node: $(hostname)\n"
            EMAIL_BODY+="Time: $(date -Iseconds)\n"
            EMAIL_BODY+="Trace ID: $TRACE_ID\n"
          fi
          
          # Send email using mail command
          echo -e "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO"
          log "Email alert sent to $EMAIL_TO"
        elif command -v sendemail >/dev/null 2>&1 && [ ! -z "$SMTP_SERVER" ]; then
          # Alternative: use sendemail if available with SMTP configuration
          local SMTP_ARGS=""
          if [ "$SMTP_USE_TLS" = "true" ]; then
            SMTP_ARGS="$SMTP_ARGS -o tls=yes"
          fi
          if [ ! -z "$SMTP_USER" ] && [ ! -z "$SMTP_PASSWORD" ]; then
            SMTP_ARGS="$SMTP_ARGS -xu $SMTP_USER -xp $SMTP_PASSWORD"
          fi
          
          # Format email content (similar to above)
          local EMAIL_SUBJECT=""
          local EMAIL_BODY=""
          
          if [ "$IS_BATCH" = "true" ]; then
            # Batch email format
            EMAIL_SUBJECT="Meowcoin Node Alert Digest - $(date '+%Y-%m-%d %H:%M')"
            EMAIL_BODY="Meowcoin Node Alert Digest\n"
            EMAIL_BODY+="Node: $(hostname)\n"
            EMAIL_BODY+="Time: $(date -Iseconds)\n"
            EMAIL_BODY+="Trace ID: $TRACE_ID\n\n"
            EMAIL_BODY+="Alerts:\n"
            EMAIL_BODY+=$(jq -r '.alerts[] | "- [" + .severity + "] " + .type + ": " + .message' "$BATCH_FILE")
          else
            # Single alert
            EMAIL_SUBJECT="Meowcoin Node Alert: $ALERT_TYPE [$ALERT_SEVERITY]"
            EMAIL_BODY="$ALERT_MESSAGE\n\n"
            EMAIL_BODY+="Alert Type: $ALERT_TYPE\n"
            EMAIL_BODY+="Severity: $ALERT_SEVERITY\n"
            EMAIL_BODY+="Node: $(hostname)\n"
            EMAIL_BODY+="Time: $(date -Iseconds)\n"
            EMAIL_BODY+="Trace ID: $TRACE_ID\n"
          fi
          
          # Send via sendemail with SMTP configuration
          echo -e "$EMAIL_BODY" | sendemail -f "$EMAIL_FROM" -t "$EMAIL_TO" -u "$EMAIL_SUBJECT" \
            -s "$SMTP_SERVER:$SMTP_PORT" $SMTP_ARGS
          log "Email alert sent via SMTP"
        else
          log "WARNING: Cannot send email: no mail command available"
        fi
      else
        log "WARNING: Cannot send email: recipient address not configured"
      fi
      ;;
      
    "log")
      # Already logged above
      ;;
      
    *)
      log "WARNING: Unknown alert method: $ALERT_METHOD"
      ;;
  esac
}

# Send immediate alert if needed (for critical alerts)
if [ "$send_immediate" = "true" ]; then
  send_alert_via_method "$ALERT_TYPE" "$MESSAGE" "$SEVERITY" "false"
fi

# Send batch if it's time
if [ "$BATCH_ALERTS" = "true" ] && command -v jq >/dev/null 2>&1; then
  CURRENT_TIME=$(date +%s)
  LAST_SENT=$(jq -r '.last_sent' "$BATCH_FILE")
  ALERT_COUNT=$(jq -r '.alerts | length' "$BATCH_FILE")
  
  if ([ $((CURRENT_TIME - LAST_SENT)) -gt $ALERT_BATCH_INTERVAL ] || [ $ALERT_COUNT -ge 5 ]) && [ $ALERT_COUNT -gt 0 ]; then
    log "Sending batch of $ALERT_COUNT alerts"
    
    # Send the batch alert
    send_alert_via_method "batch" "Batch of $ALERT_COUNT alerts" "info" "true"
    
    # Update last sent time and clear alerts
    jq --arg time "$CURRENT_TIME" '.last_sent = ($time | tonumber) | .alerts = []' "$BATCH_FILE" > "${BATCH_FILE}.new"
    mv "${BATCH_FILE}.new" "$BATCH_FILE"
    
    exit 0
  fi
fi

# If not batching or sending immediate, send regular alert
if [ "$BATCH_ALERTS" != "true" ]; then
  send_alert_via_method "$ALERT_TYPE" "$MESSAGE" "$SEVERITY" "false"
fi

# Record alert in metrics if directory exists
if [ -d "$METRICS_DIR" ]; then
  echo "$(date +%s) 1" >> "$METRICS_DIR/alerts_${SEVERITY}.current"
  echo "$(date +%s) 1" >> "$METRICS_DIR/alerts_${ALERT_TYPE}.current"
fi

# Report success
exit 0
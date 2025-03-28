#!/bin/bash
# Alert generation functions

# Function to send alerts with tracing
function send_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local SEVERITY="${3:-warning}"
  local TRACE_ID="$DISTRIBUTED_TRACE_ID"
  
  # Check if alerts are enabled
  if [ "${ENABLE_ALERTS:-true}" != "true" ]; then
    log "Alert suppressed (alerts disabled): $ALERT_TYPE - $MESSAGE"
    return
  fi
  
  # Check for alert cooldown
  if [ -f "$ALERT_HISTORY" ]; then
    local LAST_ALERT_TIME=$(jq -r ".[\"$ALERT_TYPE\"].timestamp // 0" "$ALERT_HISTORY")
    local CURRENT_TIME=$(date +%s)
    
    if [ $((CURRENT_TIME - LAST_ALERT_TIME)) -lt ${ALERT_COOLDOWN:-3600} ]; then
      log "Alert suppressed (cooldown): $ALERT_TYPE - $MESSAGE"
      return
    fi
  fi
  
  log "ALERT [$SEVERITY]: $MESSAGE"
  
  # Record this alert
  mkdir -p "$(dirname "$ALERT_HISTORY")"
  if [ ! -f "$ALERT_HISTORY" ]; then
    echo "{}" > "$ALERT_HISTORY"
  fi
  
  # Update alert history
  local TIMESTAMP=$(date +%s)
  local TEMP_FILE=$(mktemp)
  jq --arg type "$ALERT_TYPE" \
     --arg timestamp "$TIMESTAMP" \
     --arg message "$MESSAGE" \
     --arg severity "$SEVERITY" \
     --arg trace_id "$TRACE_ID" \
     '.[$type] = {"timestamp": $timestamp|tonumber, "message": $message, "severity": $severity, "trace_id": $trace_id}' \
     "$ALERT_HISTORY" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$ALERT_HISTORY"
  
  # Send via configured method
  case "${ALERT_METHOD:-log}" in
    "webhook")
      send_webhook_alert "$ALERT_TYPE" "$MESSAGE" "$SEVERITY" "$TRACE_ID"
      ;;
    "email")
      send_email_alert "$ALERT_TYPE" "$MESSAGE" "$SEVERITY" "$TRACE_ID"
      ;;
    "log")
      # Already logged above
      ;;
    *)
      log "Unknown alert method: $ALERT_METHOD"
      ;;
  esac
  
  # Record alert in metrics
  record_metric "alerts_total" "1" "counter"
  record_metric "alert_${SEVERITY}_total" "1" "counter"
  record_metric "alert_${ALERT_TYPE}_total" "1" "counter"
  
  # Execute health check hook if plugin system available
  if [ -x /usr/local/bin/entrypoint/plugins.sh ]; then
    TRACE_ID="$TRACE_ID" HOOK_ARGS="$ALERT_TYPE $MESSAGE $SEVERITY" /usr/local/bin/entrypoint/plugins.sh execute_hooks "health_check"
  fi
}

# Function to send webhook alerts
function send_webhook_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local SEVERITY="$3"
  local TRACE_ID="$4"
  
  if [ -z "${ALERT_WEBHOOK_URL}" ]; then
    log "Cannot send webhook: URL not configured"
    return 1
  fi
  
  # Prepare JSON payload
  local PAYLOAD="{\"type\":\"$ALERT_TYPE\",\"message\":\"$MESSAGE\",\"severity\":\"$SEVERITY\",\"timestamp\":\"$(date -Iseconds)\",\"node\":\"$(hostname)\",\"trace_id\":\"$TRACE_ID\"}"
  
  # Use curl or wget with retries and validation
  if command -v curl >/dev/null 2>&1; then
    if ! curl -s --retry 3 --max-time 10 -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "${ALERT_WEBHOOK_URL}" >> $LOG_FILE 2>&1; then
      log "Failed to send webhook alert"
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -q --tries=3 --timeout=10 --post-data="$PAYLOAD" --header="Content-Type: application/json" -O - "${ALERT_WEBHOOK_URL}" >> $LOG_FILE 2>&1; then
      log "Failed to send webhook alert"
      return 1
    fi
  else
    log "Cannot send webhook: curl or wget not found"
    return 1
  fi
  
  return 0
}

# Function to send email alerts
function send_email_alert() {
  local ALERT_TYPE="$1"
  local MESSAGE="$2"
  local SEVERITY="$3"
  local TRACE_ID="$4"
  
  if [ -z "${ALERT_EMAIL}" ]; then
    log "Cannot send email: recipient address not configured"
    return 1
  fi
  
  # Check if mail command exists
  if command -v mail >/dev/null 2>&1; then
    # Format email content
    local EMAIL_SUBJECT="Meowcoin Node Alert: $ALERT_TYPE [$SEVERITY]"
    local EMAIL_BODY="$MESSAGE

Alert ID: $TRACE_ID
Time: $(date -Iseconds)
Node: $(hostname)
"
    # Send email
    if ! echo "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" "$ALERT_EMAIL"; then
      log "Failed to send email alert"
      return 1
    fi
  else
    log "Cannot send email: mail command not available"
    return 1
  fi
  
  return 0
}

# Function to assess overall health status
function evaluate_health_status() {
  # Store status in JSON format with improved content and tracing
  cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_id": "$DISTRIBUTED_TRACE_ID",
  "check_time": $(date +%s),
  "blockchain": {
    "blocks": $BLOCKS,
    "headers": $HEADERS,
    "blocks_behind": $BLOCKS_BEHIND,
    "verification_progress": $VERIFICATION_PROGRESS,
    "chain": "$CHAIN"
  },
  "network": {
    "connections": $CONNECTIONS,
    "network_ok": $NETWORK_OK,
    "version": $VERSION,
    "subversion": "$SUBVERSION",
    "protocol_version": $PROTOCOL_VERSION
  },
  "mempool": {
    "transactions": $MEMPOOL_SIZE,
    "bytes": $MEMPOOL_BYTES,
    "usage": $MEMPOOL_USAGE,
    "max_mem": $MEMPOOL_MAX_MEM
  },
  "system": {
    "disk_space_gb": $AVAILABLE_SPACE_GB,
    "total_space_gb": $TOTAL_SPACE_GB,
    "disk_usage_pct": $DISK_USAGE_PCT,
    "disk_space_warning": $([ $AVAILABLE_SPACE_GB -lt $MIN_FREE_SPACE_GB ] && echo "true" || echo "false")
  },
  "status": "unknown"
}
EOF
  
  # Evaluate health with improved detection
  HEALTH_ISSUES=0
  ALERT_SEVERITY="info"
  
  # Check if node is in sync
  if [ $BLOCKS_BEHIND -gt $MAX_BLOCKS_BEHIND ]; then
    log "Node is $BLOCKS_BEHIND blocks behind headers"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    ALERT_SEVERITY="warning"
    
    # Check sync progress
    if (( $(echo "$VERIFICATION_PROGRESS < 0.999" | bc -l) )); then
      sed -i 's/"status": "unknown"/"status": "syncing"/' "$STATUS_FILE"
      SYNC_PERCENT=$(echo "$VERIFICATION_PROGRESS * 100" | bc -l | xargs printf "%.2f")
      log "Node is syncing, $SYNC_PERCENT% complete"
    else
      sed -i 's/"status": "unknown"/"status": "behind"/' "$STATUS_FILE"
    fi
    
    send_alert "node_behind" "Node is $BLOCKS_BEHIND blocks behind headers" "warning"
  fi
  
  # Check peer connections
  if [ $CONNECTIONS -lt $MIN_PEERS ]; then
    log "Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    ALERT_SEVERITY="warning"
    sed -i 's/"status": "unknown"/"status": "low_peers"/' "$STATUS_FILE"
    send_alert "low_peers" "Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)" "warning"
  fi
  
  # Check mempool size
  if [ $MEMPOOL_SIZE -gt $MAX_MEMPOOL_SIZE ]; then
    log "Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    sed -i 's/"status": "unknown"/"status": "high_mempool"/' "$STATUS_FILE"
    send_alert "high_mempool" "Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)" "warning"
  fi
  
  # Check mempool memory usage
  MEMPOOL_USAGE_PCT=$(echo "scale=2; $MEMPOOL_USAGE * 100 / $MEMPOOL_MAX_MEM" | bc)
  if (( $(echo "$MEMPOOL_USAGE_PCT > 90" | bc -l) )); then
    log "High mempool memory usage: ${MEMPOOL_USAGE_PCT}% of maximum"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    send_alert "high_mempool_mem" "High mempool memory usage: ${MEMPOOL_USAGE_PCT}% of maximum" "warning"
  fi
  
  # Final health determination
  if [ $HEALTH_ISSUES -eq 0 ]; then
    # Node is healthy
    sed -i 's/"status": "unknown"/"status": "healthy"/' "$STATUS_FILE"
    log "Node is healthy: $BLOCKS blocks, $CONNECTIONS peers, $MEMPOOL_SIZE mempool transactions"
    
    # Execute plugin hooks
    if [ -x /usr/local/bin/entrypoint/plugins.sh ]; then
      TRACE_ID="$DISTRIBUTED_TRACE_ID" HOOK_ARGS="healthy" /usr/local/bin/entrypoint/plugins.sh execute_hooks "health_check"
    fi
  else
    # Node has issues
    log "Node has $HEALTH_ISSUES health issues"
    
    # If status is still unknown, set it based on severity
    if grep -q '"status": "unknown"' "$STATUS_FILE"; then
      if [ "$ALERT_SEVERITY" = "critical" ]; then
        sed -i 's/"status": "unknown"/"status": "critical"/' "$STATUS_FILE"
      else
        sed -i 's/"status": "unknown"/"status": "warning"/' "$STATUS_FILE"
      fi
    fi
    
    # Update status file with issue count
    sed -i "s/\"check_time\": \([0-9]*\)/\"check_time\": \1, \"issues\": $HEALTH_ISSUES/" "$STATUS_FILE"
    
    # Execute plugin hooks
    if [ -x /usr/local/bin/entrypoint/plugins.sh ]; then
      TRACE_ID="$DISTRIBUTED_TRACE_ID" HOOK_ARGS="unhealthy $HEALTH_ISSUES" /usr/local/bin/entrypoint/plugins.sh execute_hooks "health_check"
    fi
  fi
}
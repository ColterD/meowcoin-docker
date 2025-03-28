#!/bin/bash
# Common functions for health checking

# Helper function for logging
function log() {
  echo "[$DISTRIBUTED_TRACE_ID][$(date -Iseconds)] $1" | tee -a $LOG_FILE
}

# Error handling function
function handle_error() {
  local EXIT_CODE=$1
  local ERROR_MESSAGE=$2
  local ERROR_SOURCE=${3:-"health-check.sh"}
  
  log "ERROR [$ERROR_SOURCE]: $ERROR_MESSAGE (exit code: $EXIT_CODE)"
  
  # Send alert if monitoring is configured
  if [ "${ENABLE_ALERTS:-true}" = "true" ] && [ -x /usr/local/bin/monitoring/send-alert.sh ]; then
    /usr/local/bin/monitoring/send-alert.sh "Health check error: $ERROR_MESSAGE" "health_check_error" "warning"
  fi
  
  return $EXIT_CODE
}

# Function to record metrics
function record_metric() {
  local METRIC_NAME="$1"
  local METRIC_VALUE="$2"
  local TIMESTAMP=$(date +%s)
  local METRIC_TYPE="${3:-gauge}"
  
  # Sanitize metric name
  if [[ ! "$METRIC_NAME" =~ ^[a-zA-Z0-9_\.]+$ ]]; then
    log "Invalid metric name: $METRIC_NAME"
    return 1
  fi
  
  # Validate metric value (should be numeric)
  if [[ ! "$METRIC_VALUE" =~ ^[-]?[0-9]+\.?[0-9]*$ ]]; then
    log "Non-numeric metric value for $METRIC_NAME: $METRIC_VALUE"
    return 1
  fi
  
  # Save current metric
  echo "$TIMESTAMP $METRIC_VALUE" >> "$METRICS_DIR/${METRIC_NAME}.current"
  
  # Store in historical data with retention
  mkdir -p "$HISTORICAL_DATA"
  echo "$TIMESTAMP $METRIC_VALUE" >> "$HISTORICAL_DATA/${METRIC_NAME}.data"
  
  # Keep only last 1000 data points to prevent unbounded growth
  if [ -f "$HISTORICAL_DATA/${METRIC_NAME}.data" ] && [ $(wc -l < "$HISTORICAL_DATA/${METRIC_NAME}.data") -gt 1000 ]; then
    tail -n 1000 "$HISTORICAL_DATA/${METRIC_NAME}.data" > "$HISTORICAL_DATA/${METRIC_NAME}.data.tmp"
    mv "$HISTORICAL_DATA/${METRIC_NAME}.data.tmp" "$HISTORICAL_DATA/${METRIC_NAME}.data"
  fi
  
  return 0
}

# Function to extract JSON values safely
function extract_json_value() {
  local JSON="$1"
  local KEY="$2"
  local DEFAULT="$3"
  
  # Use 'jq' if available for more reliable JSON parsing
  if command -v jq >/dev/null 2>&1; then
    local VALUE=$(echo "$JSON" | jq -r ".$KEY // \"$DEFAULT\"" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$VALUE" = "null" ] || [ -z "$VALUE" ]; then
      echo "$DEFAULT"
    else
      echo "$VALUE"
    fi
  else
    # Fallback to grep for simple cases
    local VALUE=$(echo "$JSON" | grep -m 1 "\"$KEY\"" | sed -E "s/.*\"$KEY\"[^0-9]*([0-9]+\.?[0-9]*).*/\1/")
    if [ -z "$VALUE" ]; then
      echo "$DEFAULT"
    else
      echo "$VALUE"
    fi
  fi
}

# Helper function to get RPC credentials with JWT support
function get_rpc_auth() {
  # Support for JWT authentication
  if grep -q "jwt=1" "$CONFIG_FILE" || grep -q "rpcauth=jwtsecret" "$CONFIG_FILE"; then
    JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
    if [ -f "$JWT_SECRET_FILE" ]; then
      # Get public key if available
      JWT_PUB_FILE="${JWT_SECRET_FILE}.pub"
      if [ -f "$JWT_PUB_FILE" ]; then
        JWT_TOKEN=$(xxd -p -c 1000 "$JWT_PUB_FILE")
      else
        JWT_TOKEN=$(xxd -p -c 1000 "$JWT_SECRET_FILE")
      fi
      echo "-rpcauth=$JWT_TOKEN"
      return 0
    fi
  fi
  
  # Default to username/password auth
  USER=$(grep -m 1 "rpcuser=" "$CONFIG_FILE" | cut -d= -f2)
  PASS=$(grep -m 1 "rpcpassword=" "$CONFIG_FILE" | cut -d= -f2)
  
  if [ -z "$USER" ] || [ -z "$PASS" ]; then
    # Fallback to password file if config doesn't have credentials
    if [ -f "/home/meowcoin/.meowcoin/.rpcpassword" ]; then
      USER="meowcoin"
      PASS=$(cat "/home/meowcoin/.meowcoin/.rpcpassword")
    else
      log "Cannot find RPC credentials"
      send_alert "rpc_credentials" "RPC credentials not found" "critical"
      return 1
    fi
  fi
  
  echo "-rpcuser=$USER -rpcpassword=$PASS"
}

# Function to execute RPC commands with retry and timeout
function execute_rpc() {
  local CMD="$1"
  shift
  local MAX_ATTEMPTS=3
  local ATTEMPT=1
  local AUTH=$(get_rpc_auth)
  
  while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    # Execute with timeout (separately capture stdout and stderr)
    local TEMP_OUT=$(mktemp)
    local TEMP_ERR=$(mktemp)
    
    if timeout $RPC_TIMEOUT_SECONDS meowcoin-cli $AUTH $CMD "$@" > "$TEMP_OUT" 2> "$TEMP_ERR"; then
      local RESULT=$(cat "$TEMP_OUT")
      rm -f "$TEMP_OUT" "$TEMP_ERR"
      echo "$RESULT"
      return 0
    else
      local EXIT_CODE=$?
      local ERROR=$(cat "$TEMP_ERR")
      rm -f "$TEMP_OUT" "$TEMP_ERR"
      
      # Check for specific error types
      if [[ "$ERROR" == *"Connection refused"* ]]; then
        log "RPC connection refused (attempt $ATTEMPT/$MAX_ATTEMPTS)"
      elif [[ "$ERROR" == *"Timeout"* || $EXIT_CODE -eq 124 ]]; then
        log "RPC command timed out (attempt $ATTEMPT/$MAX_ATTEMPTS)"
      elif [[ "$ERROR" == *"incorrect password"* || "$ERROR" == *"unauthorized"* ]]; then
        log "RPC authentication failed"
        send_alert "rpc_auth" "RPC authentication failed" "critical"
        return 1
      else
        log "RPC command failed: $CMD (attempt $ATTEMPT/$MAX_ATTEMPTS): $ERROR"
      fi
      
      if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        log "All RPC attempts failed for command: $CMD"
        return $EXIT_CODE
      fi
      
      # Use exponential backoff
      local DELAY=$(( 2 ** (ATTEMPT - 1) ))
      log "Retrying in $DELAY seconds..."
      sleep $DELAY
      ATTEMPT=$((ATTEMPT + 1))
    fi
  done
  
  return 1
}

# Check if node is running
function check_node_running() {
  # Check both meowcoind and meowcoin-qt (in case of GUI node)
  if ! pgrep -x "meowcoind" > /dev/null && ! pgrep -x "meowcoin-qt" > /dev/null; then
    log "Meowcoin daemon is not running"
    
    # Check for crash logs
    local CRASH_LOG=$(find /home/meowcoin/.meowcoin -name "core.*" -o -name "crash_*" -o -name "*.core" -o -name "*.dump" | sort -r | head -1)
    if [ ! -z "$CRASH_LOG" ]; then
      log "Found potential crash evidence: $CRASH_LOG"
      # Extract crash info if core dump tools available
      if command -v gdb >/dev/null 2>&1; then
        log "Crash analysis:"
        gdb -batch -ex "thread apply all bt" /usr/bin/meowcoind "$CRASH_LOG" 2>/dev/null | head -20 >> $LOG_FILE
      fi
    fi
    
    # Check recent logs for error patterns
    if [ -f "/home/meowcoin/.meowcoin/debug.log" ]; then
      log "Last 10 log entries before crash:"
      tail -n 10 "/home/meowcoin/.meowcoin/debug.log" >> $LOG_FILE
    fi
    
    # Write status file
    cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "offline",
  "trace_id": "$DISTRIBUTED_TRACE_ID",
  "error": "Daemon not running",
  "check_time": $(date +%s)
}
EOF
    
    # Send alert
    send_alert "node_offline" "Meowcoin daemon is not running" "critical"
    
    return 1
  fi
  
  return 0
}
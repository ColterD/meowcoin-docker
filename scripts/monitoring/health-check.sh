#!/bin/bash
set -e

# Configuration
CONFIG_FILE="/home/meowcoin/.meowcoin/meowcoin.conf"
THRESHOLD_FILE="/etc/meowcoin/health/thresholds.conf"
STATUS_FILE="/tmp/meowcoin_health_status.json"
LOG_FILE="/var/log/meowcoin/health-check.log"
METRICS_DIR="/var/lib/meowcoin/metrics"
ALERT_HISTORY="/var/lib/meowcoin/alert_history.json"
HISTORICAL_DATA="/var/lib/meowcoin/historical_data"
CONNECTIVITY_TEST_HOSTS=("1.1.1.1" "8.8.8.8")
ALERT_COOLDOWN=3600  # Don't send duplicate alerts within this time period (seconds)
ANOMALY_DETECTION_ENABLED=true
RESOURCE_CHECK_ENABLED=true
DISTRIBUTED_TRACE_ID="${TRACE_ID:-$(date +%s)-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)}"

# Ensure directories exist
mkdir -p "$(dirname $STATUS_FILE)" "$(dirname $LOG_FILE)" "$METRICS_DIR" "$(dirname $ALERT_HISTORY)" "$HISTORICAL_DATA"

# Load thresholds
if [ -f "$THRESHOLD_FILE" ]; then
  source "$THRESHOLD_FILE"
else
  # Default thresholds
  MAX_BLOCKS_BEHIND=6
  MIN_PEERS=3
  MAX_MEMPOOL_SIZE=300
  HEALTH_CHECK_INTERVAL=300
  ALERT_ON_SYNC_STALLED=true
  CHECK_DISK_SPACE=true
  MIN_FREE_SPACE_GB=5
  MAX_CPU_USAGE=90
  MAX_MEMORY_USAGE=90
  MIN_NETWORK_PEERS=3
  RPC_TIMEOUT_SECONDS=5
  DISK_IO_THRESHOLD=90
  ENABLE_ALERTS=true
  ALERT_METHOD="log"  # Options: log, webhook, email
  ALERT_WEBHOOK_URL=""
  ALERT_EMAIL=""
fi

# Create log entry
echo "[$DISTRIBUTED_TRACE_ID][$(date -Iseconds)] Running health check" > $LOG_FILE

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
    /usr/local/bin/monitoring/send-alert.sh "Health check error: $ERROR_MESSAGE" "health_check_error" "

# Function to record metrics
function record_metric() {
  local METRIC_NAME="$1"
  local METRIC_VALUE="$2"
  local TIMESTAMP=$(date +%s)
  local METRIC_TYPE="${3:-gauge}"
  
  # Sanitize metric name
  if [[ ! "$METRIC_NAME" =~ ^[a-zA-Z0-9_\.]+$ ]]; then
    log "WARNING: Invalid metric name: $METRIC_NAME"
    return 1
  fi
  
  # Validate metric value (should be numeric)
  if [[ ! "$METRIC_VALUE" =~ ^[-]?[0-9]+\.?[0-9]*$ ]]; then
    log "WARNING: Non-numeric metric value for $METRIC_NAME: $METRIC_VALUE"
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

# Function to detect traditional anomalies using standard deviation
function detect_anomaly() {
  local METRIC_NAME="$1"
  local CURRENT_VALUE="$2"
  local THRESHOLD="$3"
  local HISTORY_FILE="$HISTORICAL_DATA/${METRIC_NAME}.data"
  
  # Need at least 10 data points for anomaly detection
  if [ ! -f "$HISTORY_FILE" ] || [ $(wc -l < "$HISTORY_FILE") -lt 10 ]; then
    return 1  # Not enough data
  fi
  
  # Calculate mean and standard deviation
  local MEAN=$(awk '{sum+=$2} END {print sum/NR}' "$HISTORY_FILE")
  local STDDEV=$(awk -v mean=$MEAN '{sum+=($2-mean)^2} END {print sqrt(sum/NR)}' "$HISTORY_FILE")
  
  # Check for division by zero or very small stddev
  if [ $(echo "$STDDEV < 0.0001" | bc -l) -eq 1 ]; then
    return 1  # Can't reliably detect anomalies with near-zero variance
  fi
  
  # Calculate z-score (number of std devs from mean)
  local ZSCORE=$(echo "scale=2; ($CURRENT_VALUE - $MEAN) / $STDDEV" | bc -l)
  
  # Record the z-score
  record_metric "${METRIC_NAME}_zscore" "$ZSCORE" "gauge"
  
  # Check if value is anomalous (beyond threshold standard deviations)
  if (( $(echo "sqrt($ZSCORE * $ZSCORE) > $THRESHOLD" | bc -l) )); then
    log "ANOMALY DETECTED: $METRIC_NAME current=$CURRENT_VALUE mean=$MEAN stddev=$STDDEV zscore=$ZSCORE"
    return 0  # Anomaly detected
  fi
  
  return 1  # No anomaly
}

# Function to detect trend anomalies
function detect_trend_anomaly() {
  local METRIC_NAME="$1"
  local HISTORY_FILE="$HISTORICAL_DATA/${METRIC_NAME}.data"
  
  # Need at least 10 data points
  if [ ! -f "$HISTORY_FILE" ] || [ $(wc -l < "$HISTORY_FILE") -lt 10 ]; then
    return 1
  fi
  
  # Get last 10 measurements
  local RECENT_DATA=$(tail -n 10 "$HISTORY_FILE")
  
  # Calculate trend using linear regression slope
  local SLOPE=$(echo "$RECENT_DATA" | awk '
    BEGIN { x_sum=0; y_sum=0; xy_sum=0; x2_sum=0; n=0; }
    { 
      x[n] = n+1; 
      y[n] = $2; 
      x_sum += x[n]; 
      y_sum += y[n]; 
      xy_sum += x[n]*y[n]; 
      x2_sum += x[n]*x[n];
      n++;
    } 
    END {
      slope = (n*xy_sum - x_sum*y_sum) / (n*x2_sum - x_sum*x_sum);
      print slope;
    }')
  
  # Normalize slope based on mean value to get percent change
  local MEAN=$(echo "$RECENT_DATA" | awk '{sum+=$2} END {print sum/NR}')
  local PERCENT_CHANGE=$(echo "scale=2; $SLOPE * 10 / $MEAN * 100" | bc -l)
  
  # Record the trend data
  record_metric "${METRIC_NAME}_trend" "$PERCENT_CHANGE" "gauge"
  
  # Detect significant trends (configurable thresholds)
  local TREND_THRESHOLD="${TREND_THRESHOLD:-5}"  # Default 5% change over 10 points
  
  if (( $(echo "sqrt($PERCENT_CHANGE * $PERCENT_CHANGE) > $TREND_THRESHOLD" | bc -l) )); then
    local DIRECTION=$([ $(echo "$PERCENT_CHANGE > 0" | bc -l) -eq 1 ] && echo "increasing" || echo "decreasing")
    log "TREND ANOMALY: $METRIC_NAME showing significant $DIRECTION trend ($PERCENT_CHANGE% per 10 points)"
    return 0  # Trend anomaly detected
  fi
  
  return 1  # No trend anomaly
}

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
    
    if [ $((CURRENT_TIME - LAST_ALERT_TIME)) -lt $ALERT_COOLDOWN ]; then
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
      if [ ! -z "${ALERT_WEBHOOK_URL}" ]; then
        # Prepare JSON payload
        local PAYLOAD="{\"type\":\"$ALERT_TYPE\",\"message\":\"$MESSAGE\",\"severity\":\"$SEVERITY\",\"timestamp\":\"$(date -Iseconds)\",\"trace_id\":\"$TRACE_ID\"}"
        
        # Use curl or wget with retries and validation
        if command -v curl >/dev/null 2>&1; then
          if ! curl -s --retry 3 --max-time 10 -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "${ALERT_WEBHOOK_URL}" >> $LOG_FILE 2>&1; then
            log "WARNING: Failed to send webhook alert"
          fi
        elif command -v wget >/dev/null 2>&1; then
          if ! wget -q --tries=3 --timeout=10 --post-data="$PAYLOAD" --header="Content-Type: application/json" -O - "${ALERT_WEBHOOK_URL}" >> $LOG_FILE 2>&1; then
            log "WARNING: Failed to send webhook alert"
          fi
        else
          log "WARNING: Cannot send webhook: curl or wget not found"
        fi
      else
        log "WARNING: Cannot send webhook: URL not configured"
      fi
      ;;
      
    "email")
      if [ ! -z "${ALERT_EMAIL}" ] && command -v mail >/dev/null 2>&1; then
        # Send email with trace ID
        echo "$MESSAGE

Alert ID: $TRACE_ID
Time: $(date -Iseconds)
Node: $(hostname)
" | mail -s "Meowcoin Node Alert: $ALERT_TYPE [$SEVERITY]" "$ALERT_EMAIL"
      else
        log "WARNING: Cannot send email: missing configuration or mail command"
      fi
      ;;
      
    "log")
      # Already logged above
      ;;
      
    *)
      log "WARNING: Unknown alert method: $ALERT_METHOD"
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

# Helper function to get RPC credentials with improved JWT support
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
      log "ERROR: Cannot find RPC credentials"
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

# Check if node is running with improved detection
function check_node_running() {
  # Check both meowcoind and meowcoin-qt (in case of GUI node)
  if ! pgrep -x "meowcoind" > /dev/null && ! pgrep -x "meowcoin-qt" > /dev/null; then
    log "ERROR: Meowcoin daemon is not running"
    
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

# Check network connectivity to important resources
function check_network_connectivity() {
  local NETWORK_OK=true
  
  # Test DNS resolution first
  if ! nslookup -timeout=2 google.com >/dev/null 2>&1 && ! nslookup -timeout=2 cloudflare.com >/dev/null 2>&1; then
    log "WARNING: DNS resolution issues detected"
    NETWORK_OK=false
    send_alert "network_dns" "DNS resolution issues detected" "warning"
  fi
  
  # Test connectivity to important resources
  for HOST in "${CONNECTIVITY_TEST_HOSTS[@]}"; do
    if ! ping -c 1 -W 5 "$HOST" >/dev/null 2>&1; then
      log "WARNING: Network connectivity issue detected - cannot reach $HOST"
      NETWORK_OK=false
    fi
  done
  
  # Check for internet connectivity via HTTPS
  if command -v curl >/dev/null 2>&1; then
    if ! curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1 && \
       ! curl -s --connect-timeout 5 https://www.cloudflare.com >/dev/null 2>&1; then
      log "WARNING: HTTPS connectivity issues detected"
      NETWORK_OK=false
      send_alert "network_https" "HTTPS connectivity issues detected" "warning"
    fi
  fi
  
  if [ "$NETWORK_OK" = "false" ]; then
    send_alert "network_connectivity" "Network connectivity issues detected" "warning"
  fi
  
  return $([[ "$NETWORK_OK" == "true" ]] && echo 0 || echo 1)
}

# Main health check function
function run_health_check() {
  log "Starting health check (trace ID: $DISTRIBUTED_TRACE_ID)"
  
  # Make sure the node is running first
  if ! check_node_running; then
    return 1
  fi
  
  # Check network connectivity
  NETWORK_OK=true
  if ! check_network_connectivity; then
    NETWORK_OK=false
    log "Network connectivity issues detected"
  fi
  
  # Get RPC auth
  RPC_AUTH=$(get_rpc_auth)
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to get RPC authentication"
    return 1
  fi
  
  # Check blockchain info
  BLOCKCHAIN_INFO=$(execute_rpc getblockchaininfo)
  if [ $? -ne 0 ]; then
    log "ERROR: Cannot get blockchain info from node"
    
    # Check for specific RPC issues
    if execute_rpc -getinfo 2>&1 | grep -q "Connection refused"; then
      log "RPC connection refused - check if RPC server is running and accessible"
      send_alert "rpc_connection" "RPC connection refused" "critical"
    elif execute_rpc -getinfo 2>&1 | grep -q "incorrect password"; then
      log "RPC authentication failed - check credentials"
      send_alert "rpc_auth" "RPC authentication failed" "critical"
    else
      log "Unknown RPC error, node may be starting or under heavy load"
      send_alert "rpc_error" "Cannot connect to RPC API" "critical"
    fi
    
    # Write status file
    cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_id": "$DISTRIBUTED_TRACE_ID",
  "status": "error",
  "error": "Cannot connect to RPC",
  "check_time": $(date +%s)
}
EOF
    
    return 1
  fi
  
  # Check network info
  NETWORK_INFO=$(execute_rpc getnetworkinfo)
  if [ $? -ne 0 ]; then
    log "ERROR: Cannot get network info from node"
    
    # Write status file
    cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_id": "$DISTRIBUTED_TRACE_ID",
  "status": "error",
  "error": "Cannot get network info",
  "check_time": $(date +%s)
}
EOF
    
    send_alert "network_info_error" "Cannot retrieve network information" "warning"
    return 1
  fi
  
  # Check mempool info
  MEMPOOL_INFO=$(execute_rpc getmempoolinfo)
  if [ $? -ne 0 ]; then
    log "ERROR: Cannot get mempool info from node"
    
    # Write status file
    cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_id": "$DISTRIBUTED_TRACE_ID",
  "status": "error",
  "error": "Cannot get mempool info",
  "check_time": $(date +%s)
}
EOF
    
    send_alert "mempool_info_error" "Cannot retrieve mempool information" "warning"
    return 1
  fi
  
  # Extract values with improved error handling
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
  
  # Extract blockchain data
  BLOCKS=$(extract_json_value "$BLOCKCHAIN_INFO" "blocks" "0")
  HEADERS=$(extract_json_value "$BLOCKCHAIN_INFO" "headers" "0")
  VERIFICATION_PROGRESS=$(extract_json_value "$BLOCKCHAIN_INFO" "verificationprogress" "0")
  CHAIN=$(extract_json_value "$BLOCKCHAIN_INFO" "chain" "unknown")
  
  # Extract network data
  CONNECTIONS=$(extract_json_value "$NETWORK_INFO" "connections" "0")
  VERSION=$(extract_json_value "$NETWORK_INFO" "version" "0")
  SUBVERSION=$(extract_json_value "$NETWORK_INFO" "subversion" "unknown")
  PROTOCOL_VERSION=$(extract_json_value "$NETWORK_INFO" "protocolversion" "0")
  
  # Extract mempool data
  MEMPOOL_SIZE=$(extract_json_value "$MEMPOOL_INFO" "size" "0")
  MEMPOOL_BYTES=$(extract_json_value "$MEMPOOL_INFO" "bytes" "0")
  MEMPOOL_USAGE=$(extract_json_value "$MEMPOOL_INFO" "usage" "0")
  MEMPOOL_MAX_MEM=$(extract_json_value "$MEMPOOL_INFO" "maxmempool" "300000000")
  
  # Calculate blocks behind
  BLOCKS_BEHIND=$((HEADERS - BLOCKS))
  
  # Check disk space
  DISK_SPACE_WARNING=false
  DISK_USAGE_PCT=0
  if [ "$CHECK_DISK_SPACE" = "true" ]; then
    AVAILABLE_SPACE_KB=$(df -k /home/meowcoin/.meowcoin | tail -1 | awk '{print $4}')
    AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE_KB / 1024 / 1024))
    TOTAL_SPACE_KB=$(df -k /home/meowcoin/.meowcoin | tail -1 | awk '{print $2}')
    TOTAL_SPACE_GB=$((TOTAL_SPACE_KB / 1024 / 1024))
    USED_SPACE_KB=$((TOTAL_SPACE_KB - AVAILABLE_SPACE_KB))
    DISK_USAGE_PCT=$((USED_SPACE_KB * 100 / TOTAL_SPACE_KB))
    
    if [ $AVAILABLE_SPACE_GB -lt $MIN_FREE_SPACE_GB ]; then
      DISK_SPACE_WARNING=true
      log "WARNING: Low disk space: ${AVAILABLE_SPACE_GB}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)"
      send_alert "low_disk_space" "Low disk space: ${AVAILABLE_SPACE_GB}GB available (minimum: ${MIN_FREE_SPACE_GB}GB)" "warning"
    fi
    
    # Check inode usage too (can be a hidden problem)
    INODE_USAGE_PCT=$(df -i /home/meowcoin/.meowcoin | tail -1 | awk '{print $5}' | tr -d '%')
    if [ $INODE_USAGE_PCT -gt 90 ]; then
      log "WARNING: High inode usage: ${INODE_USAGE_PCT}% (can prevent new file creation)"
      send_alert "high_inode_usage" "High inode usage: ${INODE_USAGE_PCT}% (can prevent new file creation)" "warning"
    fi
  fi
  
  # Check system resources if enabled
  if [ "$RESOURCE_CHECK_ENABLED" = "true" ]; then
    # Check CPU usage
    if command -v top >/dev/null 2>&1; then
      CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
      record_metric "cpu_usage" "$CPU_USAGE"
      
      if [ $(echo "$CPU_USAGE > $MAX_CPU_USAGE" | bc -l) -eq 1 ]; then
        log "WARNING: High CPU usage: ${CPU_USAGE}% (threshold: ${MAX_CPU_USAGE}%)"
        send_alert "high_cpu" "High CPU usage: ${CPU_USAGE}% (threshold: ${MAX_CPU_USAGE}%)" "warning"
      fi
      
      # Check for CPU anomalies
      if [ "$ANOMALY_DETECTION_ENABLED" = "true" ]; then
        if detect_anomaly "cpu_usage" "$CPU_USAGE" "2.5"; then
          send_alert "cpu_anomaly" "Unusual CPU usage pattern detected: ${CPU_USAGE}%" "warning"
        fi
        
        # Check for CPU usage trends
        if detect_trend_anomaly "cpu_usage"; then
          send_alert "cpu_trend" "Unusual CPU usage trend detected" "warning"
        fi
      fi
    fi
    
    # Check memory usage
    if command -v free >/dev/null 2>&1; then
      MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
      record_metric "memory_usage" "$MEMORY_USAGE"
      
      if [ $(echo "$MEMORY_USAGE > $MAX_MEMORY_USAGE" | bc -l) -eq 1 ]; then
        log "WARNING: High memory usage: ${MEMORY_USAGE}% (threshold: ${MAX_MEMORY_USAGE}%)"
        send_alert "high_memory" "High memory usage: ${MEMORY_USAGE}% (threshold: ${MAX_MEMORY_USAGE}%)" "warning"
      fi
      
      # Check for memory anomalies
      if [ "$ANOMALY_DETECTION_ENABLED" = "true" ]; then
        if detect_anomaly "memory_usage" "$MEMORY_USAGE" "2.5"; then
          send_alert "memory_anomaly" "Unusual memory usage pattern detected: ${MEMORY_USAGE}%" "warning"
        fi
      fi
    fi
    
    # Check disk I/O
    if command -v iostat >/dev/null 2>&1; then
      DISK_IO=$(iostat -x | grep -A 1 "avg-cpu" | tail -1 | awk '{print $14}')
      record_metric "disk_io" "$DISK_IO"
      
      if [ $(echo "$DISK_IO > $DISK_IO_THRESHOLD" | bc -l) -eq 1 ]; then
        log "WARNING: High disk I/O utilization: ${DISK_IO}% (threshold: ${DISK_IO_THRESHOLD}%)"
        send_alert "high_disk_io" "High disk I/O: ${DISK_IO}% (threshold: ${DISK_IO_THRESHOLD}%)" "warning"
      fi
    fi
  fi
  
  # Record all core metrics
  record_metric "blocks" "$BLOCKS"
  record_metric "headers" "$HEADERS"
  record_metric "blocks_behind" "$BLOCKS_BEHIND"
  record_metric "connections" "$CONNECTIONS"
  record_metric "mempool_size" "$MEMPOOL_SIZE"
  record_metric "mempool_bytes" "$MEMPOOL_BYTES"
  record_metric "disk_usage" "$DISK_USAGE_PCT"
  record_metric "verification_progress" "$VERIFICATION_PROGRESS"
  record_metric "mempool_usage" "$MEMPOOL_USAGE"
  
  # Analyze connected peers
  if [ $CONNECTIONS -gt 0 ]; then
    # Get detailed peer info
    PEER_INFO=$(execute_rpc getpeerinfo)
    if [ $? -eq 0 ]; then
      # Count inbound vs outbound connections
      if command -v jq >/dev/null 2>&1; then
        INBOUND=$(echo "$PEER_INFO" | jq '[.[] | select(.inbound == true)] | length')
        OUTBOUND=$(echo "$PEER_INFO" | jq '[.[] | select(.inbound == false)] | length')
        
        # Check connection distribution
        record_metric "inbound_connections" "$INBOUND"
        record_metric "outbound_connections" "$OUTBOUND"
        
        if [ $INBOUND -eq 0 ]; then
          log "WARNING: No inbound connections - check port forwarding"
          send_alert "no_inbound" "No inbound connections - check port forwarding" "warning"
        fi
        
        if [ $OUTBOUND -eq 0 ]; then
          log "WARNING: No outbound connections - check firewall/network"
          send_alert "no_outbound" "No outbound connections - check firewall/network" "warning"
        fi
        
        # Check for banned peers
        BANNED_INFO=$(execute_rpc listbanned)
        if [ $? -eq 0 ]; then
          BANNED_COUNT=$(echo "$BANNED_INFO" | jq '. | length')
          record_metric "banned_peers" "$BANNED_COUNT"
          
          if [ $BANNED_COUNT -gt 10 ]; then
            log "WARNING: High number of banned peers: $BANNED_COUNT"
            send_alert "high_banned" "High number of banned peers: $BANNED_COUNT" "warning"
          fi
        fi
      fi
    fi
  fi
  
  # Get uptime information
  UPTIME_INFO=$(execute_rpc uptime)
  if [ $? -eq 0 ]; then
    record_metric "node_uptime" "$UPTIME_INFO"
  fi
  
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
    "disk_space_warning": $DISK_SPACE_WARNING
  },
  "status": "unknown"
}
EOF
  
  # Evaluate health with improved detection
  HEALTH_ISSUES=0
  ALERT_SEVERITY="info"
  
  # Check if node is in sync
  if [ $BLOCKS_BEHIND -gt $MAX_BLOCKS_BEHIND ]; then
    log "WARNING: Node is $BLOCKS_BEHIND blocks behind headers"
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
    log "WARNING: Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    ALERT_SEVERITY="warning"
    sed -i 's/"status": "unknown"/"status": "low_peers"/' "$STATUS_FILE"
    send_alert "low_peers" "Only $CONNECTIONS peer connections (minimum: $MIN_PEERS)" "warning"
  fi
  
  # Check mempool size
  if [ $MEMPOOL_SIZE -gt $MAX_MEMPOOL_SIZE ]; then
    log "WARNING: Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    sed -i 's/"status": "unknown"/"status": "high_mempool"/' "$STATUS_FILE"
    send_alert "high_mempool" "Mempool has $MEMPOOL_SIZE transactions (maximum: $MAX_MEMPOOL_SIZE)" "warning"
  fi
  
  # Check mempool memory usage
  MEMPOOL_USAGE_PCT=$(echo "scale=2; $MEMPOOL_USAGE * 100 / $MEMPOOL_MAX_MEM" | bc)
  if (( $(echo "$MEMPOOL_USAGE_PCT > 90" | bc -l) )); then
    log "WARNING: High mempool memory usage: ${MEMPOOL_USAGE_PCT}% of maximum"
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    send_alert "high_mempool_mem" "High mempool memory usage: ${MEMPOOL_USAGE_PCT}% of maximum" "warning"
  fi
  
  # Check disk space
  if [ "$DISK_SPACE_WARNING" = "true" ]; then
    HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
    ALERT_SEVERITY="warning"
    sed -i 's/"status": "unknown"/"status": "low_disk_space"/' "$STATUS_FILE"
  fi
  
  # Check for stalled sync if enabled
  if [ "$ALERT_ON_SYNC_STALLED" = "true" ] && [ $BLOCKS_BEHIND -gt 0 ]; then
    if [ -f "/tmp/meowcoin_last_block" ]; then
      LAST_BLOCK=$(cat /tmp/meowcoin_last_block)
      LAST_CHECK_TIME=$(cat /tmp/meowcoin_last_check_time 2>/dev/null || echo "0")
      CURRENT_TIME=$(date +%s)
      
      # Only check for stall if enough time has passed
      if [ $((CURRENT_TIME - LAST_CHECK_TIME)) -gt 300 ]; then
        if [ "$LAST_BLOCK" = "$BLOCKS" ]; then
          log "WARNING: Sync appears stalled - block height hasn't changed since last check"
          HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
          ALERT_SEVERITY="warning"
          sed -i 's/"status": "unknown"/"status": "sync_stalled"/' "$STATUS_FILE"
          send_alert "sync_stalled" "Sync appears stalled - block height hasn't changed since last check" "warning"
          
          # Check if verification progress is still changing
          if [ -f "/tmp/meowcoin_last_verification" ]; then
            LAST_VERIFICATION=$(cat /tmp/meowcoin_last_verification)
            if (( $(echo "$VERIFICATION_PROGRESS - $LAST_VERIFICATION < 0.0001" | bc -l) )); then
              log "WARNING: Verification progress also stalled"
              send_alert "sync_frozen" "Blockchain verification appears frozen" "critical"
            fi
          fi
        fi
        
        # Update last check time
        echo "$CURRENT_TIME" > /tmp/meowcoin_last_check_time
        echo "$VERIFICATION_PROGRESS" > /tmp/meowcoin_last_verification
      fi
    fi
    
    # Update last block
    echo "$BLOCKS" > /tmp/meowcoin_last_block
  fi
  
  # Check for unusual changes in metrics if anomaly detection enabled
  if [ "$ANOMALY_DETECTION_ENABLED" = "true" ]; then
    # Check for unusual drop in peer count
    if detect_anomaly "connections" "$CONNECTIONS" "3.0"; then
      log "WARNING: Unusual change in peer connections detected"
      HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
      send_alert "peer_anomaly" "Unusual change in peer connections detected: $CONNECTIONS" "warning"
    fi
    
    # Check for unusual mempool growth
    if detect_anomaly "mempool_size" "$MEMPOOL_SIZE" "3.0"; then
      log "WARNING: Unusual mempool growth detected"
      HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
      send_alert "mempool_anomaly" "Unusual mempool growth detected: $MEMPOOL_SIZE transactions" "warning"
    fi
    
    # Check for unusual disk usage growth
    if detect_anomaly "disk_usage" "$DISK_USAGE_PCT" "2.0"; then
      log "WARNING: Unusual disk usage growth detected"
      HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
      send_alert "disk_anomaly" "Unusual disk usage growth detected: ${DISK_USAGE_PCT}%" "warning"
    fi
    
    # Look for trend anomalies
    if detect_trend_anomaly "disk_usage"; then
      log "WARNING: Disk usage showing significant trend"
      HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
      send_alert "disk_trend" "Disk usage showing significant trend" "warning"
    fi
  fi
  
  # Check log file for error patterns
  if [ -f "/home/meowcoin/.meowcoin/debug.log" ]; then
    # Check last 100 lines for critical errors
    ERROR_COUNT=$(tail -n 100 "/home/meowcoin/.meowcoin/debug.log" | grep -c -E "ERROR:|EXCEPTION:|core dumped|segmentation fault|fatal error")
    if [ $ERROR_COUNT -gt 0 ]; then
      log "WARNING: Found $ERROR_COUNT error(s) in recent log entries"
      HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
      ALERT_SEVERITY="warning"
      
      # Extract last error for alert
      LAST_ERROR=$(tail -n 100 "/home/meowcoin/.meowcoin/debug.log" | grep -E "ERROR:|EXCEPTION:|core dumped|segmentation fault|fatal error" | tail -1)
      send_alert "log_errors" "Found errors in logs: $LAST_ERROR" "warning"
    fi
  fi
  
  # Final health determination
  if [ $HEALTH_ISSUES -eq 0 ]; then
    # Node is healthy
    sed -i 's/"status": "unknown"/"status": "healthy"/' "$STATUS_FILE"
    log "Node is healthy: $BLOCKS blocks, $CONNECTIONS peers, $MEMPOOL_SIZE mempool transactions"
    
    # Send periodic health status (if alerting enabled and not sent recently)
    if [ "${ENABLE_ALERTS:-true}" = "true" ] && [ "${PERIODIC_HEALTH_ALERTS:-true}" = "true" ]; then
      LAST_HEALTHY_ALERT=0
      if [ -f "$ALERT_HISTORY" ]; then
        LAST_HEALTHY_ALERT=$(jq -r '.healthy.timestamp // 0' "$ALERT_HISTORY")
      fi
      
      CURRENT_TIME=$(date +%s)
      if [ $((CURRENT_TIME - LAST_HEALTHY_ALERT)) -gt $((3600 * 24)) ]; then  # Once per day
        send_alert "healthy" "Node is healthy: $BLOCKS blocks, $CONNECTIONS peers, $MEMPOOL_SIZE mempool transactions" "info"
      fi
    fi
    
    # Execute plugin hooks
    if [ -x /usr/local/bin/entrypoint/plugins.sh ]; then
      TRACE_ID="$DISTRIBUTED_TRACE_ID" HOOK_ARGS="healthy" /usr/local/bin/entrypoint/plugins.sh execute_hooks "health_check"
    fi
    
    return 0
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
    
    return 1
  fi
}

# Main execution - run the health check
run_health_check
exit $?